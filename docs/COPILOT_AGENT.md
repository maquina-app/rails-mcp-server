# GitHub Copilot Agent Setup Guide

This guide explains how to configure the Rails MCP Server for use with GitHub Copilot coding agent in GitHub Actions environments.

## Overview

GitHub Copilot coding agent runs in ephemeral GitHub Actions environments where:

- There's no persistent user configuration directory
- The agent has read-only access to the repository
- The repository root is the working directory
- Only MCP **tools** are supported (not resources)

The `--single-project` flag enables Rails MCP Server to work in these environments by using the current directory as the project without requiring `projects.yml`.

## Prerequisites

- A Rails project repository on GitHub
- GitHub Copilot enabled for your repository
- Ruby version specified in your project (via `.ruby-version` or `Gemfile`)

## Configuration Steps

### 1. Create Setup Workflow

Create `.github/workflows/copilot-setup-steps.yml` in your repository:

```yaml
name: "Copilot Setup Steps"

on:
  workflow_dispatch:

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
          ruby-version: '3.3'  # Or use .ruby-version file
          bundler-cache: true

      - name: Install Rails MCP Server
        run: gem install rails-mcp-server

      - name: Install project dependencies
        run: bundle install
```

### 2. Configure MCP Server

Go to your repository settings:

**Repository Settings → Copilot → Coding agent → MCP configuration**

Add the following JSON configuration:

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

### 3. Verify Setup

After configuration, the Copilot coding agent will:

1. Run the setup workflow to install dependencies
2. Start the Rails MCP Server with `--single-project` flag
3. Automatically use the repository as the active project

## Available Tools

With `--single-project` mode, all tools work immediately without needing to call `switch_project`:

| Tool | Description |
|------|-------------|
| `switch_project` | Optional - project is auto-selected |
| `search_tools` | Discover available analyzers by category |
| `execute_tool` | Run internal analyzers (routes, models, schema, etc.) |
| `execute_ruby` | Execute sandboxed Ruby code in project context |

### Internal Analyzers (via execute_tool)

- `project_info` - Project overview and structure
- `list_files` - Browse files with patterns
- `get_file` - Read file contents
- `get_routes` - Rails routes with filtering
- `analyze_models` - Model associations and validations
- `get_schema` - Database schema information
- `analyze_controller_views` - Controller-view relationships
- `analyze_environment_config` - Environment configuration analysis
- `load_guide` - Load documentation guides (if downloaded)

## Limitations

### Resources Not Supported

GitHub Copilot Agent only supports MCP **tools**, not resources. This means:

- ❌ MCP resource URIs (`rails://guides/getting_started`) won't work
- ✅ `load_guide` via `execute_tool` still works if guides are downloaded

### Workaround for Documentation

If you need Rails documentation available, add a step to download guides in your setup workflow:

```yaml
- name: Download Rails guides
  run: rails-mcp-server-download-resources rails
```

Then use:

```
execute_tool("load_guide", { guides: "rails", guide: "getting_started" })
```

### Read-Only Access

The Copilot agent has read-only access to the repository. The Rails MCP Server respects this:

- ✅ All read operations work (file reading, route analysis, schema inspection)
- ✅ `execute_ruby` with read operations works
- ❌ `execute_ruby` cannot write files (sandboxed)

## Troubleshooting

### Server Fails to Start

1. **Check Ruby version**: Ensure your setup workflow installs a compatible Ruby version
2. **Check gem installation**: Verify `rails-mcp-server` is installed in the setup steps
3. **Check working directory**: The MCP server should start from the repository root

### Tools Return "No project selected"

This shouldn't happen with `--single-project`, but if it does:

1. Verify `--single-project` is in the `args` array
2. Check that the server starts from the repository root
3. Try calling `switch_project` with the auto-detected project name

### analyze_models Returns Empty

The `analyze_models` tool uses `rails runner` to introspect models. Ensure:

1. Your project has a valid `Gemfile` with Rails
2. `bundle install` runs successfully in setup
3. Database configuration is valid (even if DB isn't available)

## Environment Variables

You can also enable single-project mode via environment variable:

```json
{
  "mcpServers": {
    "rails": {
      "type": "local",
      "command": "rails-mcp-server",
      "args": [],
      "env": {
        "RAILS_MCP_SINGLE_PROJECT": "1"
      },
      "tools": ["switch_project", "search_tools", "execute_tool", "execute_ruby"]
    }
  }
}
```

## Example Workflow

Here's a complete example of using Rails MCP Server with Copilot:

1. **Copilot Agent starts**
2. **Setup workflow runs**: Installs Ruby, gems, and Rails MCP Server
3. **MCP Server starts**: `rails-mcp-server --single-project`
4. **Project auto-detected**: Current directory becomes active project
5. **Tools available immediately**:
   - `search_tools()` - See all available analyzers
   - `execute_tool("project_info")` - Get project overview
   - `execute_tool("get_routes")` - See all routes
   - `execute_ruby("puts read_file('Gemfile')")` - Read any file

## See Also

- [README.md](../README.md) - Main documentation
- [AGENT.md](AGENT.md) - AI Agent guide for using the MCP tools
- [RESOURCES.md](RESOURCES.md) - Documentation resources guide
