module RailsMcpServer
  module Analyzers
    class BaseAnalyzer
      extend Forwardable

      def_delegators :RailsMcpServer, :log, :projects
      def_delegators :RailsMcpServer, :current_project, :active_project_path

      def call(**params)
        raise NotImplementedError, "Subclasses must implement #call"
      end

      protected

      def execute_rails_runner(script)
        require "tempfile"

        Tempfile.create(["analyzer", ".rb"]) do |f|
          f.write(script)
          f.flush

          RailsMcpServer::RunProcess.execute_rails_command(
            active_project_path,
            "bin/rails runner #{f.path} 2>/dev/null"
          )
        end
      end

      def camelize(string)
        string.split("_").map(&:capitalize).join
      end

      def underscore(string)
        string.gsub("::", "/")
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .tr("-", "_")
          .downcase
      end
    end
  end
end
