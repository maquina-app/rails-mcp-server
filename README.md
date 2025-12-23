# Rails MCP Server

A Ruby implementation of a Model Context Protocol (MCP) server for Rails projects. This server allows LLMs (Large Language Models) to interact with Rails projects through the Model Context Protocol, providing capabilities for code analysis, exploration, and development assistance.

## What is MCP?

The Model Context Protocol (MCP) is a standardized way for AI models to interact with their environment. It defines a structured method for models to request and use tools, access resources, and maintain context during interactions.

This Rails MCP Server implements the MCP specification to give AI models access to Rails projects for code analysis, exploration, and assistance.

## Features

- Manage multiple Rails projects
- Browse project files and structures
- View Rails routes with filtering options
- Inspect model information and relationships (with Prism static analysis)
- Get database schema information
- Analyze controller-view relationships
- Analyze environment configurations
- Execute sandboxed Ruby code for custom queries
- Access comprehensive Rails, Turbo, Stimulus, and Kamal documentation
- Context-efficient architecture with progressive tool discovery
- Seamless integration with LLM clients

## Installation

Install the gem:

```bash
gem install rails-mcp-server
```

After installation, the following executables will be available in your PATH:

- `rails-mcp-server` - The MCP server itself
- `rails-mcp-config` - Interactive configuration tool (recommended)
- `rails-mcp-setup-claude` - Legacy Claude Desktop setup script
- `rails-mcp-server-download-resources` - Legacy resource download script

## Configuration

### Using the Configuration Tool (Recommended)

The easiest way to configure the Rails MCP Server is using the interactive configuration tool:

```bash
rails-mcp-config
```

This provides a user-friendly TUI (Terminal User Interface) for:

- **Managing Projects**: Add, edit, remove, and validate Rails projects
- **Downloading Guides**: Download Rails, Turbo, Stimulus, and Kamal documentation
- **Importing Custom Guides**: Add your own markdown documentation
- **Claude Desktop Integration**: Automatically configure Claude Desktop

The tool uses [Gum](https://github.com/charmbracelet/gum) for an enhanced experience if installed, but works with a basic terminal fallback.

```bash
# Install Gum for best experience (optional)
brew install gum        # macOS
sudo apt install gum    # Debian/Ubuntu
yay -S gum              # Arch Linux
```

### Manual Configuration

The Rails MCP Server follows the XDG Base Directory Specification for configuration files:

- On macOS: `$XDG_CONFIG_HOME/rails-mcp` or `~/.config/rails-mcp` if XDG_CONFIG_HOME is not set
- On Windows: `%APPDATA%\rails-mcp`

The server will automatically create these directories and an empty `projects.yml` file the first time it runs.

To configure your projects manually:

1. Edit the `projects.yml` file in your config directory to include your Rails projects:

```yaml
store: "~/projects/store"
blog: "~/projects/rails-blog"
ecommerce: "/full/path/to/ecommerce-app"
```

Each key in the YAML file is a project name (which will be used with the `switch_project` tool), and each value is the path to the project directory.

## Usage

### Starting the server

The Rails MCP Server can run in two modes:

1. **STDIO mode (default)**: Communicates over standard input/output for direct integration with clients like Claude Desktop.
2. **HTTP mode**: Runs as an HTTP server with JSON-RPC and Server-Sent Events (SSE) endpoints.

```bash
# Start in default STDIO mode
rails-mcp-server

# Start in HTTP mode on the default port (6029)
rails-mcp-server --mode http

# Start in HTTP mode on a custom port
rails-mcp-server --mode http -p 8080

# Start in HTTP mode binding to all interfaces (for local network access)
rails-mcp-server --mode http --bind-all
```

When running in HTTP mode, the server provides two endpoints:

- JSON-RPC endpoint: `http://localhost:<port>/mcp/messages`
- SSE endpoint: `http://localhost:<port>/mcp/sse`

### Network Access (HTTP Mode)

By default, the HTTP server only binds to localhost for security. If you need to access the server from other machines on your local network (e.g., for testing with multiple devices), you can use the `--bind-all` flag:

```bash
# Allow access from any machine on your local network
rails-mcp-server --mode http --bind-all

# With a custom port
rails-mcp-server --mode http --bind-all -p 8080
```

When using `--bind-all`:

- The server binds to `0.0.0.0` instead of `localhost`
- Access is allowed from local network IP ranges (192.168.x.x, 10.x.x.x)
- The server accepts connections from `.local` domain names (e.g., `my-computer.local`)
- Security features remain active to prevent unauthorized access

**Security Note**: Only use `--bind-all` on trusted networks. The server includes built-in security features to validate origins and IP addresses, but exposing any service to your network increases the attack surface.

### Logging Options

The server logs to a file in the `./log` directory by default. You can customize logging with these options:

```bash
# Set the log level (debug, info, error)
rails-mcp-server --log-level debug
```

## Claude Desktop Integration

The Rails MCP Server can be used with Claude Desktop. There are multiple options to set this up:

### Option 1: Use the configuration tool (recommended)

Run the interactive configuration tool and select "Claude Desktop integration":

```bash
rails-mcp-config
```

The tool will:

- Detect your current Claude Desktop configuration
- Let you choose between STDIO or HTTP mode
- Automatically find the correct Ruby and server paths
- Create a backup before making changes
- Update the Claude Desktop configuration

### Option 2: Use the setup script (legacy)

Run the setup script which will automatically configure Claude Desktop:

```bash
rails-mcp-setup-claude
```

The script will:

- Create the appropriate config directory for your platform
- Create an empty `projects.yml` file if it doesn't exist
- Update the Claude Desktop configuration

After running the script, restart Claude Desktop to apply the changes.

### Option 3: Direct Configuration

1. Create the appropriate config directory for your platform:
   - macOS: `$XDG_CONFIG_HOME/rails-mcp` or `~/.config/rails-mcp` if XDG_CONFIG_HOME is not set
   - Windows: `%APPDATA%\rails-mcp`

2. Create a `projects.yml` file in that directory with your Rails projects.

3. Find or create the Claude Desktop configuration file:
   - macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
   - Windows: `%APPDATA%\Claude\claude_desktop_config.json`

4. Add or update the MCP server configuration:

```json
{
  "mcpServers": {
    "railsMcpServer": {
      "command": "ruby",
      "args": ["/full/path/to/rails-mcp-server/exe/rails-mcp-server"] 
    }
  }
}
```

5. Restart Claude Desktop to apply the changes.

### Ruby Version Manager Users

Claude Desktop launches the MCP server using your system's default Ruby environment, bypassing version manager initialization (e.g., rbenv, RVM). The MCP server needs to use the same Ruby version where it was installed, as MCP server startup failures can occur when using an incompatible Ruby version.

If you are using a Ruby version manager such as rbenv, you can use the Ruby shim path to ensure the correct version is used:

```json
{
  "mcpServers": {
    "railsMcpServer": {
      "command": "/home/your_user/.rbenv/shims/ruby",
      "args": ["/full/path/to/rails-mcp-server/exe/rails-mcp-server"] 
    }
  }
}
```

Replace "/home/your_user/.rbenv/shims/ruby" with your actual path for the Ruby shim.

**Tip**: The `rails-mcp-config` tool automatically detects your Ruby path and uses the correct shim path when configuring Claude Desktop.

### Using an MCP Proxy (Advanced)

Claude Desktop and many other LLM clients only support STDIO mode communication, but you might want to use the HTTP/SSE capabilities of the server. An MCP proxy can bridge this gap:

1. Start the Rails MCP Server in HTTP mode:

```bash
rails-mcp-server --mode http
```

2. Install and run an MCP proxy. There are several implementations available in different languages. An MCP proxy allows a client that only supports STDIO communication to communicate via HTTP SSE. Here's an example using a JavaScript-based MCP proxy:

```bash
# Install the Node.js based MCP proxy
npm install -g mcp-remote

# Run the proxy, pointing to your running Rails MCP Server
npx mcp-remote http://localhost:6029/mcp/sse
```

3. Configure Claude Desktop (or other LLM client) to use the proxy instead of connecting directly to the server:

```json
{
  "mcpServers": {
    "railsMcpServer": {
      "command": "npx",
      "args": ["mcp-remote", "http://localhost:6029/mcp/sse"]
    }
  }
}
```

This setup allows STDIO-only clients to communicate with the Rails MCP Server through the proxy, benefiting from the HTTP/SSE capabilities while maintaining client compatibility.

**Tip**: The `rails-mcp-config` tool can configure HTTP mode with mcp-remote automatically.

## How the Server Works

The Rails MCP Server implements the Model Context Protocol using either:

- **STDIO mode**: Reads JSON-RPC 2.0 requests from standard input and returns responses to standard output.
- **HTTP mode**: Provides HTTP endpoints for JSON-RPC 2.0 requests and Server-Sent Events.

Each request includes a sequence number to match requests with responses, as defined in the MCP specification. The server maintains project context and provides Rails-specific analysis capabilities across multiple codebases.

### Context-Efficient Architecture

The server uses a progressive tool discovery architecture to minimize context usage. Instead of exposing all tools upfront, it provides 4 bootstrap tools that allow LLMs to discover and invoke additional analyzers on-demand:

- **`switch_project`** - Select the active Rails project
- **`search_tools`** - Discover available tools by category or keyword
- **`execute_tool`** - Invoke internal analyzers with parameters
- **`execute_ruby`** - Run sandboxed Ruby code for custom queries

This design reduces initial context from ~2,400 tokens to ~800 tokens while maintaining full functionality.

## AI Agent Guide

For AI agents (Claude, GPT, etc.) using this server, see the comprehensive **[AI Agent Guide](docs/AGENT.md)** which covers:

- Quick start workflow
- Tool selection guide for common tasks
- Helper methods available in `execute_ruby`
- Common pitfalls and how to avoid them
- Error handling and fallback strategies
- Integration with other MCP servers (e.g., Neovim MCP)

## Available Tools

The server provides 4 registered tools plus internal analyzers accessible via `execute_tool`.

### Registered Tools

#### 1. `switch_project`

**Description:** Change the active Rails project. Must be called before using other tools.

**Parameters:**

- `project_name`: (String, required) Name of the project as defined in projects.yml

After switching, you'll see a Quick Start guide with common commands.

#### 2. `search_tools`

**Description:** Discover available tools by category or keyword.

**Parameters:**

- `query`: (String, optional) Search term (e.g., 'routes', 'model', 'schema')
- `category`: (String, optional) Filter by category: models, database, routing, controllers, files, project, guides
- `detail_level`: (String, optional) Output detail: 'names', 'summary', or 'full' (default: 'summary')

#### 3. `execute_tool`

**Description:** Invoke internal analyzers by name.

**Parameters:**

- `tool_name`: (String, required) Name of the analyzer (e.g., 'get_routes', 'analyze_models')
- `params`: (Hash, optional) Parameters for the analyzer

#### 4. `execute_ruby`

**Description:** Execute sandboxed Ruby code in the Rails project context.

**Parameters:**

- `code`: (String, required) Ruby code to execute
- `timeout`: (Integer, optional) Timeout in seconds (default: 30, max: 60)

**Available helper methods:**

- `read_file(path)` - Read a file safely
- `file_exists?(path)` - Check if a file exists
- `list_files(pattern)` - Glob files (e.g., `'app/models/**/*.rb'`)
- `project_root` - Get the project root path

**Note:** Use `puts` to see output from your code.

**Security:** The sandbox prevents file writes, system calls, network access, and reading sensitive files (.env, credentials, etc.).

### Internal Analyzers (via execute_tool)

#### `project_info`

Retrieve comprehensive project information including Rails version, directory structure, and organization.

```
execute_tool(tool_name: "project_info")
```

#### `list_files`

List files matching a pattern in a directory.

```
execute_tool(tool_name: "list_files", params: { directory: "app/models", pattern: "*.rb" })
```

#### `get_file`

Retrieve the content of a specific file.

```
execute_tool(tool_name: "get_file", params: { path: "app/models/user.rb" })
```

#### `get_routes`

Retrieve Rails routes with optional filtering.

```
execute_tool(tool_name: "get_routes")
execute_tool(tool_name: "get_routes", params: { controller: "users" })
execute_tool(tool_name: "get_routes", params: { verb: "POST" })
execute_tool(tool_name: "get_routes", params: { path_contains: "api" })
```

#### `analyze_models`

Analyze Active Record models with associations, validations, and optional Prism static analysis.

```
execute_tool(tool_name: "analyze_models")
execute_tool(tool_name: "analyze_models", params: { model_name: "User" })
execute_tool(tool_name: "analyze_models", params: { model_name: "User", analysis_type: "full" })
execute_tool(tool_name: "analyze_models", params: { detail_level: "names" })
```

**Parameters:**

- `model_name`: Specific model to analyze
- `model_names`: Array of models to analyze
- `detail_level`: 'names', 'summary', or 'full'
- `analysis_type`: 'introspection', 'static', or 'full' (includes Prism AST analysis)

#### `get_schema`

Retrieve database schema information.

```
execute_tool(tool_name: "get_schema")
execute_tool(tool_name: "get_schema", params: { table_name: "users" })
execute_tool(tool_name: "get_schema", params: { detail_level: "tables" })
```

#### `analyze_controller_views`

Analyze controller-view relationships with optional Prism static analysis.

```
execute_tool(tool_name: "analyze_controller_views")
execute_tool(tool_name: "analyze_controller_views", params: { controller_name: "users" })
execute_tool(tool_name: "analyze_controller_views", params: { controller_name: "users", analysis_type: "full" })
```

#### `analyze_environment_config`

Analyze environment configurations for inconsistencies and security issues.

```
execute_tool(tool_name: "analyze_environment_config")
```

#### `load_guide`

Load documentation guides from Rails, Turbo, Stimulus, Kamal, or Custom.

```
execute_tool(tool_name: "load_guide", params: { guides: "rails" })
execute_tool(tool_name: "load_guide", params: { guides: "rails", guide: "getting_started" })
execute_tool(tool_name: "load_guide", params: { guides: "turbo" })
execute_tool(tool_name: "load_guide", params: { guides: "stimulus" })
```

## Resources and Documentation

The Rails MCP Server provides access to comprehensive documentation through both the `load_guide` tool and direct MCP resource access. You can access official guides for Rails, Turbo, Stimulus, and Kamal, as well as import your own custom documentation.

### Available Resource Categories

- **Rails Guides**: Official Ruby on Rails 8.0.2 documentation
- **Turbo Guides**: Official Turbo (Hotwire) framework documentation  
- **Stimulus Guides**: Official Stimulus JavaScript framework documentation
- **Kamal Guides**: Official Kamal deployment tool documentation
- **Custom Guides**: Your imported markdown files

### Getting Started with Resources

The easiest way to manage resources is using the configuration tool:

```bash
rails-mcp-config
```

Then select "Download guides" or "Import custom guides" from the menu.

Alternatively, you can use the legacy command-line tools:

```bash
# Download Rails guides
rails-mcp-server-download-resources rails

# Download Turbo guides
rails-mcp-server-download-resources turbo

# Import custom markdown files
rails-mcp-server-download-resources --file /path/to/your/docs/
```

### Resource Access Methods

1. **Tool-based access**: Use the `load_guide` tool in conversations
2. **Direct resource access**: MCP clients can query resources using URI patterns like `rails://guides/{guide_name}`

For complete information about downloading, managing, and using resources, see the [Resources Guide](docs/RESOURCES.md).

## Testing and Debugging

The easiest way to test and debug the Rails MCP Server is by using the MCP Inspector, a developer tool designed specifically for testing and debugging MCP servers.

To use MCP Inspector with Rails MCP Server:

```bash
# Install and run MCP Inspector
npm -g install @modelcontextprotocol/inspector

npx @modelcontextprotocol/inspector /path/to/rails-mcp-server
```

This will:

1. Start your Rails MCP Server in HTTP mode
2. Launch the MCP Inspector UI in your browser (default port: 6274)
3. Set up an MCP Proxy server (default port: 6277)

In the MCP Inspector UI, you can:

- See all available tools (you should see 4 registered tools)
- Execute tool calls interactively
- View request and response details
- Debug issues in real-time

The Inspector UI provides an intuitive interface to interact with your MCP server, making it easy to test and debug your Rails MCP Server implementation.

### Testing Workflow

1. **Switch to a project:** `switch_project` with your project name
2. **Discover tools:** `search_tools` to see available analyzers
3. **Test analyzers:** `execute_tool` to invoke specific analyzers
4. **Test Ruby execution:** `execute_ruby` with code like `puts read_file('Gemfile')`

## Integration with LLM Clients

This server is designed to be integrated with LLM clients that support the Model Context Protocol, such as Claude Desktop or other MCP-compatible applications.

To use with an MCP client:

1. Start the Rails MCP Server (it will use STDIO mode by default)
2. Connect your MCP-compatible client to the server
3. The client will be able to use the available tools to interact with your Rails projects

## Security

For security concerns, please see [SECURITY.md](SECURITY.md).

## License

This Rails MCP server is released under the MIT License, a permissive open-source license that allows for free use, modification, distribution, and private use.

Copyright (c) 2025 Mario Alberto Chávez Cárdenas

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/maquina-app/rails-mcp-server>.
