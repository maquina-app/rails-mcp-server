require "test_helper"

class PathValidatorTest < Minitest::Test
  include FixtureHelpers

  PathValidator = RailsMcpServer::PathValidator

  def setup
    @project_root = sample_project_path
  end

  # === safe_path? tests ===

  def test_safe_path_allows_relative_paths_inside_project
    assert PathValidator.safe_path?("app/models/user.rb", @project_root)
    assert PathValidator.safe_path?("config/routes.rb", @project_root)
    assert PathValidator.safe_path?("lib/tasks/something.rake", @project_root)
  end

  def test_safe_path_blocks_parent_directory_traversal
    refute PathValidator.safe_path?("../etc/passwd", @project_root)
    refute PathValidator.safe_path?("app/../../etc/passwd", @project_root)
    refute PathValidator.safe_path?("app/../../../etc/passwd", @project_root)
  end

  def test_safe_path_blocks_absolute_paths_outside_project
    refute PathValidator.safe_path?("/etc/passwd", @project_root)
    refute PathValidator.safe_path?("/tmp/other_project/file.rb", @project_root)
  end

  def test_safe_path_blocks_empty_and_nil_paths
    refute PathValidator.safe_path?(nil, @project_root)
    refute PathValidator.safe_path?("", @project_root)
  end

  def test_safe_path_blocks_root_directory_access
    # Prevent access to project root itself (edge case for sensitive file checks)
    refute PathValidator.safe_path?(".", @project_root)
    refute PathValidator.safe_path?("./", @project_root)
  end

  # === sensitive_path? tests ===

  def test_sensitive_path_detects_env_files
    assert PathValidator.sensitive_path?(".env")
    assert PathValidator.sensitive_path?(".env.local")
    assert PathValidator.sensitive_path?(".env.production")
    assert PathValidator.sensitive_path?(".ENV")
  end

  def test_sensitive_path_detects_key_files
    assert PathValidator.sensitive_path?("config/master.key")
    assert PathValidator.sensitive_path?("config/credentials/production.key")
    assert PathValidator.sensitive_path?("private.key")
    assert PathValidator.sensitive_path?("server.pem")
  end

  def test_sensitive_path_detects_credentials_files
    assert PathValidator.sensitive_path?("config/credentials.yml.enc")
    assert PathValidator.sensitive_path?("config/credentials.yml")
    assert PathValidator.sensitive_path?("config/secrets.yml")
    assert PathValidator.sensitive_path?("database.yml")
  end

  def test_sensitive_path_detects_ssh_files
    assert PathValidator.sensitive_path?(".ssh/id_rsa")
    assert PathValidator.sensitive_path?(".ssh/id_ed25519")
    assert PathValidator.sensitive_path?("id_rsa")
  end

  def test_sensitive_path_allows_normal_files
    refute PathValidator.sensitive_path?("app/models/user.rb")
    refute PathValidator.sensitive_path?("config/routes.rb")
    refute PathValidator.sensitive_path?("Gemfile")
    refute PathValidator.sensitive_path?("README.md")
  end

  # === validate_path tests ===

  def test_validate_path_returns_expanded_path_for_safe_files
    result = PathValidator.validate_path("app/models/user.rb", @project_root)
    assert_equal File.join(@project_root, "app/models/user.rb"), result
  end

  def test_validate_path_returns_nil_for_traversal_attempts
    assert_nil PathValidator.validate_path("../etc/passwd", @project_root)
    assert_nil PathValidator.validate_path("app/../../etc/passwd", @project_root)
  end

  def test_validate_path_returns_nil_for_sensitive_files
    assert_nil PathValidator.validate_path(".env", @project_root)
    assert_nil PathValidator.validate_path("config/master.key", @project_root)
    assert_nil PathValidator.validate_path("config/credentials.yml.enc", @project_root)
  end

  # === valid_identifier? tests ===

  def test_valid_identifier_accepts_simple_class_names
    assert PathValidator.valid_identifier?("User")
    assert PathValidator.valid_identifier?("Product")
    assert PathValidator.valid_identifier?("ApplicationRecord")
  end

  def test_valid_identifier_accepts_namespaced_class_names
    assert PathValidator.valid_identifier?("Admin::User")
    assert PathValidator.valid_identifier?("API::V1::UserSerializer")
    assert PathValidator.valid_identifier?("Foo::Bar::Baz::Qux")
  end

  def test_valid_identifier_accepts_underscored_names
    assert PathValidator.valid_identifier?("user_role")
    assert PathValidator.valid_identifier?("Admin::user_config")
  end

  def test_valid_identifier_rejects_shell_injection_attempts
    refute PathValidator.valid_identifier?("User; rm -rf /")
    refute PathValidator.valid_identifier?("User`whoami`")
    refute PathValidator.valid_identifier?("User$(id)")
    refute PathValidator.valid_identifier?("User|cat /etc/passwd")
  end

  def test_valid_identifier_rejects_path_traversal
    refute PathValidator.valid_identifier?("../User")
    refute PathValidator.valid_identifier?("User/../Admin")
  end

  def test_valid_identifier_rejects_empty_and_nil
    refute PathValidator.valid_identifier?(nil)
    refute PathValidator.valid_identifier?("")
  end

  # === valid_table_name? tests ===

  def test_valid_table_name_accepts_snake_case_names
    assert PathValidator.valid_table_name?("users")
    assert PathValidator.valid_table_name?("user_profiles")
    assert PathValidator.valid_table_name?("api_v1_tokens")
  end

  def test_valid_table_name_rejects_namespacing
    # Table names don't have :: namespacing
    refute PathValidator.valid_table_name?("admin::users")
    refute PathValidator.valid_table_name?("Admin::Users")
  end

  def test_valid_table_name_rejects_sql_injection_attempts
    refute PathValidator.valid_table_name?("users; DROP TABLE users;")
    refute PathValidator.valid_table_name?("users' OR '1'='1")
    refute PathValidator.valid_table_name?("users--")
  end

  # === filter_sensitive_files tests ===

  def test_filter_sensitive_files_removes_sensitive_entries
    files = [
      "#{@project_root}/app/models/user.rb",
      "#{@project_root}/.env",
      "#{@project_root}/config/master.key",
      "#{@project_root}/config/routes.rb"
    ]

    result = PathValidator.filter_sensitive_files(files, @project_root)

    assert_includes result, "#{@project_root}/app/models/user.rb"
    assert_includes result, "#{@project_root}/config/routes.rb"
    refute_includes result, "#{@project_root}/.env"
    refute_includes result, "#{@project_root}/config/master.key"
  end

  # === excluded_directory? tests ===

  def test_excluded_directory_detects_git_directory
    assert PathValidator.excluded_directory?(".git/config")
    assert PathValidator.excluded_directory?(".git/hooks/pre-commit")
  end

  def test_excluded_directory_detects_node_modules
    assert PathValidator.excluded_directory?("node_modules/lodash/index.js")
  end

  def test_excluded_directory_detects_vendor_bundle
    assert PathValidator.excluded_directory?("vendor/bundle/ruby/3.2.0/gems/foo")
  end

  def test_excluded_directory_allows_normal_directories
    refute PathValidator.excluded_directory?("app/models/user.rb")
    refute PathValidator.excluded_directory?("lib/tasks/foo.rake")
  end
end
