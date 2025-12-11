module RailsMcpServer
  module Analyzers
    class GetSchema < BaseAnalyzer
      def call(table_name: nil, table_names: nil, detail_level: "full")
        unless current_project
          message = "No active project. Please switch to a project first."
          log(:warn, message)
          return message
        end

        detail_level = "full" unless %w[tables summary full].include?(detail_level)

        if table_names&.is_a?(Array) && table_names.any?
          return batch_table_info(table_names)
        end

        if table_name
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
        unless File.exist?(schema_file)
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
        schema_output = execute_rails_runner(<<~RUBY)
          require 'active_record'
          puts ActiveRecord::Base.connection.columns('#{table_name}').map{|c| [c.name, c.type, c.null, c.default].inspect}.join('\\n')
        RUBY

        if schema_output.strip.empty?
          message = "Table '#{table_name}' not found or has no columns."
          log(:warn, message)
          return message
        end

        columns = schema_output.strip.split("\\n").map do |column_info|
          eval(column_info) # rubocop:disable Security/Eval
        end

        formatted_columns = columns.map do |name, type, nullable, default|
          "  #{name} (#{type})#{", nullable" if nullable}#{", default: #{default}" if default}"
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
        tables_output = execute_rails_runner(<<~RUBY)
          require 'active_record'
          puts ActiveRecord::Base.connection.tables.sort.join('\\n')
        RUBY
        tables_output.strip.split("\n").reject(&:empty?)
      end

      def get_column_count(table_name)
        count_output = execute_rails_runner(<<~RUBY)
          require 'active_record'
          puts ActiveRecord::Base.connection.columns('#{table_name}').size
        RUBY
        count_output.strip.to_i
      rescue
        "?"
      end

      def get_foreign_keys(table_name)
        fk_output = execute_rails_runner(<<~RUBY)
          require 'active_record'
          puts ActiveRecord::Base.connection.foreign_keys('#{table_name}').map{|fk| [fk.from_table, fk.to_table, fk.column, fk.primary_key].inspect}.join('\\n')
        RUBY

        return nil if fk_output.strip.empty?

        foreign_keys = fk_output.strip.split("\n").map do |fk_info|
          eval(fk_info) # rubocop:disable Security/Eval
        end

        formatted_fks = foreign_keys.map do |from_table, to_table, column, primary_key|
          "  #{column} -> #{to_table}.#{primary_key}"
        end

        <<~FK

          Foreign Keys:
          #{formatted_fks.join("\n")}
        FK
      rescue => e
        log(:warn, "Error fetching foreign keys: #{e.message}")
        nil
      end

      def get_indexes(table_name)
        idx_output = execute_rails_runner(<<~RUBY)
          require 'active_record'
          puts ActiveRecord::Base.connection.indexes('#{table_name}').map{|i| [i.name, i.columns, i.unique].inspect}.join('\\n')
        RUBY

        return nil if idx_output.strip.empty?

        indexes = idx_output.strip.split("\n").map do |idx_info|
          eval(idx_info) # rubocop:disable Security/Eval
        end

        formatted_indexes = indexes.map do |name, columns, unique|
          cols = columns.is_a?(Array) ? columns.join(", ") : columns
          "  #{name} (#{cols})#{" UNIQUE" if unique}"
        end

        <<~IDX

          Indexes:
          #{formatted_indexes.join("\n")}
        IDX
      rescue => e
        log(:warn, "Error fetching indexes: #{e.message}")
        nil
      end
    end
  end
end
