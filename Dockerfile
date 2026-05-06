# Sweet Home 3D 7.7-Online - Multi-stage Docker Build
# Stage 1: Build Environment (Compile Java to JavaScript with JSweet)
FROM eclipse-temurin:11-jdk as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    ant \
    git \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy source files
COPY SweetHome3D-7.7-Online/sweethome3d-code-r9047-branches-develop-SweetHome3D-7.7-Online-SweetHome3DJS /build/

# Build the application
RUN ant applicationDistribution

# Prepare deployment files
RUN mkdir -p /deploy && \
    cp -r deployDirectHomeRecorder/* /deploy/ && \
    cp -r dist/* /deploy/ && \
    cp -r lib/*.min.js /deploy/lib/ && \
    cp -r lib/*.css /deploy/lib/

# Stage 2: Runtime Environment (PHP + Apache)
FROM php:8.2-apache

# Install PHP extensions and utilities
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    && docker-php-ext-install zip \
    && rm -rf /var/lib/apt/lists/*

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

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start Apache
CMD ["apache2-foreground"]
