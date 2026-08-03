require "bundler"
require "shellwords"
require "open3"
require "timeout"

module RailsMcpServer
  class RunProcess
    # `timeout` (seconds) bounds execution. When set, the command runs in its
    # own process group so a timeout kills the whole tree; nil keeps the
    # original unbounded behavior.
    def self.execute_rails_command(project_path, command, timeout: nil)
      RailsMcpServer.log(:debug, "Executing: #{command}")

      Bundler.with_unbundled_env do
        subprocess_env = ENV.to_h
        subprocess_env.delete("BUNDLE_GEMFILE")

        # Make `bin/rails` resolve the *project's* Ruby regardless of which
        # version manager is in use. mise, asdf and rbenv each expose a "shims"
        # directory whose wrappers pick the Ruby from the project's
        # .ruby-version / .tool-versions / .mise.toml at run time. Prepending it
        # to PATH is manager-agnostic and needs no manager-specific environment
        # variables (the previous RBENV_VERSION handling only worked for rbenv).
        prepend_version_manager_shims(subprocess_env)

        shell = ENV.fetch("SHELL", "/bin/bash")
        shell_command = build_shell_command(project_path, command)

        # A *non-login* shell (`-c`, not `-l`). A login shell triggers macOS
        # `path_helper` (via /etc/zprofile), which rebuilds PATH with /usr/bin
        # ahead of the manager's shims — the exact reason the system Ruby leaked
        # in. It also never sources ~/.zshrc, where mise/asdf activation usually
        # lives. `-c` keeps the PATH we assembled above intact.
        stdout_str, stderr_str, status =
          if timeout
            capture3_with_timeout(subprocess_env, shell, shell_command, timeout)
          else
            Open3.capture3(subprocess_env, shell, "-c", shell_command)
          end

        if status.success?
          RailsMcpServer.log(:debug, "Command succeeded")
          stdout_str
        else
          RailsMcpServer.log(:error, "Command failed with status: #{status.exitstatus}")
          RailsMcpServer.log(:error, "stderr: #{stderr_str}")

          error_output = stderr_str.empty? ? stdout_str : stderr_str
          "Error executing Rails command: #{command}\n\n#{error_output}"
        end
      end
    rescue Timeout::Error
      RailsMcpServer.log(:error, "Command timed out after #{timeout} seconds")
      "TIMEOUT: Execution exceeded #{timeout} seconds"
    rescue => e
      RailsMcpServer.log(:error, "Exception executing Rails command: #{e.message}")
      "Exception executing command: #{e.message}"
    end

    # Run the command in its own process group so a timeout can kill the entire
    # tree (the shell *and* its `rails runner` grandchild). Open3.capture3 gives
    # no handle to signal the group, so drive popen3 directly and drain stdout/
    # stderr on separate threads to avoid a full-pipe deadlock. Re-raises
    # Timeout::Error after killing; the caller maps it to a user-facing message.
    def self.capture3_with_timeout(env, shell, shell_command, timeout)
      Open3.popen3(env, shell, "-c", shell_command, pgroup: true) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        out = +""
        err = +""
        out_reader = Thread.new { out << stdout.read }
        err_reader = Thread.new { err << stderr.read }

        begin
          status = Timeout.timeout(timeout) { wait_thr.value }
          out_reader.join
          err_reader.join
          [out, err, status]
        rescue Timeout::Error
          kill_process_group(wait_thr.pid)
          out_reader.join(1)
          err_reader.join(1)
          raise
        end
      end
    end

    # KILL the process group led by `pid`. Negative pid targets the whole group.
    def self.kill_process_group(pid)
      Process.kill("KILL", -Process.getpgid(pid))
    rescue Errno::ESRCH, Errno::EPERM
      # Already exited or not signalable; nothing to clean up.
    end

    # Shim directories for the version managers installed on this machine,
    # detected by their well-known locations so resolution works even in a
    # non-login shell that never sourced the manager's activation. Honors the
    # managers' own overrides (MISE_DATA_DIR / XDG_DATA_HOME, ASDF_DATA_DIR,
    # RBENV_ROOT). A machine normally has just one.
    def self.version_manager_shim_dirs(home: Dir.home, env: ENV)
      mise_data = env["MISE_DATA_DIR"] ||
        File.join(env["XDG_DATA_HOME"] || File.join(home, ".local", "share"), "mise")

      [
        File.join(mise_data, "shims"),                                        # mise
        File.join(env["ASDF_DATA_DIR"] || File.join(home, ".asdf"), "shims"), # asdf
        File.join(env["RBENV_ROOT"] || File.join(home, ".rbenv"), "shims")    # rbenv
      ].select { |dir| File.directory?(dir) }
    end

    # Prepend the detected shim directories to the subprocess PATH.
    def self.prepend_version_manager_shims(env)
      dirs = version_manager_shim_dirs(env: env)
      return if dirs.empty?

      path = env["PATH"].to_s
      env["PATH"] = (path.empty? ? dirs : dirs + [path]).join(File::PATH_SEPARATOR)
    end

    # rvm has no shims — it activates through a shell function keyed off the
    # working directory, so source it (before `cd`, so its chpwd hook is in
    # place) when it is installed. Everything else just runs in the project dir.
    def self.build_shell_command(project_path, command)
      cd = "cd #{Shellwords.escape(project_path)}"
      rvm_script = File.join(Dir.home, ".rvm", "scripts", "rvm")

      if File.exist?(rvm_script)
        "source #{Shellwords.escape(rvm_script)} && #{cd} && #{command}"
      else
        "#{cd} && #{command}"
      end
    end
  end
end
