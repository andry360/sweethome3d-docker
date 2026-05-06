#!/bin/bash
# Sweet Home 3D Docker Entrypoint Script
# Handles dynamic authentication configuration

set -e

echo "🚀 Starting Sweet Home 3D 7.7-Online..."

# Configure authentication if enabled
if [ "${AUTH_ENABLED}" = "true" ]; then
    echo "🔒 Configuring HTTP Basic Authentication..."
    
    # Create .htpasswd file with credentials
    htpasswd -cb /var/www/.htpasswd "${AUTH_USERNAME:-admin}" "${AUTH_PASSWORD:-changeme}"
    
    # Enable authentication in .htaccess
    cat > /var/www/html/.htaccess << 'EOF'
# Sweet Home 3D .htaccess
# HTTP Basic Authentication

AuthType Basic
AuthName "Sweet Home 3D - Private Access"
AuthUserFile /var/www/.htpasswd
Require valid-user

# Allow access to homes directory only via PHP
<FilesMatch "^(index\.html|.*\.php)$">
    # Allow access
</FilesMatch>

# Deny direct access to .sh3d files from homes directory
<FilesMatch "\.sh3d$">
    Require all denied
</FilesMatch>

# Enable rewrite engine for clean URLs (optional)
RewriteEngine On
EOF
    
    echo "✅ Authentication enabled for user: ${AUTH_USERNAME:-admin}"
else
    echo "ℹ️  Authentication disabled - using default .htaccess"
fi

# Update PHP configuration from environment variables
if [ -n "${UPLOAD_MAX_FILESIZE}" ]; then
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = ${UPLOAD_MAX_FILESIZE}/" /usr/local/etc/php/conf.d/uploads.ini
fi

if [ -n "${POST_MAX_SIZE}" ]; then
    sed -i "s/post_max_size = .*/post_max_size = ${POST_MAX_SIZE}/" /usr/local/etc/php/conf.d/uploads.ini
fi

if [ -n "${MEMORY_LIMIT}" ]; then
    sed -i "s/memory_limit = .*/memory_limit = ${MEMORY_LIMIT}/" /usr/local/etc/php/conf.d/uploads.ini
fi

# Ensure proper permissions
chown -R www-data:www-data /var/www/html/homes
chmod 755 /var/www/html/homes

echo "✅ Sweet Home 3D is ready!"
echo "   Access at: http://localhost:80"
if [ "${AUTH_ENABLED}" = "true" ]; then
    echo "   Username: ${AUTH_USERNAME:-admin}"
fi

# Start Apache in foreground
exec apache2-foreground
