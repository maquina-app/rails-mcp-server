$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "minitest/reporters"
require "mocha/minitest"
require "fileutils"
require "tmpdir"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Test Config class in isolation
class ConfigTest < Minitest::Test
  def setup
    @original_env = ENV.to_h
    @original_pwd = Dir.pwd
    @temp_dir = Dir.mktmpdir("rails_mcp_test")

    # Clear any existing env vars that might affect tests
    ENV.delete("RAILS_MCP_PROJECT_PATH")
    ENV.delete("XDG_CONFIG_HOME")
  end

  def teardown
    Dir.chdir(@original_pwd)
    FileUtils.rm_rf(@temp_dir)

    # Restore original environment
    ENV.clear
    @original_env.each { |k, v| ENV[k] = v }

    # Reset the singleton config to a fresh instance (not nil!)
    RailsMcpServer.instance_variable_set(:@config, RailsMcpServer::Config.setup)
  end

  def test_env_var_mode_takes_priority
    # Setup: Create a Rails project directory
    project_path = File.join(@temp_dir, "my_rails_app")
    FileUtils.mkdir_p(project_path)
    File.write(File.join(project_path, "Gemfile"), 'gem "rails"')

    # Set environment variable
    ENV["RAILS_MCP_PROJECT_PATH"] = project_path
    ENV["XDG_CONFIG_HOME"] = @temp_dir

    # Load config
    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    assert_equal "my_rails_app", config.current_project
    assert_equal project_path, config.active_project_path
    assert_equal({
      "my_rails_app" => project_path
    }, config.projects)
  end

  def test_auto_detect_rails_project_from_cwd
    # Setup: Create a Rails project in temp dir and cd into it
    rails_project = File.join(@temp_dir, "detected_app")
    FileUtils.mkdir_p(rails_project)
    File.write(File.join(rails_project, "Gemfile"), 'gem "rails", "~> 8.0"')

    # Setup config dir with empty projects.yml
    config_dir = File.join(@temp_dir, "config")
    FileUtils.mkdir_p(config_dir)
    ENV["XDG_CONFIG_HOME"] = @temp_dir

    Dir.chdir(rails_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    assert_equal "detected_app", config.current_project
    # Use realpath to handle macOS /var -> /private/var symlink
    assert_equal File.realpath(rails_project), File.realpath(config.active_project_path)
  end

  def test_auto_detect_skips_non_rails_directories
    # Setup: Create a non-Rails project (no rails gem in Gemfile)
    non_rails_project = File.join(@temp_dir, "not_rails")
    FileUtils.mkdir_p(non_rails_project)
    File.write(File.join(non_rails_project, "Gemfile"), 'gem "sinatra"')

    # Setup config dir with a project
    config_dir = File.join(@temp_dir, "rails-mcp")
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, "projects.yml"), "test_project: #{@temp_dir}/some_project")
    FileUtils.mkdir_p(File.join(@temp_dir, "some_project"))
    ENV["XDG_CONFIG_HOME"] = @temp_dir

    Dir.chdir(non_rails_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    # Should have loaded from projects.yml, not auto-detected
    assert_includes config.projects.keys, "test_project"
  end

  def test_auto_detect_with_double_quoted_rails
    # Test detection with double-quoted gem
    rails_project = File.join(@temp_dir, "double_quote_app")
    FileUtils.mkdir_p(rails_project)
    File.write(File.join(rails_project, "Gemfile"), "gem \"rails\"\n")

    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(rails_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    assert_equal "double_quote_app", config.current_project
  end

  def test_auto_detect_with_single_quoted_rails
    # Test detection with single-quoted gem
    rails_project = File.join(@temp_dir, "single_quote_app")
    FileUtils.mkdir_p(rails_project)
    File.write(File.join(rails_project, "Gemfile"), "gem 'rails'\n")

    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(rails_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    assert_equal "single_quote_app", config.current_project
  end

  def test_single_project_in_projects_yml_auto_switches
    # Setup config dir with single project
    config_dir = File.join(@temp_dir, "rails-mcp")
    FileUtils.mkdir_p(config_dir)

    project_path = File.join(@temp_dir, "only_project")
    FileUtils.mkdir_p(project_path)
    File.write(File.join(config_dir, "projects.yml"), "only_project: #{project_path}")

    ENV["XDG_CONFIG_HOME"] = @temp_dir

    # CD to a non-rails directory so auto-detect doesn't kick in
    Dir.chdir(@temp_dir)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    # Should auto-switch to the only project
    assert_equal "only_project", config.current_project
    assert_equal project_path, config.active_project_path
  end

  def test_multiple_projects_in_projects_yml_does_not_auto_switch
    # Setup config dir with multiple projects
    config_dir = File.join(@temp_dir, "rails-mcp")
    FileUtils.mkdir_p(config_dir)

    project1_path = File.join(@temp_dir, "project1")
    project2_path = File.join(@temp_dir, "project2")
    FileUtils.mkdir_p(project1_path)
    FileUtils.mkdir_p(project2_path)

    projects_yml = <<~YAML
      project1: #{project1_path}
      project2: #{project2_path}
    YAML
    File.write(File.join(config_dir, "projects.yml"), projects_yml)

    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(@temp_dir)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    # Should NOT auto-switch when multiple projects exist
    assert_nil config.current_project
    assert_nil config.active_project_path
    assert_equal 2, config.projects.size
  end

  def test_env_var_takes_priority_over_auto_detect
    # Setup: Rails project in cwd AND env var pointing elsewhere
    rails_in_cwd = File.join(@temp_dir, "cwd_rails")
    FileUtils.mkdir_p(rails_in_cwd)
    File.write(File.join(rails_in_cwd, "Gemfile"), 'gem "rails"')

    env_var_project = File.join(@temp_dir, "env_var_rails")
    FileUtils.mkdir_p(env_var_project)

    ENV["RAILS_MCP_PROJECT_PATH"] = env_var_project
    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(rails_in_cwd)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    # Env var should take priority
    assert_equal "env_var_rails", config.current_project
    assert_equal env_var_project, config.active_project_path
  end

  def test_env_var_expands_relative_paths
    project_path = File.join(@temp_dir, "relative_test")
    FileUtils.mkdir_p(project_path)

    Dir.chdir(@temp_dir)
    ENV["RAILS_MCP_PROJECT_PATH"] = "./relative_test"
    ENV["XDG_CONFIG_HOME"] = @temp_dir

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    # Use realpath to handle macOS /var -> /private/var symlink
    assert_equal File.realpath(project_path), File.realpath(config.active_project_path)
  end

  def test_auto_detect_rails_engine_with_rails_dependency
    # Setup: Create a Rails engine with gemspec
    engine_project = File.join(@temp_dir, "my_engine")
    FileUtils.mkdir_p(engine_project)

    gemspec_content = <<~GEMSPEC
      Gem::Specification.new do |spec|
        spec.name = "my_engine"
        spec.version = "0.1.0"
        spec.authors = ["Test"]
        spec.summary = "A Rails engine"

        spec.add_dependency "rails", ">= 7.0"
      end
    GEMSPEC
    File.write(File.join(engine_project, "my_engine.gemspec"), gemspec_content)

    # Create a Gemfile without explicit rails (typical for engines)
    File.write(File.join(engine_project, "Gemfile"), "gemspec\n")

    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(engine_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    assert_equal "my_engine", config.current_project
    assert_equal File.realpath(engine_project), File.realpath(config.active_project_path)
  end

  def test_auto_detect_rails_engine_with_railties_dependency
    # Setup: Create a Rails engine that depends on railties
    engine_project = File.join(@temp_dir, "railties_engine")
    FileUtils.mkdir_p(engine_project)

    gemspec_content = <<~GEMSPEC
      Gem::Specification.new do |spec|
        spec.name = "railties_engine"
        spec.version = "0.1.0"
        spec.add_runtime_dependency "railties", ">= 6.0"
        spec.add_runtime_dependency "activerecord", ">= 6.0"
      end
    GEMSPEC
    File.write(File.join(engine_project, "railties_engine.gemspec"), gemspec_content)

    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(engine_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    assert_equal "railties_engine", config.current_project
  end

  def test_auto_detect_rails_engine_with_actionpack_dependency
    # Setup: Create a Rails engine that depends on actionpack
    engine_project = File.join(@temp_dir, "actionpack_engine")
    FileUtils.mkdir_p(engine_project)

    gemspec_content = <<~GEMSPEC
      Gem::Specification.new do |spec|
        spec.name = "actionpack_engine"
        spec.version = "0.1.0"
        spec.add_dependency 'actionpack'
      end
    GEMSPEC
    File.write(File.join(engine_project, "actionpack_engine.gemspec"), gemspec_content)

    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(engine_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    assert_equal "actionpack_engine", config.current_project
  end

  def test_auto_detect_skips_non_rails_gem
    # Setup: Create a regular Ruby gem without Rails dependencies
    gem_project = File.join(@temp_dir, "plain_gem")
    FileUtils.mkdir_p(gem_project)

    gemspec_content = <<~GEMSPEC
      Gem::Specification.new do |spec|
        spec.name = "plain_gem"
        spec.version = "0.1.0"
        spec.add_dependency "httparty"
        spec.add_development_dependency "rspec"
      end
    GEMSPEC
    File.write(File.join(gem_project, "plain_gem.gemspec"), gemspec_content)

    # Setup config dir with a project
    config_dir = File.join(@temp_dir, "rails-mcp")
    FileUtils.mkdir_p(config_dir)
    File.write(File.join(config_dir, "projects.yml"), "fallback_project: #{@temp_dir}/fallback")
    FileUtils.mkdir_p(File.join(@temp_dir, "fallback"))

    ENV["XDG_CONFIG_HOME"] = @temp_dir
    Dir.chdir(gem_project)

    require "rails_mcp_server"
    config = RailsMcpServer::Config.new

    # Should have loaded from projects.yml, not auto-detected
    assert_includes config.projects.keys, "fallback_project"
    refute_includes config.projects.keys, "plain_gem"
  end
end
