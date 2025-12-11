module RailsMcpServer
  module Analyzers
    class ProjectInfo < BaseAnalyzer
      def call(max_depth: 2, include_files: true, detail_level: "full")
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        max_depth = [[max_depth.to_i, 1].max, 5].min # rubocop:disable Style/ComparableClamp
        detail_level = "full" unless %w[minimal summary full].include?(detail_level)

        gemfile_path = File.join(active_project_path, "Gemfile")
        gemfile_content = File.exist?(gemfile_path) ? File.read(gemfile_path) : "Gemfile not found"

        rails_version = gemfile_content.match(/gem ['"]rails['"],\s*['"](.+?)['"]/)&.captures&.first || "Unknown"

        config_application_path = File.join(active_project_path, "config", "application.rb")
        is_api_only = File.exist?(config_application_path) &&
          File.read(config_application_path).include?("config.api_only = true")

        log(:info, "Project info: Rails v#{rails_version}, API-only: #{is_api_only}")

        case detail_level
        when "minimal"
          <<~INFO
            Project: #{current_project}
            Path: #{active_project_path}
            Rails version: #{rails_version}
            API only: #{is_api_only ? "Yes" : "No"}
          INFO

        when "summary"
          key_dirs = get_key_directories
          <<~INFO
            Project: #{current_project}
            Path: #{active_project_path}
            Rails version: #{rails_version}
            API only: #{is_api_only ? "Yes" : "No"}

            Key directories:
            #{key_dirs}
          INFO

        when "full"
          <<~INFO
            Current project: #{current_project}
            Path: #{active_project_path}
            Rails version: #{rails_version}
            API only: #{is_api_only ? "Yes" : "No"}

            Project structure:
            #{get_directory_structure(active_project_path, max_depth: max_depth, include_files: include_files)}
          INFO
        end
      end

      private

      def get_key_directories
        key_paths = %w[
          app/models
          app/controllers
          app/views
          app/jobs
          app/services
          app/graphql
          config
          db/migrate
          spec
          test
        ]

        output = []
        key_paths.each do |path|
          full_path = File.join(active_project_path, path)
          if File.directory?(full_path)
            count = Dir.glob(File.join(full_path, "**", "*.rb")).size
            output << "  #{path}/ (#{count} Ruby files)"
          end
        end

        output.empty? ? "  (no key directories found)" : output.join("\n")
      end

      def get_directory_structure(path, max_depth:, include_files:, current_depth: 0, prefix: "")
        return "" if current_depth > max_depth || !File.directory?(path)

        ignored_dirs = [
          ".git", "node_modules", "tmp", "log",
          "storage", "coverage", "public/assets",
          "public/packs", ".bundle", "vendor/bundle",
          "vendor/cache", ".ruby-lsp"
        ]

        output = +""  # Mutable string to avoid frozen string literal warning
        directories = []
        files = []

        Dir.foreach(path) do |entry|
          next if entry == "." || entry == ".."
          next if ignored_dirs.include?(entry)

          full_path = File.join(path, entry)

          if File.directory?(full_path)
            directories << entry
          elsif include_files
            files << entry
          end
        end

        directories.sort.each do |dir|
          output << "#{prefix}└── #{dir}/\n"
          full_path = File.join(path, dir)
          output << get_directory_structure(
            full_path,
            max_depth: max_depth,
            include_files: include_files,
            current_depth: current_depth + 1,
            prefix: "#{prefix}    "
          )
        end

        if include_files
          files.sort.each do |file|
            output << "#{prefix}└── #{file}\n"
          end
        end

        output
      end
    end
  end
end
