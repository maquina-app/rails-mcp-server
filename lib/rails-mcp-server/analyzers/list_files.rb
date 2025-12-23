module RailsMcpServer
  module Analyzers
    class ListFiles < BaseAnalyzer
      def call(directory: "", pattern: "*.rb")
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        if directory.empty?
          full_path = active_project_path
        else
          validated_dir = PathValidator.validate_path(directory, active_project_path)
          if validated_dir.nil?
            message = "Access denied: directory '#{directory}' is outside the project or is sensitive."
            log(:warn, "Directory access blocked: #{directory}")
            return message
          end
          full_path = validated_dir
        end

        unless File.directory?(full_path)
          message = "Directory '#{directory}' not found in the project."
          log(:warn, message)
          return message
        end

        sanitized_pattern = pattern.gsub(/[^a-zA-Z0-9*?.\/_-]/, "")
        if sanitized_pattern != pattern
          log(:warn, "Pattern sanitized from '#{pattern}' to '#{sanitized_pattern}'")
        end

        files = collect_files(full_path, sanitized_pattern, directory)
        files = PathValidator.filter_sensitive_files(files, active_project_path)

        log(:debug, "Found #{files.size} files matching pattern (after filtering)")

        "Files in #{directory.empty? ? "project root" : directory} matching '#{sanitized_pattern}':\n\n#{files.join("\n")}"
      end

      private

      def collect_files(full_path, pattern, directory)
        is_git_repo = git_repository?

        if is_git_repo
          log(:debug, "Project is a git repository, using git ls-files")
          collect_files_git(directory, pattern)
        else
          log(:debug, "Project is not a git repository, using Dir.glob")
          collect_files_glob(full_path, pattern)
        end
      end

      def git_repository?
        Dir.chdir(active_project_path) do
          system("git", "rev-parse", "--is-inside-work-tree",
            out: File::NULL, err: File::NULL)
        end
      end

      def collect_files_git(directory, pattern)
        relative_dir = directory.empty? ? "" : "#{directory}/"
        search_pattern = "#{relative_dir}#{pattern}"

        files = Dir.chdir(active_project_path) do
          IO.popen(
            ["git", "ls-files", "--cached", "--others", "--exclude-standard", search_pattern],
            &:read
          )
        end

        files.to_s.split("\n").map(&:strip).reject(&:empty?).sort
      end

      def collect_files_glob(full_path, pattern)
        Dir.glob(File.join(full_path, pattern))
          .map { |f| f.sub("#{active_project_path}/", "") }
          .reject { |file| PathValidator.excluded_directory?(file) }
          .sort
      end
    end
  end
end
