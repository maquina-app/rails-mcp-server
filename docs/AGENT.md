# Rails MCP Server - AI Agent Guide

This guide helps AI agents (Claude, GPT, etc.) use the Rails MCP Server effectively. It covers tool selection, common patterns, and troubleshooting.

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

**Primary method** - Use `execute_ruby` with `read_file()`:

```
railsMcpServer:execute_ruby code: "puts read_file('config/routes.rb')"
railsMcpServer:execute_ruby code: "puts read_file('app/models/user.rb')"
railsMcpServer:execute_ruby code: "puts read_file('app/controllers/users_controller.rb')"
```

**Alternative** - Use `get_file` tool:

```
railsMcpServer:execute_tool tool_name: "get_file" params: { path: "config/routes.rb" }
```

> ⚠️ **Important:** Do NOT use Claude's built-in `view` tool for Rails project files. It cannot access the project directory. Always use Rails MCP tools.

---

### Finding Files

**Use `execute_ruby` with `Dir.glob()`:**

```
# Find all models
railsMcpServer:execute_ruby code: "puts Dir.glob('app/models/**/*.rb').join('\n')"

# Find all controllers
railsMcpServer:execute_ruby code: "puts Dir.glob('app/controllers/**/*.rb').join('\n')"

# Find files by name pattern
railsMcpServer:execute_ruby code: "puts Dir.glob('app/**/*user*').join('\n')"

# Find all view templates
railsMcpServer:execute_ruby code: "puts Dir.glob('app/views/**/*.erb').join('\n')"

# Find Stimulus controllers
railsMcpServer:execute_ruby code: "puts Dir.glob('app/javascript/controllers/**/*.js').join('\n')"
```

**Using `list_files` helper** (glob pattern):

```
# List Ruby files in models directory
railsMcpServer:execute_ruby code: "puts list_files('app/models/**/*.rb')"
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

**Fallback if `get_routes` fails:**

```
railsMcpServer:execute_ruby code: "puts read_file('config/routes.rb')"
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
railsMcpServer:execute_tool tool_name: "load_guide" params: { guides: "rails", guide: "getting_started" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { guides: "rails", guide: "active_record_basics" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { guides: "turbo" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { guides: "stimulus" }
railsMcpServer:execute_tool tool_name: "load_guide" params: { guides: "kamal" }
```

---

### Environment Configuration

```
# Compare environment configs, find inconsistencies
railsMcpServer:execute_tool tool_name: "analyze_environment_config"
```

---

## Helper Methods in `execute_ruby`

When using `execute_ruby`, these helper methods are available:

| Helper | Usage | Description |
|--------|-------|-------------|
| `read_file(path)` | `read_file('config/routes.rb')` | Read file contents (relative to project root) |
| `file_exists?(path)` | `file_exists?('app/models/user.rb')` | Check if file exists (returns boolean) |
| `list_files(pattern)` | `list_files('app/models/*.rb')` | Glob pattern to find files |
| `project_root` | `project_root` | Returns the project root path |

**Critical:** Always use `puts` to see output:

```
# ❌ Bad - returns "Code executed successfully (no output)"
railsMcpServer:execute_ruby code: "read_file('Gemfile')"

# ✅ Good - returns file contents
railsMcpServer:execute_ruby code: "puts read_file('Gemfile')"
```

---

## Tool Selection Summary

| Task | Tool to Use |
|------|-------------|
| Read a project file | `execute_ruby` with `read_file()` or `get_file` |
| Find files by pattern | `execute_ruby` with `Dir.glob()` |
| Analyze models | `analyze_models` |
| Get database schema | `get_schema` |
| Get routes | `get_routes` (fallback: read routes.rb) |
| Analyze controllers | `analyze_controller_views` |
| Compare environments | `analyze_environment_config` |
| Load documentation | `load_guide` |
| Custom Ruby queries | `execute_ruby` |

---

## Rails MCP vs Claude Built-in Tools

| Task | Use This | NOT This |
|------|----------|----------|
| Read Rails project files | `railsMcpServer:execute_ruby` with `read_file()` | Claude's `view` tool |
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
railsMcpServer:execute_ruby code: "puts Dir.glob('app/**/*transaction*').join('\n')"

# 3. Understand the data model
railsMcpServer:execute_tool tool_name: "analyze_models" params: { model_name: "Transaction" }
railsMcpServer:execute_tool tool_name: "get_schema" params: { table_name: "transactions" }

# 4. Check the routes
railsMcpServer:execute_tool tool_name: "get_routes" params: { controller: "transactions" }

# 5. Read the controller
railsMcpServer:execute_ruby code: "puts read_file('app/controllers/transactions_controller.rb')"

# 6. Check existing views
railsMcpServer:execute_ruby code: "puts Dir.glob('app/views/transactions/**/*').join('\n')"
```

---

## Common Pitfalls

### ❌ Don't

- Use Claude's `view` tool for Rails project files
- Forget `puts` in `execute_ruby` calls
- Use absolute paths (always use paths relative to project root)
- Skip `switch_project` before using other tools

### ✅ Do

- Call `switch_project` before any other MCP tool
- Use `execute_ruby` with `read_file()` as your primary file reading method
- Use `puts` to output results in `execute_ruby`
- Fall back to `execute_ruby` when specialized tools fail
- Use `search_tools` when unsure what's available

---

## Error Handling & Fallbacks

### "undefined method" errors from analyzers

Some analyzers may fail with certain Rails versions. Fall back to `execute_ruby`:

```
# If get_routes fails:
railsMcpServer:execute_ruby code: "puts read_file('config/routes.rb')"

# If analyze_models fails:
railsMcpServer:execute_ruby code: "puts read_file('app/models/user.rb')"
```

### "Path not found" errors

1. Ensure you've called `switch_project` first
2. Use relative paths, not absolute paths
3. Check if path exists:
   ```
   railsMcpServer:execute_ruby code: "puts file_exists?('app/models/user.rb')"
   ```

### "wrong number of arguments" errors

The `list_files()` helper takes a glob pattern as a single argument:
```
# Correct usage
railsMcpServer:execute_ruby code: "puts list_files('app/models/**/*.rb')"
```

### No output from `execute_ruby`

Add `puts` before your expression:
```
# Before (no output)
railsMcpServer:execute_ruby code: "User.count"

# After (shows result)
railsMcpServer:execute_ruby code: "puts User.count"
```

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
