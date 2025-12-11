module RailsMcpServer
  class KamalGuidesResources < BaseResource
    include GuideLoaderTemplate

    uri "kamal://guides"
    resource_name "Kamal Guides"
    description "Access to available Kamal deployment guides"
    mime_type "text/markdown"

    protected

    def framework_name
      "Kamal"
    end

    def resource_directory
      "kamal"
    end

    def download_command
      "rails-mcp-server-download-resources kamal"
    end

    def example_guides
      [
        {guide: "installation/index", comment: "Load installation guide"},
        {guide: "configuration/environment-variables", comment: "Load environment variables configuration"},
        {guide: "commands/deploy", comment: "Load deploy command guide"},
        {guide: "hooks/overview", comment: "Load hooks overview"},
        {guide: "upgrading/overview", comment: "Load upgrading overview"}
      ]
    end

    # Kamal guides have subdirectories but not handbook/reference sections
    def supports_sections?
      false
    end

    # Override to format guides organized by Kamal's directory structure
    def format_flat_guides(manifest)
      guides = []

      # Group guides by their directory structure
      sections = {
        "installation" => [],
        "configuration" => [],
        "commands" => [],
        "hooks" => [],
        "upgrading" => []
      }

      other_guides = []

      manifest["files"].each do |filename, file_data|
        next unless filename.end_with?(".md")

        log(:debug, "Processing guide: #{filename}")

        guide_name = filename.sub(".md", "")
        title = file_data["title"] || guide_name.split("/").last.gsub(/[_-]/, " ").split.map(&:capitalize).join(" ")
        description = file_data["description"] || ""

        # Categorize by directory
        case filename
        when /^installation\//
          sections["installation"] << {name: guide_name, title: title, description: description}
        when /^configuration\//
          sections["configuration"] << {name: guide_name, title: title, description: description}
        when /^commands\//
          sections["commands"] << {name: guide_name, title: title, description: description}
        when /^hooks\//
          sections["hooks"] << {name: guide_name, title: title, description: description}
        when /^upgrading\//
          sections["upgrading"] << {name: guide_name, title: title, description: description}
        else
          other_guides << {name: guide_name, title: title, description: description}
        end
      end

      # Format each section
      sections.each do |section_name, section_guides|
        next if section_guides.empty?

        guides << "\n## #{section_name.capitalize}\n"
        section_guides.each do |guide|
          guides << format_guide_entry(guide[:title], guide[:name], guide[:name], guide[:description])
        end
      end

      # Add any other guides that don't fit the standard structure
      if other_guides.any?
        guides << "\n## Other\n"
        other_guides.each do |guide|
          guides << format_guide_entry(guide[:title], guide[:name], guide[:name], guide[:description])
        end
      end

      guides
    end

    # Format individual guide entry
    def format_guide_entry(title, short_name, full_name, description)
      <<~GUIDE
        ### #{title}
        **Guide name:** `#{short_name}`
        #{"**Description:** #{description}" unless description.empty?}
      GUIDE
    end
  end
end
