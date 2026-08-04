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

  # Fix 1: IO.read is a separate entry point from File.read and must be sandboxed.
  def test_sandbox_blocks_io_read_outside_project
    output = run_sandbox('puts IO.read("/etc/hosts")')

    assert_includes output, "PATH ERROR"
  end

  # Fix 1: File.readlines is a sibling of File.read and must be sandboxed.
  def test_sandbox_blocks_file_readlines_outside_project
    output = run_sandbox('puts File.readlines("/etc/hosts").length')

    assert_includes output, "PATH ERROR"
  end

  # Fix 1: sensitive project files are blocked via IO.read too, not just File.read.
  def test_sandbox_blocks_sensitive_files_via_io_read
    output = run_sandbox("puts IO.read('config/master.key')")

    assert_includes output, "ACCESS DENIED"
  end

  # Fix 2: the raw native reader is no longer exposed as a public alias.
  def test_sandbox_does_not_expose_original_read_alias
    output = run_sandbox('puts File.original_read("/etc/hosts")')

    assert_includes output, "ERROR"
    refute_includes output, "127.0.0.1"
  end

  # Fix 3: a symlink inside the project must not read a target outside it.
  def test_sandbox_blocks_symlink_escaping_project
    link = File.join(sample_project_path, "escape_hatch_test_link")
    File.symlink("/etc/hosts", link)

    output = run_sandbox('puts File.read("escape_hatch_test_link")')

    assert_includes output, "PATH ERROR"
  ensure
    File.unlink(link) if link && File.symlink?(link)
  end

  # Fix 4: ENV access beyond ENV[] / ENV.fetch is rejected by static analysis.
  def test_static_analysis_rejects_broad_env_access
    %w[ENV.to_h ENV.values_at("X") ENV.each ENV["X"]].each do |snippet|
      error = @tool.send(:validate_code_safety, "puts #{snippet}")

      refute_nil error, "expected #{snippet} to be rejected"
      assert_includes error, "REJECTED"
    end
  end

  # Fix 4: `Rails.env` must not trip the ENV pattern (case-sensitive \bENV\b).
  def test_static_analysis_allows_rails_env
    assert_nil @tool.send(:validate_code_safety, "puts Rails.env")
  end

  # DB harm-reduction: without ActiveRecord the guard is a transparent no-op,
  # so ordinary read-only code still runs and returns output.
  def test_readonly_guard_is_noop_without_active_record
    output = run_sandbox("puts 21 * 2")

    assert_includes output, "42"
    refute_includes output, "ERROR"
  end

  # DB harm-reduction: when a database is available the user code runs inside a
  # transaction that is forced to roll back. Exercised with a stub ActiveRecord.
  def test_readonly_guard_forces_rollback_when_database_available
    output = run_sandbox(<<~RUBY)
      module ActiveRecord
        class Rollback < StandardError; end
        class Base
          @rolled_back = false
          def self.connection = :stub
          def self.rolled_back? = @rolled_back
          def self.transaction
            yield
          rescue ActiveRecord::Rollback
            @rolled_back = true
          end
        end
      end

      ran = false
      McpSandbox.readonly_guard { ran = true }
      puts "ran=\#{ran} rolled_back=\#{ActiveRecord::Base.rolled_back?}"
    RUBY

    assert_includes output, "ran=true rolled_back=true"
  end

  # Confirmation tier: dual-use constructs are not executed without confirm_risky.
  def test_dual_use_constructs_require_confirmation
    {
      "obj.send(:foo)" => "send",
      "obj.public_send(:foo)" => "public_send",
      "Object.const_get(:Kernel)" => "const_get",
      'open("somefile")' => "Kernel#open"
    }.each do |snippet, label|
      result = @tool.send(:confirmation_required, "puts #{snippet}")

      refute_nil result, "expected #{snippet} to require confirmation"
      assert_includes result, "CONFIRMATION REQUIRED"
      assert_includes result, label
      assert_includes result, "confirm_risky: true"
    end
  end

  # Confirmation tier: File.open and similar receiver.open calls are not flagged
  # as Kernel#open, and ordinary code needs no confirmation.
  def test_confirmation_not_required_for_safe_code
    assert_nil @tool.send(:confirmation_required, "puts File.open('Gemfile').read")
    assert_nil @tool.send(:confirmation_required, "puts read_file('Gemfile')")
    assert_nil @tool.send(:confirmation_required, "puts User.count")
  end

  # Confirmation tier: call() returns the confirmation message instead of running
  # the code when confirm_risky is not set.
  def test_call_returns_confirmation_message_without_confirm_risky
    result = @tool.call(code: "puts [].send(:length)")

    assert_includes result, "CONFIRMATION REQUIRED"
  end

  # Confirmation tier: with confirm_risky: true the code runs (proven by output).
  def test_call_executes_risky_code_with_confirm_risky
    @tool.stubs(:execute_sandboxed).returns("executed")

    result = @tool.call(code: "puts [].send(:length)", confirm_risky: true)

    assert_equal "executed", result
  end

  # Tier 1 hardening: PTY.spawn / PTY.getpty start a child process outside the
  # Kernel#system guard and must be rejected by static analysis.
  def test_static_analysis_rejects_pty
    ["PTY.spawn('/bin/sh')", "PTY.getpty('/bin/echo', 'hi')", "require \"pty\""].each do |snippet|
      error = @tool.send(:validate_code_safety, snippet)

      refute_nil error, "expected #{snippet} to be rejected"
      assert_includes error, "REJECTED"
    end
  end

  # Tier 1 hardening: native/syscall bridges can call libc directly.
  def test_static_analysis_rejects_native_bridges
    ["require \"fiddle\"", "require \"ffi\"", "Fiddle::Function.new(x)", "FFI::Library"].each do |snippet|
      refute_nil @tool.send(:validate_code_safety, snippet), "expected #{snippet} to be rejected"
    end
  end

  # Tier 1 hardening: require is blocked outright. bin/rails runner has already
  # booted Rails and the stdlib it loads, so inspection code never needs it,
  # and every dangerous stdlib escape has to be required first. Covers literal
  # (quoted / parenthesized), dynamic, and require_relative forms.
  def test_static_analysis_rejects_all_requires
    [
      'require "pty"',
      "require 'open3'",
      'require("socket")',
      'require "json"',
      "require SOME_CONST",
      'require_relative "../../config/environment"'
    ].each do |snippet|
      error = @tool.send(:validate_code_safety, snippet)

      refute_nil error, "expected #{snippet} to be rejected"
      assert_includes error, "REJECTED"
    end
  end

  # require_dependency (Rails autoload helper) is not a `require` and must not
  # be swept up by the require block.
  def test_static_analysis_allows_require_dependency
    assert_nil @tool.send(:validate_code_safety, 'require_dependency "app/models/user"')
  end

  # Tier 1 hardening: dynamic dispatch to an execution sink by name is
  # hard-blocked, not merely gated behind confirmation.
  def test_static_analysis_hard_blocks_dynamic_dispatch_to_sinks
    [
      'Object.const_get("Open3").capture2("id")',
      "Process.send(:spawn, \"echo hi\")",
      "Kernel.public_send(:system, \"echo hi\")",
      "obj.__send__(:exec, \"echo hi\")"
    ].each do |snippet|
      error = @tool.send(:validate_code_safety, snippet)

      refute_nil error, "expected #{snippet} to be rejected"
      assert_includes error, "REJECTED"
    end
  end

  # Tier 1 hardening: benign dynamic dispatch is untouched by the hard block
  # (it may still hit the confirmation tier, but is not statically rejected).
  def test_static_analysis_allows_benign_send
    assert_nil @tool.send(:validate_code_safety, "record.send(:name)")
    assert_nil @tool.send(:validate_code_safety, 'model.const_get("VERSION")')
  end

  # Tier 1 hardening: end-to-end, a PTY payload never reaches execution.
  def test_pty_payload_is_rejected_end_to_end
    result = @tool.call(code: "require \"pty\"\nPTY.spawn('/bin/echo', 'pwned')")

    assert_includes result, "REJECTED"
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
