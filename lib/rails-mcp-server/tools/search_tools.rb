module RailsMcpServer
  class SearchTools < BaseTool
    tool_name "search_tools"

    description <<~DESC
      Search available Rails MCP tools by keyword or category. Use this to discover tools 
      before invoking them with execute_tool.

      Workflow:
      1. Call search_tools to find relevant tools
      2. Call execute_tool(tool_name: "tool_name", params: {...}) to run them

      Categories: models, database, routing, controllers, files, project, guides
    DESC

    arguments do
      optional(:query).filled(:string).description(
        "Search term to find matching tools (e.g., 'model', 'routes', 'schema', 'controller')"
      )
      optional(:category).filled(:string).description(
        "Filter by category: models, database, routing, controllers, files, project, guides"
      )
      optional(:detail_level).filled(:string).description(
        "Level of detail: 'names' (tool names only), 'summary' (names + one-line description), 'full' (complete definition with parameters). Default: 'summary'"
      )
    end

    TOOL_CATALOG = {
      "project_info" => {
        category: "project",
        keywords: %w[project info structure directory tree rails version],
        summary: "Get Rails version, directory structure, and project overview",
        parameters: [
          {name: "max_depth", type: "integer", required: false, description: "Directory tree depth (default: 2, max: 5)"},
          {name: "include_files", type: "boolean", required: false, description: "Include files in tree (default: true)"},
          {name: "detail_level", type: "string", required: false, description: "'minimal', 'summary', or 'full' (default: 'full')"}
        ]
      },
      "list_files" => {
        category: "files",
        keywords: %w[files list directory glob find search],
        summary: "List files matching a pattern in a directory",
        parameters: [
          {name: "directory", type: "string", required: false, description: "Directory path relative to project root"},
          {name: "pattern", type: "string", required: false, description: "Glob pattern (default: '*.rb')"}
        ]
      },
      "get_file" => {
        category: "files",
        keywords: %w[file read content source code view],
        summary: "Read the contents of a specific file",
        parameters: [
          {name: "path", type: "string", required: true, description: "File path relative to project root"}
        ]
      },
      "get_routes" => {
        category: "routing",
        keywords: %w[routes endpoints urls api paths http verbs controller actions introspection],
        summary: "List HTTP routes via Rails introspection with filtering by controller, verb, or path",
        parameters: [
          {name: "controller", type: "string", required: false, description: "Filter by controller name"},
          {name: "verb", type: "string", required: false, description: "Filter by HTTP verb (GET, POST, PUT, PATCH, DELETE)"},
          {name: "path_contains", type: "string", required: false, description: "Filter routes containing path segment"},
          {name: "named_only", type: "boolean", required: false, description: "Only return named routes (default: false)"},
          {name: "detail_level", type: "string", required: false, description: "'names', 'summary', or 'full' (default: 'full')"}
        ]
      },
      "analyze_models" => {
        category: "models",
        keywords: %w[model active_record orm association schema database belongs_to has_many validations callbacks scopes prism introspection],
        summary: "Analyze ActiveRecord models using Rails introspection and/or Prism static analysis",
        parameters: [
          {name: "model_name", type: "string", required: false, description: "Single model name (CamelCase)"},
          {name: "model_names", type: "array", required: false, description: "Array of model names for batch analysis"},
          {name: "detail_level", type: "string", required: false, description: "'names', 'associations', or 'full' (default: 'full')"},
          {name: "analysis_type", type: "string", required: false, description: "'introspection' (runtime), 'static' (Prism AST), or 'full' (both). Default: 'introspection'"}
        ]
      },
      "get_schema" => {
        category: "database",
        keywords: %w[schema database table column migration sql foreign_key index],
        summary: "Get database schema - all tables or specific table details",
        parameters: [
          {name: "table_name", type: "string", required: false, description: "Specific table (snake_case, plural)"},
          {name: "table_names", type: "array", required: false, description: "Array of table names for batch retrieval"},
          {name: "detail_level", type: "string", required: false, description: "'tables', 'summary', or 'full' (default: 'full')"}
        ]
      },
      "analyze_controller_views" => {
        category: "controllers",
        keywords: %w[controller view action template partial stimulus erb html callbacks filters before_action strong_params prism introspection],
        summary: "Analyze controllers using Rails introspection and/or Prism static analysis (callbacks, filters, strong params, renders)",
        parameters: [
          {name: "controller_name", type: "string", required: false, description: "Specific controller to analyze"},
          {name: "detail_level", type: "string", required: false, description: "'names', 'summary', or 'full' (default: 'full')"},
          {name: "analysis_type", type: "string", required: false, description: "'introspection' (runtime), 'static' (Prism AST), or 'full' (both). Default: 'introspection'"}
        ]
      },
      "analyze_environment_config" => {
        category: "project",
        keywords: %w[environment config configuration development production test settings],
        summary: "Compare environment configurations and find inconsistencies",
        parameters: []
      },
      "load_guide" => {
        category: "guides",
        keywords: %w[guide documentation rails turbo stimulus kamal docs help],
        summary: "Load Rails, Turbo, Stimulus, or Kamal documentation guides",
        parameters: [
          {name: "guides", type: "string", required: true, description: "Library: 'rails', 'turbo', 'stimulus', 'kamal', 'custom'"},
          {name: "guide", type: "string", required: false, description: "Specific guide name to load"}
        ]
      }
    }.freeze

    CATEGORIES = %w[models database routing controllers files project guides].freeze

    def call(query: nil, category: nil, detail_level: "summary")
      detail_level = "summary" unless %w[names summary full].include?(detail_level)

      # Filter tools
      filtered_tools = TOOL_CATALOG.dup

      if category && CATEGORIES.include?(category.downcase)
        filtered_tools = filtered_tools.select { |_, info| info[:category] == category.downcase }
      end

      if query && !query.strip.empty?
        query_terms = query.downcase.split(/\s+/)
        filtered_tools = filtered_tools.select do |name, info|
          searchable = [name, info[:category], info[:summary], *info[:keywords]].join(" ").downcase
          query_terms.all? { |term| searchable.include?(term) }
        end
      end

      if filtered_tools.empty?
        return "No tools found matching your criteria. Available categories: #{CATEGORIES.join(", ")}"
      end

      format_results(filtered_tools, detail_level)
    end

    private

    def format_results(tools, detail_level)
      case detail_level
      when "names"
        output = ["Available tools (invoke via execute_tool):\n"]
        output << tools.keys.sort.join("\n")
        output.join

      when "summary"
        output = ["Available tools (invoke via execute_tool):\n"]
        tools.sort_by { |name, _| name }.each do |name, info|
          output << "  #{name} [#{info[:category]}]"
          output << "    #{info[:summary]}"
          output << ""
        end
        output << "Example: execute_tool(tool_name: \"analyze_models\", params: { model_name: \"User\", analysis_type: \"full\" })"
        output.join("\n")

      when "full"
        output = ["Available tools (invoke via execute_tool):\n"]
        tools.sort_by { |name, _| name }.each do |name, info|
          output << "  #{name}"
          output << "    Category: #{info[:category]}"
          output << "    #{info[:summary]}"
          output << "    Keywords: #{info[:keywords].join(", ")}"

          if info[:parameters].any?
            output << "    Parameters:"
            info[:parameters].each do |param|
              req = param[:required] ? "required" : "optional"
              output << "      - #{param[:name]} (#{param[:type]}, #{req}): #{param[:description]}"
            end
          else
            output << "    Parameters: none"
          end
          output << ""
        end
        output << "Usage: execute_tool(tool_name: \"<name>\", params: { ... })"
        output.join("\n")
      end
    end
  end
end
