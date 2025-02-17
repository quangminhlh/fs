#!/bin/bash

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Script này cần chạy với quyền root. Hãy sử dụng sudo!" 1>&2
    exit 1
fi

# Get user inputs
read -p "Nhập username admin: " admin_user
read -s -p "Nhập password admin: " admin_pass
echo
read -p "Nhập email admin: " admin_email

# Port configuration
echo -e "\nChọn port (80/443), mặc định 443:"
read port
if [[ -z "$port" ]]; then
    port=443
elif [[ "$port" != "80" && "$port" != "443" ]]; then
    echo "Port không hợp lệ! Sử dụng port mặc định 443."
    port=443
fi

# Get server IP
ip=$(curl -s http://checkip.amazonaws.com)

# Configure APP_URL
if [[ "$port" == "80" ]]; then
    app_url="http://$ip"
else
    app_url="https://$ip"
fi

# Install dependencies
echo -e "\nCài đặt các gói cần thiết..."
apt update && apt upgrade -y
apt install -y curl mariadb-server nginx php-fpm php-cli php-common php-curl php-gd php-mysql php-mbstring php-xml php-zip php-bcmath php-tokenizer openssl redis-server

# Install Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configure database
echo -e "\nCấu hình database..."
db_password=$(openssl rand -hex 16)
mysql -e "CREATE DATABASE panel;"
mysql -e "CREATE USER 'pterodactyl'@'localhost' IDENTIFIED BY '${db_password}';"
mysql -e "GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Install Panel
echo -e "\nCài đặt Pterodactyl Panel..."
mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl
curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
tar -xzvf panel.tar.gz
chmod -R 755 storage/* bootstrap/cache/

# Configure .env
cp .env.example .env
sed -i "s/APP_URL=.*/APP_URL=${app_url}/" .env
sed -i "s/DB_HOST=.*/DB_HOST=127.0.0.1/" .env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=panel/" .env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=pterodactyl/" .env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${db_password}/" .env
sed -i "s/APP_ENV=.*/APP_ENV=production/" .env
sed -i "s/CACHE_DRIVER=.*/CACHE_DRIVER=redis/" .env
sed -i "s/SESSION_DRIVER=.*/SESSION_DRIVER=redis/" .env
sed -i "s/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/" .env

# Install dependencies and setup
composer install --optimize-autoloader --no-dev
php artisan key:generate --force
php artisan migrate --force
php artisan db:seed --force
php artisan p:user:make --email=${admin_email} --username=${admin_user} --name=Admin --admin=1 --password=${admin_pass}

# Configure Nginx
echo -e "\nCấu hình Nginx..."
if [[ "$port" == "443" ]]; then
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/pterodactyl.key -out /etc/nginx/ssl/pterodactyl.crt -subj "/CN=${ip}"
fi

cat > /etc/nginx/sites-available/pterodactyl.conf <<EOL
server {
    listen ${port} ${([[ "$port" == "443" ]] && echo "ssl")};
    server_name ${ip};
    root /var/www/pterodactyl/public;
    index index.php;

    $([[ "$port" == "443" ]] && echo "ssl_certificate /etc/nginx/ssl/pterodactyl.crt;
    ssl_certificate_key /etc/nginx/ssl/pterodactyl.key;")

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$(ls /var/run/php/php*-fpm.sock);
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Install Nebula theme
echo -e "\nCài đặt theme Nebula..."
cd /var/www/pterodactyl/public/themes
git clone https://github.com/NebulaServices/Nebula.git nebula
echo 'APP_THEME=nebula' >> /var/www/pterodactyl/.env
php artisan view:clear

# Final output
echo -e "\nCài đặt hoàn tất!"
echo "Truy cập Panel tại: ${app_url}"
echo "Username admin: ${admin_user}"
echo "Password admin: ${admin_pass}"
if [[ "$port" == "443" ]]; then
    echo "Lưu ý: Bạn đang sử dụng chứng chỉ tự tạo, trình duyệt có thể cảnh báo bảo mật!"
fi

echo -e "\nHướng dẫn thay đổi theme:"
echo "1. Clone theme vào thư mục /var/www/pterodactyl/public/themes/"
echo "2. Sửa file .env: APP_THEME=tên_theme"
echo "3. Chạy lệnh: php artisan view:clear"
