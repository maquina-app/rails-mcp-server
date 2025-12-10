require "test_helper"

class GetRoutesTest < AnalyzerTestCase
  def setup
    super
    @analyzer = RailsMcpServer::Analyzers::GetRoutes.new
  end

  def test_get_routes_with_introspection
    routes_response = {
      routes: [
        {name: "users", verb: "GET", path: "/users", controller: "users", action: "index", controller_action: "users#index", constraints: {}, defaults: {}, required_parts: [], optional_parts: []},
        {name: "user", verb: "GET", path: "/users/:id", controller: "users", action: "show", controller_action: "users#show", constraints: {}, defaults: {}, required_parts: ["id"], optional_parts: []},
        {name: "", verb: "POST", path: "/users", controller: "users", action: "create", controller_action: "users#create", constraints: {}, defaults: {}, required_parts: [], optional_parts: []}
      ],
      total_count: 3,
      controllers: {"users" => 3}
    }.to_json

    stub_rails_runner(@analyzer, routes_response)

    result = @analyzer.call(detail_level: "summary")

    assert_includes result, "Rails Routes (3 routes)"
    assert_includes result, "users:"
    assert_includes result, "GET"
    assert_includes result, "/users"
  end

  def test_filter_by_controller
    routes_response = {
      routes: [
        {name: "users", verb: "GET", path: "/users", controller: "users", action: "index", controller_action: "users#index", constraints: {}, defaults: {}, required_parts: [], optional_parts: []}
      ],
      total_count: 1,
      controllers: {"users" => 1}
    }.to_json

    stub_rails_runner(@analyzer, routes_response)

    result = @analyzer.call(controller: "users", detail_level: "names")

    assert_includes result, "/users"
  end

  def test_filter_by_verb
    routes_response = {
      routes: [
        {name: "", verb: "POST", path: "/users", controller: "users", action: "create", controller_action: "users#create", constraints: {}, defaults: {}, required_parts: [], optional_parts: []}
      ],
      total_count: 1,
      controllers: {"users" => 1}
    }.to_json

    stub_rails_runner(@analyzer, routes_response)

    result = @analyzer.call(verb: "POST")

    assert_includes result, "POST"
  end

  def test_no_routes_found
    routes_response = {routes: [], total_count: 0, controllers: {}}.to_json

    stub_rails_runner(@analyzer, routes_response)

    result = @analyzer.call(controller: "nonexistent")

    assert_includes result, "No routes found"
  end
end
