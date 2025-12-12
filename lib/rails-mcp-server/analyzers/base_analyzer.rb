require "active_support/core_ext/string/inflections"

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
        string.to_s.camelize
      end

      def underscore(string)
        string.to_s.underscore
      end

      def extract_json(output)
        return output if output.nil? || output.empty?

        start_idx = output.index("{")
        return output unless start_idx

        end_idx = output.rindex("}")
        return output unless end_idx && end_idx > start_idx

        output[start_idx..end_idx]
      end
    end
  end
end
