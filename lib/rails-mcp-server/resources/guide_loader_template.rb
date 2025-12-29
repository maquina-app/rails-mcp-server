module RailsMcpServer
  # Template module that provides complete guide loading implementation
  # Eliminates the need to implement load_specific_guide in each resource
  module GuideLoaderTemplate
    def self.included(base)
      # Ensure all required modules are included
      base.include GuideFrameworkContract unless base.included_modules.include?(GuideFrameworkContract)
      base.include GuideManifestOperations unless base.included_modules.include?(GuideManifestOperations)
      base.include GuideFileFinder unless base.included_modules.include?(GuideFileFinder)
      base.include GuideContentFormatter unless base.included_modules.include?(GuideContentFormatter)
      base.include GuideErrorHandler unless base.included_modules.include?(GuideErrorHandler)
    end

    # Complete single guide content implementation
    def content
      guide_name = params[:guide_name]

      begin
        manifest = load_manifest
      rescue => e
        return handle_manifest_error(e)
      end

      if !guide_name.nil? && !guide_name.strip.empty?
        log(:debug, "Loading #{framework_name} guide: #{guide_name}")
        load_specific_guide(guide_name, manifest)
      else
        log(:debug, "Provide a name for a #{framework_name} guide")
        "Provide a name for a #{framework_name} guide"
      end
    end

    # Complete guides list implementation
    def list_content
      begin
        manifest = load_manifest
      rescue => e
        return handle_manifest_error(e)
      end

      log(:debug, "Loading #{framework_name} guides...")
      format_guides_index(manifest)
    end

    protected

    # Template method for loading a specific guide
    def load_specific_guide(guide_name, manifest)
      normalized_guide_name = guide_name.gsub(/[^a-zA-Z0-9_\/.-]/, "")

      begin
        filename, guide_data = find_guide_file(normalized_guide_name, manifest)

        if filename && guide_data
          guides_path = File.dirname(File.join(config_dir, "resources", resource_directory, "manifest.yaml"))
          guide_file_path = File.join(guides_path, filename)

          if File.exist?(guide_file_path)
            log(:debug, "Loading guide: #{filename}")
            content = File.read(guide_file_path)

            # Allow customization of display name
            display_name = customize_display_name(guide_name, guide_data)
            format_guide_content(content, display_name, guide_data, filename)
          else
            format_not_found_message(guide_name, manifest)
          end
        else
          format_not_found_message(guide_name, manifest)
        end
      rescue => e
        handle_guide_loading_error(guide_name, e)
      end
    end

    # Template method for formatting guides index
    def format_guides_index(manifest)
      guides = []

      guides << "# Available #{framework_name} Guides\n"
      guides << "Use `execute_tool(\"load_guide\", { library: \"#{framework_name.downcase}\", guide: \"guide_name\" })` to load a specific guide.\n"

      if supports_sections?
        guides << "You can use either the full path (e.g., `handbook/01_introduction`) or just the filename (e.g., `01_introduction`).\n"
      end

      guide_files = get_guide_files(manifest)

      if supports_sections?
        guides.concat(format_sectioned_guides(guide_files))
      else
        guides.concat(format_flat_guides(guide_files))
      end

      # Add examples if this is a list resource
      if respond_to?(:example_guides) && example_guides.any?
        guides << format_usage_examples
      end

      guides.join("\n")
    end

    # Template method for not found messages
    def format_not_found_message(guide_name, manifest)
      guide_files = get_guide_files(manifest)
      available_guides = guide_files.keys.map { |f| f.sub(".md", "") }

      message = create_not_found_message(guide_name, available_guides)

      # Allow framework-specific additions to not found message
      message = customize_not_found_message(message, guide_name) if respond_to?(:customize_not_found_message, true)

      log(:error, "Guide not found: #{guide_name}")
      message
    end

    # Hook for customizing display name (override in resources if needed)
    def customize_display_name(guide_name, guide_data)
      guide_name
    end
  end
end
