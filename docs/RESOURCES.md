# Rails MCP Server - Resources Guide

This guide explains how the Rails MCP Server handles documentation resources, how to download predefined guides, and how to load custom documentation files. Resources in the Rails MCP Server provide access to comprehensive documentation for Rails and related frameworks through both the `load_guide` tool and direct MCP resource access.

## Table of Contents

- [What are Resources?](#what-are-resources)
- [Available Resource Categories](#available-resource-categories)
- [Downloading Predefined Resources](#downloading-predefined-resources)
- [Loading Custom Files](#loading-custom-files)
- [Using the load_guide Tool](#using-the-load_guide-tool)
- [Direct Resource Access](#direct-resource-access)
- [Troubleshooting](#troubleshooting)

## What are Resources?

Resources in the Rails MCP Server are documentation guides that can be accessed through two main methods:

1. **Tool-based access**: Using the `load_guide` tool to retrieve specific guides
2. **Direct resource access**: MCP clients can directly query resources using URI templates

Resources are stored locally in your configuration directory and can be:
- **Predefined resources**: Official documentation from Rails, Turbo, Stimulus, and Kamal
- **Custom resources**: Your own markdown files imported into the system

## Available Resource Categories

The Rails MCP Server supports five categories of resources:

### 1. Rails Guides
- **Framework**: Ruby on Rails
- **Content**: Official Rails 8.0.2 documentation

### 2. Turbo Guides  
- **Framework**: Turbo (Hotwire)
- **Content**: Official Turbo framework documentation

### 3. Stimulus Guides
- **Framework**: Stimulus (Hotwire)
- **Content**: Official Stimulus JavaScript framework documentation

### 4. Kamal Guides
- **Framework**: Kamal Deploy
- **Content**: Official Kamal deployment tool documentation

### 5. Custom Guides
- **Framework**: Custom/Local
- **Content**: Your imported markdown files

## Downloading Predefined Resources

Before you can use predefined resources, you need to download them using the resource downloader tool.

### Basic Download Command

```bash
# Download Rails guides
rails-mcp-server-download-resources rails

# Download Turbo guides  
rails-mcp-server-download-resources turbo

# Download Stimulus guides
rails-mcp-server-download-resources stimulus

# Download Kamal guides
rails-mcp-server-download-resources kamal
```

### Download Options

```bash
# Force download even if files haven't changed
rails-mcp-server-download-resources --force rails

# Verbose output to see download progress
rails-mcp-server-download-resources --verbose turbo

# Combine options
rails-mcp-server-download-resources --verbose --force stimulus
```

### Download Process

When you run the download command:

1. **Creates directories**: Sets up the resource folder structure in your config directory
2. **Downloads guides**: Fetches the latest documentation from official repositories
3. **Creates manifest**: Generates a manifest.yaml file tracking all downloaded files
4. **Tracks changes**: Monitors file modifications to avoid unnecessary re-downloads

### Resource Storage Location

Downloaded resources are stored in:
- **macOS**: `~/.config/rails-mcp/resources/`
- **Windows**: `%APPDATA%\rails-mcp\resources\`

Directory structure:
```
~/.config/rails-mcp/resources/
├── rails/
│   ├── manifest.yaml
│   ├── getting_started.md
│   ├── active_record_basics.md
│   └── ...
├── turbo/
│   ├── manifest.yaml
│   ├── handbook/
│   │   ├── 01_introduction.md
│   │   └── ...
│   └── reference/
│       ├── streams.md
│       └── ...
├── stimulus/
├── kamal/
└── custom/
```

## Loading Custom Files

You can import your own markdown files into the Custom guides category using the `--file` option.

### Import Single File

```bash
# Import a single markdown file
rails-mcp-server-download-resources --file /path/to/guide.md

# Force import even if file hasn't changed
rails-mcp-server-download-resources --force --file /path/to/api-docs.md
```

### Import Directory

```bash
# Import all markdown files from a directory
rails-mcp-server-download-resources --file /path/to/docs/

# Verbose import with progress information
rails-mcp-server-download-resources --verbose --file /path/to/project-docs/
```

### Import Process

When importing custom files:

1. **File validation**: Checks that source files exist and are readable
2. **Filename normalization**: Converts filenames to lowercase with underscores
3. **Duplication handling**: Skips unchanged files unless `--force` is used
4. **Manifest updates**: Tracks imported files in the custom manifest

### Filename Normalization

Custom files are normalized for consistency:
- `API Documentation.md` → `api_documentation.md`
- `Setup-Guide.md` → `setup_guide.md`
- `user_manual.md` → `user_manual.md` (already normalized)

## Using the load_guide Tool

The `load_guide` tool is the primary way to access resources programmatically within MCP conversations.

### Basic Syntax

```
execute_tool("load_guide", { library: "category", guide: "guide_name" })
```

### Loading Specific Guides

#### Rails Guides
```
Can you load the Rails getting started guide?

I need to see the Active Record basics documentation.

Show me the Rails routing guide.
```

#### Turbo Guides
```
Can you load the Turbo introduction guide?

I'd like to see the Turbo Frames documentation.

Show me the Turbo streams reference.
```

#### Stimulus Guides  
```
Load the Hello Stimulus tutorial for me.

I need help with Stimulus controllers - can you show me that guide?

Can you display the Stimulus targets reference?
```

#### Kamal Guides
```
Show me the Kamal installation guide.

I need to understand Kamal deployment - can you load that documentation?

Can you get the Kamal configuration overview?
```

#### Custom Guides
```
Load my API documentation guide.

Can you show me the setup guide I imported?

I need to see my custom user manual.
```

### Listing Available Guides

```
What Rails guides are available?

Show me all the Turbo documentation.

List the available custom guides I've imported.
```

### Tool Output Format

The `load_guide` tool returns formatted content with:

```markdown
# Guide Title

**Source:** Framework Name
**Guide:** guide_name
**File:** path/to/file.md (for sectioned guides)

---

[Guide content here...]
```

## Direct Resource Access

MCP clients that support resources can access documentation directly without using the `load_guide` tool.

### Resource URIs

Each resource category has specific URI patterns:

#### List Resources (Available Guides)
- `rails://guides` - List all Rails guides
- `turbo://guides` - List all Turbo guides  
- `stimulus://guides` - List all Stimulus guides
- `kamal://guides` - List all Kamal guides
- `custom://guides` - List all custom guides

#### Specific Guide Resources
- `rails://guides/{guide_name}` - Access specific Rails guide
- `turbo://guides/{guide_name}` - Access specific Turbo guide
- `stimulus://guides/{guide_name}` - Access specific Stimulus guide
- `kamal://guides/{guide_name}` - Access specific Kamal guide
- `custom://guides/{guide_name}` - Access specific custom guide

### Resource Metadata

Each resource includes metadata:
- `resource_name`: Human-readable name
- `description`: Resource description
- `mime_type`: Content type (text/markdown)
- `uri`: URI template pattern

## Troubleshooting

### Common Issues

#### Resource Not Found
```
Error: Unknown resource: rails
```
**Solution**: Check available resources with `--help` flag

#### Download Failures
```
failed (HTTP 404)
```
**Solution**: Resource may have moved; try updating or check internet connection

#### Permission Errors
```
Error: Source not readable: /path/to/file
```
**Solution**: Check file permissions and path existence

#### Guide Not Found
```
Guide 'invalid_guide' not found in Rails guides.
```
**Solution**: Use `execute_tool("load_guide", { library: "rails" })` to see available guides

### Verbose Troubleshooting

Use verbose mode for detailed information:

```bash
# Verbose download
rails-mcp-server-download-resources --verbose rails

# Verbose import
rails-mcp-server-download-resources --verbose --file /path/to/docs/
```

### Manual Resource Management

If needed, you can manually manage resources:

```bash
# Remove all downloaded resources
rm -rf ~/.config/rails-mcp/resources/

# Re-download everything  
rails-mcp-server-download-resources rails
rails-mcp-server-download-resources turbo
rails-mcp-server-download-resources stimulus
rails-mcp-server-download-resources kamal
```

## Best Practices

### Resource Organization
1. **Download first**: Always download resources before using the `load_guide` tool
2. **Update regularly**: Keep resources current by re-downloading periodically
3. **Organize custom guides**: Use descriptive filenames for custom imports

### Performance Tips
1. **Selective downloads**: Only download resources you need
2. **Avoid force**: Don't use `--force` unless necessary
3. **Batch imports**: Import multiple custom files at once using directory paths

This comprehensive resource system makes the Rails MCP Server a powerful documentation companion for Rails development, providing instant access to official guides and your custom documentation through both tool-based and direct resource access methods.
