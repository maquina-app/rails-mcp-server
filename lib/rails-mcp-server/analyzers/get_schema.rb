module RailsMcpServer
  module Analyzers
    class GetSchema < BaseAnalyzer
      # Tab character for parsing output
      FIELD_SEPARATOR = "\t"

      def call(table_name: nil, table_names: nil, detail_level: "full")
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        detail_level = "full" unless %w[tables summary full].include?(detail_level)

        if table_names&.is_a?(Array) && table_names.any?
          invalid_tables = table_names.reject { |t| PathValidator.valid_table_name?(t) }
          if invalid_tables.any?
            return "Invalid table names: #{invalid_tables.join(", ")}. Table names must be alphanumeric with underscores."
          end
          return batch_table_info(table_names)
        end

        if table_name
          unless PathValidator.valid_table_name?(table_name)
            return "Invalid table name: '#{table_name}'. Table names must be alphanumeric with underscores."
          end
          log(:info, "Getting schema for table: #{table_name}")
          return single_table_info(table_name)
        end

        case detail_level
        when "tables"
          tables_list_only
        when "summary"
          tables_with_summary
        when "full"
          full_schema
        end
      end

      private

      def tables_list_only
        tables = get_table_names
        return "Could not retrieve table list." if tables.empty?

        "Database tables (#{tables.size}):\n\n#{tables.join("\n")}"
      end

      def tables_with_summary
        tables = get_table_names
        return "Could not retrieve table list." if tables.empty?

        output = ["Database schema summary (#{tables.size} tables):\n"]

        tables.each do |table|
          column_count = get_column_count(table)
          output << "  #{table} (#{column_count} columns)"
        end

        output.join("\n")
      end

      def full_schema
        log(:info, "Getting full schema")

        schema_file = File.join(active_project_path, "db", "schema.rb")
        structure_file = File.join(active_project_path, "db", "structure.sql")

        unless File.exist?(schema_file) || File.exist?(structure_file)
          log(:info, "Schema file not found, attempting to generate it")
          RailsMcpServer::RunProcess.execute_rails_command(active_project_path, "db:schema:dump")
        end

        if File.exist?(schema_file)
          schema_content = File.read(schema_file)
          tables = get_table_names

          <<~SCHEMA
            Database Schema (#{tables.size} tables)

            Tables:
            #{tables.join("\n")}

            Schema Definition:
            ```ruby
            #{schema_content}
            ```
          SCHEMA
        elsif File.exist?(structure_file)
          tables = get_table_names

          <<~SCHEMA
            Database Schema (#{tables.size} tables)

            Tables:
            #{tables.join("\n")}

            Note: Project uses structure.sql format. Use get_schema with a specific table_name for details.
          SCHEMA
        else
          tables = get_table_names
          if tables.empty?
            "Could not retrieve schema information. Try running 'rails db:schema:dump' in your project first."
          else
            <<~SCHEMA
              Database Schema

              Tables:
              #{tables.join("\n")}

              Note: Full schema definition is not available. Run 'rails db:schema:dump' to generate the schema.rb file.
            SCHEMA
          end
        end
      end

      def single_table_info(table_name)
        columns = get_columns(table_name)

        if columns.empty?
          message = "Table '#{table_name}' not found or has no columns."
          log(:warn, message)
          return message
        end

        formatted_columns = columns.map do |col|
          line = "  #{col[:name]} (#{col[:type]})"
          line += ", nullable" if col[:null]
          line += ", default: #{col[:default]}" if col[:default]
          line
        end

        output = <<~SCHEMA
          Table: #{table_name} (#{columns.size} columns)

          Columns:
          #{formatted_columns.join("\n")}
        SCHEMA

        fk_output = get_foreign_keys(table_name)
        output += fk_output if fk_output

        idx_output = get_indexes(table_name)
        output += idx_output if idx_output

        output
      end

      def batch_table_info(table_names)
        output = ["Schema for #{table_names.size} tables:\n"]

        table_names.each do |table|
          output << "=" * 50
          output << single_table_info(table)
          output << ""
        end

        output.join("\n")
      end

      def get_table_names
        output = execute_rails_runner(<<~RUBY)
          puts ActiveRecord::Base.connection.tables.sort.join("\\n")
        RUBY

        parse_lines(output)
      end

      def get_column_count(table_name)
        return "?" unless PathValidator.valid_table_name?(table_name)

        output = execute_rails_runner(<<~RUBY)
          puts ActiveRecord::Base.connection.columns(#{table_name.inspect}).size
        RUBY

        output.strip.to_i
      rescue
        "?"
      end

      def get_columns(table_name)
        output = execute_rails_runner(<<~RUBY)
          ActiveRecord::Base.connection.columns(#{table_name.inspect}).each do |c|
            puts [c.name, c.type, c.null, c.default].join("\\t")
          end
        RUBY

        parse_lines(output).map do |line|
          parts = line.split(FIELD_SEPARATOR)
          next if parts.size < 3

          {
            name: parts[0],
            type: parts[1],
            null: parts[2] == "true",
            default: (parts[3] == "") ? nil : parts[3]
          }
        end.compact
      end

      def get_foreign_keys(table_name)
        output = execute_rails_runner(<<~RUBY)
          ActiveRecord::Base.connection.foreign_keys(#{table_name.inspect}).each do |fk|
            puts [fk.from_table, fk.to_table, fk.column, fk.primary_key].join("\\t")
          end
        RUBY

        lines = parse_lines(output)
        return nil if lines.empty?

        formatted_fks = lines.map do |line|
          parts = line.split(FIELD_SEPARATOR)
          next if parts.size < 4

          "  #{parts[2]} -> #{parts[1]}.#{parts[3]}"
        end.compact

        return nil if formatted_fks.empty?

        <<~FK

          Foreign Keys:
          #{formatted_fks.join("\n")}
        FK
      rescue => e
        log(:warn, "Error fetching foreign keys: #{e.message}")
        nil
      end

      def get_indexes(table_name)
        output = execute_rails_runner(<<~RUBY)
          ActiveRecord::Base.connection.indexes(#{table_name.inspect}).each do |i|
            cols = i.columns.is_a?(Array) ? i.columns.join(",") : i.columns
            puts [i.name, cols, i.unique].join("\\t")
          end
        RUBY

        lines = parse_lines(output)
        return nil if lines.empty?

        formatted_indexes = lines.map do |line|
          parts = line.split(FIELD_SEPARATOR)
          next if parts.size < 3

          cols = parts[1].tr(",", ", ")
          unique_marker = (parts[2] == "true") ? " UNIQUE" : ""
          "  #{parts[0]} (#{cols})#{unique_marker}"
        end.compact

        return nil if formatted_indexes.empty?

        <<~IDX

          Indexes:
          #{formatted_indexes.join("\n")}
        IDX
      rescue => e
        log(:warn, "Error fetching indexes: #{e.message}")
        nil
      end

      def parse_lines(output)
        output.to_s.lines.map(&:chomp).reject(&:empty?)
      end
    end
  end
end
