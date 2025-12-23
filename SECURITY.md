# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.4.x   | :white_check_mark: |
| < 1.4   | :x:                |

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

- **Sandboxed execution**: `execute_ruby` tool runs code in a restricted environment with file/network/system call protections
- **Path validation**: file operations are constrained to the configured Rails project directory
- **Project isolation**: each configured project has its own scope
- **Dependency security**: automated updates via Dependabot, bundler-audit in CI
- **Static analysis**: CodeQL scans on every PR and weekly
- **Code review**: all changes require review before merging

## Acknowledgments

We thank the following researchers for responsibly disclosing vulnerabilities:

*No vulnerabilities reported yet.*
