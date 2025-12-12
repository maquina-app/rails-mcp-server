require "active_support/core_ext/string/inflections"

module RailsMcpServer
  class GetModels < BaseTool
    tool_name "get_models"

    description "Retrieve detailed information about Active Record models in the project. When called without parameters, lists all model files. When a specific model is specified, returns its schema, associations (has_many, belongs_to, has_one), and complete source code."

    arguments do
      optional(:model_name).filled(:string).description("Class name of a specific model to get detailed information for (e.g., 'User', 'Product'). Use CamelCase, not snake_case. If omitted, returns a list of all models.")
    end

    def call(model_name: nil)
      unless current_project
        message = "No active project. Please switch to a project first."
        log(:warn, message)

        return message
      end

      if model_name
        unless PathValidator.valid_identifier?(model_name)
          message = "Invalid model name: #{model_name}. Use CamelCase (e.g., 'User', 'Admin::User')."
          log(:warn, message)
          return message
        end

        log(:info, "Getting info for specific model: #{model_name}")

        # Check if the model file exists
        model_file = File.join(active_project_path, "app", "models", "#{model_name.underscore}.rb")
        unless File.exist?(model_file)
          log(:warn, "Model file not found: #{model_name}")
          message = "Model '#{model_name}' not found."
          log(:warn, message)

          return message
        end

        log(:debug, "Reading model file: #{model_file}")

        # Get the model file content
        model_content = File.read(model_file)

        # Try to get schema information
        log(:debug, "Executing Rails runner to get schema information")
        schema_info = execute_rails_command(
          active_project_path,
          "puts #{model_name}.column_names"
        )

        # Try to get associations
        associations = []
        if model_content.include?("has_many")
          has_many = model_content.scan(/has_many\s+:(\w+)/).flatten
          associations << "Has many: #{has_many.join(", ")}" unless has_many.empty?
        end

        if model_content.include?("belongs_to")
          belongs_to = model_content.scan(/belongs_to\s+:(\w+)/).flatten
          associations << "Belongs to: #{belongs_to.join(", ")}" unless belongs_to.empty?
        end

        if model_content.include?("has_one")
          has_one = model_content.scan(/has_one\s+:(\w+)/).flatten
          associations << "Has one: #{has_one.join(", ")}" unless has_one.empty?
        end

        log(:debug, "Found #{associations.size} associations for model: #{model_name}")

        # Format the output
        <<~INFO
          Model: #{model_name}
          
          Schema:
          #{schema_info}
          
          Associations:
          #{associations.empty? ? "None found" : associations.join("\n")}
          
          Model Definition:
          ```ruby
          #{model_content}
          ```
        INFO
      else
        log(:info, "Listing all models")

        # List all models
        models_dir = File.join(active_project_path, "app", "models")
        unless File.directory?(models_dir)
          message = "Models directory not found."
          log(:warn, message)

          return message
        end

        # Get all .rb files in the models directory and its subdirectories
        model_files = Dir.glob(File.join(models_dir, "**", "*.rb"))
          .map { |f| f.sub("#{models_dir}/", "").sub(/\.rb$/, "") }
          .sort # rubocop:disable Performance/ChainArrayAllocation

        log(:debug, "Found #{model_files.size} model files")

        "Models in the project:\n\n#{model_files.join("\n")}"
      end
    end

    private

    def execute_rails_command(project_path, runner_script)
      Dir.chdir(project_path) do
        IO.popen(
          ["bin/rails", "runner", runner_script],
          err: [:child, :out],
          &:read
        )
      end
    end
  end
end
