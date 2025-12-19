# GitHub Copilot Agent Integration

This guide covers how to configure Rails MCP Server for use with GitHub Copilot coding agent in your Rails projects.

## Overview

GitHub Copilot coding agent runs MCP servers in ephemeral GitHub Actions environments. Rails MCP Server supports this through:

- **Auto-detection**: Automatically detects Rails projects in the current directory
- **`--single-project` flag**: Explicitly uses current directory as the project
- **`RAILS_MCP_PROJECT_PATH` env var**: Specifies project path directly

## Prerequisites

- A Rails application repository on GitHub
- GitHub Copilot with coding agent enabled
- Ruby 3.1+ (recommended: 3.3)

## Configuration

### Step 1: MCP Configuration

Create `.github/copilot/mcp.json` in your repository:

```json
{
  "mcpServers": {
    "rails": {
      "type": "local",
      "command": "rails-mcp-server",
      "args": ["--single-project"],
      "tools": ["switch_project", "search_tools", "execute_tool", "execute_ruby"]
    }
  }
}
```

### Step 2: Setup Steps Workflow

Create `.github/workflows/copilot-setup-steps.yml`:

```yaml
name: "Copilot Setup Steps"

on:
  workflow_dispatch:
  push:
    paths:
      - .github/workflows/copilot-setup-steps.yml
  pull_request:
    paths:
      - .github/workflows/copilot-setup-steps.yml

jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Install Rails MCP Server
        run: gem install rails-mcp-server

      - name: Install project dependencies
        run: bundle install
```

## Configuration Options

### Option A: `--single-project` flag (Recommended)

The simplest approach. Sets the current directory as the project:

```json
{
  "mcpServers": {
    "rails": {
      "type": "local",
      "command": "rails-mcp-server",
      "args": ["--single-project"]
    }
  }
}
```

### Option B: Environment Variable

Use `RAILS_MCP_PROJECT_PATH` for explicit path control:

```json
{
  "mcpServers": {
    "rails": {
      "type": "local",
      "command": "rails-mcp-server",
      "env": {
        "RAILS_MCP_PROJECT_PATH": "."
      }
    }
  }
}
```

### Option C: Auto-Detection

If the server starts from a directory containing a `Gemfile` with Rails, it auto-detects:

```json
{
  "mcpServers": {
    "rails": {
      "type": "local",
      "command": "rails-mcp-server"
    }
  }
}
```

## Available Tools

GitHub Copilot Agent only supports MCP **tools**. The following are available:

| Tool | Description |
|------|-------------|
| `switch_project` | Change active project (optional in single-project mode) |
| `search_tools` | Discover available analyzers |
| `execute_tool` | Invoke internal analyzers |
| `execute_ruby` | Run sandboxed Ruby code |

### Internal Analyzers (via `execute_tool`)

- `project_info` - Project structure and Rails version
- `list_files` - List files matching patterns
- `get_file` - Read file contents
- `get_routes` - Rails routes with filtering
- `get_schema` - Database schema information
- `analyze_models` - Model associations and validations
- `analyze_controller_views` - Controller-view relationships
- `analyze_environment_config` - Environment configuration analysis
- `load_guide` - Load framework documentation

## Limitations

### MCP Resources Not Supported

GitHub Copilot Agent only supports tools. MCP resources and prompts are not available. This means:

- Direct resource URIs (e.g., `rails://guides/getting_started`) won't work
- Use `execute_tool("load_guide", { library: "rails", guide: "getting_started" })` instead

### Documentation Guides

The `load_guide` analyzer requires guides to be downloaded. To include guides:

1. Download during setup steps:

```yaml
- name: Download Rails guides
  run: rails-mcp-server-download-resources rails
```

2. Or bundle guides in your repository under `.rails-mcp/resources/`

### Network Restrictions

GitHub Copilot Agent runs in a sandboxed environment with firewall restrictions. The MCP server has read-only access to the repository.

## Troubleshooting

### Server Fails to Start

1. Verify Ruby is installed in setup steps
2. Check that `rails-mcp-server` gem is installed
3. Ensure the workflow runs before Copilot agent starts

### Project Not Detected

1. Verify `Gemfile` exists in repository root
2. Verify `Gemfile` contains `gem "rails"` or `gem 'rails'`
3. Try explicit `--single-project` flag

### Tools Not Working

1. Verify project dependencies are installed (`bundle install`)
2. Check that the project has valid Rails structure
3. Use `search_tools` to verify available analyzers

## Example Workflow

Here's a complete example for a typical Rails project:

**.github/copilot/mcp.json**:
```json
{
  "mcpServers": {
    "rails": {
      "type": "local",
      "command": "rails-mcp-server",
      "args": ["--single-project"],
      "tools": ["switch_project", "search_tools", "execute_tool", "execute_ruby"]
    }
  }
}
```

**.github/workflows/copilot-setup-steps.yml**:
```yaml
name: "Copilot Setup Steps"

on: workflow_dispatch

jobs:
  copilot-setup-steps:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Install Rails MCP Server
        run: gem install rails-mcp-server

      - name: Install dependencies
        run: bundle install

      - name: Setup database
        run: bin/rails db:schema:load
        env:
          RAILS_ENV: test
```

## Priority Order

The server uses this priority for project detection:

1. `RAILS_MCP_PROJECT_PATH` environment variable (highest)
2. Auto-detection from `Gemfile` in current directory
3. `projects.yml` configuration file (lowest)

In GitHub Copilot Agent environments, options 1 or 2 will typically be used since `projects.yml` doesn't exist.

## Related Documentation

- [AI Agent Guide](AGENT.md) - Comprehensive guide for AI agents
- [Resources Guide](RESOURCES.md) - Documentation and guides management
- [README](../README.md) - General server documentation
