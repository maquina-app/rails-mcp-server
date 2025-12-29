module RailsMcpServer
  module Analyzers
    class LoadGuide < BaseAnalyzer
      GUIDE_LIBRARIES = %w[rails turbo stimulus kamal custom].freeze

      # Parameters:
      #   library: The guide source - 'rails', 'turbo', 'stimulus', 'kamal', or 'custom'
      #   guide: (optional) Specific guide name to load. If omitted, lists all available guides.
      #
      # Examples:
      #   execute_tool("load_guide", { library: "rails" })                          # List all Rails guides
      #   execute_tool("load_guide", { library: "rails", guide: "active_record" })  # Load ActiveRecord guide
      #   execute_tool("load_guide", { library: "custom", guide: "tailwind" })      # Load custom Tailwind guide
      def call(library:, guide: nil)
        unless GUIDE_LIBRARIES.include?(library.to_s.downcase)
          return "Unknown guide library '#{library}'. Available: #{GUIDE_LIBRARIES.join(", ")}"
        end

        guides_path = get_guides_path(library.to_s.downcase)

        unless guides_path && File.directory?(guides_path)
          return "Guides for '#{library}' not found. Run: rails-mcp-server-download-resources #{library}"
        end

        if guide
          load_specific_guide(guides_path, guide)
        else
          list_available_guides(library, guides_path)
        end
      end

      private

      def get_guides_path(library)
        base_path = File.join(RailsMcpServer.config_dir, "resources", library)
        File.directory?(base_path) ? base_path : nil
      end

      def list_available_guides(library, guides_path)
        guide_files = Dir.glob(File.join(guides_path, "**", "*.md"))
          .map { |f| f.sub("#{guides_path}/", "").sub(/\.md$/, "") }
          .sort # rubocop:disable Performance/ChainArrayAllocation

        if guide_files.empty?
          return "No guides found for '#{library}'."
        end

        output = ["Available #{library.capitalize} Guides (#{guide_files.size}):", ""]
        guide_files.each { |g| output << "  #{g}" }
        output << ""
        output << "Load a guide with: execute_tool(\"load_guide\", { library: \"#{library}\", guide: \"<guide_name>\" })"
        output.join("\n")
      end

      def load_specific_guide(guides_path, guide_name)
        # Validate guide name format - allow letters, numbers, underscores, hyphens, and forward slashes
        unless guide_name.to_s.match?(/\A[a-zA-Z0-9_\-\/]+\z/)
          return "Invalid guide name '#{guide_name}'. Use letters, numbers, underscores, hyphens, or forward slashes only."
        end

        # Prevent directory traversal
        if guide_name.to_s.include?("..") || guide_name.to_s.start_with?("/")
          return "Invalid guide name '#{guide_name}'. Directory traversal is not allowed."
        end

        # Try exact match first
        guide_file = File.join(guides_path, "#{guide_name}.md")

        # Try finding in subdirectories
        unless File.exist?(guide_file)
          matches = Dir.glob(File.join(guides_path, "**", "#{guide_name}.md"))
          guide_file = matches.first if matches.any?
        end

        # Try partial match
        unless guide_file && File.exist?(guide_file)
          all_guides = Dir.glob(File.join(guides_path, "**", "*.md"))
          matches = all_guides.select { |f| File.basename(f, ".md").include?(guide_name) }
          guide_file = matches.first if matches.size == 1

          if matches.size > 1
            names = matches.map { |f| File.basename(f, ".md") }
            return "Multiple guides match '#{guide_name}': #{names.join(", ")}"
          end
        end

        unless guide_file && File.exist?(guide_file)
          return "Guide '#{guide_name}' not found."
        end

        content = File.read(guide_file)
        guide_title = File.basename(guide_file, ".md")

        <<~GUIDE
          # #{guide_title}

          #{content}
        GUIDE
      end
    end
  end
end
