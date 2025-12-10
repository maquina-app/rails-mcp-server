# CLAUDE.md - Rails MCP Server

## Project Overview

Rails MCP Server is a Ruby gem that implements the Model Context Protocol (MCP) for Rails projects. It allows AI assistants like Claude to interact with Rails codebases through standardized tools for code analysis, exploration, and development assistance.

**Key value proposition:** Context-efficient architecture that reduces token consumption by 67% through progressive tool discovery.

## Quick Reference

```bash
# Run tests
bundle exec rake test

# Run specific test file
bundle exec ruby -Itest test/analyzers/analyze_models_test.rb

# Run linter
bundle exec standardrb

# Build gem
gem build rails-mcp-server.gemspec

# Install locally
gem install --local pkg/rails-mcp-server-*.gem

# Start server (STDIO mode)
bundle exec exe/rails-mcp-server

# Start server (HTTP mode)
bundle exec exe/rails-mcp-server --mode http -p 6029

# Run config tool
bundle exec exe/rails-mcp-config
```

## Architecture

### Core Components

```
lib/
├── rails_mcp_server.rb          # Main entry point, module setup
├── rails-mcp-server/
│   ├── config.rb                # Configuration management (XDG paths)
│   ├── version.rb               # Version constant
│   ├── tools/                   # MCP-registered tools (4 total)
│   │   ├── base_tool.rb         # Inherits from FastMcp::Tool
│   │   ├── switch_project.rb    # Project switching
│   │   ├── search_tools.rb      # Tool discovery
│   │   ├── execute_tool.rb      # Analyzer invocation
│   │   └── execute_ruby.rb      # Sandboxed Ruby execution
│   ├── analyzers/               # Internal analyzers (9 total)
│   │   ├── base_analyzer.rb     # Base class with Rails runner support
│   │   ├── project_info.rb
│   │   ├── list_files.rb
│   │   ├── get_file.rb
│   │   ├── get_routes.rb
│   │   ├── get_schema.rb
│   │   ├── analyze_models.rb
│   │   ├── analyze_controller_views.rb
│   │   ├── analyze_environment_config.rb
│   │   └── load_guide.rb
│   ├── resources/               # MCP resources for guides
│   │   ├── base_resource.rb
│   │   ├── guide_*.rb           # Guide loading infrastructure
│   │   └── *_guides_resource.rb # Per-framework resources
│   ├── helpers/                 # Resource downloading/importing
│   └── utilities/               # Shared utilities
```

### Design Patterns

1. **Progressive Tool Discovery**: Only 4 tools registered with MCP. Internal analyzers discovered via `search_tools` and invoked via `execute_tool`.

2. **Rails Introspection**: Analyzers use actual Rails APIs (`reflect_on_all_associations`, `validators`, etc.) rather than regex parsing.

3. **Sandboxed Execution**: `execute_ruby` runs code in a restricted environment with file/network/system call protections.

4. **XDG Configuration**: Config files stored in `~/.config/rails-mcp/` following XDG Base Directory spec.

## Tool vs Analyzer Pattern

**Tools** (in `lib/rails-mcp-server/tools/`):
- Inherit from `RailsMcpServer::BaseTool` (which inherits from `FastMcp::Tool`)
- Registered with MCP server, visible to clients
- Use FastMCP DSL: `tool_name`, `description`, `argument`
- Implement `call(**params)` method

**Analyzers** (in `lib/rails-mcp-server/analyzers/`):
- Inherit from `RailsMcpServer::Analyzers::BaseAnalyzer`
- Internal, invoked through `execute_tool`
- Define `METADATA` hash with name, description, parameters, category
- Implement `call(**params)` method
- Can use `execute_rails_runner(script)` to run code in target Rails project

## Creating New Analyzers

```ruby
# lib/rails-mcp-server/analyzers/my_analyzer.rb
module RailsMcpServer
  module Analyzers
    class MyAnalyzer < BaseAnalyzer
      METADATA = {
        name: "my_analyzer",
        description: "Description for tool discovery",
        parameters: {
          param_name: {
            type: "string",
            description: "Parameter description",
            required: false
          }
        },
        category: "models"  # models, database, routing, controllers, files, project, guides
      }.freeze

      def call(**params)
        # Implementation
        # Use execute_rails_runner(script) to run Ruby in target project
        # Return string result
      end
    end
  end
end
```

Then register in `lib/rails-mcp-server/tools/execute_tool.rb`:
```ruby
ANALYZERS = {
  # ... existing analyzers
  "my_analyzer" => Analyzers::MyAnalyzer
}.freeze
```

## Testing

Tests use Minitest with a sample Rails project fixture:

```ruby
class MyAnalyzerTest < AnalyzerTestCase
  # AnalyzerTestCase provides:
  # - setup_sample_project / teardown_sample_project
  # - sample_project_path
  # - fixture_path(relative)
  # - stub_rails_runner(analyzer, response)

  def test_basic_functionality
    analyzer = RailsMcpServer::Analyzers::MyAnalyzer.new
    
    # Mock rails runner if needed
    stub_rails_runner(analyzer, '{"result": "data"}')
    
    result = analyzer.call(param: "value")
    assert_match /expected/, result
  end
end
```

Test fixtures are in `test/fixtures/sample_project/` - a minimal Rails-like structure.

## Configuration Files

- `config/resources.yml` - Guide download URLs and metadata
- `~/.config/rails-mcp/projects.yml` - User's Rails projects (created at runtime)
- `~/.config/rails-mcp/resources/` - Downloaded guides (created at runtime)

## Executables

All in `exe/`:

| Executable | Purpose |
|------------|---------|
| `rails-mcp-server` | Main MCP server (STDIO or HTTP mode) |
| `rails-mcp-config` | Interactive TUI for configuration |
| `rails-mcp-setup-claude` | Legacy: Claude Desktop setup |
| `rails-mcp-server-download-resources` | Legacy: Guide downloading |

## Dependencies

- `fast-mcp` (~> 1.6.0) - MCP protocol implementation
- `rack` (~> 3.2.0) - HTTP server support
- `puma` (~> 7.1.0) - Web server for HTTP mode
- `addressable` (~> 2.8) - URI handling
- `logger` (~> 1.7.0) - Logging

## Code Style

- Follow StandardRB (Ruby Standard Style)
- Run `bundle exec standardrb` before committing
- Run `bundle exec standardrb --fix` for auto-fixes

## Common Tasks

### Adding a new guide framework

1. Create resource files in `lib/rails-mcp-server/resources/`:
   - `{framework}_guides_resource.rb` - Single guide loader
   - `{framework}_guides_resources.rb` - Guide list provider

2. Add download config to `config/resources.yml`

3. Register in `load_guide.rb` analyzer

### Modifying the config TUI

Edit `exe/rails-mcp-config`. Uses Gum (optional) for enhanced UI with fallback to basic terminal.

Key classes:
- `RailsMcpConfig::UI` - Terminal UI wrapper
- `RailsMcpConfig::ProjectManager` - Main application logic

### Debugging

```bash
# Enable debug logging
rails-mcp-server --log-level debug

# Logs written to ./log/rails-mcp-server.log

# Test with MCP Inspector
npx @modelcontextprotocol/inspector exe/rails-mcp-server
```

## Important Notes

1. **This is a gem, not a Rails app** - No `bin/rails` in this project. Analyzers run `bin/rails runner` in *target* Rails projects.

2. **Sample project for tests** - `test/fixtures/sample_project/` is a minimal fixture, not a real Rails app.

3. **XDG paths** - User config goes to `~/.config/rails-mcp/`, not the gem directory.

4. **Version bumps** - Update `lib/rails-mcp-server/version.rb` and `CHANGELOG.md`.
