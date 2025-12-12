module RailsMcpServer
  # Module for handling guide manifest operations
  module GuideManifestOperations
    protected

    # Load and validate manifest file
    def load_manifest
      manifest_file = File.join(config_dir, "resources", resource_directory, "manifest.yaml")

      unless File.exist?(manifest_file)
        error_message = "No #{framework_name} guides found. Run '#{download_command}' first."
        log(:error, error_message)
        raise StandardError, error_message
      end

      YAML.safe_load_file(manifest_file, permitted_classes: [Symbol, Time])
    end

    # Extract guide metadata from manifest entry
    def extract_guide_metadata(filename, file_data)
      {
        filename: filename,
        guide_name: filename.sub(".md", ""),
        title: file_data["title"] || generate_title_from_filename(filename),
        description: file_data["description"] || "",
        original_filename: file_data["original_filename"] # For custom guides
      }
    end

    # Generate title from filename if not in manifest
    def generate_title_from_filename(filename)
      base_name = filename.sub(".md", "").split("/").last
      base_name.gsub(/[_-]/, " ").split.map(&:capitalize).join(" ")
    end

    # Get all guide files from manifest
    def get_guide_files(manifest)
      manifest["files"].select { |filename, _| filename.end_with?(".md") }
    end

    # Get guide files organized by sections
    def get_sectioned_guide_files(manifest)
      guide_files = get_guide_files(manifest)

      {
        handbook: guide_files.select { |filename, _| filename.start_with?("handbook/") },
        reference: guide_files.select { |filename, _| filename.start_with?("reference/") },
        other: guide_files.reject { |filename, _| filename.start_with?("handbook/", "reference/") }
      }
    end
  end
end
