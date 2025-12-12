require "bundler"
require "shellwords"

module RailsMcpServer
  class RunProcess
    def self.execute_rails_command(project_path, command)
      RailsMcpServer.log(:debug, "Executing: #{command}")

      Bundler.with_unbundled_env do
        subprocess_env = ENV.to_h
        subprocess_env.delete("BUNDLE_GEMFILE")

        # Set RBENV_VERSION from project's .ruby-version if it exists
        ruby_version_file = File.join(project_path, ".ruby-version")
        if File.exist?(ruby_version_file)
          subprocess_env["RBENV_VERSION"] = File.read(ruby_version_file).strip
        else
          subprocess_env.delete("RBENV_VERSION")
        end

        shell = ENV.fetch("SHELL", "/bin/bash")
        shell_command = "cd #{Shellwords.escape(project_path)} && #{command}"
        stdout_str, stderr_str, status = Open3.capture3(subprocess_env, shell, "-l", "-c", shell_command)

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
  end
end
