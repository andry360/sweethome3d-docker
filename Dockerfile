# Sweet Home 3D 7.7-Online - Multi-stage Docker Build
# Downloads sources from SourceForge and builds automatically
# Use BuildKit for better caching: DOCKER_BUILDKIT=1 docker build .

# syntax=docker/dockerfile:1

# Stage 1: Build Environment (Compile Java to JavaScript with JSweet)
FROM eclipse-temurin:11-jdk as builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ant \
    wget \
    unzip \
    subversion \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Download Sweet Home 3D 7.7-Online source from SourceForge using SVN
# This is the most reliable method to get the exact source code
# Cache buster can be used with: --build-arg CACHE_BUSTER=$(date +%s)
RUN echo "Downloading Sweet Home 3D 7.7-Online sources from SourceForge..." && \
    svn export --non-interactive --trust-server-cert-failures=unknown-ca \
    https://svn.code.sf.net/p/sweethome3d/code/branches/develop-SweetHome3D-7.7-Online/SweetHome3DJS /src && \
    cp -r /src/. /build/ && rm -rf /src

# Build the application
RUN echo "Building Sweet Home 3D 7.7-Online (this may take 10-20 minutes)..." && \
    cd /build && \
    ant applicationDistribution 2>&1 | tee /tmp/build.log

# Prepare deployment files
RUN mkdir -p /deploy && \
    cp -r deployDirectHomeRecorder/* /deploy/ && \
    cp -r dist/* /deploy/ && \
    cp -r lib/*.min.js /deploy/lib/ 2>/dev/null || true && \
    cp -r lib/*.css /deploy/lib/ 2>/dev/null || true

# Stage 2: Runtime Environment (PHP + Apache)
FROM php:8.2-apache

LABEL maintainer="andrea.castellano"
LABEL description="Sweet Home 3D 7.7-Online - Self-hosted 3D home design application"
LABEL version="7.7"

# Install PHP extensions and utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    libzip-dev \
    zip \
    unzip \
    curl \
    apache2-utils \
    && docker-php-ext-install zip \
    && rm -rf /var/lib/apt/lists/* /tmp/*

# Configure PHP upload limits
RUN echo "upload_max_filesize = 50M" > /usr/local/etc/php/conf.d/uploads.ini && \
    echo "post_max_size = 50M" >> /usr/local/etc/php/conf.d/uploads.ini && \
    echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/uploads.ini && \
    echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/uploads.ini

# Enable Apache modules
RUN a2enmod rewrite headers

# Copy application files from builder stage
COPY --from=builder /deploy /var/www/html/

# Create storage directory for saved homes
RUN mkdir -p /var/www/html/homes && \
    chown -R www-data:www-data /var/www/html/homes && \
    chmod 755 /var/www/html/homes

# Set proper permissions
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

# Create .htaccess for authentication (if needed)
COPY docker/htaccess.conf /var/www/html/.htaccess
COPY docker/apache-config.conf /etc/apache2/sites-available/000-default.conf

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null | grep -qE "^(200|401)$" || exit 1

# Use custom entrypoint for dynamic configuration
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
