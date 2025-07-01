# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Development Commands

```bash
# Install dependencies
bundle install

# Run tests
rake test
# or
bundle exec rake test

# Run linter (Standard Ruby)
bundle exec standardrb

# Auto-fix linting issues
bundle exec standardrb --fix

# Build gem
bundle exec rake build

# Release gem (requires permissions)
bundle exec rake release
```

### Executable Commands

```bash
# Start the MCP server (STDIO mode - default)
./exe/rails-mcp-server

# Start the MCP server in HTTP mode
./exe/rails-mcp-server --mode http

# Set up Claude Desktop integration
./exe/rails-mcp-setup-claude

# Download documentation resources
./exe/rails-mcp-server-download-resources rails
./exe/rails-mcp-server-download-resources turbo
./exe/rails-mcp-server-download-resources stimulus
./exe/rails-mcp-server-download-resources kamal

# Import custom markdown files
./exe/rails-mcp-server-download-resources --file /path/to/docs/
```

## Architecture

This Rails MCP Server implements the Model Context Protocol to allow LLMs to interact with Rails projects. The architecture follows a modular design with clear separation of concerns:

### Core Components

1. **Main Entry Point**: `lib/rails_mcp_server.rb` - Sets up configuration, logging, and extension loading
2. **Configuration**: `lib/rails-mcp-server/config.rb` - Manages project configuration and XDG-compliant paths
3. **Tools**: `lib/rails-mcp-server/tools/` - MCP tools for Rails project interaction
4. **Resources**: `lib/rails-mcp-server/resources/` - Documentation resource management
5. **Extensions**: `lib/rails-mcp-server/extensions/` - FastMcp framework extensions for URI templating

### Tool Architecture

All tools inherit from `BaseTool` and implement:
- `execute(params)` method for tool logic
- Schema definitions for parameters
- Project context management

Key tools include:
- `SwitchProject` - Changes active Rails project
- `ProjectInfo` - Retrieves project metadata
- `AnalyzeModels` - Analyzes ActiveRecord models
- `GetRoutes` - Retrieves Rails routes
- `LoadGuide` - Loads documentation resources

### Resource System

The resource system provides access to documentation through:
- Guide loaders for each framework (Rails, Turbo, Stimulus, Kamal, Custom)
- Manifest-based file tracking
- URI template support for direct resource access
- Modular template methods for consistent behavior

### Extension System

Extensions enhance FastMcp capabilities:
- `ResourceTemplating` - Adds URI template support to FastMcp::Resource
- `ServerTemplating` - Adds resource matching to FastMcp::Server

These extensions are automatically loaded on module initialization.

## Testing

Tests are located in the `test/` directory and use Minitest. Run specific tests with:

```bash
# Run a specific test file
bundle exec rake test TEST=test/tools/switch_project_test.rb

# Run tests matching a pattern
bundle exec rake test TESTOPTS="--name=/project/"
```

## Key Dependencies

- `fast-mcp` (~> 1.4.0) - MCP protocol implementation
- `puma` (~> 6.6.0) - HTTP server for HTTP mode
- `standard` (dev) - Ruby linting and formatting