# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
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
- **Code execution bypass**: defeating the `execute_ruby` guardrails to reach blocked APIs (shell, process spawning, network, out-of-project file access)
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

- **Restricted execution guardrails**: `execute_ruby` runs caller-supplied Ruby with file/network/system-call restrictions applied by both static analysis (a forbidden-pattern scan) and runtime overrides of `File`/`IO`/`Dir`/`FileUtils`/`Kernel`. These are guardrails against accidental damage and obvious escapes, not an isolation boundary (see [Known limitations](#known-limitations))
- **No process execution or arbitrary `require`**: shell/system calls (`system`, `exec`, backticks, `spawn`), process/pseudo-terminal and native bridges (`Open3`, `IO.popen`, `Process.spawn`, `PTY`, `Fiddle`, `FFI`, sockets), and dynamic dispatch aimed by name at an execution/eval sink (`send`/`const_get` → `system`/`spawn`/`Open3`/…) are rejected. `require` is limited to a small allowlist of standard-library data helpers and `require_relative` is refused, so those libraries cannot be pulled in to defeat the scan
- **Path validation**: file operations are constrained to the configured Rails project directory. The `execute_ruby` guardrails resolve symlinks (`realpath`) before validating, so a link inside the project cannot point outside it, and cover every `File`/`IO` read entry point (`read`, `readlines`, `binread`, `foreach`, `open`). Read-only access to a small allowlist of system timezone paths (e.g. `/usr/share/zoneinfo`) is additionally permitted, matched against their canonical (symlink-resolved) locations
- **Sensitive-file protection**: `.env`, credentials, keys, and any `.gitignore`d path are refused; environment-variable access (`ENV`) is blocked by the static scan
- **Database-write rollback**: `execute_ruby` runs user code inside a transaction that is always rolled back, so accidental writes (`delete_all`, `update`, `save`, raw DML) are undone. This is harm reduction, not a guarantee — DDL may auto-commit on some adapters (e.g. MySQL) and `after_commit` callbacks are suppressed
- **Resource bounds**: `execute_ruby` enforces a timeout (default 30s, max 60s) by killing the entire process group, preventing an orphaned runaway `bin/rails runner`
- **Confirmation for dual-use constructs**: the remaining dual-use forms of `send`, `public_send`, `const_get`, and `Kernel#open` are not executed until the caller opts in via `confirm_risky: true`, so a human can review them first
- **Project isolation**: each configured project has its own scope
- **Dependency security**: automated updates via Dependabot, bundler-audit in CI
- **Static analysis**: CodeQL scans on every PR and weekly
- **Code review**: all changes require review before merging

### Known limitations

The `execute_ruby` controls are defense-in-depth, not a hard isolation boundary. The tool executes real Ruby with full access to the Rails application and runs with the privileges of the process that started the server, so metaprogramming can, in principle, still reach otherwise-blocked APIs, DDL and non-default-connection writes can escape the transaction rollback, and there are no per-process CPU/memory caps beyond the timeout.

**Threat model.** This server is started by the operator, usually locally, against their own Rails project, and the Ruby it executes comes from that operator or from a coding agent acting on their behalf — not from an anonymous remote party. The practical risk is therefore *unintended* execution: a coding agent induced by prompt injection (a hostile issue, README, or dependency file it reads) into calling `execute_ruby` with a malicious payload, which then runs with the operator's privileges. The guardrails above raise the bar against that, but do not eliminate it. Only enable `execute_ruby` for projects and clients you trust, and review code before approving a `confirm_risky` run. For stronger guarantees, run the server against a database user with read-only grants and/or inside OS-level isolation (a container, `sandbox-exec`, seccomp, or a dedicated low-privilege user with no ambient credentials or network).

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

*No vulnerabilities reported yet.*
