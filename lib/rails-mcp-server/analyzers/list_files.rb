module RailsMcpServer
  module Analyzers
    class ListFiles < BaseAnalyzer
      def call(directory: "", pattern: "*.rb")
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        full_path = File.join(active_project_path, directory)
        unless File.directory?(full_path)
          message = "Directory '#{directory}' not found in the project."
          log(:warn, message)
          return message
        end

        # Check if this is a git repository
        is_git_repo = system("cd #{active_project_path} && git rev-parse --is-inside-work-tree > /dev/null 2>&1")

        if is_git_repo
          log(:debug, "Project is a git repository, using git ls-files")

          relative_dir = directory.empty? ? "" : "#{directory}/"
          git_cmd = "cd #{active_project_path} && git ls-files --cached --others --exclude-standard #{relative_dir}#{pattern}"

          files = `#{git_cmd}`.split("\n").map(&:strip).sort
        else
          log(:debug, "Project is not a git repository or git not available, using Dir.glob")

          files = Dir.glob(File.join(full_path, pattern))
            .map { |f| f.sub("#{active_project_path}/", "") }
            .reject { |file| file.start_with?(".git/", ".ruby-lsp/", "node_modules/", "storage/", "public/assets/", "public/packs/", ".bundle/", "vendor/bundle/", "vendor/cache/", "tmp/", "log/") }
            .sort
        end

        log(:debug, "Found #{files.size} files matching pattern")

        "Files in #{directory.empty? ? "project root" : directory} matching '#{pattern}':\n\n#{files.join("\n")}"
      end
    end
  end
end
