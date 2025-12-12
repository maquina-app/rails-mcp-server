require "net/http"
require "uri"
require_relative "resource_base"

module RailsMcpServer
  class ResourceDownloader < ResourceBase
    class DownloadError < StandardError; end

    def initialize(resource_name, config_dir:, force: false, verbose: false)
      super
      load_config
    end

    def download
      setup_directories
      load_manifest

      log "Downloading #{@resource_name} resources..."

      results = {downloaded: 0, skipped: 0, failed: 0}

      @config["files"].each do |file|
        result = download_file(file)
        results[result] += 1
      end

      save_manifest
      results
    end

    def self.available_resources(config_dir)
      config_file = File.join(File.dirname(__FILE__), "..", "..", "..", "config", "resources.yml")
      return [] unless File.exist?(config_file)

      YAML.safe_load_file(config_file, permitted_classes: [Symbol]).keys
    rescue => e
      warn "Failed to load resource configuration: #{e.message}"
      []
    end

    protected

    def create_manifest
      {
        "resource" => @resource_name,
        "base_url" => @config["base_url"],
        "description" => @config["description"],
        "version" => @config["version"],
        "files" => {},
        "created_at" => Time.now.to_s,
        "updated_at" => Time.now.to_s
      }
    end

    def timestamp_key
      "downloaded_at"
    end

    private

    def load_config
      config_file = File.join(File.dirname(__FILE__), "..", "..", "..", "config", "resources.yml")

      raise DownloadError, "Resource configuration file not found" unless File.exist?(config_file)

      all_configs = YAML.safe_load_file(config_file, permitted_classes: [Symbol])
      @config = all_configs[@resource_name]

      raise DownloadError, "Unknown resource: #{@resource_name}" unless @config
    end

    def download_file(filename)
      file_path = File.join(@resource_folder, filename)
      url = "#{@config["base_url"]}/#{filename}"

      # Skip if unchanged
      if !@force && file_unchanged?(filename, file_path)
        log "Skipping #{filename} (unchanged)"
        return :skipped
      end

      log "Downloading #{filename}... ", newline: false

      begin
        uri = URI(url)
        response = Net::HTTP.get_response(uri)

        if response.code == "200"
          FileUtils.mkdir_p(File.dirname(file_path))
          File.write(file_path, response.body)
          save_file_to_manifest(filename, file_path)
          log "done"
          :downloaded
        else
          log "failed (HTTP #{response.code})"
          :failed
        end
      rescue => e
        log "failed (#{e.message})"
        :failed
      end
    end
  end
end
