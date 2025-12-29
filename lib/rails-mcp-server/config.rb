require "logger"

module RailsMcpServer
  class Config
    attr_accessor :logger, :projects, :current_project, :active_project_path, :config_dir
    attr_reader :log_level

    def self.setup
      new.tap do |instance|
        yield(instance) if block_given?
      end
    end

    def initialize
      @log_level = Logger::INFO
      @config_dir = get_config_dir
      @current_project = nil
      @active_project_path = nil

      configure_logger
      load_projects
    end

    def log_level=(level)
      @log_level = LEVELS[level] || Logger::INFO
      @logger.level = @log_level
    end

    private

    def load_projects
      # Priority 1: Environment variable (GitHub Copilot Agent mode)
      return if load_from_env_var

      # Priority 2: Auto-detect Rails project in current directory
      return if auto_detect_rails_project

      # Priority 3: Load from projects.yml (existing behavior)
      load_from_projects_file
    end

    def load_from_env_var
      return false unless ENV["RAILS_MCP_PROJECT_PATH"]

      path = File.expand_path(ENV["RAILS_MCP_PROJECT_PATH"])
      project_name = File.basename(path)

      @projects = {project_name => path}
      @current_project = project_name
      @active_project_path = path
      @logger.add(Logger::INFO, "Using RAILS_MCP_PROJECT_PATH: #{project_name} at #{path}")
      true
    end

    def auto_detect_rails_project
      # Check for Rails app (Gemfile with rails gem)
      if rails_app?
        set_auto_detected_project("Rails application")
        return true
      end

      # Check for Rails engine (gemspec with rails dependency)
      if rails_engine?
        set_auto_detected_project("Rails engine")
        return true
      end

      false
    rescue => e
      @logger.add(Logger::DEBUG, "Auto-detect failed: #{e.message}")
      false
    end

    def rails_app?
      gemfile = File.join(Dir.pwd, "Gemfile")
      return false unless File.exist?(gemfile)

      content = File.read(gemfile)
      content.include?("'rails'") || content.include?('"rails"') ||
        content.match?(/gem\s+['"]rails['"]/)
    end

    def rails_engine?
      # Find gemspec files in current directory
      gemspec_files = Dir.glob(File.join(Dir.pwd, "*.gemspec"))
      return false if gemspec_files.empty?

      gemspec_files.any? do |gemspec_file|
        content = File.read(gemspec_file)
        # Check for rails dependency in gemspec
        # Common patterns:
        #   add_dependency "rails", ...
        #   add_runtime_dependency "rails", ...
        #   add_dependency "railties", ...
        #   add_runtime_dependency "actionpack", ...
        content.match?(/add(?:_runtime)?_dependency\s+['"](?:rails|railties|actionpack|activerecord|activesupport|actionview|actionmailer|activejob|actioncable|activestorage|actionmailbox|actiontext)['"]/)
      end
    end

    def set_auto_detected_project(project_type)
      project_name = File.basename(Dir.pwd)
      @projects = {project_name => Dir.pwd}
      @current_project = project_name
      @active_project_path = Dir.pwd
      @logger.add(Logger::INFO, "Auto-detected #{project_type}: #{project_name} at #{Dir.pwd}")
    end

    def load_from_projects_file
      projects_file = File.join(@config_dir, "projects.yml")
      @projects = {}

      @logger.add(Logger::INFO, "Loading projects from: #{projects_file}")

      # Create empty projects file if it doesn't exist
      unless File.exist?(projects_file)
        @logger.add(Logger::INFO, "Creating empty projects file: #{projects_file}")
        FileUtils.mkdir_p(File.dirname(projects_file))
        File.write(projects_file, "# Rails MCP Projects\n# Format: project_name: /path/to/project\n")
      end

      @projects = YAML.safe_load_file(projects_file, permitted_classes: [Symbol]) || {}
      found_projects_size = @projects.size
      @logger.add(Logger::INFO, "Loaded #{found_projects_size} projects: #{@projects.keys.join(", ")}")

      if found_projects_size.zero?
        message = "No projects found.\nPlease add a project to #{projects_file} or run from a Rails directory."
        puts message
        @logger.add(Logger::ERROR, message)
        exit 1
      end

      # Auto-switch if only one project configured
      if @projects.size == 1
        name, path = @projects.first
        @current_project = name
        @active_project_path = File.expand_path(path)
        @logger.add(Logger::INFO, "Auto-switched to single project: #{name}")
      end
    end

    def configure_logger
      FileUtils.mkdir_p(File.join(@config_dir, "log"))
      log_file = File.join(@config_dir, "log", "rails_mcp_server.log")

      @logger = Logger.new(log_file)
      @logger.level = @log_level

      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime.strftime("%Y-%m-%d %H:%M:%S")}] #{severity}: #{msg}\n"
      end
    end

    def get_config_dir
      # Use XDG_CONFIG_HOME if set, otherwise use ~/.config
      xdg_config_home = ENV["XDG_CONFIG_HOME"]
      if xdg_config_home && !xdg_config_home.empty?
        File.join(xdg_config_home, "rails-mcp")
      else
        File.join(Dir.home, ".config", "rails-mcp")
      end
    end
  end
end
