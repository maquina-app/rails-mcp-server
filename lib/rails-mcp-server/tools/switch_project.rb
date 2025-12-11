module RailsMcpServer
  class SwitchProject < BaseTool
    tool_name "switch_project"

    description "Change the active Rails project to interact with a different codebase. Must be called before using other tools unless --single-project mode is enabled (auto-selects current directory). Available projects are defined in the projects.yml configuration file."

    arguments do
      required(:project_name).filled(:string).description("Name of the project as defined in the projects.yml file (case-sensitive)")
    end

    QUICK_START = <<~GUIDE

      Quick Start:
      • Get project overview:  execute_tool("project_info")
      • Read a file:           execute_ruby("puts read_file('config/routes.rb')")
      • Find files:            execute_ruby("puts Dir.glob('app/models/*.rb').join('\\n')")
      • Analyze models:        execute_tool("analyze_models", { model_name: "User" })
      • Get routes:            execute_tool("get_routes")
      • Get schema:            execute_tool("get_schema", { table_name: "users" })
      • Search available tools: search_tools()

      Helpers in execute_ruby: read_file(path), file_exists?(path), list_files(pattern), project_root
      Note: Always use `puts` in execute_ruby to see output.
    GUIDE

    def call(project_name:)
      if projects.key?(project_name)
        self.current_project = project_name
        self.active_project_path = File.expand_path(projects[project_name])
        log(:info, "Switched to project: #{project_name} at path: #{active_project_path}")

        "Switched to project: #{project_name} at path: #{active_project_path}\n#{QUICK_START}"
      else
        log(:warn, "Project not found: #{project_name}")

        "Project '#{project_name}' not found. Available projects: #{projects.keys.join(", ")}"
      end
    end
  end
end
