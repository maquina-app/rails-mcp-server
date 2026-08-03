module RailsMcpServer
  module Analyzers
    class AnalyzeModels < BaseAnalyzer
      def call(model_name: nil, model_names: nil, detail_level: "full", analysis_type: "introspection")
        unless current_project
          return "No active project. Please switch to a project first."
        end

        detail_level = "full" unless %w[names associations full].include?(detail_level)
        analysis_type = "introspection" unless %w[introspection static full].include?(analysis_type)

        if model_names&.is_a?(Array) && model_names.any?
          return batch_model_info(model_names, detail_level, analysis_type)
        end

        if model_name
          return single_model_info(model_name, detail_level, analysis_type)
        end

        list_all_models(detail_level)
      end

      private

      def list_all_models(detail_level)
        models_dir = File.join(active_project_path, "app", "models")
        return "Models directory not found." unless File.directory?(models_dir)

        model_files = Dir.glob(File.join(models_dir, "**", "*.rb"))
          .map { |f| f.sub("#{models_dir}/", "").sub(/\.rb$/, "") }
          .reject { |f| f.include?("concern") || f.include?("application_record") } # rubocop:disable Performance/ChainArrayAllocation
          .sort # rubocop:disable Performance/ChainArrayAllocation

        case detail_level
        when "names"
          "Models in project (#{model_files.size}):\n\n#{model_files.join("\n")}"
        when "associations"
          output = ["Models with associations (#{model_files.size} models):\n"]
          model_files.each do |model_file|
            model_name = classify_model_name(model_file)
            associations = get_associations_via_introspection(model_name)
            if associations&.any?
              output << "  #{model_name}:"
              associations.each { |a| output << "    #{a[:type]} :#{a[:name]}" }
            else
              output << "  #{model_name}: (no associations)"
            end
          end
          output.join("\n")
        else
          "Models in the project (#{model_files.size}):\n\n#{model_files.join("\n")}\n\nUse model_name parameter for details."
        end
      end

      def single_model_info(model_name, detail_level, analysis_type)
        model_file = find_model_file(model_name)
        unless model_file && File.exist?(model_file)
          return <<~ERROR
            Model '#{model_name}' not found.

            Tips:
            - Use CamelCase: 'User', 'BlogPost', 'OrderItem'
            - For namespaced models use 'Namespace::Model' or the file path 'namespace/model'
            - Use singular form: 'User' not 'Users'
            - Run analyze_models without params to list all models
          ERROR
        end

        # Resolve the canonical constant from the file we actually found, rather
        # than trusting the raw input. This lets namespaced ("Base::FundHolding"),
        # path ("base/fund_holding") and flattened ("BaseFundHolding") inputs all
        # produce a valid Ruby constant for the introspection runner, and keeps
        # unvalidated user input out of the interpolated script.
        class_name = model_class_name(model_file)

        case detail_level
        when "names"
          "Model: #{class_name}\nFile: #{model_file.sub(active_project_path + "/", "")}"
        when "associations"
          format_associations_only(class_name, model_file)
        else
          build_full_analysis(class_name, model_file, analysis_type)
        end
      end

      def format_associations_only(class_name, model_file)
        associations = get_associations_via_introspection(class_name)
        output = ["Model: #{class_name}", "File: #{model_file.sub(active_project_path + "/", "")}", "", "Associations:"]
        if associations&.any?
          associations.each { |a| output << "  #{a[:type]} :#{a[:name]}" }
        else
          output << "  None found"
        end
        output.join("\n")
      end

      def build_full_analysis(class_name, model_file, analysis_type)
        output = ["=" * 60, "Model: #{class_name}", "File: #{model_file.sub(active_project_path + "/", "")}", "=" * 60]

        if %w[introspection full].include?(analysis_type)
          output << "" << introspection_analysis(class_name)
        end

        if %w[static full].include?(analysis_type)
          output << "" << static_analysis(model_file)
        end

        output << "" << "Source Code:" << "```ruby" << File.read(model_file) << "```"
        output.join("\n")
      end

      def introspection_analysis(class_name)
        script = build_introspection_script(class_name)
        raw_output = execute_rails_runner(script)
        data = begin
          JSON.parse(extract_json(raw_output))
        rescue
          nil
        end
        return "Introspection Error: Could not parse output" unless data
        format_introspection_result(data)
      end

      def build_introspection_script(class_name)
        <<~RUBY
          require 'json'
          begin
            model = Object.const_get(#{class_name.inspect})
            result = {}
            unless model.is_a?(Class) && model.respond_to?(:reflect_on_all_associations)
              raise "\#{model} is not an ActiveRecord model"
            end
            if model.respond_to?(:table_name) && model.table_exists?
              result[:table_name] = model.table_name
              result[:primary_key] = model.primary_key
              result[:columns] = model.columns.map { |c| { name: c.name, type: c.type.to_s, null: c.null, default: c.default } }
              result[:associations] = model.reflect_on_all_associations.map { |a| { name: a.name.to_s, type: a.macro.to_s, class_name: a.class_name, options: a.options.transform_keys(&:to_s) } }
              result[:validations] = model.validators.map { |v| { type: v.class.name.demodulize.underscore.sub('_validator', ''), attributes: v.attributes.map(&:to_s) } }
              result[:enums] = model.defined_enums.transform_values { |v| v.keys } if model.respond_to?(:defined_enums)
            else
              result[:error] = "Not an ActiveRecord model or table doesn't exist"
            end
            puts result.to_json
          rescue => e
            puts({ error: e.message }.to_json)
          end
        RUBY
      end

      def format_introspection_result(data)
        return "Introspection Error: #{data["error"]}" if data["error"]
        output = ["RAILS INTROSPECTION:", "-" * 40]
        output << "Table: #{data["table_name"]} (PK: #{data["primary_key"]})" << ""

        if data["columns"]&.any?
          output << "Columns (#{data["columns"].size}):"
          data["columns"].each { |c| output << "  #{c["name"]}: #{c["type"]} #{c["null"] ? "NULL" : "NOT NULL"}" }
          output << ""
        end

        if data["associations"]&.any?
          output << "Associations (#{data["associations"].size}):"
          data["associations"].each { |a| output << "  #{a["type"]} :#{a["name"]} -> #{a["class_name"]}" }
          output << ""
        end

        if data["validations"]&.any?
          output << "Validations:"
          grouped = data["validations"].group_by { |v| v["attributes"].join(", ") }
          grouped.each { |attrs, vals| output << "  #{attrs}: #{vals.map { |v| v["type"] }.join(", ")}" }
          output << ""
        end

        if data["enums"]&.any?
          output << "Enums:"
          data["enums"].each { |name, values| output << "  #{name}: #{values.join(", ")}" }
        end

        output.join("\n")
      end

      def static_analysis(model_file)
        script = build_static_analysis_script(model_file)
        raw_output = execute_rails_runner(script)
        data = begin
          JSON.parse(extract_json(raw_output))
        rescue
          nil
        end
        return "Static Analysis Error: Could not parse output" unless data
        return "Static Analysis Error: #{data["error"]}" if data["error"]
        format_static_result(data)
      end

      def build_static_analysis_script(model_file)
        <<~RUBY
          require 'json'
          begin
            require 'prism'
            source = File.read('#{model_file}')
            result = Prism.parse(source)
            callbacks, scopes, concerns, methods = [], [], [], []
            
            visit = ->(node) {
              case node
              when Prism::CallNode
                name = node.name.to_s
                args = node.arguments&.arguments&.map { |a| a.is_a?(Prism::SymbolNode) ? a.value.to_s : nil }&.compact || []
                if %w[before_save after_save before_create after_create before_update after_update before_destroy after_destroy after_commit before_validation after_validation].include?(name)
                  callbacks << { name: name, args: args }
                elsif name == 'scope'
                  scopes << args.first
                elsif %w[include extend].include?(name)
                  concerns.concat(args)
                end
              when Prism::DefNode
                methods << { name: node.name.to_s, line: node.location.start_line }
              end
              node.child_nodes.compact.each { |c| visit.call(c) }
            }
            result.value.statements.body.each { |n| visit.call(n) }
            puts({ callbacks: callbacks, scopes: scopes, concerns: concerns, methods: methods }.to_json)
          rescue LoadError
            puts({ error: "Prism not available" }.to_json)
          rescue => e
            puts({ error: e.message }.to_json)
          end
        RUBY
      end

      def format_static_result(data)
        output = ["PRISM STATIC ANALYSIS:", "-" * 40]
        output << "Concerns: #{data["concerns"].join(", ")}" if data["concerns"]&.any?
        if data["callbacks"]&.any?
          output << "Callbacks:"
          data["callbacks"].each { |c| output << "  #{c["name"]} :#{c["args"].join(", :")}" }
        end
        output << "Scopes: #{data["scopes"].join(", ")}" if data["scopes"]&.any?
        if data["methods"]&.any?
          output << "Methods:"
          data["methods"].each { |m| output << "  #{m["name"]} (line #{m["line"]})" }
        end
        output.join("\n")
      end

      def batch_model_info(model_names, detail_level, analysis_type)
        output = ["Analysis for #{model_names.size} models:\n"]
        model_names.each { |m| output << single_model_info(m, detail_level, analysis_type) << "" }
        output.join("\n")
      end

      def get_associations_via_introspection(class_name)
        script = "require 'json'; puts (Object.const_get(#{class_name.inspect}).reflect_on_all_associations.map { |a| { name: a.name.to_s, type: a.macro.to_s } } rescue []).to_json"
        begin
          JSON.parse(extract_json(execute_rails_runner(script))).map { |a| a.transform_keys(&:to_sym) }
        rescue
          []
        end
      end

      def find_model_file(model_name)
        models_dir = File.join(active_project_path, "app", "models")
        return nil unless File.directory?(models_dir)

        # Fast path: conventional inflection (Base::FundHolding -> base/fund_holding.rb).
        direct = File.join(models_dir, "#{underscore(model_name)}.rb")
        return direct if File.exist?(direct)

        # Fallback: match against the files that actually exist so namespaced,
        # path, flattened and bare-leaf forms all resolve, independent of any
        # custom inflections the app registers. Prefer a full relative-path
        # match; only then fall back to a bare filename (leaf) match.
        files = Dir.glob(File.join(models_dir, "**", "*.rb"))
        target = model_key(model_name)

        files.find { |file| model_key(relative_model_path(file, models_dir)) == target } ||
          files.find { |file| model_key(File.basename(file, ".rb")) == target }
      end

      # Normalizes a model reference to a separator- and case-insensitive key so
      # "Base::FundHolding", "base/fund_holding" and "BaseFundHolding" all collapse
      # to the same value ("basefundholding") for matching against real files.
      def model_key(name)
        name.to_s.gsub("::", "/").split("/").map { |segment| segment.tr("-", "_").delete("_").downcase }.join
      end

      def relative_model_path(file, models_dir)
        file.sub("#{models_dir}/", "").sub(/\.rb$/, "")
      end

      # Canonical Ruby constant name for a resolved model file.
      def model_class_name(model_file)
        models_dir = File.join(active_project_path, "app", "models")
        classify_model_name(relative_model_path(model_file, models_dir))
      end

      def classify_model_name(model_file)
        model_file.split("/").map { |part| camelize(part) }.join("::")
      end
    end
  end
end
