FROM ruby:3.2-slim

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy gemspec and gemfile
COPY Gemfile Gemfile.lock rails-mcp-server.gemspec ./
COPY lib/rails-mcp-server/version.rb ./lib/rails-mcp-server/

# Install gems
RUN bundle install

# Copy the rest of the application
COPY . .

# Create config directory structure
RUN mkdir -p /root/.config/rails-mcp/resources

# Copy default projects.yml if you want to include one
# COPY config/projects.yml /root/.config/rails-mcp/

# Expose the default HTTP port
EXPOSE 6029

# Default to HTTP mode for container deployment
CMD ["bundle", "exec", "rails-mcp-server", "--mode", "http", "--log-level", "info"]