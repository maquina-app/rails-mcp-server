module RailsMcpServer
  class ExecuteRuby < BaseTool
    tool_name "execute_ruby"

    description <<~DESC
      Execute Ruby code in the context of the Rails project, for inspection and
      exploration. Use this for:
      - Complex queries that would require multiple tool calls
      - Filtering/transforming data before returning
      - Custom exploration of the codebase

      This runs with the privileges of the rails-mcp-server process. The
      restrictions below are best-effort guardrails against accidental writes
      and obvious escapes, not a security boundary for untrusted code; only run
      code you would run yourself.

      RESTRICTIONS:
      - Cannot create, modify, or delete files
      - Cannot read .env, credentials, key files, or .gitignore'd files
      - Cannot access files outside the project directory (read-only system data
        such as timezone files under /usr/share/zoneinfo is allowed)
      - Cannot execute shell commands or system calls
      - Can only `require` a small allowlist of standard-library data helpers
        (json, set, yaml, csv, digest, ...); require_relative is not permitted
      - Database writes run inside a transaction that is always rolled back, so
        treat this as read-only for data too (note: DDL may still commit on some
        adapters, and after_commit callbacks do not fire)

      HELPER METHODS AVAILABLE:
      - read_file(path) - safely read a file
      - file_exists?(path) - check if file exists (false for sensitive files)
      - list_files(pattern) - glob files safely, e.g., list_files('app/models/**/*.rb')
      - project_root - returns the project root path

      NOTE: Use `puts` to see output, e.g., puts read_file('Gemfile')

      Some dual-use constructs (Kernel#open, send, public_send, const_get) are
      not run immediately: the tool returns a CONFIRMATION REQUIRED message
      explaining the risk. Re-invoke with confirm_risky: true only after the
      user has reviewed the code and approved it.
    DESC

    arguments do
      required(:code).filled(:string).description("Ruby code to execute (inspection operations only)")
      optional(:timeout).filled(:integer).description("Timeout in seconds. Default: 30, Max: 60")
      optional(:confirm_risky).filled(:bool).description("Set true ONLY after the user has explicitly approved running code that uses sandbox-bypass-capable constructs (send, public_send, const_get, Kernel#open). When false/absent, such code is not executed; the tool returns a CONFIRMATION REQUIRED message instead.")
    end

    # Patterns that indicate dangerous operations
    FORBIDDEN_PATTERNS = [
      # File/IO writing
      /File\.(write|open|new)\s*\([^)]*['"][wa+]/i,
      /File\.(delete|unlink|rename|chmod|chown|truncate)/i,
      /FileUtils\./i,
      /IO\.(write|syswrite|popen|pipe)/i,
      /\.(write|puts|print|syswrite)\s*[(\s]/,

      # Directory modification
      /Dir\.(mkdir|rmdir|delete|chdir)/i,

      # System/shell execution
      /system\s*[(\s]/,
      /exec\s*[(\s]/,
      /`[^`]+`/,
      /%x[{(\[]/,
      /Kernel\.(system|exec|spawn|`)/,
      /Open3\./i,
      /IO\.popen/i,
      /Process\.(spawn|exec|fork)/i,
      /Shellwords/i,

      # Pseudo-terminals and native/syscall bridges. PTY.spawn / PTY.getpty
      # start a child process outside the Kernel#system guard; Fiddle and FFI
      # can call libc (e.g. system(3), execve(2)) directly. None of these are
      # needed for read-only inspection.
      /\bPTY\b/,
      /\bFiddle\b/,
      /\bFFI\b/,

      # Dynamic dispatch aimed at an execution/eval sink *by name* is hard
      # blocked. The general send/public_send/const_get forms stay in the
      # confirmation tier below; only a dangerous literal target is rejected
      # outright, so `record.send(:name)` still works while
      # `Process.send(:spawn, ...)` or `const_get("Open3")` do not.
      /\b(?:public_send|__send__|send)\s*(?:\(\s*)?[:'"](?:system|exec|spawn|fork|eval|popen|syscall|`)/i,
      /\bconst_get\s*(?:\(\s*)?['"](?:Open3|Process|PTY|Kernel|Socket|Fiddle|FFI|Binding|ObjectSpace|TCPSocket|UDPSocket)\b/i,

      # Network access
      /Net::(HTTP|FTP|SMTP)/i,
      /URI\.(open|parse)/i,
      /HTTParty/i,
      /Faraday/i,
      /RestClient/i,
      /open-uri/i,
      /Socket/i,
      /TCPSocket/i,
      /UDPSocket/i,

      # Dangerous Ruby features
      /eval\s*[(\s]/,
      /instance_eval/i,
      /class_eval/i,
      /module_eval/i,
      /define_method/i,
      /send\s*[(\s]+[:'"]*(system|exec|`)/i,
      /__send__/,
      /ObjectSpace/i,
      /Binding/i,
      /set_trace_func/i,

      # Environment/credentials access
      # Match any ENV usage (ENV[, ENV.fetch, ENV.to_h, ENV.values_at, ENV.each,
      # ...). Case-sensitive so it doesn't flag `Rails.env` or a local `env`.
      /\bENV\b/,
      /Rails\.application\.credentials/i,
      /Rails\.application\.secrets/i,

      # Load/require that could execute arbitrary code
      /load\s*[(\s]+[^)]*\$/i,
      /require\s+[^'"]/i
    ].freeze

    # Only these libraries may be `require`d from executed code. Everything
    # else is rejected: the code runs under `bin/rails runner`, so Rails and
    # the app's own gems are already loaded and inspection rarely needs to
    # require anything. An allowlist closes stdlib escalation paths the pattern
    # denylist cannot enumerate — e.g. `require "pty"` (PTY.spawn),
    # `require "fiddle"`/`"ffi"` (raw libc calls), `require "open3"`. Matched
    # case-insensitively; a trailing ".rb" is ignored.
    REQUIRE_ALLOWLIST = %w[
      json set date time bigdecimal ostruct pp yaml csv
      digest securerandom base64 abbrev
    ].freeze

    # Extracts require/require_relative statements with a *literal* target in
    # any of `require "x"`, `require'x'`, `require("x")` forms. Dynamic targets
    # (no literal) are already rejected by the /require\s+[^'"]/ pattern above.
    REQUIRE_STATEMENT = /\b(require|require_relative)\b\s*(?:\(\s*)?(['"])([^'"]+)\2/

    # Dual-use constructs that are NOT hard-blocked (they have legitimate
    # read-only uses) but can defeat the static safety scan, so running them
    # requires explicit user confirmation via confirm_risky: true.
    # Each entry: [pattern, label, why-it-is-risky].
    CONFIRMATION_REQUIRED_PATTERNS = [
      [/(?<![.\w])open\s*\(/, "Kernel#open",
        "`open(arg)` runs a shell command when arg begins with '|', and can open network/URI targets — both escape the sandbox."],
      [/\bpublic_send\b/, "public_send",
        "dynamic dispatch can invoke methods the static scan cannot see, e.g. reaching blocked system/file APIs indirectly."],
      [/\bsend\s*[(\s]/, "send",
        "dynamic dispatch can invoke methods the static scan cannot see, e.g. reaching blocked system/file APIs indirectly."],
      [/\bconst_get\b/, "const_get",
        "resolves constants by name at runtime, which can reach classes the static scan would otherwise block."]
    ].freeze

    # Sensitive file patterns (in addition to .gitignore)
    SENSITIVE_PATTERNS = [
      /\.env(\..*)?$/i,
      /\.key$/i,
      /\.pem$/i,
      /\.crt$/i,
      /\.p12$/i,
      /credentials\.yml/i,
      /secrets\.yml/i,
      /master\.key/i,
      /config\/credentials/i,
      /config\/secrets/i,
      /\.secret$/i,
      /password/i,
      /\.ssh\//i,
      /id_rsa/i,
      /id_ed25519/i
    ].freeze

    # Read-only system data directories the sandbox may read. TZInfo lazily
    # loads IANA timezone data on first Time.zone use; these are its default
    # search paths plus /var/db/timezone, the real location behind macOS's
    # /usr/share/zoneinfo symlink. Writes remain blocked by the File/Dir/
    # FileUtils overrides.
    ALLOWED_READ_PATHS = %w[
      /usr/share/zoneinfo
      /usr/share/lib/zoneinfo
      /etc/zoneinfo
      /var/db/timezone
    ].freeze

    NO_OUTPUT_MESSAGE = <<~MSG
      Code executed successfully (no output).

      Hint: Use `puts` to see results, e.g.:
        puts read_file('config/routes.rb')
        puts User.count
        puts Dir.glob('app/models/*.rb')
    MSG

    def call(code:, timeout: 30, confirm_risky: false)
      unless current_project
        return "No active project. Please switch to a project first."
      end

      timeout = [timeout.to_i, 60].min # Cap at 60 seconds
      timeout = 10 if timeout < 1

      # Step 1: Static analysis - reject outright-dangerous code
      validation_error = validate_code_safety(code)
      return validation_error if validation_error

      # Step 2: Dual-use constructs require explicit user confirmation
      unless confirm_risky
        confirmation = confirmation_required(code)
        return confirmation if confirmation
      end

      # Step 3: Build the sandboxed execution environment
      sandbox_code = build_sandbox(code)

      # Step 4: Execute with timeout
      execute_sandboxed(sandbox_code, timeout)
    end

    private

    def validate_code_safety(code)
      FORBIDDEN_PATTERNS.each do |pattern|
        if code.match?(pattern)
          return "REJECTED: Code contains forbidden pattern (#{pattern.source.split("\\").first}...). " \
                 "This tool only allows a restricted set of inspection operations."
        end
      end

      validate_requires(code)
    end

    # Rejects `require_relative` (which loads and executes arbitrary project
    # Ruby) and any `require` of a library outside REQUIRE_ALLOWLIST. Returns an
    # error string, or nil when every require statement is permitted.
    def validate_requires(code)
      code.scan(REQUIRE_STATEMENT).each do |method, _quote, lib|
        if method == "require_relative"
          return "REJECTED: require_relative is not permitted; it loads and executes arbitrary project files."
        end

        normalized = lib.downcase.sub(/\.rb\z/, "")
        unless REQUIRE_ALLOWLIST.include?(normalized)
          return "REJECTED: require of '#{lib}' is not permitted. " \
                 "Only these libraries may be required: #{REQUIRE_ALLOWLIST.join(", ")}."
        end
      end
      nil
    end

    # Returns a message asking the model to confirm with the user when the code
    # uses dual-use constructs, or nil when there is nothing to confirm.
    def confirmation_required(code)
      matched = CONFIRMATION_REQUIRED_PATTERNS.select { |pattern, _label, _reason| code.match?(pattern) }
      return nil if matched.empty?

      details = matched.map { |_pattern, label, reason| "  - `#{label}`: #{reason}" }.join("\n")

      <<~MSG
        CONFIRMATION REQUIRED: This code uses constructs that can bypass the sandbox's static safety checks:

        #{details}

        These are not blocked outright because they have legitimate read-only uses, but they can reach APIs the safety scan would otherwise stop. Ask the user to review the code and confirm they want to run it. If they approve, re-invoke execute_ruby with confirm_risky: true. Do not set confirm_risky yourself without the user's explicit approval.
      MSG
    end

    def build_sandbox(user_code)
      gitignore_patterns = parse_gitignore
      all_patterns = SENSITIVE_PATTERNS.map(&:source) + gitignore_patterns
      sensitive_patterns_ruby = all_patterns.map { |p| "Regexp.new(#{p.inspect}, Regexp::IGNORECASE)" }.join(",\n      ")

      <<~RUBY
        require "stringio" # the File.open override below yields StringIO objects

        # Sandbox wrapper for safe execution
        module McpSandbox
          # realpath-normalized so symlink resolution below compares against the
          # canonical root (e.g. macOS /var -> /private/var) rather than a path
          # that would never prefix-match a resolved target.
          PROJECT_ROOT = File.realpath(#{active_project_path.inspect}).freeze

          ALLOWED_READ_PATHS = #{ALLOWED_READ_PATHS.inspect}.freeze

          # realpath-resolved forms of the allowlist, so a resolved target still
          # matches when the allowed dir is itself a symlink (e.g. macOS
          # /usr/share/zoneinfo -> /private/var/db/timezone/.../zoneinfo).
          CANONICAL_ALLOWED_READ_PATHS = ALLOWED_READ_PATHS.map { |dir|
            File.exist?(dir) ? File.realpath(dir) : dir
          }.freeze

          SENSITIVE_PATTERNS = [
            #{sensitive_patterns_ruby}
          ].freeze

          # Native method handles captured *before* the File/Dir overrides below
          # replace them. Held in private constants so sandboxed user code has no
          # public `File.original_read`-style alias to call the raw method back.
          ORIGINAL_FILE_READ      = File.method(:read)
          ORIGINAL_FILE_READLINES = File.method(:readlines)
          ORIGINAL_FILE_BINREAD   = File.method(:binread)
          ORIGINAL_FILE_EXIST     = File.method(:exist?)
          ORIGINAL_FILE_DIRECTORY = File.method(:directory?)
          ORIGINAL_FILE_FILE      = File.method(:file?)
          ORIGINAL_FILE_REALPATH  = File.method(:realpath)
          ORIGINAL_DIR_GLOB       = Dir.method(:glob)
          ORIGINAL_DIR_ENTRIES    = Dir.method(:entries)
          private_constant :ORIGINAL_FILE_READ, :ORIGINAL_FILE_READLINES,
            :ORIGINAL_FILE_BINREAD, :ORIGINAL_FILE_EXIST, :ORIGINAL_FILE_DIRECTORY,
            :ORIGINAL_FILE_FILE, :ORIGINAL_FILE_REALPATH, :ORIGINAL_DIR_GLOB,
            :ORIGINAL_DIR_ENTRIES

          class PathViolation < StandardError; end
          class SensitiveFileViolation < StandardError; end
          class WriteViolation < StandardError; end

          module_function

          # Resolve symlinks so a link *inside* the project cannot be used to
          # read a target outside it. realpath needs the path to exist, so for a
          # not-yet-existing path resolve the deepest existing ancestor and
          # re-append the remainder (which still catches a symlinked ancestor).
          def resolve_symlinks(expanded)
            return ORIGINAL_FILE_REALPATH.call(expanded) if ORIGINAL_FILE_EXIST.call(expanded)

            parent = File.dirname(expanded)
            return expanded if parent == expanded

            File.join(resolve_symlinks(parent), File.basename(expanded))
          end

          def validate_path!(path)
            expanded = File.expand_path(path, PROJECT_ROOT)
            resolved = resolve_symlinks(expanded)

            if (ALLOWED_READ_PATHS + CANONICAL_ALLOWED_READ_PATHS).any? { |dir| resolved == dir || resolved.start_with?(dir + "/") }
              return resolved
            end

            unless resolved.start_with?(PROJECT_ROOT + "/") || resolved == PROJECT_ROOT
              raise PathViolation, "Access denied: path '\#{path}' is outside project directory"
            end

            relative_path = resolved.sub(PROJECT_ROOT + "/", "")

            SENSITIVE_PATTERNS.each do |pattern|
              if relative_path.match?(pattern)
                raise SensitiveFileViolation, "Access denied: '\#{relative_path}' matches sensitive file pattern"
              end
            end

            resolved
          end

          def safe_read(path)
            ORIGINAL_FILE_READ.call(validate_path!(path))
          end

          def safe_readlines(path)
            ORIGINAL_FILE_READLINES.call(validate_path!(path))
          end

          def safe_binread(path)
            ORIGINAL_FILE_BINREAD.call(validate_path!(path))
          end

          def safe_foreach(path, &block)
            lines = safe_readlines(path)
            return lines.each unless block

            lines.each(&block)
          end

          def safe_exist?(path)
            ORIGINAL_FILE_EXIST.call(validate_path!(path))
          rescue PathViolation, SensitiveFileViolation
            false
          end

          def safe_directory?(path)
            ORIGINAL_FILE_DIRECTORY.call(validate_path!(path))
          rescue PathViolation, SensitiveFileViolation
            false
          end

          def safe_file?(path)
            ORIGINAL_FILE_FILE.call(validate_path!(path))
          rescue PathViolation, SensitiveFileViolation
            false
          end

          def safe_glob(pattern, base: PROJECT_ROOT)
            ORIGINAL_DIR_GLOB.call(File.join(base, pattern)).select do |path|
              validate_path!(path)
              true
            rescue PathViolation, SensitiveFileViolation
              false
            end
          end

          def safe_entries(path)
            ORIGINAL_DIR_ENTRIES.call(validate_path!(path)).reject { |e| e.start_with?(".") }
          end

          # True only when ActiveRecord is loaded *and* a connection can be
          # obtained, so we never turn a pure-Ruby read-only snippet into a
          # database connection error just to wrap it in a transaction.
          def database_available?
            return false unless defined?(ActiveRecord::Base)

            ActiveRecord::Base.connection
            true
          rescue StandardError
            false
          end

          # Run the block inside a transaction that is *always* rolled back, so
          # accidental writes are undone. Harm reduction, not a guarantee: DDL
          # auto-commits on some adapters (e.g. MySQL) and after_commit
          # callbacks are suppressed. Falls back to a plain call when no
          # database is available. Real exceptions still propagate (and also
          # trigger the rollback).
          def readonly_guard
            return yield unless database_available?

            result = nil
            ActiveRecord::Base.transaction do
              result = yield
              raise ActiveRecord::Rollback
            end
            result
          end
        end

        # Override File class methods
        class File
          class << self
            def read(path, *args)
              McpSandbox.safe_read(path)
            end

            def readlines(path, *args)
              McpSandbox.safe_readlines(path)
            end

            def binread(path, *args)
              McpSandbox.safe_binread(path)
            end

            def foreach(path, *args, &block)
              McpSandbox.safe_foreach(path, &block)
            end

            def exist?(path)
              McpSandbox.safe_exist?(path)
            end

            def directory?(path)
              McpSandbox.safe_directory?(path)
            end

            def file?(path)
              McpSandbox.safe_file?(path)
            end

            # Block all write operations
            [:write, :delete, :unlink, :rename, :chmod, :chown, :truncate].each do |method|
              define_method(method) do |*args, &block|
                raise McpSandbox::WriteViolation, "Write operations are not permitted: File.\#{method}"
              end
            end

            # Handle open specially - allow read-only mode
            def open(path, mode = "r", *args, &block)
              if mode.to_s =~ /[wa+]/
                raise McpSandbox::WriteViolation, "Write operations are not permitted: File.open with mode '\#{mode}'"
              end
              content = McpSandbox.safe_read(path)
              if block_given?
                yield StringIO.new(content)
              else
                StringIO.new(content)
              end
            end
          end
        end

        # Override Dir class methods
        class Dir
          class << self
            def glob(pattern, *args)
              McpSandbox.safe_glob(pattern)
            end

            def entries(path)
              McpSandbox.safe_entries(path)
            end

            [:mkdir, :rmdir, :delete, :chdir].each do |method|
              define_method(method) do |*args|
                raise McpSandbox::WriteViolation, "Directory modifications are not permitted: Dir.\#{method}"
              end
            end
          end
        end

        # Override IO read entry points. File < IO, but IO.read / IO.readlines /
        # IO.binread / IO.foreach are separate class methods that bypass the File
        # overrides above, so they must be sandboxed independently.
        class IO
          class << self
            def read(path, *args)
              McpSandbox.safe_read(path)
            end

            def readlines(path, *args)
              McpSandbox.safe_readlines(path)
            end

            def binread(path, *args)
              McpSandbox.safe_binread(path)
            end

            def foreach(path, *args, &block)
              McpSandbox.safe_foreach(path, &block)
            end
          end
        end

        # Block FileUtils entirely
        if defined?(FileUtils)
          module FileUtils
            class << self
              def method_missing(method, *args)
                raise McpSandbox::WriteViolation, "FileUtils operations are not permitted"
              end
            end
          end
        end

        # Block system calls at Kernel level
        module Kernel
          def system(*args)
            raise McpSandbox::WriteViolation, "System calls are not permitted"
          end

          def exec(*args)
            raise McpSandbox::WriteViolation, "System calls are not permitted"
          end

          def spawn(*args)
            raise McpSandbox::WriteViolation, "System calls are not permitted"
          end

          def `(cmd)
            raise McpSandbox::WriteViolation, "Shell execution is not permitted"
          end
        end

        # Block backticks at Object level
        class Object
          def `(cmd)
            raise McpSandbox::WriteViolation, "Shell execution is not permitted"
          end
        end

        # Provide convenient aliases for sandboxed operations
        def read_file(path)
          McpSandbox.safe_read(path)
        end

        def file_exists?(path)
          McpSandbox.safe_exist?(path)
        end

        def list_files(pattern)
          McpSandbox.safe_glob(pattern)
        end

        def project_root
          McpSandbox::PROJECT_ROOT
        end

        # ============ USER CODE BELOW ============
        # Wrapped in an always-rolled-back transaction so accidental DB writes
        # (delete_all, update, save, raw DML) are undone. See McpSandbox
        # .readonly_guard for the caveats; it's a no-op without a database.
        begin
          McpSandbox.readonly_guard do
            #{user_code}
          end
        rescue McpSandbox::PathViolation => e
          puts "PATH ERROR: \#{e.message}"
        rescue McpSandbox::SensitiveFileViolation => e
          puts "ACCESS DENIED: \#{e.message}"
        rescue McpSandbox::WriteViolation => e
          puts "WRITE ERROR: \#{e.message}"
        rescue => e
          puts "ERROR: \#{e.class} - \#{e.message}"
        end
      RUBY
    end

    def parse_gitignore
      gitignore_path = File.join(active_project_path, ".gitignore")
      return [] unless File.exist?(gitignore_path)

      File.readlines(gitignore_path)
        .map(&:strip)
        .reject { |line| line.empty? || line.start_with?("#") } # rubocop:disable Performance/ChainArrayAllocation
        .map { |pattern| convert_gitignore_to_regex(pattern) } # rubocop:disable Performance/ChainArrayAllocation
    end

    def convert_gitignore_to_regex(pattern)
      # Convert gitignore glob pattern to regex
      regex = Regexp.escape(pattern)
        .gsub('\*\*', ".*")           # ** matches everything
        .gsub('\*', "[^/]*")          # * matches within directory
        .gsub('\?', ".")              # ? matches single char
        .gsub(/^\//, "^")             # Leading / anchors to root

      # If pattern doesn't start with /, it can match anywhere
      regex = "(?:^|/)" + regex unless pattern.start_with?("/")

      regex
    end

    def execute_sandboxed(code, timeout)
      require "tempfile"

      Tempfile.create(["mcp_sandbox", ".rb"]) do |f|
        f.write(code)
        f.flush

        # RunProcess enforces the timeout by killing the whole process group, so
        # a runaway `rails runner` is actually terminated rather than orphaned.
        result = RailsMcpServer::RunProcess.execute_rails_command(
          active_project_path,
          "bin/rails runner #{f.path} 2>&1",
          timeout: timeout
        )
        result.to_s.empty? ? NO_OUTPUT_MESSAGE : result
      end
    end
  end
end
