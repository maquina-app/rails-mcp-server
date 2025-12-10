module RailsMcpServer
  class ExecuteRuby < BaseTool
    tool_name "execute_ruby"

    description <<~DESC
      Execute read-only Ruby code in the context of the Rails project. Use this for:
      - Complex queries that would require multiple tool calls
      - Filtering/transforming data before returning
      - Custom exploration of the codebase

      RESTRICTIONS:
      - Cannot create, modify, or delete files
      - Cannot read .env, credentials, key files, or .gitignore'd files
      - Cannot access files outside the project directory
      - Cannot execute shell commands or system calls

      HELPER METHODS AVAILABLE:
      - read_file(path) - safely read a file
      - file_exists?(path) - check if file exists (false for sensitive files)
      - list_files(pattern) - glob files safely, e.g., list_files('app/models/**/*.rb')
      - project_root - returns the project root path

      NOTE: Use `puts` to see output, e.g., puts read_file('Gemfile')
    DESC

    arguments do
      required(:code).filled(:string).description("Ruby code to execute (read-only operations only)")
      optional(:timeout).filled(:integer).description("Timeout in seconds. Default: 30, Max: 60")
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
      /ENV\[/i,
      /ENV\.fetch/i,
      /Rails\.application\.credentials/i,
      /Rails\.application\.secrets/i,

      # Load/require that could execute arbitrary code
      /load\s*[(\s]+[^)]*\$/i,
      /require\s+[^'"]/i
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

    NO_OUTPUT_MESSAGE = <<~MSG
      Code executed successfully (no output).

      Hint: Use `puts` to see results, e.g.:
        puts read_file('config/routes.rb')
        puts User.count
        puts Dir.glob('app/models/*.rb')
    MSG

    def call(code:, timeout: 30)
      unless current_project
        return "No active project. Please switch to a project first."
      end

      timeout = [timeout.to_i, 60].min # Cap at 60 seconds
      timeout = 10 if timeout < 1

      # Step 1: Static analysis - reject dangerous code
      validation_error = validate_code_safety(code)
      return validation_error if validation_error

      # Step 2: Build the sandboxed execution environment
      sandbox_code = build_sandbox(code)

      # Step 3: Execute with timeout
      execute_sandboxed(sandbox_code, timeout)
    end

    private

    def validate_code_safety(code)
      FORBIDDEN_PATTERNS.each do |pattern|
        if code.match?(pattern)
          return "REJECTED: Code contains forbidden pattern (#{pattern.source.split("\\").first}...). " \
                 "This tool only allows read-only operations."
        end
      end
      nil
    end

    def build_sandbox(user_code)
      gitignore_patterns = parse_gitignore
      all_patterns = SENSITIVE_PATTERNS.map(&:source) + gitignore_patterns
      sensitive_patterns_ruby = all_patterns.map { |p| "Regexp.new(#{p.inspect}, Regexp::IGNORECASE)" }.join(",\n      ")

      <<~RUBY
        # Sandbox wrapper for safe execution
        module McpSandbox
          PROJECT_ROOT = #{active_project_path.inspect}.freeze

          SENSITIVE_PATTERNS = [
            #{sensitive_patterns_ruby}
          ].freeze

          class PathViolation < StandardError; end
          class SensitiveFileViolation < StandardError; end
          class WriteViolation < StandardError; end

          module_function

          def validate_path!(path)
            expanded = File.expand_path(path, PROJECT_ROOT)

            unless expanded.start_with?(PROJECT_ROOT + "/") || expanded == PROJECT_ROOT
              raise PathViolation, "Access denied: path '\#{path}' is outside project directory"
            end

            relative_path = expanded.sub(PROJECT_ROOT + "/", "")

            SENSITIVE_PATTERNS.each do |pattern|
              if relative_path.match?(pattern)
                raise SensitiveFileViolation, "Access denied: '\#{relative_path}' matches sensitive file pattern"
              end
            end

            expanded
          end

          def safe_read(path)
            validated_path = validate_path!(path)
            File.original_read(validated_path)
          end

          def safe_exist?(path)
            validated_path = validate_path!(path)
            File.original_exist?(validated_path)
          rescue PathViolation, SensitiveFileViolation
            false
          end

          def safe_directory?(path)
            validated_path = validate_path!(path)
            File.original_directory?(validated_path)
          rescue PathViolation, SensitiveFileViolation
            false
          end

          def safe_file?(path)
            validated_path = validate_path!(path)
            File.original_file?(validated_path)
          rescue PathViolation, SensitiveFileViolation
            false
          end

          def safe_glob(pattern, base: PROJECT_ROOT)
            Dir.original_glob(File.join(base, pattern)).select do |path|
              validate_path!(path)
              true
            rescue PathViolation, SensitiveFileViolation
              false
            end
          end

          def safe_entries(path)
            validated_path = validate_path!(path)
            Dir.original_entries(validated_path).reject { |e| e.start_with?(".") }
          end
        end

        # Override File class methods
        class File
          class << self
            alias_method :original_read, :read
            alias_method :original_exist?, :exist?
            alias_method :original_directory?, :directory?
            alias_method :original_file?, :file?

            def read(path, *args)
              McpSandbox.safe_read(path)
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
            alias_method :original_glob, :glob
            alias_method :original_entries, :entries

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
        begin
          #{user_code}
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
      require "timeout"

      Tempfile.create(["mcp_sandbox", ".rb"]) do |f|
        f.write(code)
        f.flush

        begin
          Timeout.timeout(timeout) do
            result = RailsMcpServer::RunProcess.execute_rails_command(
              active_project_path,
              "bin/rails runner #{f.path} 2>&1"
            )
            result.empty? ? NO_OUTPUT_MESSAGE : result
          end
        rescue Timeout::Error
          "TIMEOUT: Execution exceeded #{timeout} seconds"
        end
      end
    end
  end
end
