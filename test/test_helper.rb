$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "rails_mcp_server"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Fixture path helper
module FixtureHelpers
  FIXTURES_PATH = File.expand_path("fixtures", __dir__)
  SAMPLE_PROJECT_PATH = File.join(FIXTURES_PATH, "sample_project")

  def fixture_path(relative_path = "")
    File.join(FIXTURES_PATH, relative_path)
  end

  def sample_project_path
    SAMPLE_PROJECT_PATH
  end

  def setup_sample_project
    RailsMcpServer.current_project = "sample_project"
    RailsMcpServer.active_project_path = sample_project_path
  end

  def teardown_sample_project
    RailsMcpServer.current_project = nil
    RailsMcpServer.active_project_path = nil
  end
end

# Base test class for analyzers
class AnalyzerTestCase < Minitest::Test
  include FixtureHelpers

  def setup
    setup_sample_project
  end

  def teardown
    teardown_sample_project
  end

  # Helper to mock rails runner responses
  def stub_rails_runner(analyzer, response)
    analyzer.stubs(:execute_rails_runner).returns(response)
  end
end
