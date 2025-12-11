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
      # Single project mode - use current directory, skip projects.yml
      if ENV["RAILS_MCP_SINGLE_PROJECT"]
        project_name = File.basename(Dir.pwd)
        @projects = {project_name => Dir.pwd}
        @current_project = project_name
        @active_project_path = Dir.pwd
        @logger.add(Logger::INFO, "Single project mode: #{project_name} at #{Dir.pwd}")
        return
      end

      projects_file = File.join(@config_dir, "projects.yml")
      @projects = {}

      @logger.add(Logger::INFO, "Loading projects from: #{projects_file}")

      # Create empty projects file if it doesn't exist
      unless File.exist?(projects_file)
        @logger.add(Logger::INFO, "Creating empty projects file: #{projects_file}")
        FileUtils.mkdir_p(File.dirname(projects_file))
        File.write(projects_file, "# Rails MCP Projects\n# Format: project_name: /path/to/project\n")
      end

      @projects = YAML.load_file(projects_file) || {}
      found_projects_size = @projects.size
      @logger.add(Logger::INFO, "Loaded #{found_projects_size} projects: #{@projects.keys.join(", ")}")

      if found_projects_size.zero?
        message = "No projects found.\nPlease add a project to #{projects_file} and try again."
        puts message
        @logger.add(Logger::ERROR, message)
        exit 1
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
