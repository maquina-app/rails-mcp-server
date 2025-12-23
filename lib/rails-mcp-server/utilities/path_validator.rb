require "shellwords"

module RailsMcpServer
  module PathValidator
    # Sensitive file patterns - files that should never be read or listed
    SENSITIVE_PATTERNS = [
      /\.env(\..*)?$/i,                    # .env, .env.local, .env.production
      /\.key$/i,                           # *.key files
      /\.pem$/i,                           # SSL certificates
      /\.crt$/i,                           # SSL certificates
      /\.p12$/i,                           # PKCS12 certificates
      /credentials\.yml(\.enc)?$/i,        # Rails credentials (encrypted or not)
      /secrets\.yml(\.enc)?$/i,            # Rails secrets
      /master\.key$/i,                     # Rails master key
      /config\/credentials/i,              # credentials directory
      /config\/secrets/i,                  # secrets directory
      /\.secret$/i,                        # generic secret files
      /password/i,                         # password files
      /\.ssh\//i,                          # SSH directory
      /id_rsa/i,                           # SSH keys
      /id_ed25519/i,                       # SSH keys
      /id_ecdsa/i,                         # SSH keys
      /\.gnupg\//i,                        # GPG directory
      /\.netrc$/i,                         # netrc credentials
      /\.pgpass$/i,                        # PostgreSQL passwords
      /database\.yml$/i,                   # Database configuration
      /storage\.yml$/i                     # Active Storage config (may contain keys)
    ].freeze

    # Directories that should be excluded from listing
    EXCLUDED_DIRECTORIES = %w[
      .git/
      .bundle/
      node_modules/
      vendor/bundle/
      vendor/cache/
      tmp/
      log/
      storage/
      .ruby-lsp/
    ].freeze

    module_function

    # Check if a path matches sensitive patterns
    def sensitive_path?(path)
      normalized = path.to_s.downcase
      SENSITIVE_PATTERNS.any? { |pattern| normalized.match?(pattern) }
    end

    # Reject paths that resolve to project_root itself (e.g., ".", "..")
    def safe_path?(path, project_root)
      return false if path.nil? || path.empty?

      expanded = File.expand_path(path, project_root)
      expanded.start_with?(project_root + "/")
    end

    # Validate and return safe absolute path, or nil if unsafe
    def validate_path(path, project_root)
      return nil unless safe_path?(path, project_root)

      expanded = File.expand_path(path, project_root)
      return nil if sensitive_path?(expanded.sub(project_root + "/", ""))

      expanded
    end

    # Escape a string for safe shell usage
    def shell_escape(str)
      Shellwords.escape(str.to_s)
    end

    def valid_identifier?(name)
      return false if name.nil? || name.empty?

      name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*(::[a-zA-Z_][a-zA-Z0-9_]*)*\z/)
    end

    # Validate table names (alphanumeric and underscores only)
    def valid_table_name?(name)
      return false if name.nil? || name.empty?

      name.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
    end

    # Filter a list of files, removing sensitive ones
    def filter_sensitive_files(files, project_root)
      files.reject do |file|
        relative_path = file.sub("#{project_root}/", "")
        sensitive_path?(relative_path)
      end
    end

    # Check if path is in excluded directory
    def excluded_directory?(path)
      EXCLUDED_DIRECTORIES.any? { |dir| path.start_with?(dir) }
    end
  end
end
