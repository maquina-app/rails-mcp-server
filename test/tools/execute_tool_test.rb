require "test_helper"

class ExecuteToolTest < Minitest::Test
  include FixtureHelpers

  def setup
    setup_sample_project
    @tool = RailsMcpServer::ExecuteTool.new
  end

  def teardown
    teardown_sample_project
  end

  def test_unknown_tool
    result = @tool.call(tool_name: "nonexistent")

    assert_includes result, "Unknown tool"
    assert_includes result, "Available:"
  end

  def test_available_tools_list
    available = RailsMcpServer::ExecuteTool.available_tools

    assert_includes available, "analyze_models"
    assert_includes available, "get_routes"
    assert_includes available, "get_schema"
    assert_includes available, "project_info"
  end

  def test_execute_project_info
    result = @tool.call(tool_name: "project_info", params: {detail_level: "minimal"})

    assert_includes result, "Project: sample_project"
  end

  def test_filters_unknown_params
    # Should not raise, just ignore unknown params
    result = @tool.call(
      tool_name: "project_info",
      params: {detail_level: "minimal", unknown_param: "ignored"}
    )

    assert_includes result, "Project:"
  end

  def test_tool_info
    info = RailsMcpServer::ExecuteTool.tool_info("analyze_models")

    assert_equal "Analyzers::AnalyzeModels", info[:class_name]
    assert_includes info[:params], :model_name
    assert_includes info[:params], :analysis_type
  end
end
