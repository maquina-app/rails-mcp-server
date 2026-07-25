require "test_helper"
require "open3"
require "tempfile"
require "rbconfig"

class ExecuteRubyTest < Minitest::Test
  include FixtureHelpers

  ZONEINFO_FILE = "/usr/share/zoneinfo/UTC"

  def setup
    setup_sample_project
    @tool = RailsMcpServer::ExecuteRuby.new
  end

  def teardown
    teardown_sample_project
  end

  def test_sandbox_embeds_allowed_read_paths
    sandbox = @tool.send(:build_sandbox, "puts 1")

    RailsMcpServer::ExecuteRuby::ALLOWED_READ_PATHS.each do |path|
      assert_includes sandbox, path
    end
  end

  def test_sandbox_allows_reading_zoneinfo
    skip "#{ZONEINFO_FILE} not present on this system" unless File.exist?(ZONEINFO_FILE)

    output = run_sandbox("puts File.read(#{ZONEINFO_FILE.inspect}).bytesize")

    refute_includes output, "PATH ERROR"
    assert_operator output.to_i, :>, 0
  end

  def test_sandbox_allows_zoneinfo_existence_checks
    skip "#{ZONEINFO_FILE} not present on this system" unless File.exist?(ZONEINFO_FILE)

    output = run_sandbox("puts File.exist?(#{ZONEINFO_FILE.inspect})")

    assert_includes output, "true"
  end

  def test_sandbox_file_open_yields_readable_io_for_allowed_paths
    skip "#{ZONEINFO_FILE} not present on this system" unless File.exist?(ZONEINFO_FILE)

    output = run_sandbox("File.open(#{ZONEINFO_FILE.inspect}, \"rb\") { |f| puts f.read.bytesize }")

    refute_includes output, "ERROR"
    assert_operator output.to_i, :>, 0
  end

  def test_sandbox_blocks_system_paths_outside_allowlist
    output = run_sandbox('puts File.read("/etc/hosts")')

    assert_includes output, "PATH ERROR"
  end

  def test_sandbox_blocks_traversal_escaping_allowed_paths
    output = run_sandbox('puts File.read("/usr/share/zoneinfo/../../../etc/hosts")')

    assert_includes output, "PATH ERROR"
  end

  def test_sandbox_blocks_writes_under_allowed_paths
    output = run_sandbox('File.write("/usr/share/zoneinfo/evil", "x")')

    assert_includes output, "WRITE ERROR"
  end

  def test_sandbox_still_reads_project_files
    output = run_sandbox("puts read_file('Gemfile')")

    refute_includes output, "PATH ERROR"
    assert_includes output, "rails"
  end

  def test_sandbox_still_blocks_sensitive_project_files
    output = run_sandbox("puts read_file('config/master.key')")

    assert_includes output, "ACCESS DENIED"
  end

  private

  # Runs the generated sandbox script in a plain Ruby subprocess (without
  # `rails runner`) and returns its stdout.
  def run_sandbox(user_code)
    sandbox = @tool.send(:build_sandbox, user_code)

    Tempfile.create(["sandbox_test", ".rb"]) do |f|
      f.write(sandbox)
      f.flush

      stdout, _stderr, _status = Open3.capture3(RbConfig.ruby, f.path)
      stdout
    end
  end
end
