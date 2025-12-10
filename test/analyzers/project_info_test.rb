require "test_helper"

class ProjectInfoTest < AnalyzerTestCase
  def setup
    super
    @analyzer = RailsMcpServer::Analyzers::ProjectInfo.new
  end

  def test_minimal_detail_level
    result = @analyzer.call(detail_level: "minimal")

    assert_includes result, "Project: sample_project"
    assert_includes result, "Rails version:"
    refute_includes result, "Project structure:"
  end

  def test_summary_detail_level
    result = @analyzer.call(detail_level: "summary")

    assert_includes result, "Project: sample_project"
    assert_includes result, "Key directories:"
  end

  def test_full_detail_level
    result = @analyzer.call(detail_level: "full")

    assert_includes result, "Project structure:"
    assert_includes result, "app/"
  end

  def test_max_depth_clamping
    # Should clamp to 1-5 range
    result_low = @analyzer.call(max_depth: 0, detail_level: "full")
    result_high = @analyzer.call(max_depth: 10, detail_level: "full")

    # Both should work without error
    assert_includes result_low, "Project structure:"
    assert_includes result_high, "Project structure:"
  end

  def test_no_project_selected
    teardown_sample_project

    result = @analyzer.call

    assert_includes result, "No active project"
  end
end
