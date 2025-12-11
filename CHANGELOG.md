# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.4.1] - 2025-12-11

### Fixed

- **rails-mcp-config rbenv compatibility**: Fixed silent failure when running via rbenv shims
  - The `__FILE__ == $0` guard failed because RubyGems' `load` creates a path mismatch between `__FILE__` (gem path) and `$0` (shim path)
  - Now correctly detects execution via `File.basename($0) == "rails-mcp-config"`

## [1.4.0] - 2025-12-10

### Added

- **Context-Efficient Architecture**: Reduced registered MCP tools from 12 to 4, cutting initial context consumption by 67%
  - 4 bootstrap tools: `switch_project`, `search_tools`, `execute_tool`, `execute_ruby`
  - 9 internal analyzers invoked via `execute_tool` meta-dispatcher
  - Tools are now discovered on-demand rather than loaded upfront
- **Sandboxed Ruby Execution** (`execute_ruby`): Secure code execution in Rails context
  - File/network/system call restrictions
  - Sensitive file protection (.env, credentials, .gitignore'd files)
  - Helper methods: `read_file`, `file_exists?`, `list_files`, `project_root`
- **Interactive Configuration Tool** (`rails-mcp-config`): New TUI for project management
  - Project management with validation
  - Guide downloading with progress indicators
  - Claude Desktop auto-configuration (STDIO/HTTP modes)
  - Gum-enhanced UI with terminal fallback
- **Claude Code Integration**: Added CLAUDE.md, .claudeignore, and .claude/ configuration
- **Agent Documentation**: New docs/AGENT.md comprehensive AI agent guide

### Changed

- **Architecture Refactor**: Separation of tools/ (FastMCP) vs analyzers/ (plain Ruby classes)
  - New `lib/rails-mcp-server/analyzers/` directory with `RailsMcpServer::Analyzers` namespace
  - Removed deprecated extensions (resource_templating, server_templating)
- **Rails Introspection** (replaces regex parsing):
  - `Model.reflect_on_all_associations` for accurate association data
  - `Model.validators` with conditions and options
  - `Controller.action_methods` instead of scanning for `def`
  - `Rails.application.routes.routes` for direct route access
  - `_process_action_callbacks` for before/after actions
- **Prism Static Analysis**: AST-based code inspection for callbacks, scopes, concerns
  - Method definitions with line numbers
  - Instance variables per controller action
  - New `analysis_type` parameter: introspection | static | full

### Improved

- **Output Optimization**: New `detail_level` parameter (names | summary | full)
- **Route Filtering**: Filter by controller, verb, or path
- **Batch Operations**: Support for analyzing multiple models and schemas at once
- **Quick Start Guide**: Shown after `switch_project` for better onboarding
- **execute_ruby Hints**: Improved feedback for missing puts statements

### Fixed

- **get_routes**: Fixed method definition order bug

### Technical

- Test suite with 32 tests covering analyzers and tools
- Test fixtures with sample Rails project structure

## [1.2.3] - 2025-12-10

### Fixed

- **Setup Script Compatibility**: Fixed `rails-mcp-setup-claude` failing on readonly filesystems (thanks to @emptyflask)
  - Only runs `chmod` when the file is not already executable
  - Resolves issues on NixOS and similar platforms with readonly filesystems
  - Fixes failures when the current user is not the owner of the executable

## [1.2.2] - 2025-07-21

### Added

- **Network Access Support**: New `--bind-all` flag for HTTP mode to allow access from local network
  - Binds to `0.0.0.0` instead of `localhost` when enabled
  - Allows connections from local network IP ranges (192.168.x.x, 10.x.x.x)
  - Accepts connections from `.local` domain names (e.g., `my-computer.local`)
  - Maintains security features with origin validation and IP filtering

### Improved

- **Security Configuration**: Enhanced allowed origins and IP configuration when using `--bind-all`
  - Automatically configures appropriate security settings for local network access
  - Preserves localhost-only mode by default for security
  - Clear documentation of security implications

### Changed

- HTTP server binding address is now configurable via `--bind-all` flag
- Updated help text to include new network access option

## [1.2.1] - 2025-06-09

### Fixed

- Fix a debug message generating invalid STDIO output.
- Fix tool name spelling.

## [1.2.0] - 2025-06-03

### Added

- **Comprehensive Resources and Documentation System**: Complete access to Rails ecosystem documentation
  - `load_guide` tool for accessing official framework documentation
  - Support for Rails, Turbo, Stimulus, and Kamal documentation
  - Custom markdown file import capabilities
  - Automatic resource downloading via `rails-mcp-server-download-resources` command
  - Resource storage in XDG-compliant directories with manifest tracking
- **Five Resource Categories**:
  - **Rails Guides**: Official Ruby on Rails 8.0.2 documentation (50+ guides)
  - **Turbo Guides**: Complete Hotwire Turbo framework documentation
  - **Stimulus Guides**: Full Stimulus JavaScript framework documentation  
  - **Kamal Guides**: Comprehensive Kamal deployment tool documentation
  - **Custom Guides**: Import and manage your own markdown documentation
- **Direct Resource Access**: MCP clients can query resources using URI templates
  - `rails://guides/{guide_name}` for Rails documentation
  - `turbo://guides/{guide_name}` for Turbo guides
  - `stimulus://guides/{guide_name}` for Stimulus documentation
  - `kamal://guides/{guide_name}` for Kamal guides
  - `custom://guides/{guide_name}` for custom imports
- **Advanced Resource Management**:
  - Force download options (`--force`) for updating resources
  - Verbose logging (`--verbose`) for troubleshooting
  - Batch import support for directory structures
  - Filename normalization for custom imports
  - Version tracking and update management

### Improved

- **Enhanced Documentation**: All tools now include comprehensive natural language examples
- **Resource Integration**: Seamless integration with existing MCP tool ecosystem
- **File Organization**: Better project structure with XDG Base Directory compliance
- **Error Handling**: Improved validation and error messages across resource operations

### Technical

- URI templating support for direct resource access
- Enhanced manifest management for resource tracking
- Integration with FastMCP for robust resource handling
- Simplified guides configuration and management

## [1.1.4] - 2025-05-02

### Fixed

- **HTTP Mode Issues**: Resolved Puma server startup failures in HTTP mode
- **Rails Command Execution**: Fixed issues with executing Rails commands in certain environments
- **Logger Configuration**: Fixed logger initialization when no config file exists (thanks to @justwiebe)

### Changed

- Improved dependency version constraints for better compatibility
- Enhanced error handling for HTTP server operations

## [1.1.0] - 2025-04-20

### Added

- **HTTP Server-Sent Events (SSE) Support**: Real-time communication capabilities
  - HTTP mode with JSON-RPC and SSE endpoints (`--mode http`)
  - Custom port configuration with `-p/--port` option
  - SSE endpoint at `/mcp/sse` for real-time updates
  - JSON-RPC endpoint at `/mcp/messages`
- **New Analysis Tools**:
  - `analyze_controller_views`: Analyze relationships between controllers, actions, and views
  - `analyze_environment_config`: Compare environment configurations for inconsistencies and security issues
- **Enhanced Integration**:
  - MCP Inspector compatibility for testing and debugging
  - Improved client compatibility through HTTP endpoints
  - Better support for multiple LLM clients

### Improved

- **Code Organization**: Major refactoring using FastMCP gem
  - Transition from mcp-rb to fast-mcp for better protocol support
  - Enhanced modular architecture for better maintainability
  - Improved error handling and validation across all tools
- **File System Respect**: All tools now respect `.gitignore` files when scanning codebases
- **Tool Enhancements**: Comprehensive review and improvement of all existing tools
  - Better edge case handling for large projects
  - Performance improvements for file operations
  - Enhanced logging and debugging capabilities

### Technical

- **FastMCP Integration**: Complete migration to FastMCP gem for robust MCP protocol implementation
- **Rack-based Architecture**: HTTP server implementation using Rack
- **Event-driven Communication**: Real-time event handling for SSE support
- **Improved Connection Management**: Better handling of client connections and message processing

### Changed

- **Internal Architecture**: Complete refactoring to use FastMCP instead of mcp-rb
- **Command-line Interface**: Enhanced CLI with mode selection and configuration options
- **Documentation**: Updated with detailed tool descriptions and usage examples

## [1.0.0] - 2025-03-20

### Added

- **Initial Release**: Rails MCP Server for AI-assisted Rails development
- **Core Tools** (8 tools):
  - `switch_project`: Change active Rails project for multi-project support
  - `project_info`: Get comprehensive Rails project information and structure
  - `list_files`: Browse project files with glob pattern matching
  - `get_file`: Retrieve file contents with syntax highlighting
  - `get_routes`: Display all Rails routes (equivalent to `rails routes`)
  - `analyze_models`: Analyze Active Record models, associations, and relationships
  - `get_schema`: Retrieve database schema information and table structures
  - Basic file and project analysis capabilities
- **Project Management System**:
  - Multi-project support through `projects.yml` configuration
  - XDG Base Directory Specification compliance for configuration
  - Automatic project detection and setup
  - Cross-platform compatibility (macOS, Windows)
- **Claude Desktop Integration**:
  - STDIO mode communication for direct integration
  - Automatic setup script (`rails-mcp-setup-claude`)
  - Ruby version manager compatibility documentation
  - JSON-RPC 2.0 protocol implementation
- **Developer Experience**:
  - Comprehensive logging system with configurable levels
  - Debug mode and verbose output options
  - Robust error handling and validation
  - Clear documentation and setup guides

### Features

- **Rails-Specific Intelligence**: Deep understanding of Rails application architecture
  - Model relationships and Active Record associations analysis
  - Controller and route mapping
  - Database schema exploration and relationship discovery
  - Rails convention-based file discovery
- **Smart File System Integration**:
  - Intelligent file discovery with glob pattern support
  - Automatic respect for Rails conventions and `.gitignore`
  - Syntax highlighting for various file types
  - Efficient handling of large codebases
- **Configuration Management**:
  - Platform-specific configuration directories
  - Project-based organization and switching
  - Automatic initialization and setup
  - Secure and isolated project environments

### Technical Foundation

- **Model Context Protocol (MCP)**: Full MCP specification implementation
- **Communication**: JSON-RPC 2.0 protocol over STDIO
- **Architecture**: Modular, extensible design for future enhancements
- **Distribution**: Ruby gem packaging for easy installation and updates
- **Compatibility**: Cross-platform support with platform-specific optimizations

---

## Version History Summary

- **v1.4.0** (2025-12-10): Context-efficient architecture with progressive tool discovery (67% token reduction)
- **v1.2.3** (2025-12-10): Setup script fix for readonly filesystems (NixOS compatibility)
- **v1.2.2** (2025-07-21): Network access support with --bind-all flag
- **v1.2.1** (2025-06-09): Bug fixes for STDIO output and tool naming
- **v1.2.0** (2025-06-03): Major documentation and resource system addition
- **v1.1.4** (2025-05-02): Critical bug fixes for HTTP mode and Rails commands
- **v1.1.0** (2025-04-20): HTTP SSE support and new analysis tools with FastMCP migration
- **v1.0.0** (2025-03-20): Initial release with core Rails MCP functionality

## Development Guidelines

### Version Numbering

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions  
- **PATCH** version for backwards-compatible bug fixes

### Release Process

1. Update version in `lib/rails-mcp-server/version.rb`
2. Update this CHANGELOG.md with new features and changes
3. Update README.md and documentation if needed
4. Create a git tag: `git tag -a v1.2.3 -m "Release version 1.2.3"`
5. Push tags: `git push origin --tags`
6. Build and publish gem: `gem build rails-mcp-server.gemspec && gem push rails-mcp-server-1.2.3.gem`

### Changelog Categories

- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes
- **Technical** for internal/technical improvements
- **Improved** for enhancements to existing features

---

## Links

- [Repository](https://github.com/maquina-app/rails-mcp-server)
- [Releases](https://github.com/maquina-app/rails-mcp-server/releases)
- [Issues](https://github.com/maquina-app/rails-mcp-server/issues)
- [Documentation](https://github.com/maquina-app/rails-mcp-server#readme)
- [Resources Guide](docs/RESOURCES.md)
