module RailsMcpServer
  module Analyzers
    class GetFile < BaseAnalyzer
      def call(path:)
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        validated_path = PathValidator.validate_path(path, active_project_path)

        if validated_path.nil?
          message, log_msg = if !PathValidator.safe_path?(path, active_project_path)
            ["Access denied: path '#{path}' is outside the project directory.",
              "Path traversal attempt blocked: #{path}"]
          else
            ["Access denied: '#{path}' matches a sensitive file pattern.",
              "Sensitive file access blocked: #{path}"]
          end
          log(:warn, log_msg)
          return message
        end

        unless File.exist?(validated_path)
          message = "File '#{path}' not found in the project."
          log(:warn, message)
          return message
        end

        if File.directory?(validated_path)
          message = "'#{path}' is a directory, not a file. Use list_files instead."
          log(:warn, message)
          return message
        end

        log(:info, "Reading file: #{path}")

        content = File.read(validated_path)
        extension = File.extname(path).delete(".")

        <<~FILE
          File: #{path}

          ```#{extension}
          #{content}
          ```
        FILE
      end
    end
  end
end
