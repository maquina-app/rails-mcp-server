module RailsMcpServer
  module Analyzers
    class GetRoutes < BaseAnalyzer
      def call(controller: nil, verb: nil, path_contains: nil, named_only: false, detail_level: "full")
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        detail_level = "full" unless %w[names summary full].include?(detail_level)

        routes_data = fetch_routes_via_introspection

        if routes_data[:error]
          log(:warn, "Error fetching routes: #{routes_data[:error]}")
          return "Error fetching routes: #{routes_data[:error]}"
        end

        routes = routes_data[:routes] || []

        routes = filter_routes(routes, controller: controller, verb: verb, path_contains: path_contains, named_only: named_only)

        if routes.empty?
          message = "No routes found"
          message += " matching filters" if controller || verb || path_contains || named_only
          return message
        end

        log(:debug, "Found #{routes.size} matching routes")

        format_routes(routes, detail_level)
      end

      private

      def fetch_routes_via_introspection
        script = <<~RUBY
          require 'json'
          
          def extract_constraints(route)
            constraints = {}
            
            if route.constraints.is_a?(Hash)
              route.constraints.each do |key, value|
                constraints[key.to_s] = value.is_a?(Regexp) ? value.source : value.to_s
              end
            end
            
            if route.respond_to?(:requirements)
              route.requirements.each do |key, value|
                next if [:controller, :action].include?(key)
                constraints[key.to_s] = value.is_a?(Regexp) ? value.source : value.to_s
              end
            end
            
            constraints
          end
          
          begin
            Rails.application.eager_load! unless Rails.application.config.eager_load
            
            routes = Rails.application.routes.routes.map do |route|
              next if route.internal
              
              path = route.path.spec.to_s
              next if path == '(.):format'
              
              path = path.gsub('(.:format)', '').gsub('(:format)', '')
              
              verb = route.verb.to_s
              verb = verb.empty? ? 'ANY' : verb
              verb = verb.gsub(/[\\^$\\/]/, '') if verb.include?('^')
              
              controller = route.defaults[:controller].to_s
              action = route.defaults[:action].to_s
              
              next if controller.empty?
              
              {
                name: route.name.to_s,
                verb: verb,
                path: path,
                controller: controller,
                action: action,
                controller_action: controller.empty? ? '' : "\#{controller}#\#{action}",
                constraints: extract_constraints(route),
                defaults: route.defaults.except(:controller, :action).transform_keys(&:to_s),
                required_parts: route.required_parts.map(&:to_s),
                optional_parts: route.parts.map(&:to_s) - route.required_parts.map(&:to_s)
              }
            end.compact
            
            by_controller = routes.group_by { |r| r[:controller] }
            
            puts({
              routes: routes,
              total_count: routes.size,
              controllers: by_controller.transform_values(&:size)
            }.to_json)
            
          rescue => e
            puts({ error: e.message, backtrace: e.backtrace.first(5) }.to_json)
          end
        RUBY

        json_output = execute_rails_runner(script)

        begin
          JSON.parse(json_output, symbolize_names: true)
        rescue JSON::ParserError => e
          {error: "Failed to parse routes: #{e.message}", raw: json_output}
        end
      end

      def filter_routes(routes, controller:, verb:, path_contains:, named_only:)
        filtered = routes

        if controller && !controller.empty?
          controller_pattern = controller.downcase
          filtered = filtered.select do |r|
            r[:controller].to_s.downcase.include?(controller_pattern)
          end
        end

        if verb && !verb.empty?
          verb_upper = verb.upcase
          filtered = filtered.select do |r|
            r[:verb].to_s.upcase.include?(verb_upper)
          end
        end

        if path_contains && !path_contains.empty?
          filtered = filtered.select do |r|
            r[:path].to_s.include?(path_contains)
          end
        end

        if named_only
          filtered = filtered.select do |r|
            r[:name] && !r[:name].empty?
          end
        end

        filtered
      end

      def format_routes(routes, detail_level)
        case detail_level
        when "names"
          paths = routes.map { |r| r[:path] }.uniq.sort # rubocop:disable Performance/ChainArrayAllocation
          "Route paths (#{paths.size} unique):\n\n#{paths.join("\n")}"

        when "summary"
          output = "Rails Routes (#{routes.size} routes):\n"

          by_controller = routes.group_by { |r| r[:controller] }

          by_controller.sort.each do |controller, controller_routes|
            output << "#{controller}:\n"
            controller_routes.each do |r|
              verb_padded = r[:verb].to_s.ljust(7)
              name_str = r[:name].to_s.empty? ? "" : " (#{r[:name]})"
              output << "  #{verb_padded} #{r[:path].ljust(40)} #{r[:action]}#{name_str}\n"
            end
            output << "\n"
          end

          output

        when "full"
          output = "Rails Routes (#{routes.size} routes):\n"
          output << "=" * 70 << "\n"

          routes.each do |r|
            output << "\n"
            output << "#{r[:verb]} #{r[:path]}\n"
            output << "  Name: #{r[:name]}\n" unless r[:name].to_s.empty?
            output << "  Controller: #{r[:controller_action]}\n"

            if r[:constraints]&.any?
              output << "  Constraints: #{r[:constraints].map { |k, v| "#{k}: #{v}" }.join(", ")}\n"
            end

            if r[:defaults]&.any?
              output << "  Defaults: #{r[:defaults].map { |k, v| "#{k}: #{v}" }.join(", ")}\n"
            end

            if r[:required_parts]&.any?
              output << "  Required params: #{r[:required_parts].join(", ")}\n"
            end

            if r[:optional_parts]&.any?
              output << "  Optional params: #{r[:optional_parts].join(", ")}\n"
            end
          end

          output << "\n"
          output << "=" * 70 << "\n"
          output << "Summary by controller:\n"

          by_controller = routes.group_by { |r| r[:controller] }
          by_controller.sort.each do |controller, controller_routes|
            output << "  #{controller}: #{controller_routes.size} routes\n"
          end

          output
        end
      end
    end
  end
end
