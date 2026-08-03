require "bundler"
require "shellwords"

module RailsMcpServer
  class RunProcess
    def self.execute_rails_command(project_path, command)
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
        stdout_str, stderr_str, status = Open3.capture3(subprocess_env, shell, "-c", shell_command)

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
    rescue => e
      RailsMcpServer.log(:error, "Exception executing Rails command: #{e.message}")
      "Exception executing command: #{e.message}"
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
