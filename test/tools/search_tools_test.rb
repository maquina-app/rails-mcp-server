require "test_helper"

class SearchToolsTest < Minitest::Test
  def setup
    @tool = RailsMcpServer::SearchTools.new
  end

  def test_search_by_category
    result = @tool.call(category: "database")

    assert_includes result, "get_schema [database]"
    refute_includes result, "analyze_models [models]" # Should not list models category tools
  end

  def test_search_by_query
    result = @tool.call(query: "model")

    assert_includes result, "analyze_models"
  end

  def test_search_no_results
    result = @tool.call(query: "xyznonexistent")

    assert_includes result, "No tools found"
  end

  def test_detail_level_names
    result = @tool.call(detail_level: "names")

    assert_includes result, "get_schema"
    refute_includes result, "Category:" # No category in names-only
  end

  def test_detail_level_summary
    result = @tool.call(detail_level: "summary")

    assert_includes result, "get_schema"
    assert_includes result, "[database]"
  end

  def test_detail_level_full
    result = @tool.call(detail_level: "full")

    assert_includes result, "Parameters:"
    assert_includes result, "table_name"
  end

  def test_all_categories_valid
    categories = %w[models database routing controllers files project guides]

    categories.each do |cat|
      result = @tool.call(category: cat)
      refute_includes result, "No tools found", "Category '#{cat}' should have tools"
    end
  end
end
