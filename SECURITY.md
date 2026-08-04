# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.0.x   | :white_check_mark: |
| 1.6.x   | :white_check_mark: |
| < 1.6   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, report them via GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/maquina-app/rails-mcp-server/security)
2. Click "Report a vulnerability"
3. Provide a detailed description

### What to include

- Type of vulnerability (path traversal, command injection, code execution, etc.)
- Step-by-step reproduction instructions
- Affected versions
- Potential impact
- Suggested fix (if any)

### Response timeline

- **Initial response**: within 72 hours
- **Status update**: within 7 days
- **Fix timeline**: depends on severity, typically 30 days for critical issues

## Security Scope

### In scope

Given that this MCP server executes code in Rails projects and provides file system access, we consider the following as security vulnerabilities:

- **Path traversal**: accessing files outside the configured Rails project directory
- **Command injection**: executing arbitrary commands via tool parameters
- **Code/command injection via tool parameters**: getting caller-supplied input (model names, table names, file paths, patterns) to execute as code or shell commands through the introspection tools
- **Arbitrary file access**: reading/writing to system files outside project scope
- **Privilege escalation**: gaining access beyond configured permissions
- **Data exfiltration**: unintended data exposure to unauthorized parties
- **Denial of service**: crashes or resource exhaustion via malformed input
- **Supply chain**: compromised dependencies or build process

### Out of scope

- Vulnerabilities in the MCP protocol itself (report to [Anthropic](https://github.com/anthropics/modelcontextprotocol))
- Vulnerabilities in Rails framework (report to [Rails Security](https://rubyonrails.org/security))
- Vulnerabilities in target Rails applications being analyzed
- Issues requiring physical access to the machine
- Social engineering attacks
- Vulnerabilities in dependencies with no realistic exploit path in this context

## Security Measures

This project implements several security controls:

- **No arbitrary code execution**: the server exposes a fixed set of introspection tools (`get_routes`, `get_schema`, `analyze_models`, `get_file`, `list_files`, …); it does not accept or run caller-supplied Ruby. (The free-form `execute_ruby` tool was removed in 2.0.0.)
- **Parameterized introspection scripts**: the tools that boot the app (`get_schema`, `get_routes`, and the introspection half of `analyze_models` / `analyze_controller_views`) run `bin/rails runner` with fixed, server-authored scripts. Caller input is passed as validated parameters — model/table names are checked with `valid_identifier?` / `valid_table_name?` and shell-escaped, never interpolated as code
- **Path validation**: file reads and globs are constrained to the configured Rails project directory via `PathValidator` (`safe_path?`), which resolves paths before checking so traversal (`../`) cannot escape the project root
- **Sensitive-file protection**: `.env`, credentials, keys, and other sensitive patterns are refused by `PathValidator` (`sensitive_path?` / `filter_sensitive_files`), so `get_file` and `list_files` will not read or list them
- **Project isolation**: each configured project has its own scope
- **Dependency security**: automated updates via Dependabot, bundler-audit in CI
- **Static analysis**: CodeQL scans on every PR and weekly
- **Code review**: all changes require review before merging

### Known limitations

The introspection tools that boot the app run `bin/rails runner` in the project directory, which loads the application's environment — its initializers, and any code they run. This is inherent to inspecting a live Rails app: **only point the server at Rails projects you trust.** The scripts themselves are server-authored and do not execute caller-supplied Ruby (see Security Measures), but booting a project you do not trust runs that project's code with your privileges.

The tools are read-oriented, but this is not enforced by an isolation boundary: a project whose initializers or eager-loaded code perform writes will still perform them on boot, and there are no per-process CPU/memory caps. For stronger guarantees, run the server against a database user with read-only grants and/or inside OS-level isolation (a container, `sandbox-exec`, seccomp, or a dedicated low-privilege user).

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

*No vulnerabilities reported yet.*
