# Docker Deployment Guide for Rails MCP Server

This guide explains how to deploy the Rails MCP Server using Docker for HTTP access.

## Quick Start

### 1. Create Configuration

First, create a local config directory and projects.yml file:

```bash
mkdir -p config/rails-mcp
```

Create `config/rails-mcp/projects.yml`:

```yaml
# Example projects configuration
myapp: "/projects/myapp"
blog: "/projects/blog"
api: "/projects/api"
```

### 2. Build and Run with Docker Compose

```bash
# Build and start the server
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the server
docker-compose down
```

The server will be available at `http://localhost:6029`

## Configuration

### Environment Variables

- `LOG_LEVEL`: Set logging level (debug, info, error)
- Port mapping: Change `"6029:6029"` in docker-compose.yml to use a different port

### Volume Mounts

The docker-compose.yml includes two volume mounts:

1. **Config directory**: `./config/rails-mcp:/root/.config/rails-mcp`
   - Store your projects.yml here
   - Downloaded resources will be stored here

2. **Rails projects**: `~/projects:/projects:ro`
   - Mount your Rails projects directory
   - Adjust the host path to match your setup
   - Read-only mount for security

### Custom Configuration

To customize the deployment:

1. **Different port**:
   ```yaml
   ports:
     - "8080:6029"
   ```

2. **Multiple project directories**:
   ```yaml
   volumes:
     - ./config/rails-mcp:/root/.config/rails-mcp
     - ~/work/projects:/work/projects:ro
     - ~/personal/projects:/personal/projects:ro
   ```

3. **Custom command options**:
   ```yaml
   command: bundle exec rails-mcp-server --mode http -p 6029 --log-level debug
   ```

## Production Deployment

### Using Pre-built Image

For production, you may want to build and push the image to a registry:

```bash
# Build image
docker build -t your-registry/rails-mcp-server:latest .

# Push to registry
docker push your-registry/rails-mcp-server:latest
```

Update docker-compose.yml:

```yaml
services:
  rails-mcp-server:
    image: your-registry/rails-mcp-server:latest
    # ... rest of configuration
```

### Security Considerations

1. **Read-only mounts**: Always mount project directories as read-only
2. **Network isolation**: Consider using Docker networks to isolate the service
3. **HTTPS**: Use a reverse proxy (nginx, traefik) for SSL termination

### Reverse Proxy Example (nginx)

```nginx
server {
    listen 443 ssl;
    server_name mcp.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:6029;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## API Endpoints

Once running in HTTP mode, the server provides:

- JSON-RPC endpoint: `http://localhost:6029/mcp/messages`
- SSE endpoint: `http://localhost:6029/mcp/sse`

## Testing the Deployment

Test the server is running:

```bash
# Check if server is responding
curl -X POST http://localhost:6029/mcp/messages \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
```

## Troubleshooting

### Container won't start

Check logs:
```bash
docker-compose logs rails-mcp-server
```

### Permission issues

Ensure the mounted directories are readable:
```bash
chmod -R o+r ~/projects
```

### Can't connect to server

1. Check container is running: `docker ps`
2. Check port binding: `docker port rails-mcp-server`
3. Check firewall rules

### Resources not found

Download resources inside the container:
```bash
docker-compose exec rails-mcp-server bundle exec rails-mcp-server-download-resources rails
```

## Advanced Usage

### Running commands in the container

```bash
# Enter the container
docker-compose exec rails-mcp-server bash

# Download resources
docker-compose exec rails-mcp-server bundle exec rails-mcp-server-download-resources rails

# Run in STDIO mode for testing
docker-compose exec rails-mcp-server bundle exec rails-mcp-server
```

### Custom Dockerfile for specific Ruby version

If you need a specific Ruby version, modify the Dockerfile:

```dockerfile
FROM ruby:3.3-slim
# ... rest of Dockerfile
```

### Multi-stage build for smaller image

For production, consider a multi-stage build:

```dockerfile
# Build stage
FROM ruby:3.2-slim as builder
# ... build steps

# Runtime stage
FROM ruby:3.2-slim
COPY --from=builder /app /app
# ... runtime configuration
```