module RailsMcpServer
  # Module for handling guide-related errors and messages
  module GuideErrorHandler
    protected

    # Format error messages consistently
    def format_error_message(message)
      "# Error\n\n#{message}"
    end

    # Create standardized not found message
    def create_not_found_message(guide_name, available_guides)
      normalized_guide_name = guide_name.gsub(/[^a-zA-Z0-9_\/.-]/, "").downcase
      suggestions = find_suggestions(normalized_guide_name, available_guides)

      message = "# Guide Not Found\n\n"
      message += "Guide '#{guide_name}' not found in #{framework_name} guides.\n\n"

      if suggestions.any?
        message += "## Did you mean one of these?\n\n"
        suggestions.each { |suggestion| message += "- #{suggestion}\n" }
        message += "\n**Try:** `execute_tool(\"load_guide\", { library: \"#{framework_name.downcase}\", guide: \"#{suggestions.first}\" })`\n"
      else
        message += format_available_guides_section(available_guides)
        message += "Use `execute_tool(\"load_guide\", { library: \"#{framework_name.downcase}\" })` to see all available guides with descriptions.\n"
      end

      message
    end

    # Format available guides section for error messages
    def format_available_guides_section(available_guides)
      return "\n" unless supports_sections?

      handbook_guides = available_guides.select { |g| g.start_with?("handbook/") }
      reference_guides = available_guides.select { |g| g.start_with?("reference/") }

      message = "## Available #{framework_name} Guides:\n\n"

      if handbook_guides.any?
        message += "### Handbook:\n"
        handbook_guides.each { |guide| message += "- #{guide.sub("handbook/", "")}\n" }
        message += "\n"
      end

      if reference_guides.any?
        message += "### Reference:\n"
        reference_guides.each { |guide| message += "- #{guide.sub("reference/", "")}\n" }
        message += "\n"
      end

      message
    end

    # Handle manifest loading errors with user-friendly messages
    def handle_manifest_error(error)
      case error.message
      when /No .* guides found/
        error.message
      when /Permission denied/
        format_error_message("Permission denied accessing guides. Check file permissions.")
      when /No such file/
        format_error_message("Guide files not found. Run '#{download_command}' to download guides.")
      else
        format_error_message("Error loading guides: #{error.message}")
      end
    end

    # Handle guide loading errors
    def handle_guide_loading_error(guide_name, error)
      log(:error, "Error loading guide #{guide_name}: #{error.message}")

      case error.message
      when /Multiple guides found/
        format_error_message(error.message)
      when /Permission denied/
        format_error_message("Permission denied reading guide '#{guide_name}'.")
      when /No such file/
        format_error_message("Guide file for '#{guide_name}' not found on disk.")
      else
        format_error_message("Error loading guide '#{guide_name}': #{error.message}")
      end
    end
  end
end
