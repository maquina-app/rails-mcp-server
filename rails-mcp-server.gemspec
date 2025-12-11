require_relative "lib/rails-mcp-server/version"

Gem::Specification.new do |spec|
  spec.name = "rails-mcp-server"
  spec.version = RailsMcpServer::VERSION
  spec.authors = ["Mario Alberto Chávez Cárdenas"]
  spec.email = ["mario.chavez@gmail.com"]

  spec.summary = "MCP server for Rails projects"
  spec.description = "A Ruby implementation of Model Context Protocol server for Rails projects"
  spec.homepage = "https://github.com/maquina-app/rails-mcp-server"
  spec.license = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.glob("{lib,exe,config,docs}/**/*") + %w[LICENSE.txt README.md CHANGELOG.md]
  spec.bindir = "exe"
  spec.executables = ["rails-mcp-server", "rails-mcp-setup-claude", "rails-mcp-server-download-resources", "rails-mcp-config"]
  spec.require_paths = ["lib"]

  spec.add_dependency "addressable", "~> 2.8"
  spec.add_dependency "fast-mcp", "~> 1.6.0"
  spec.add_dependency "rack", "~> 3.2.0"
  spec.add_dependency "puma", ">= 6.6.0"
  spec.add_dependency "logger", "~> 1.7.0"

  spec.add_development_dependency "standard"
  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "minitest-reporters", "~> 1.7"
  spec.add_development_dependency "mocha", "~> 2.7"
end
