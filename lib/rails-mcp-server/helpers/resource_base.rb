require "fileutils"
require "digest"
require "yaml"

module RailsMcpServer
  class ResourceBase
    attr_reader :resource_name, :config_dir, :resource_folder, :manifest_file

    def initialize(resource_name, config_dir:, force: false, verbose: false)
      @resource_name = resource_name.to_s
      @config_dir = config_dir
      @force = force
      @verbose = verbose
      setup_paths
    end

    protected

    def setup_paths
      @resource_folder = File.join(@config_dir, "resources", @resource_name)
      @manifest_file = File.join(@resource_folder, "manifest.yaml")
    end

    def setup_directories
      FileUtils.mkdir_p(@resource_folder)
    end

    def load_manifest
      @manifest = if File.exist?(@manifest_file)
        YAML.safe_load_file(@manifest_file, permitted_classes: [Symbol, Time])
      else
        create_manifest
      end
    end

    def save_manifest
      @manifest["updated_at"] = Time.now.to_s
      File.write(@manifest_file, @manifest.to_yaml)
    end

    def file_unchanged?(filename, file_path)
      return false unless File.exist?(file_path)
      current_hash = file_hash(file_path)
      @manifest["files"][filename] && @manifest["files"][filename]["hash"] == current_hash
    end

    def save_file_to_manifest(filename, file_path, additional_data = {})
      metadata = extract_metadata(File.read(file_path), filename)

      @manifest["files"][filename] = {
        "hash" => file_hash(file_path),
        "size" => File.size(file_path)
      }.merge(timestamp_key => Time.now.to_s)
        .merge(additional_data)
        .merge(metadata)
    end

    def extract_metadata(content, filename = nil)
      metadata = {}

      title = find_title(content) || (filename ? humanize_filename(filename) : nil)
      metadata["title"] = title if title

      description = find_description(content)
      metadata["description"] = description if description && !description.empty?

      metadata
    end

    def find_title(content)
      lines = content.lines

      # H1 header
      lines.each do |line|
        return $1.strip if line.strip =~ /^#\s+(.+)$/
      end

      # Underlined title
      lines.each_with_index do |line, index|
        next if index >= lines.length - 1
        return line.strip if /^=+$/.match?(lines[index + 1].strip)
      end

      nil
    end

    def find_description(content)
      # Clean content
      clean = content.dup
      clean = clean.sub(/^---\s*\n.*?\n---\s*\n/m, "") # Remove YAML frontmatter
      clean = clean.gsub(/^#\s+.*?\n/, "") # Remove H1 headers
      clean = clean.gsub(/^.+\n=+\s*\n/, "") # Remove underlined titles
      clean = clean.strip.gsub(/\n+/, " ").gsub(/\s+/, " ")

      return "" if clean.empty?

      if clean.length > 200
        truncate_at = clean.rindex(" ", 200) || 200
        clean[0...truncate_at] + "..."
      else
        clean
      end
    end

    def humanize_filename(filename)
      base = File.basename(filename, File.extname(filename))

      title = base.gsub(/[_-]/, " ")
        .gsub(/^\d+[.\-_\s]*/, "")
        .split(" ").map(&:capitalize).join(" ")

      # Common abbreviations
      replacements = {
        /\bApi\b/ => "API", /\bHtml\b/ => "HTML", /\bCss\b/ => "CSS",
        /\bJs\b/ => "JavaScript", /\bUi\b/ => "UI", /\bUrl\b/ => "URL",
        /\bRest\b/ => "REST", /\bJson\b/ => "JSON", /\bXml\b/ => "XML",
        /\bSql\b/ => "SQL"
      }

      replacements.each { |pattern, replacement| title = title.gsub(pattern, replacement) }

      title.strip.empty? ? "Untitled Guide" : title
    end

    def file_hash(file_path)
      Digest::SHA256.file(file_path).hexdigest
    end

    def log(message, newline: true)
      return unless @verbose
      newline ? puts(message) : print(message)
    end

    # Abstract methods to be implemented by subclasses
    def create_manifest
      raise NotImplementedError
    end

    def timestamp_key
      raise NotImplementedError
    end
  end
end
