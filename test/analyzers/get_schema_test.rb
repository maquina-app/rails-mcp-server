require "test_helper"

class GetSchemaTest < AnalyzerTestCase
  def setup
    super
    @analyzer = RailsMcpServer::Analyzers::GetSchema.new
  end

  def test_tables_list_only
    tables_response = "users\nposts\ncomments"

    stub_rails_runner(@analyzer, tables_response)

    result = @analyzer.call(detail_level: "tables")

    assert_includes result, "Database tables"
    assert_includes result, "users"
    assert_includes result, "posts"
  end

  def test_full_schema_with_file
    # The schema.rb file exists in fixtures
    result = @analyzer.call(detail_level: "full")

    assert_includes result, "Schema Definition"
    assert_includes result, "create_table"
  end

  def test_single_table_info
    # Tab-separated format: name\ttype\tnull\tdefault
    columns_response = "id\tinteger\tfalse\t\nname\tstring\tfalse\t\nemail\tstring\tfalse\t"

    stub_rails_runner(@analyzer, columns_response)

    result = @analyzer.call(table_name: "users")

    assert_includes result, "Table: users"
  end

  def test_batch_table_info
    # Tab-separated format: name\ttype\tnull\tdefault
    columns_response = "id\tinteger\tfalse\t"

    stub_rails_runner(@analyzer, columns_response)

    result = @analyzer.call(table_names: ["users", "posts"])

    assert_includes result, "Schema for 2 tables"
  end
end
