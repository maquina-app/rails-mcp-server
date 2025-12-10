# Custom Commands for Rails MCP Server

## /test

Run the full test suite:

```bash
bundle exec rake test
```

## /test:file $FILE

Run a specific test file:

```bash
bundle exec ruby -Itest $FILE
```

Example: `/test:file test/analyzers/analyze_models_test.rb`

## /lint

Check code style with StandardRB:

```bash
bundle exec standardrb
```

## /lint:fix

Auto-fix code style issues:

```bash
bundle exec standardrb --fix
```

## /build

Build the gem:

```bash
gem build rails-mcp-server.gemspec
```

## /install

Install the gem locally:

```bash
gem install --local pkg/rails-mcp-server-*.gem
```

## /server

Start the MCP server in STDIO mode:

```bash
bundle exec exe/rails-mcp-server
```

## /server:http

Start the MCP server in HTTP mode:

```bash
bundle exec exe/rails-mcp-server --mode http -p 6029
```

## /inspect

Test with MCP Inspector:

```bash
npx @modelcontextprotocol/inspector exe/rails-mcp-server
```

## /config

Run the interactive configuration tool:

```bash
bundle exec exe/rails-mcp-config
```

## /release $VERSION

Prepare a release (update version, changelog, build):

```bash
# 1. Update version
echo "Updating version to $VERSION"
# Edit lib/rails-mcp-server/version.rb

# 2. Update CHANGELOG.md

# 3. Build gem
gem build rails-mcp-server.gemspec

# 4. Test install
gem install --local pkg/rails-mcp-server-$VERSION.gem
```

