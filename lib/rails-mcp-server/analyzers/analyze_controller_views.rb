module RailsMcpServer
  module Analyzers
    class AnalyzeControllerViews < BaseAnalyzer
      def call(controller_name: nil, detail_level: "full", analysis_type: "introspection")
        unless current_project
          return "No active project. Please switch to a project first."
        end

        detail_level = "full" unless %w[names summary full].include?(detail_level)
        analysis_type = "introspection" unless %w[introspection static full].include?(analysis_type)

        controllers_dir = File.join(active_project_path, "app", "controllers")
        return "Controllers directory not found." unless File.directory?(controllers_dir)

        controller_files = Dir.glob(File.join(controllers_dir, "**", "*_controller.rb"))
          .reject { |f| f.include?("application_controller") }

        return "No controllers found." if controller_files.empty?

        if controller_name
          normalized = normalize_controller_name(controller_name)
          controller_files = controller_files.select { |f| File.basename(f).downcase == "#{normalized}_controller.rb" }
          return "Controller '#{controller_name}' not found." if controller_files.empty?
        end

        analyze_controllers(controller_files, detail_level, analysis_type)
      end

      private

      def normalize_controller_name(name)
        name.sub(/_?controller$/i, "").downcase
      end

      def analyze_controllers(controller_files, detail_level, analysis_type)
        output = []
        controller_files.each do |file_path|
          controller_class = derive_controller_class(file_path)
          relative_path = file_path.sub(active_project_path + "/", "")

          case detail_level
          when "names"
            actions = get_actions_via_introspection(controller_class)
            output << "#{controller_class} (#{actions.size} actions)"
            output << "  Actions: #{actions.join(", ")}" << ""
          when "summary"
            output << format_summary(controller_class, file_path, relative_path)
          else
            output << format_full_analysis(controller_class, file_path, relative_path, analysis_type)
          end
        end
        output.join("\n")
      end

      def get_actions_via_introspection(controller_class)
        script = "require 'json'; puts (#{controller_class}.action_methods.to_a.sort rescue []).to_json"
        begin
          JSON.parse(execute_rails_runner(script))
        rescue
          []
        end
      end

      def format_summary(controller_class, file_path, relative_path)
        data = get_controller_summary(controller_class)
        output = [controller_class.to_s, "  File: #{relative_path}", "  Actions: #{data[:actions].size}"]
        data[:actions].each do |action|
          route = data[:routes].find { |r| r[:action] == action }
          output << if route
            "    #{action}: [#{route[:verb].empty? ? "ANY" : route[:verb]}] #{route[:path]}"
          else
            "    #{action}: (no route)"
          end
        end
        output << ""
        output.join("\n")
      end

      def get_controller_summary(controller_class)
        script = <<~RUBY
          require 'json'
          begin
            c = #{controller_class}
            actions = c.action_methods.to_a.sort
            routes = Rails.application.routes.routes.select { |r| r.defaults[:controller] == '#{controller_class.sub("Controller", "").underscore}' }
              .map { |r| { verb: r.verb.to_s.gsub(/[\\^$\\/]/, ''), path: r.path.spec.to_s.gsub('(.:format)', ''), action: r.defaults[:action].to_s } }
            puts({ actions: actions, routes: routes }.to_json)
          rescue => e
            puts({ actions: [], routes: [], error: e.message }.to_json)
          end
        RUBY
        begin
          JSON.parse(execute_rails_runner(script), symbolize_names: true)
        rescue
          {actions: [], routes: []}
        end
      end

      def format_full_analysis(controller_class, file_path, relative_path, analysis_type)
        output = ["=" * 70, "Controller: #{controller_class}", "File: #{relative_path}", "=" * 70]

        if %w[introspection full].include?(analysis_type)
          output << "" << introspection_analysis(controller_class)
        end

        if %w[static full].include?(analysis_type)
          output << "" << static_analysis(file_path)
        end

        output << "" << view_analysis(file_path)
        output.join("\n")
      end

      def introspection_analysis(controller_class)
        script = <<~RUBY
          require 'json'
          begin
            c = #{controller_class}
            result = {
              actions: c.action_methods.to_a.sort,
              parent: c.superclass.name,
              callbacks: c._process_action_callbacks.map { |cb| { kind: cb.kind.to_s, filter: cb.filter.to_s, only: Array(cb.options[:only]).map(&:to_s), except: Array(cb.options[:except]).map(&:to_s) } },
              routes: Rails.application.routes.routes.select { |r| r.defaults[:controller] == '#{controller_class.sub("Controller", "").underscore}' }
                .map { |r| { name: r.name.to_s, verb: r.verb.to_s.gsub(/[\\^$\\/]/, ''), path: r.path.spec.to_s.gsub('(.:format)', ''), action: r.defaults[:action].to_s } }
            }
            puts result.to_json
          rescue => e
            puts({ error: e.message }.to_json)
          end
        RUBY
        data = begin
          JSON.parse(execute_rails_runner(script), symbolize_names: true)
        rescue
          nil
        end
        return "Introspection Error" unless data
        return "Error: #{data[:error]}" if data[:error]
        format_introspection_result(data)
      end

      def format_introspection_result(data)
        output = ["RAILS INTROSPECTION:", "-" * 40, "Parent: #{data[:parent]}", "", "Actions (#{data[:actions].size}):"]
        data[:actions].each { |a| output << "  #{a}" }

        if data[:callbacks]&.any?
          output << "" << "Callbacks:"
          data[:callbacks].each do |cb|
            opts = []
            opts << "only: [#{cb[:only].join(", ")}]" if cb[:only]&.any?
            opts << "except: [#{cb[:except].join(", ")}]" if cb[:except]&.any?
            output << "  #{cb[:kind]}_action :#{cb[:filter]}#{", #{opts.join(", ")}" if opts.any?}"
          end
        end

        if data[:routes]&.any?
          output << "" << "Routes (#{data[:routes].size}):"
          data[:routes].each do |r|
            verb = r[:verb].empty? ? "ANY" : r[:verb]
            output << "  #{verb.ljust(7)} #{r[:path].ljust(35)} -> #{r[:action]}"
          end
        end

        output.join("\n")
      end

      def static_analysis(file_path)
        script = <<~RUBY
          require 'json'
          begin
            require 'prism'
            source = File.read('#{file_path}')
            result = Prism.parse(source)
            before_actions, strong_params, instance_vars = [], [], {}
            
            visit = ->(node, ctx = {}) {
              case node
              when Prism::CallNode
                name = node.name.to_s
                args = node.arguments&.arguments&.map { |a| a.is_a?(Prism::SymbolNode) ? a.value.to_s : nil }&.compact || []
                before_actions << { method: args.first, name: name } if %w[before_action after_action skip_before_action].include?(name)
                strong_params << args if name == 'permit'
              when Prism::DefNode
                mname = node.name.to_s
                instance_vars[mname] = []
                node.child_nodes.compact.each { |c| visit.call(c, { method: mname }) }
                return
              when Prism::InstanceVariableWriteNode
                instance_vars[ctx[:method]] << node.name.to_s if ctx[:method]
              end
              node.child_nodes.compact.each { |c| visit.call(c, ctx) }
            }
            result.value.statements.body.each { |n| visit.call(n) }
            puts({ before_actions: before_actions, strong_params: strong_params, instance_vars: instance_vars }.to_json)
          rescue LoadError
            puts({ error: "Prism not available" }.to_json)
          rescue => e
            puts({ error: e.message }.to_json)
          end
        RUBY
        data = begin
          JSON.parse(execute_rails_runner(script), symbolize_names: true)
        rescue
          nil
        end
        return "Static Analysis Error" unless data
        return "Error: #{data[:error]}" if data[:error]
        format_static_result(data)
      end

      def format_static_result(data)
        output = ["PRISM STATIC ANALYSIS:", "-" * 40]
        if data[:before_actions]&.any?
          output << "Filters:"
          data[:before_actions].each { |ba| output << "  #{ba[:name]} :#{ba[:method]}" }
        end
        if data[:strong_params]&.any?
          output << "Strong Parameters:"
          data[:strong_params].each { |sp| output << "  permit(#{sp.join(", ")})" }
        end
        if data[:instance_vars]&.any?
          output << "Instance Variables by Action:"
          data[:instance_vars].each { |action, vars| output << "  #{action}: #{vars.uniq.join(", ")}" if vars.any? }
        end
        output.join("\n")
      end

      def view_analysis(file_path)
        controller_name = File.basename(file_path, "_controller.rb")
        views_dir = File.join(active_project_path, "app", "views", controller_name)
        output = ["VIEW TEMPLATES:", "-" * 40]

        unless File.directory?(views_dir)
          output << "  No views directory found"
          return output.join("\n")
        end

        view_files = Dir.glob(File.join(views_dir, "*")).reject { |f| File.directory?(f) }
        if view_files.empty?
          output << "  No view templates found"
        else
          by_action = view_files.group_by { |f| File.basename(f).split(".").first }
          by_action.sort.each { |action, files| output << "  #{action}: #{files.map { |f| File.basename(f) }.join(", ")}" }
        end
        output.join("\n")
      end

      def derive_controller_class(file_path)
        relative = file_path.sub(File.join(active_project_path, "app", "controllers") + "/", "").sub(/_controller\.rb$/, "")
        relative.split("/").map { |part| camelize(part) }.join("::") + "Controller"
      end
    end
  end
end
