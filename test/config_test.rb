$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"
require "fileutils"
require "yaml"
require "rails_mcp_server"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Test single-project mode configuration
# These tests verify the --single-project flag behavior
class ConfigSingleProjectTest < Minitest::Test
  def setup
    # Store original state
    @original_env = ENV["RAILS_MCP_SINGLE_PROJECT"]
    @original_pwd = Dir.pwd
    @original_config = RailsMcpServer.instance_variable_get(:@config)

    # Create a temporary directory to simulate a project
    @temp_dir = File.join(Dir.tmpdir, "test_rails_project_#{Process.pid}_#{rand(10000)}")
    FileUtils.mkdir_p(@temp_dir)
  end

  def teardown
    # Restore original environment
    if @original_env
      ENV["RAILS_MCP_SINGLE_PROJECT"] = @original_env
    else
      ENV.delete("RAILS_MCP_SINGLE_PROJECT")
    end

    Dir.chdir(@original_pwd)

    # Clean up temporary directory
    FileUtils.rm_rf(@temp_dir) if @temp_dir && File.exist?(@temp_dir)

    # Restore original config
    RailsMcpServer.instance_variable_set(:@config, @original_config)
  end

  def test_single_project_mode_uses_current_directory
    ENV["RAILS_MCP_SINGLE_PROJECT"] = "1"
    Dir.chdir(@temp_dir)

    # Create a fresh config instance
    config = create_fresh_config

    # Use realpath to resolve symlinks (macOS /var -> /private/var)
    expected_path = File.realpath(@temp_dir)
    actual_path = File.realpath(config.active_project_path)

    assert_equal expected_path, actual_path
    assert_equal File.basename(@temp_dir), config.current_project
    assert_equal File.basename(@temp_dir), config.projects.keys.first
  end

  def test_single_project_mode_auto_switches_project
    ENV["RAILS_MCP_SINGLE_PROJECT"] = "1"
    Dir.chdir(@temp_dir)

    config = create_fresh_config

    # Project should be auto-switched (current_project and active_project_path set)
    refute_nil config.current_project
    refute_nil config.active_project_path
  end

  def test_single_project_mode_skips_projects_yml
    ENV["RAILS_MCP_SINGLE_PROJECT"] = "1"
    Dir.chdir(@temp_dir)

    # Even without projects.yml, single-project mode should work
    config = create_fresh_config

    # Should work without projects.yml
    # Use realpath to resolve symlinks (macOS /var -> /private/var)
    expected_path = File.realpath(@temp_dir)
    actual_path = File.realpath(config.active_project_path)
    assert_equal expected_path, actual_path

    # Only one project should be configured
    assert_equal 1, config.projects.size
  end

  def test_environment_variable_enables_single_project_mode
    # Test that setting the env var is enough (no CLI flag needed)
    ENV["RAILS_MCP_SINGLE_PROJECT"] = "1"
    Dir.chdir(@temp_dir)

    config = create_fresh_config

    # Use realpath to resolve symlinks (macOS /var -> /private/var)
    expected_path = File.realpath(@temp_dir)
    actual_path = File.realpath(config.active_project_path)
    assert_equal expected_path, actual_path
  end

  def test_project_name_is_directory_basename
    ENV["RAILS_MCP_SINGLE_PROJECT"] = "1"
    Dir.chdir(@temp_dir)

    config = create_fresh_config

    expected_name = File.basename(@temp_dir)
    assert_equal expected_name, config.current_project
    assert config.projects.key?(expected_name)
  end

  private

  def create_fresh_config
    # Create a new config instance directly, bypassing the singleton
    RailsMcpServer::Config.new
  end
end
