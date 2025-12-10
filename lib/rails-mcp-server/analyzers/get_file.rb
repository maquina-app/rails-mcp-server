module RailsMcpServer
  module Analyzers
    class GetFile < BaseAnalyzer
      def call(path:)
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        full_path = File.join(active_project_path, path)

        unless File.exist?(full_path)
          message = "File '#{path}' not found in the project."
          log(:warn, message)
          return message
        end

        if File.directory?(full_path)
          message = "'#{path}' is a directory, not a file. Use list_files instead."
          log(:warn, message)
          return message
        end

        log(:info, "Reading file: #{path}")

        content = File.read(full_path)
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
