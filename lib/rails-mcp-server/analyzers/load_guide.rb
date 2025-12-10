module RailsMcpServer
  module Analyzers
    class LoadGuide < BaseAnalyzer
      GUIDE_LIBRARIES = %w[rails turbo stimulus kamal custom].freeze

      def call(guides:, guide: nil)
        unless GUIDE_LIBRARIES.include?(guides.to_s.downcase)
          return "Unknown guide library '#{guides}'. Available: #{GUIDE_LIBRARIES.join(", ")}"
        end

        guides_path = get_guides_path(guides.to_s.downcase)

        unless guides_path && File.directory?(guides_path)
          return "Guides for '#{guides}' not found. Run: rails-mcp-server-download-resources"
        end

        if guide
          load_specific_guide(guides_path, guide)
        else
          list_available_guides(guides, guides_path)
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
        output << "Load a guide with: load_guide(guides: '#{library}', guide: '<guide_name>')"
        output.join("\n")
      end

      def load_specific_guide(guides_path, guide_name)
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
