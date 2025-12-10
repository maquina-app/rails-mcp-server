require "test_helper"

class AnalyzeModelsTest < AnalyzerTestCase
  def setup
    super
    @analyzer = RailsMcpServer::Analyzers::AnalyzeModels.new
  end

  def test_list_all_models_names_only
    result = @analyzer.call(detail_level: "names")

    assert_includes result, "Models in project"
    assert_includes result, "user"
    assert_includes result, "post"
  end

  def test_single_model_not_found
    result = @analyzer.call(model_name: "NonExistent")

    assert_includes result, "not found"
  end

  def test_single_model_names_detail
    result = @analyzer.call(model_name: "User", detail_level: "names")

    assert_includes result, "Model: User"
    assert_includes result, "app/models/user.rb"
  end

  def test_single_model_with_introspection
    # Mock the rails runner response for introspection
    introspection_response = {
      table_name: "users",
      primary_key: "id",
      columns: [
        {name: "id", type: "integer", null: false},
        {name: "name", type: "string", null: false},
        {name: "email", type: "string", null: false}
      ],
      associations: [
        {name: "posts", type: "has_many", class_name: "Post"},
        {name: "organization", type: "belongs_to", class_name: "Organization"}
      ],
      validations: [
        {type: "presence", attributes: ["email"]},
        {type: "uniqueness", attributes: ["email"]}
      ],
      enums: {role: ["user", "admin", "moderator"]}
    }.to_json

    stub_rails_runner(@analyzer, introspection_response)

    result = @analyzer.call(model_name: "User", detail_level: "full", analysis_type: "introspection")

    assert_includes result, "RAILS INTROSPECTION"
    assert_includes result, "Table: users"
  end

  def test_single_model_with_static_analysis
    static_response = {
      callbacks: [
        {name: "before_save", args: ["normalize_email"]},
        {name: "after_create", args: ["send_welcome_email"]}
      ],
      scopes: ["active", "admins"],
      concerns: [],
      methods: [
        {name: "normalize_email", line: 20},
        {name: "send_welcome_email", line: 25}
      ]
    }.to_json

    stub_rails_runner(@analyzer, static_response)

    result = @analyzer.call(model_name: "User", detail_level: "full", analysis_type: "static")

    assert_includes result, "PRISM STATIC ANALYSIS"
    assert_includes result, "Callbacks"
    assert_includes result, "before_save"
  end

  def test_batch_model_analysis
    result = @analyzer.call(model_names: ["User", "Post"], detail_level: "names")

    assert_includes result, "Analysis for 2 models"
    assert_includes result, "Model: User"
    assert_includes result, "Model: Post"
  end

  def test_no_project_selected
    teardown_sample_project

    result = @analyzer.call

    assert_includes result, "No active project"
  end
end
