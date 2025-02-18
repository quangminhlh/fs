#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_message "Please run as root" "$RED"
    exit
fi

# Get user inputs
read -p "Enter admin email: " EMAIL
read -p "Enter admin username: " USERNAME
read -sp "Enter admin password: " PASSWORD
echo
read -p "Do you want to use HTTPS? (y/N): " USE_HTTPS
read -p "Enter custom port (press Enter for default 443/80): " CUSTOM_PORT

# Set default port based on protocol
if [ -z "$CUSTOM_PORT" ]; then
    if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
        PORT=443
    else
        PORT=80
    fi
else
    PORT=$CUSTOM_PORT
fi

# Update system
print_message "Updating system..." "$YELLOW"
apt update && apt upgrade -y

# Install required dependencies
print_message "Installing dependencies..." "$YELLOW"
apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

# Add PHP repository
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php

# Add MariaDB repository
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

# Update repositories
apt update

# Install required packages
apt -y install php8.2 php8.2-{cli,gd,mysql,pdo,mbstring,tokenizer,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

# Install Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configure MariaDB
mysql_secure_installation

# Create database
DBPASS=$(openssl rand -base64 16)
mysql -u root -e "CREATE DATABASE panel;"
mysql -u root -e "CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
mysql -u root -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;"
mysql -u root -e "FLUSH PRIVILEGES;"

# Download Pterodactyl
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Create user for Composer
useradd -r -s /bin/bash pterodactyl
chown -R pterodactyl:pterodactyl /var/www/pterodactyl

# Install panel as pterodactyl user
su pterodactyl <<'EOF'
cd /var/www/pterodactyl
cp .env.example .env
composer install --no-dev --optimize-autoloader
php artisan key:generate --force
EOF

# Setup environment
php artisan p:environment:setup \
    --author=$EMAIL \
    --url=http://localhost \
    --timezone=Asia/Ho_Chi_Minh \
    --cache=redis \
    --session=redis \
    --queue=redis \
    --redis-host=127.0.0.1 \
    --redis-pass= \
    --redis-port=6379

# Setup database
php artisan p:environment:database \
    --host=127.0.0.1 \
    --port=3306 \
    --database=panel \
    --username=pterodactyl \
    --password=$DBPASS

# Setup mail
php artisan p:environment:mail

# Setup admin user
php artisan p:user:make \
    --email=$EMAIL \
    --username=$USERNAME \
    --name-first=Admin \
    --name-last=User \
    --password=$PASSWORD \
    --admin=1

# Set permissions
chown -R www-data:www-data /var/www/pterodactyl/*

# Configure Nginx
cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen ${PORT};
    server_name _;
    
    root /var/www/pterodactyl/public;
    index index.php;

    access_log /var/log/nginx/pterodactyl.app-access.log;
    error_log  /var/log/nginx/pterodactyl.app-error.log error;

    # allow larger file uploads and longer script runtimes
    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable site configuration
ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
rm -f /etc/nginx/sites-enabled/default

# Install SSL if HTTPS is selected
if [[ "$USE_HTTPS" =~ ^[Yy]$ ]]; then
    apt install -y certbot python3-certbot-nginx
    print_message "Please setup SSL certificate using: certbot --nginx" "$YELLOW"
fi

# Install Nebula theme
cd /var/www/pterodactyl
mkdir -p public/themes
cd public/themes
git clone https://github.com/Pterodactyl-Theme/Nebula.git
cd Nebula
yarn install
yarn build

# Restart services
systemctl restart nginx
systemctl restart php8.2-fpm

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

# Print completion message
print_message "\nPterodactyl Panel Installation Complete!" "$GREEN"
print_message "Panel URL: http://$SERVER_IP:$PORT" "$GREEN"
print_message "Admin Username: $USERNAME" "$GREEN"
print_message "Admin Password: $PASSWORD" "$GREEN"
print_message "\nTo install themes, visit: https://github.com/topics/pterodactyl-theme" "$YELLOW"
print_message "To change theme:" "$YELLOW"
print_message "1. Go to Admin Panel > Settings > Theme" "$YELLOW"
print_message "2. Select your desired theme" "$YELLOW"
print_message "3. Save changes" "$YELLOW"
