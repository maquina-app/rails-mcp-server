# Governed MCP Clients

Rails MCP Server exposes Rails project tools and documentation resources through the Model Context Protocol. Some teams connect those MCP tools to a governed AI client or control plane so tool access, audit trails, approvals, and cost controls can be managed centrally.

This guide describes the integration pattern. Rails MCP Server continues to own the Rails project tools and resources. The governed client or gateway owns model access, policy decisions, and cross-application reporting.

## Pattern

1. Start Rails MCP Server in STDIO or HTTP mode.
2. Register the server with an MCP-compatible client or control plane.
3. Let the client decide which users, roles, or agents can call Rails MCP tools.
4. Keep Rails project paths and credentials local to the Rails MCP Server environment.

## Example: Tuning Engines

Tuning Engines can be used as a governed AI control plane in front of model, agent, and MCP workflows. In this setup:

- Rails MCP Server provides tools such as `switch_project`, `search_tools`, `execute_tool`, and `load_guide`.
- The MCP client or control plane registers the Rails MCP Server and discovers its tools.
- Tuning Engines can enforce tenant, role, or policy-based access to MCP tools and record traces/costs for model and tool activity.

For local development, start Rails MCP Server normally:

```bash
rails-mcp-server
```

For HTTP/SSE testing or a local proxy:

```bash
rails-mcp-server --mode http
```

Then configure your MCP-compatible client or control plane to connect to the STDIO command or HTTP/SSE endpoint.

## Security notes

- Do not expose Rails MCP Server on an untrusted network.
- Prefer STDIO or localhost HTTP mode unless you have a trusted network and explicit access controls.
- Keep Rails project paths, credentials, and `.env` files local to the server.
- Use the governed client to restrict high-risk tools such as code execution or broad project scans.
- Preserve request IDs or trace IDs in client metadata when available so tool calls can be correlated with model calls.

This pattern is useful when Rails MCP Server is part of a larger production AI workflow and the organization needs compliance, control, and cost reporting outside individual MCP clients.
