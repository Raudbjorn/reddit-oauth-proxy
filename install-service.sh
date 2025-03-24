#!/bin/bash
set -e

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or with sudo"
  exit 1
fi

# Define paths
SERVICE_NAME="reddit-oauth-proxy"
PROJECT_DIR=$(dirname "$(readlink -f "$0")")
SERVICE_FILE="$PROJECT_DIR/systemd/$SERVICE_NAME.service"
DEST_SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"
OVERRIDE_DIR="/etc/systemd/system/$SERVICE_NAME.service.d"
NGINX_CONF="$PROJECT_DIR/nginx/$SERVICE_NAME.conf"
NGINX_AVAILABLE="/etc/nginx/sites-available/$SERVICE_NAME.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/$SERVICE_NAME.conf"

# Check if nginx is installed
NGINX_INSTALLED=true
if ! command -v nginx &> /dev/null; then
    NGINX_INSTALLED=false
    echo "WARNING: Nginx is not installed. Skipping Nginx configuration."
fi

# Collect environment variables
echo "==== Reddit OAuth Proxy Installer ===="
echo "Please enter the following information:"

read -p "Reddit Client ID: " REDDIT_CLIENT_ID
read -p "Reddit Client Secret: " REDDIT_CLIENT_SECRET
read -p "Reddit Redirect URI (default: https://auth.sveinbjorn.dev/callback): " REDDIT_REDIRECT_URI
REDDIT_REDIRECT_URI=${REDDIT_REDIRECT_URI:-https://auth.sveinbjorn.dev/callback}
read -p "Port (default: 3000): " PORT
PORT=${PORT:-3000}
read -p "Service user (default: $USER): " SERVICE_USER
SERVICE_USER=${SERVICE_USER:-$USER}

if [ "$NGINX_INSTALLED" = true ]; then
    read -p "Server name for Nginx (default: auth.sveinbjorn.dev): " SERVER_NAME
    SERVER_NAME=${SERVER_NAME:-auth.sveinbjorn.dev}
    
    # Ask for SSL certificate paths if they're not default
    read -p "Use Let's Encrypt certificates for $SERVER_NAME? (Y/n): " USE_LETSENCRYPT
    USE_LETSENCRYPT=${USE_LETSENCRYPT:-Y}
    
    if [[ "$USE_LETSENCRYPT" =~ ^[Yy]$ ]]; then
        SSL_CERT="/etc/letsencrypt/live/$SERVER_NAME/fullchain.pem"
        SSL_KEY="/etc/letsencrypt/live/$SERVER_NAME/privkey.pem"
    else
        read -p "SSL certificate path: " SSL_CERT
        read -p "SSL key path: " SSL_KEY
    fi
    
    # Check if SSL certificates exist
    if [ ! -f "$SSL_CERT" ]; then
        echo "WARNING: SSL certificate not found at $SSL_CERT"
        echo "You may need to obtain SSL certificates before enabling HTTPS."
    fi
    
    if [ ! -f "$SSL_KEY" ]; then
        echo "WARNING: SSL key not found at $SSL_KEY"
        echo "You may need to obtain SSL certificates before enabling HTTPS."
    fi
fi

# Get the path to node executable
NODE_PATH=$(which node || echo "/usr/bin/node")
if [ ! -f "$NODE_PATH" ]; then
    echo "WARNING: Node.js executable not found at $NODE_PATH. Using default path."
    NODE_PATH="/usr/bin/node"
fi

# Install systemd service
echo "Installing systemd service..."

# Copy the service file to a temporary file and replace placeholders
TMP_SERVICE_FILE=$(mktemp)
cat "$SERVICE_FILE" | \
    sed "s|{{USER}}|$SERVICE_USER|g" | \
    sed "s|{{WORK_DIR}}|$PROJECT_DIR|g" | \
    sed "s|{{NODE_PATH}}|$NODE_PATH|g" \
    > "$TMP_SERVICE_FILE"

# Copy the modified file to destination
cp "$TMP_SERVICE_FILE" "$DEST_SERVICE_FILE"
rm "$TMP_SERVICE_FILE"

# Create override directory if it doesn't exist
mkdir -p "$OVERRIDE_DIR"

# Create the override.conf file with environment variables
cat > "$OVERRIDE_DIR/override.conf" << EOF
[Service]
Environment=PORT=$PORT
Environment=REDDIT_CLIENT_ID=$REDDIT_CLIENT_ID
Environment=REDDIT_CLIENT_SECRET=$REDDIT_CLIENT_SECRET
Environment=REDDIT_REDIRECT_URI=$REDDIT_REDIRECT_URI
EOF

# Reload systemd, enable and start the service
echo "Reloading systemd configuration..."
systemctl daemon-reload
echo "Enabling service to run at startup..."
systemctl enable "$SERVICE_NAME"
echo "Starting service..."
systemctl start "$SERVICE_NAME"

# Install nginx configuration if nginx is installed
if [ "$NGINX_INSTALLED" = true ]; then
    echo "Installing Nginx configuration..."
    
    # Create a temporary file with updated server_name and SSL paths
    TMP_NGINX_CONF=$(mktemp)
    cat "$NGINX_CONF" | \
        sed "s/server_name auth.sveinbjorn.dev;/server_name $SERVER_NAME;/g" | \
        sed "s|ssl_certificate /etc/letsencrypt/live/auth.sveinbjorn.dev/fullchain.pem;|ssl_certificate $SSL_CERT;|g" | \
        sed "s|ssl_certificate_key /etc/letsencrypt/live/auth.sveinbjorn.dev/privkey.pem;|ssl_certificate_key $SSL_KEY;|g" | \
        sed "s|proxy_pass http://localhost:3000;|proxy_pass http://localhost:$PORT;|g" \
        > "$TMP_NGINX_CONF"
    
    # Copy to nginx sites-available
    cp "$TMP_NGINX_CONF" "$NGINX_AVAILABLE"
    rm "$TMP_NGINX_CONF"
    
    # Create symlink to sites-enabled if it doesn't exist
    if [ -f "$NGINX_ENABLED" ]; then
        echo "Removing existing symlink..."
        rm "$NGINX_ENABLED"
    fi
    
    ln -s "$NGINX_AVAILABLE" "$NGINX_ENABLED"
    
    # Test nginx configuration
    echo "Testing Nginx configuration..."
    if nginx -t; then
        echo "Reloading Nginx..."
        systemctl reload nginx
    else
        echo "ERROR: Nginx configuration test failed. Please check the configuration manually."
        echo "The configuration file is at: $NGINX_AVAILABLE"
    fi
fi

echo "==== Installation Complete ===="
echo "Service status:"
systemctl status "$SERVICE_NAME"
echo ""
echo "View logs with: journalctl -u $SERVICE_NAME"
echo ""
echo "Configuration can be found at:"
echo "- Service file: $DEST_SERVICE_FILE"
echo "- Environment variables: $OVERRIDE_DIR/override.conf"
if [ "$NGINX_INSTALLED" = true ]; then
    echo "- Nginx configuration: $NGINX_AVAILABLE"
fi