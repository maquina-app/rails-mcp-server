# Rails MCP Server - AI Agent Guide

This guide helps AI agents (Claude, GPT, etc.) use the Rails MCP Server effectively. It covers tool selection, common patterns, and troubleshooting.

## Architecture Overview

Rails MCP Server uses a **progressive tool discovery** pattern to minimize context usage:

```
MCP Client (Claude, etc.)
    │
    ▼
┌─────────────────────────────────────────────┐
│  3 MCP-Registered Tools                     │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │switch_project│  │search_tools        │   │
│  └─────────────┘  └─────────────────────┘   │
│  ┌─────────────┐  ┌─────────────────────┐   │
│  │execute_tool │──▶│ 9 Internal Analyzers│   │
│  └─────────────┘  └─────────────────────┘   │
└─────────────────────────────────────────────┘
```

**Key concept:** Only 3 tools are registered with MCP. The 9 internal analyzers (`analyze_models`, `get_routes`, `get_file`, etc.) are discovered via `search_tools` and invoked via `execute_tool`. The server is an introspection tool — it exposes this fixed set of analyzers and does not execute arbitrary Ruby.

---

## Quick Start

**Always start with these two steps:**

```
# 1. Switch to the project
railsMcpServer:switch_project project_name: "your-project-name"

# 2. Get project overview
railsMcpServer:execute_tool tool_name: "project_info"
```

**If unsure what tools are available:**

```
railsMcpServer:search_tools
railsMcpServer:search_tools category: "models"
railsMcpServer:search_tools query: "routes"
```

---

## Tool Selection Guide

### Reading Files

Use the `get_file` analyzer:

```
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "config/routes.rb" }
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "app/models/user.rb" }
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "app/controllers/users_controller.rb" }
```

Paths are relative to the project root. Reads are confined to the project directory, and sensitive files (`.env`, credentials, keys) are refused.

> ⚠️ **Important:** Do NOT use Claude's built-in `view` tool for Rails project files. It cannot access the project directory. Always use Rails MCP tools.

---

### Finding Files

Use the `list_files` analyzer with a glob `pattern` (and optional `directory`):

```
# Find all models
railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/models/**/*.rb" }

# Find all controllers
railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/controllers/**/*.rb" }

# Find files by name pattern
railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/**/*user*" }

# Find all view templates
railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/views/**/*.erb" }

# Find Stimulus controllers
railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/javascript/controllers/**/*.js" }
```

---

### Analyzing Models

```
# List all models
railsMcpServer:execute_tool tool_name: "analyze_models"

# Analyze specific model with associations, validations, callbacks
railsMcpServer:execute_tool tool_name: "analyze_models" params: { model_name: "User" }

# Analyze multiple models
railsMcpServer:execute_tool tool_name: "analyze_models" params: { model_names: ["User", "Post", "Comment"] }

# Quick list (names only)
railsMcpServer:execute_tool tool_name: "analyze_models" params: { detail_level: "names" }

# With Prism static analysis (callbacks, scopes, methods)
railsMcpServer:execute_tool tool_name: "analyze_models" params: { model_name: "User", analysis_type: "full" }
```

---

### Getting Database Schema

```
# List all tables
railsMcpServer:execute_tool tool_name: "get_schema" params: { detail_level: "tables" }

# Get specific table schema
railsMcpServer:execute_tool tool_name: "get_schema" params: { table_name: "users" }

# Get multiple tables
railsMcpServer:execute_tool tool_name: "get_schema" params: { table_names: ["users", "posts"] }

# Full schema with indexes
railsMcpServer:execute_tool tool_name: "get_schema"
```

---

### Getting Routes

```
# All routes
railsMcpServer:execute_tool tool_name: "get_routes"

# Filter by controller
railsMcpServer:execute_tool tool_name: "get_routes" params: { controller: "users" }

# Filter by HTTP verb
railsMcpServer:execute_tool tool_name: "get_routes" params: { verb: "POST" }

# Filter by path
railsMcpServer:execute_tool tool_name: "get_routes" params: { path_contains: "api" }

# Named routes only
railsMcpServer:execute_tool tool_name: "get_routes" params: { named_only: true }
```

**Fallback if `get_routes` fails:** read the routes file directly.

```
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "config/routes.rb" }
```

---

### Analyzing Controllers

```
# List all controllers
railsMcpServer:execute_tool tool_name: "analyze_controller_views" params: { detail_level: "names" }

# Analyze specific controller (actions, callbacks, views)
railsMcpServer:execute_tool tool_name: "analyze_controller_views" params: { controller_name: "users" }

# With Prism analysis (filters, strong params, instance variables)
railsMcpServer:execute_tool tool_name: "analyze_controller_views" params: { controller_name: "users", analysis_type: "full" }
```

---

### Loading Framework Guides

```
railsMcpServer:execute_tool tool_name: "load_guide" params: { library: "rails", guide: "getting_started" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { library: "rails", guide: "active_record_basics" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { library: "turbo" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { library: "stimulus" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { library: "kamal" }
```

---

### Environment Configuration

```
# Compare environment configs, find inconsistencies
railsMcpServer:execute_tool tool_name: "analyze_environment_config"
```

---

## Tool Selection Summary

| Task | Tool to Use |
|------|-------------|
| Read a project file | `get_file` (params: `path`) |
| Find files by pattern | `list_files` (params: `pattern`) |
| Analyze models | `analyze_models` |
| Get database schema | `get_schema` |
| Get routes | `get_routes` (fallback: `get_file` on `config/routes.rb`) |
| Analyze controllers | `analyze_controller_views` |
| Compare environments | `analyze_environment_config` |
| Load documentation | `load_guide` |
| Project overview | `project_info` |

---

## Analyzer Parameter Quick Reference

| Analyzer | Required | Optional |
|----------|----------|----------|
| `project_info` | - | `max_depth`, `include_files`, `detail_level` |
| `list_files` | - | `directory`, `pattern` |
| `get_file` | `path` | - |
| `get_routes` | - | `controller`, `verb`, `path_contains`, `named_only`, `detail_level` |
| `analyze_models` | - | `model_name`, `model_names`, `detail_level`, `analysis_type` |
| `get_schema` | - | `table_name`, `table_names`, `detail_level` |
| `analyze_controller_views` | - | `controller_name`, `detail_level`, `analysis_type` |
| `analyze_environment_config` | - | (none) |
| `load_guide` | `library` | `guide` |

**Common parameter values:**
- `detail_level`: `"names"`, `"summary"`, `"full"`
- `analysis_type`: `"introspection"`, `"static"`, `"full"`
- `library` (for load_guide): `"rails"`, `"turbo"`, `"stimulus"`, `"kamal"`, `"custom"`

---

## Rails MCP vs Claude Built-in Tools

| Task | Use This | NOT This |
|------|----------|----------|
| Read Rails project files | `railsMcpServer:execute_tool` with `get_file` | Claude's `view` tool |
| Edit files in Neovim | `nvimMcpServer:update_buffer` | Claude's `str_replace` |
| Create new files | Claude's `create_file` | — |
| View images | Claude's `view` tool | — |

**Key distinction:**
- **Rails MCP tools** operate within the Rails project context (after `switch_project`)
- **Claude's built-in tools** operate on a container filesystem, not your project directory
- **Neovim MCP tools** operate on files currently open in your editor

---

## Recommended Exploration Workflow

When starting work on an unfamiliar codebase:

```
# 1. Get the lay of the land
railsMcpServer:execute_tool tool_name: "project_info"

# 2. Find relevant files
railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/**/*transaction*" }

# 3. Understand the data model
railsMcpServer:execute_tool tool_name: "analyze_models" params: { model_name: "Transaction" }
railsMcpServer:execute_tool tool_name: "get_schema" params: { table_name: "transactions" }

# 4. Check the routes
railsMcpServer:execute_tool tool_name: "get_routes" params: { controller: "transactions" }

# 5. Read the controller
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "app/controllers/transactions_controller.rb" }

# 6. Check existing views
railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/views/transactions/**/*" }
```

---

## Decision Tree: Which Tool Should I Use?

```
What do you need to do?
│
├─► Read/analyze code?
│   ├─► Single file? ──────────► get_file (params: path)
│   ├─► Model info? ───────────► analyze_models (params: model_name)
│   ├─► Controller info? ──────► analyze_controller_views (params: controller_name)
│   └─► Multiple files? ───────► list_files (params: pattern)
│
├─► Database info?
│   ├─► Table structure? ──────► get_schema (params: table_name)
│   └─► List all tables? ──────► get_schema (params: detail_level: "tables")
│
├─► Routing info?
│   ├─► All routes? ───────────► get_routes
│   └─► Filtered routes? ──────► get_routes (params: controller, verb, path_contains)
│
├─► Project overview? ─────────► project_info
│
└─► Documentation? ────────────► load_guide (params: library, guide)
```

---

## Common Pitfalls

### ❌ Don't

- Use Claude's `view` tool for Rails project files
- Use absolute paths (always use paths relative to project root)
- Skip `switch_project` before using other tools
- Use `users` (plural) for model names - use `User` (singular CamelCase)
- Use `User` for table names - use `users` (plural snake_case)

### ✅ Do

- Call `switch_project` before any other MCP tool
- Use `get_file` to read files and `list_files` to find them
- Use the specialized analyzers (`analyze_models`, `get_routes`, `get_schema`) for structured info
- Use `search_tools` when unsure what's available
- Use CamelCase singular for models: `User`, `BlogPost`, `OrderItem`
- Use snake_case plural for tables: `users`, `blog_posts`, `order_items`

---

## Error Handling & Fallbacks

### "undefined method" errors from analyzers

Some analyzers may fail with certain Rails versions. Fall back to reading the source directly:

```
# If get_routes fails:
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "config/routes.rb" }

# If analyze_models fails:
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "app/models/user.rb" }
```

### "Path not found" / "Access denied" errors

1. Ensure you've called `switch_project` first
2. Use relative paths, not absolute paths
3. Check whether the file shows up in a listing:
   ```
   railsMcpServer:execute_tool tool_name: "list_files" params: { pattern: "app/models/*.rb" }
   ```
4. Sensitive files (`.env`, credentials, keys) are intentionally refused by `get_file` / `list_files`.

### `get_schema` / `get_routes` fail to boot the app (Bundler / wrong Ruby)

These tools run the project's `bin/rails`. The server auto-selects the project's Ruby via your version manager's shims (**mise**, **asdf**, **rbenv**; **rvm** is sourced), reading `.ruby-version` / `.tool-versions` / `.mise.toml`. If they still fail with a Bundler or boot error:

1. Confirm the project has a `.ruby-version` (or `.tool-versions` / `.mise.toml`) and that Ruby is installed in your manager.
2. Confirm your manager is one of mise, asdf, rbenv, or rvm — these are auto-detected.
3. The underlying boot error is included in the tool output (no longer suppressed), so read it for the specific cause.

---

## Integration with Neovim MCP

If using alongside Neovim MCP Server:

```
# Check what files are open in Neovim
nvimMcpServer:get_project_buffers project_name: "your-project"

# Update a file that's open in Neovim
nvimMcpServer:update_buffer project_name: "your-project" file_path: "/full/path/to/file.rb" content: "new content"
```

**Use Neovim MCP when:**
- You need to edit a file that's already open in the editor
- You want changes to appear immediately in the user's editor

**Use Rails MCP when:**
- You need to read/analyze project files
- You need Rails-specific analysis (models, routes, schema)
- The file isn't open in Neovim
```
