require "fast_mcp"

module RailsMcpServer
  class BaseTool < FastMcp::Tool
    extend Forwardable

    def_delegators :RailsMcpServer, :log, :projects
    def_delegators :RailsMcpServer, :current_project=, :current_project
    def_delegators :RailsMcpServer, :active_project_path=, :active_project_path
  end
end
