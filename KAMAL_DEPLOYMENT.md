# Kamal Deployment Guide for Rails MCP Server

This guide explains how to deploy the Rails MCP Server to production servers using Kamal, the deployment tool from 37signals.

## Prerequisites

1. **Install Kamal**:
   ```bash
   gem install kamal
   ```

2. **Server Requirements**:
   - Ubuntu/Debian server with SSH access
   - Docker installed on the server (Kamal can install it)
   - Public IP address or domain name
   - Open ports: 22 (SSH), 80 (HTTP), 443 (HTTPS), 6029 (MCP)

3. **Docker Registry Account**:
   - Docker Hub account (or GitHub Container Registry)
   - Authentication credentials

## Initial Setup

### 1. Configure Deployment

The repository includes a `config/deploy.yml` file. Update it with your settings:

```yaml
# Update server IP
servers:
  web:
    hosts:
      - YOUR.SERVER.IP.HERE

# Update registry username
image: your-dockerhub-username/rails-mcp-server

# Update domain for SSL
labels:
  traefik.http.routers.rails-mcp.rule: Host(`mcp.yourdomain.com`)

# Update email for Let's Encrypt
traefik:
  args:
    certificatesResolvers.letsencrypt.acme.email: "your-email@example.com"
```

### 2. Set Up Secrets

Copy and configure the secrets file:

```bash
cp .kamal/secrets.example .kamal/secrets
```

Edit `.kamal/secrets`:
```bash
KAMAL_REGISTRY_USERNAME=your-docker-username
KAMAL_REGISTRY_PASSWORD=your-docker-password
```

### 3. Prepare Your Server

Set up your Rails projects on the server:

```bash
# SSH into your server
ssh deploy@your-server-ip

# Create directories
sudo mkdir -p /opt/rails-mcp/config
sudo mkdir -p /home/deploy/rails-projects

# Set permissions
sudo chown -R deploy:deploy /opt/rails-mcp
sudo chown -R deploy:deploy /home/deploy/rails-projects

# Copy your Rails projects to the server
# Example: scp -r ~/my-rails-app deploy@server:/home/deploy/rails-projects/
```

### 4. Create Server Configuration

On your server, create `/opt/rails-mcp/config/projects.yml`:

```yaml
myapp: "/projects/myapp"
blog: "/projects/blog"
api: "/projects/api"
```

## Deployment

### First Deployment

```bash
# Setup Docker and dependencies on the server
kamal setup

# This will:
# - Install Docker on your server (if needed)
# - Set up Traefik for HTTPS
# - Build and push your Docker image
# - Deploy the Rails MCP Server
```

### Subsequent Deployments

```bash
# Deploy new version
kamal deploy

# Deploy without rebuilding the image
kamal redeploy

# Deploy to specific servers
kamal deploy --hosts 192.168.1.100
```

## Managing the Deployment

### Viewing Logs

```bash
# View application logs
kamal app logs

# Follow logs in real-time
kamal app logs -f

# View logs for specific host
kamal app logs --hosts 192.168.1.100

# View Traefik logs
kamal traefik logs
```

### Executing Commands

```bash
# Enter the Rails MCP Server container
kamal app exec -i bash

# Download Rails guides
kamal app exec "bundle exec rails-mcp-server-download-resources rails"

# Run any command
kamal app exec "bundle exec rails-mcp-server --version"
```

### Managing the Application

```bash
# Stop the application
kamal app stop

# Start the application
kamal app start

# Restart the application
kamal app restart

# Remove containers (keeps data)
kamal app remove

# View running containers
kamal app containers
```

### Health Checks

The deployment includes a health check endpoint. You can verify it's working:

```bash
# From your local machine
curl https://mcp.yourdomain.com/health

# Check the service status
kamal app details
```

## Advanced Configuration

### Custom Health Check

Add a health check endpoint to your server by creating a simple Rack middleware:

```ruby
# lib/rails-mcp-server/health_check.rb
module RailsMcpServer
  class HealthCheck
    def initialize(app)
      @app = app
    end

    def call(env)
      if env['PATH_INFO'] == '/health'
        [200, {'Content-Type' => 'text/plain'}, ['OK']]
      else
        @app.call(env)
      end
    end
  end
end
```

### Multiple Environments

Create environment-specific deploy files:

```bash
# config/deploy.production.yml
# config/deploy.staging.yml

# Deploy to specific environment
kamal deploy -c config/deploy.staging.yml
```

### Load Balancing

For multiple servers, update deploy.yml:

```yaml
servers:
  web:
    hosts:
      - 192.168.1.100
      - 192.168.1.101
      - 192.168.1.102
    labels:
      traefik.http.services.rails-mcp.loadbalancer.server.port: 6029
```

### Persistent Storage

The deployment uses volumes for:
- `/opt/rails-mcp/config` - Configuration files
- `/home/deploy/rails-projects` - Rails projects (read-only)

### Environment Variables

Add environment variables in deploy.yml:

```yaml
env:
  clear:
    LOG_LEVEL: info
    PORT: 6029
    CUSTOM_VAR: value
  secret:
    - API_KEY
    - SECRET_TOKEN
```

## Monitoring

### Server Resources

```bash
# Check server disk usage
kamal server exec "df -h"

# Check memory usage
kamal server exec "free -m"

# Check Docker stats
kamal server exec "docker stats --no-stream"
```

### Application Status

```bash
# View container details
kamal app details

# Check recent deploys
kamal audit

# View current version
kamal app version
```

## Troubleshooting

### Deployment Fails

1. **Check build logs**:
   ```bash
   kamal build push
   ```

2. **Verify registry credentials**:
   ```bash
   kamal registry login
   ```

3. **Check server connectivity**:
   ```bash
   kamal server exec "echo 'Connected'"
   ```

### Application Won't Start

1. **Check container logs**:
   ```bash
   kamal app logs --lines 100
   ```

2. **Verify health check**:
   ```bash
   kamal app exec "curl -f http://localhost:6029/health"
   ```

3. **Check port availability**:
   ```bash
   kamal server exec "netstat -tlnp | grep 6029"
   ```

### SSL Certificate Issues

1. **Check Traefik logs**:
   ```bash
   kamal traefik logs
   ```

2. **Verify DNS**:
   ```bash
   dig mcp.yourdomain.com
   ```

3. **Force certificate renewal**:
   ```bash
   kamal traefik remove
   kamal traefik boot
   ```

## Rollback

If something goes wrong:

```bash
# Rollback to previous version
kamal rollback

# Rollback to specific version
kamal rollback --version 20231201120000

# View available versions
kamal app versions
```

## Security Best Practices

1. **Use SSH keys** for server access
2. **Enable firewall** (ufw) with only necessary ports
3. **Keep secrets in** `.kamal/secrets` and never commit
4. **Mount Rails projects** as read-only volumes
5. **Regular updates** of server packages and Docker
6. **Monitor logs** for suspicious activity

## Backup Strategy

1. **Configuration backup**:
   ```bash
   # Backup server config
   scp -r deploy@server:/opt/rails-mcp/config ./backup/
   ```

2. **Resource backup**:
   ```bash
   # Backup downloaded resources
   kamal app exec "tar -czf /tmp/resources.tar.gz /root/.config/rails-mcp/resources"
   kamal app download /tmp/resources.tar.gz ./backup/
   ```

## Integration with CI/CD

Example GitHub Actions workflow:

```yaml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          
      - name: Install Kamal
        run: gem install kamal
        
      - name: Deploy
        env:
          KAMAL_REGISTRY_USERNAME: ${{ secrets.DOCKER_USERNAME }}
          KAMAL_REGISTRY_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
        run: kamal deploy
```

This deployment setup provides a production-ready Rails MCP Server with SSL, health checks, and easy management through Kamal.