module RailsMcpServer
  # Module for formatting guide content and messages
  module GuideContentFormatter
    protected

    # Format the guide content with appropriate headers
    def format_guide_content(content, guide_name, guide_data, filename)
      title = guide_data["title"] || generate_title_from_filename(filename)

      header = if supports_sections?
        section = determine_section(filename)
        <<~HEADER
          # #{title}

          **Source:** #{framework_name} #{section}
          **Guide:** #{guide_name}
          **File:** #{filename}

          ---

        HEADER
      else
        <<~HEADER
          # #{title}

          **Source:** #{framework_name} Guides
          **Guide:** #{guide_name}

          ---

        HEADER
      end

      header + content
    end

    # Format individual guide entry for listings
    def format_guide_entry(title, short_name, full_name, description)
      if supports_sections? && short_name != full_name
        <<~GUIDE
          ### #{title}
          **Guide name:** `#{short_name}` or `#{full_name}`
          #{"**Description:** #{description}" unless description.empty?}
        GUIDE
      else
        <<~GUIDE
          ## #{title}
          **Guide name:** `#{short_name}`
          #{"**Description:** #{description}" unless description.empty?}
        GUIDE
      end
    end

    # Format usage examples section
    def format_usage_examples
      examples = example_guides

      usage = "\n## Example Usage:\n"
      usage += "```\n"

      examples.each do |example|
        usage += "load_guide guides: \"#{framework_name.downcase}\", guide: \"#{example[:guide]}\"#{" # " + example[:comment] if example[:comment]}\n"
      end

      usage += "```\n"
      usage
    end

    # Determine section from filename (handbook/reference/etc)
    def determine_section(filename)
      return "Handbook" if filename.start_with?("handbook/")
      return "Reference" if filename.start_with?("reference/")

      # Framework-specific section detection can be overridden
      framework_specific_section(filename) if respond_to?(:framework_specific_section, true)

      "Documentation"
    end

    # Format guides organized by sections (handbook/reference)
    def format_sectioned_guides(guide_files)
      sectioned = get_sectioned_guide_files(guide_files.keys.zip(guide_files.values).to_h)
      guides = []

      # Add handbook section
      if sectioned[:handbook].any?
        guides << "\n## Handbook (Main Documentation)\n"
        sectioned[:handbook].each do |filename, file_data|
          metadata = extract_guide_metadata(filename, file_data)
          short_name = metadata[:guide_name].sub("handbook/", "")
          guides << format_guide_entry(metadata[:title], short_name, metadata[:guide_name], metadata[:description])
        end
      end

      # Add reference section
      if sectioned[:reference].any?
        guides << "\n## Reference (API Documentation)\n"
        sectioned[:reference].each do |filename, file_data|
          metadata = extract_guide_metadata(filename, file_data)
          short_name = metadata[:guide_name].sub("reference/", "")
          guides << format_guide_entry(metadata[:title], short_name, metadata[:guide_name], metadata[:description])
        end
      end

      # Add other sections
      if sectioned[:other].any?
        guides << "\n## Other Guides\n"
        sectioned[:other].each do |filename, file_data|
          metadata = extract_guide_metadata(filename, file_data)
          guides << format_guide_entry(metadata[:title], metadata[:guide_name], metadata[:guide_name], metadata[:description])
        end
      end

      guides
    end

    # Format guides in a flat structure (no sections)
    def format_flat_guides(guide_files)
      guides = []

      guide_files.each do |filename, file_data|
        log(:debug, "Processing guide: #{filename}")
        metadata = extract_guide_metadata(filename, file_data)
        guides << format_guide_entry(metadata[:title], metadata[:guide_name], metadata[:guide_name], metadata[:description])
      end

      guides
    end
  end
end
