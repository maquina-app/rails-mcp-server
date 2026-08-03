require "test_helper"
require "tmpdir"
require "fileutils"
require "shellwords"

class RunProcessTest < Minitest::Test
  def test_no_shim_dirs_when_no_manager_is_installed
    Dir.mktmpdir do |home|
      dirs = RailsMcpServer::RunProcess.version_manager_shim_dirs(home: home, env: {})

      assert_empty dirs
    end
  end

  def test_detects_mise_shims
    Dir.mktmpdir do |home|
      shims = File.join(home, ".local", "share", "mise", "shims")
      FileUtils.mkdir_p(shims)

      dirs = RailsMcpServer::RunProcess.version_manager_shim_dirs(home: home, env: {})

      assert_equal [shims], dirs
    end
  end

  def test_detects_asdf_shims
    Dir.mktmpdir do |home|
      shims = File.join(home, ".asdf", "shims")
      FileUtils.mkdir_p(shims)

      dirs = RailsMcpServer::RunProcess.version_manager_shim_dirs(home: home, env: {})

      assert_equal [shims], dirs
    end
  end

  def test_detects_rbenv_shims
    Dir.mktmpdir do |home|
      shims = File.join(home, ".rbenv", "shims")
      FileUtils.mkdir_p(shims)

      dirs = RailsMcpServer::RunProcess.version_manager_shim_dirs(home: home, env: {})

      assert_equal [shims], dirs
    end
  end

  def test_honors_mise_data_dir_override
    Dir.mktmpdir do |home|
      Dir.mktmpdir do |data|
        shims = File.join(data, "shims")
        FileUtils.mkdir_p(shims)

        dirs = RailsMcpServer::RunProcess.version_manager_shim_dirs(
          home: home, env: {"MISE_DATA_DIR" => data}
        )

        assert_equal [shims], dirs
      end
    end
  end

  def test_honors_xdg_data_home_for_mise
    Dir.mktmpdir do |home|
      Dir.mktmpdir do |xdg|
        shims = File.join(xdg, "mise", "shims")
        FileUtils.mkdir_p(shims)

        dirs = RailsMcpServer::RunProcess.version_manager_shim_dirs(
          home: home, env: {"XDG_DATA_HOME" => xdg}
        )

        assert_equal [shims], dirs
      end
    end
  end

  def test_prepend_shims_puts_them_ahead_of_existing_path
    shims = "/opt/mise/shims"
    RailsMcpServer::RunProcess.stubs(:version_manager_shim_dirs).returns([shims])

    env = {"PATH" => "/usr/bin:/bin"}
    RailsMcpServer::RunProcess.prepend_version_manager_shims(env)

    assert_equal "#{shims}:/usr/bin:/bin", env["PATH"]
  end

  def test_prepend_shims_is_a_noop_without_a_manager
    RailsMcpServer::RunProcess.stubs(:version_manager_shim_dirs).returns([])

    env = {"PATH" => "/usr/bin:/bin"}
    RailsMcpServer::RunProcess.prepend_version_manager_shims(env)

    assert_equal "/usr/bin:/bin", env["PATH"]
  end

  def test_build_shell_command_cds_into_project
    Dir.mktmpdir do |home|
      Dir.stubs(:home).returns(home) # no ~/.rvm here

      cmd = RailsMcpServer::RunProcess.build_shell_command("/tmp/my project", "bin/rails runner x.rb")

      assert_equal "cd #{Shellwords.escape("/tmp/my project")} && bin/rails runner x.rb", cmd
    end
  end

  def test_build_shell_command_sources_rvm_before_cd_when_present
    Dir.mktmpdir do |home|
      rvm_script = File.join(home, ".rvm", "scripts", "rvm")
      FileUtils.mkdir_p(File.dirname(rvm_script))
      File.write(rvm_script, "")
      Dir.stubs(:home).returns(home)

      cmd = RailsMcpServer::RunProcess.build_shell_command("/tmp/app", "bin/rails runner x.rb")

      assert_equal(
        "source #{Shellwords.escape(rvm_script)} && cd #{Shellwords.escape("/tmp/app")} && bin/rails runner x.rb",
        cmd
      )
    end
  end
end
