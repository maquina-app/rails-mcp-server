module RailsMcpServer
  class ExecuteTool < BaseTool
    tool_name "execute_tool"

    description <<~DESC
      Execute a Rails MCP analyzer by name. Use search_tools first to discover available 
      analyzers and their parameters, then invoke them through this meta-tool.

      This approach reduces context usage by not loading all tool definitions upfront.
    DESC

    arguments do
      required(:tool_name).filled(:string).description(
        "Name of the analyzer to execute (e.g., 'get_routes', 'analyze_models', 'get_schema')"
      )
      optional(:params).description(
        "Hash of parameters to pass to the analyzer (e.g., { model_name: 'User', analysis_type: 'full' })"
      )
    end

    # Registry of available internal analyzers with their allowed parameters
    INTERNAL_TOOLS = {
      "project_info" => {
        class_name: "Analyzers::ProjectInfo",
        params: [:max_depth, :include_files, :detail_level]
      },
      "list_files" => {
        class_name: "Analyzers::ListFiles",
        params: [:directory, :pattern]
      },
      "get_file" => {
        class_name: "Analyzers::GetFile",
        params: [:path]
      },
      "get_routes" => {
        class_name: "Analyzers::GetRoutes",
        params: [:controller, :verb, :path_contains, :named_only, :detail_level]
      },
      "analyze_models" => {
        class_name: "Analyzers::AnalyzeModels",
        params: [:model_name, :model_names, :detail_level, :analysis_type]
      },
      "get_schema" => {
        class_name: "Analyzers::GetSchema",
        params: [:table_name, :table_names, :detail_level]
      },
      "analyze_controller_views" => {
        class_name: "Analyzers::AnalyzeControllerViews",
        params: [:controller_name, :detail_level, :analysis_type]
      },
      "analyze_environment_config" => {
        class_name: "Analyzers::AnalyzeEnvironmentConfig",
        params: []
      },
      "load_guide" => {
        class_name: "Analyzers::LoadGuide",
        params: [:library, :guide]
      }
    }.freeze

    def call(tool_name:, params: {})
      tool_config = INTERNAL_TOOLS[tool_name]

      unless tool_config
        available = INTERNAL_TOOLS.keys.sort.join(", ")
        return "Unknown tool '#{tool_name}'. Available: #{available}\n\nUse search_tools to discover tools and their parameters."
      end

      # Get the analyzer class from the Analyzers module
      analyzer_class = tool_config[:class_name].split("::").reduce(RailsMcpServer) { |mod, name| mod.const_get(name) }

      # Instantiate the analyzer
      analyzer_instance = analyzer_class.new

      # Handle params passed as JSON string (from some MCP clients like Inspector)
      params ||= {}
      params = JSON.parse(params, symbolize_names: true) if params.is_a?(String)
      params = params.transform_keys(&:to_sym) if params.is_a?(Hash)

      allowed_params = tool_config[:params]
      filtered_params = params.slice(*allowed_params)

      # Log any ignored params for debugging
      ignored_params = params.keys - allowed_params
      if ignored_params.any?
        log(:debug, "Ignored unknown params for '#{tool_name}': #{ignored_params.join(", ")}")
      end

      log(:info, "Executing analyzer '#{tool_name}' with params: #{filtered_params.inspect}")

      begin
        if filtered_params.empty?
          analyzer_instance.call
        else
          analyzer_instance.call(**filtered_params)
        end
      rescue ArgumentError => e
        "Error calling '#{tool_name}': #{e.message}\n\nUse search_tools(query: '#{tool_name}', detail_level: 'full') to see required parameters."
      rescue => e
        log(:error, "Error executing analyzer '#{tool_name}': #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        "Error executing '#{tool_name}': #{e.message}"
      end
    end

    class << self
      def available_tools
        INTERNAL_TOOLS.keys.sort
      end

      def tool_info(name)
        INTERNAL_TOOLS[name]
      end
    end
  end
end
