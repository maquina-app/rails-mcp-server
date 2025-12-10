module RailsMcpServer
  module Analyzers
    class AnalyzeEnvironmentConfig < BaseAnalyzer
      def call
        unless current_project
          return "No active project. Please switch to a project first."
        end

        environments_dir = File.join(active_project_path, "config", "environments")
        unless File.directory?(environments_dir)
          return "Environments directory not found at config/environments."
        end

        env_files = Dir.glob(File.join(environments_dir, "*.rb"))
        return "No environment files found." if env_files.empty?

        analyze_environments(env_files)
      end

      private

      def analyze_environments(env_files)
        configs = {}

        env_files.each do |file|
          env_name = File.basename(file, ".rb")
          content = File.read(file)
          configs[env_name] = extract_config_settings(content)
        end

        output = ["Environment Configuration Analysis", "=" * 50, ""]

        # List each environment's settings
        configs.each do |env, settings|
          output << "#{env.capitalize}:"
          settings.each do |key, value|
            output << "  #{key} = #{value}"
          end
          output << ""
        end

        # Find inconsistencies
        all_keys = configs.values.flat_map(&:keys).uniq.sort
        inconsistencies = []

        all_keys.each do |key|
          values_by_env = configs.map { |env, settings| [env, settings[key]] }.to_h
          present_in = values_by_env.select { |_, v| !v.nil? }.keys

          if present_in.size < configs.size && present_in.size > 0
            missing = configs.keys - present_in
            inconsistencies << "#{key}: missing in #{missing.join(", ")}"
          end
        end

        if inconsistencies.any?
          output << "Potential Issues:"
          output << "-" * 30
          inconsistencies.each { |i| output << "  ⚠ #{i}" }
        else
          output << "No inconsistencies found between environments."
        end

        output.join("\n")
      end

      def extract_config_settings(content)
        settings = {}

        # Match config.setting = value patterns
        content.scan(/config\.(\w+(?:\.\w+)*)\s*=\s*(.+?)(?:\n|$)/).each do |key, value|
          settings[key] = value.strip
        end

        settings
      end
    end
  end
end
