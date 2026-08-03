# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.5.x   | :white_check_mark: |
| < 1.5   | :x:                |

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
- **Code execution bypass**: escaping the sandboxed Ruby execution environment
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

- **Sandboxed execution**: `execute_ruby` runs code in a restricted environment with file/network/system-call protections, applied by both static analysis (a forbidden-pattern scan) and runtime overrides of `File`/`IO`/`Dir`/`FileUtils`/`Kernel`
- **Path validation**: file operations are constrained to the configured Rails project directory. The `execute_ruby` sandbox resolves symlinks (`realpath`) before validating, so a link inside the project cannot point outside it, and covers every `File`/`IO` read entry point (`read`, `readlines`, `binread`, `foreach`, `open`). It additionally allows read-only access to a small allowlist of system timezone paths (e.g. `/usr/share/zoneinfo`), matched against their canonical (symlink-resolved) locations
- **Sensitive-file protection**: `.env`, credentials, keys, and any `.gitignore`d path are refused; environment-variable access (`ENV`) is blocked by the static scan
- **Read-only database access**: `execute_ruby` runs user code inside a transaction that is always rolled back, so accidental writes (`delete_all`, `update`, `save`, raw DML) are undone. This is harm reduction, not a guarantee — DDL may auto-commit on some adapters (e.g. MySQL) and `after_commit` callbacks are suppressed
- **Resource bounds**: `execute_ruby` enforces a timeout (default 30s, max 60s) by killing the entire process group, preventing an orphaned runaway `bin/rails runner`
- **Confirmation for dual-use constructs**: `send`, `public_send`, `const_get`, and `Kernel#open` are not executed until the caller opts in via `confirm_risky: true`, so a human can review them first
- **Project isolation**: each configured project has its own scope
- **Dependency security**: automated updates via Dependabot, bundler-audit in CI
- **Static analysis**: CodeQL scans on every PR and weekly
- **Code review**: all changes require review before merging

### Known limitations

The `execute_ruby` controls are defense-in-depth, not a hard isolation boundary. The tool executes real Ruby with full access to the Rails application, so metaprogramming can, in principle, still reach otherwise-blocked APIs, DDL and non-default-connection writes can escape the transaction rollback, and there are no per-process CPU/memory caps beyond the timeout. Only enable `execute_ruby` for projects and clients you trust. For stronger guarantees, run the server against a database user with read-only grants and/or inside an OS-level sandbox (container, `sandbox-exec`, seccomp, etc.).

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

*No vulnerabilities reported yet.*
