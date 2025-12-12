require "logger"
require "fileutils"
require "forwardable"
require "open3"
require_relative "rails-mcp-server/version"
require_relative "rails-mcp-server/config"
require_relative "rails-mcp-server/utilities/run_process"
require_relative "rails-mcp-server/utilities/path_validator"

# MCP Tools (registered with FastMCP)
require_relative "rails-mcp-server/tools/base_tool"
require_relative "rails-mcp-server/tools/switch_project"
require_relative "rails-mcp-server/tools/search_tools"
require_relative "rails-mcp-server/tools/execute_tool"
require_relative "rails-mcp-server/tools/execute_ruby"

# Analyzers (internal, invoked via execute_tool)
require_relative "rails-mcp-server/analyzers/base_analyzer"
require_relative "rails-mcp-server/analyzers/project_info"
require_relative "rails-mcp-server/analyzers/list_files"
require_relative "rails-mcp-server/analyzers/get_file"
require_relative "rails-mcp-server/analyzers/get_routes"
require_relative "rails-mcp-server/analyzers/get_schema"
require_relative "rails-mcp-server/analyzers/analyze_models"
require_relative "rails-mcp-server/analyzers/analyze_controller_views"
require_relative "rails-mcp-server/analyzers/analyze_environment_config"
require_relative "rails-mcp-server/analyzers/load_guide"

# Resources
require_relative "rails-mcp-server/resources/base_resource"
require_relative "rails-mcp-server/resources/guide_content_formatter"
require_relative "rails-mcp-server/resources/guide_error_handler"
require_relative "rails-mcp-server/resources/guide_file_finder"
require_relative "rails-mcp-server/resources/guide_loader_template"
require_relative "rails-mcp-server/resources/guide_manifest_operations"
require_relative "rails-mcp-server/resources/guide_framework_contract"
require_relative "rails-mcp-server/resources/rails_guides_resource"
require_relative "rails-mcp-server/resources/rails_guides_resources"
require_relative "rails-mcp-server/resources/stimulus_guides_resource"
require_relative "rails-mcp-server/resources/stimulus_guides_resources"
require_relative "rails-mcp-server/resources/turbo_guides_resource"
require_relative "rails-mcp-server/resources/turbo_guides_resources"
require_relative "rails-mcp-server/resources/custom_guides_resource"
require_relative "rails-mcp-server/resources/custom_guides_resources"
require_relative "rails-mcp-server/resources/kamal_guides_resource"
require_relative "rails-mcp-server/resources/kamal_guides_resources"

module RailsMcpServer
  LEVELS = {debug: Logger::DEBUG, info: Logger::INFO, error: Logger::ERROR}
  @config = Config.setup

  class << self
    extend Forwardable

    attr_reader :config

    def_delegators :@config, :log_level, :log_level=
    def_delegators :@config, :logger, :logger=
    def_delegators :@config, :projects
    def_delegators :@config, :current_project, :current_project=
    def_delegators :@config, :active_project_path, :active_project_path=
    def_delegators :@config, :config_dir

    def log(level, message)
      log_level = LEVELS[level] || Logger::INFO

      @config.logger.add(log_level, message)
    end
  end
end
