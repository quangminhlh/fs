#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Special characters for boxes
horizontal="═"
vertical="║"
top_left="╔"
top_right="╗"
bottom_left="╚"
bottom_right="╝"

# Function to print centered text in a box
print_centered_box() {
    local text="$1"
    local width=53
    local padding=$(( (width - ${#text}) / 2 ))
    
    echo -e "${top_left}${horizontal:0:width}${top_right}"
    printf "${vertical}%*s%s%*s${vertical}\n" $padding "" "$text" $padding ""
    echo -e "${bottom_left}${horizontal:0:width}${bottom_right}"
}

# Welcome banner
clear
echo -e "${PURPLE}"
print_centered_box "𝓩𝔂𝓷𝓽𝓱𝓮𝓻 𝓦𝓮𝓫𝓼𝓲𝓽𝓮"
print_centered_box "Installation & Setup Script"
echo -e "${NC}"

# Check if running on Ubuntu 22.04
if [ "$(lsb_release -rs)" != "22.04" ]; then
    echo -e "${RED}Warning: This script is designed for Ubuntu 22.04${NC}"
    read -p "Do you want to continue anyway? (y/n): " continue_anyway
    if [ "$continue_anyway" != "y" ]; then
        exit 1
    fi
fi

# Configuration variables
read -p "Enter your domain name: " DOMAIN_NAME
read -p "Enter desired MySQL root password: " MYSQL_ROOT_PASSWORD
read -p "Enter desired VS Code password: " VSCODE_PASSWORD
read -p "Select control panel (cpanel/directadmin/aapanel/cyberpanel): " CONTROL_PANEL

# Install basic requirements
echo -e "${CYAN}Installing basic requirements...${NC}"
apt update && apt upgrade -y
apt install -y curl wget git unzip nginx

# Install Prometheus and Grafana
install_monitoring() {
    echo -e "${CYAN}Installing Prometheus and Grafana...${NC}"
    
    # Install Prometheus
    useradd --no-create-home --shell /bin/false prometheus
    mkdir /etc/prometheus
    mkdir /var/lib/prometheus
    
    wget https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-amd64.tar.gz
    tar xvf prometheus-*.tar.gz
    cp prometheus-*/prometheus /usr/local/bin/
    cp prometheus-*/promtool /usr/local/bin/
    
    # Configure Prometheus
    cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

    # Create Prometheus service
    cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

    # Install Grafana
    apt-get install -y software-properties-common
    wget -q -O /usr/share/keyrings/grafana.key https://packages.grafana.com/gpg.key
    echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://packages.grafana.com/oss/deb stable main" | tee /etc/apt/sources.list.d/grafana.list
    apt-get update
    apt-get install -y grafana

    # Configure Grafana to run on port 3001
    sed -i 's/;http_port = 3000/http_port = 3001/' /etc/grafana/grafana.ini

    # Start services
    systemctl start prometheus
    systemctl enable prometheus
    systemctl start grafana-server
    systemctl enable grafana-server
}

# Install selected control panel
install_control_panel() {
    case $CONTROL_PANEL in
        "cpanel")
            echo -e "${CYAN}Installing cPanel...${NC}"
            cd /home && curl -o latest -L https://securedownloads.cpanel.net/latest && sh latest
            ;;
        "directadmin")
            echo -e "${CYAN}Installing DirectAdmin...${NC}"
            wget http://www.directadmin.com/setup.sh && chmod 755 setup.sh && ./setup.sh
            ;;
        "aapanel")
            echo -e "${CYAN}Installing aaPanel...${NC}"
            wget -O install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh && bash install.sh
            ;;
        "cyberpanel")
            echo -e "${CYAN}Installing CyberPanel...${NC}"
            sh <(curl https://cyberpanel.net/install.sh || wget -O - https://cyberpanel.net/install.sh)
            ;;
    esac
}

# Install LiteSpeed
install_litespeed() {
    echo -e "${CYAN}Installing LiteSpeed...${NC}"
    wget -O - http://rpms.litespeedtech.com/debian/enable_lst_debian_repo.sh | bash
    apt-get install openlitespeed -y
}

# Install phpMyAdmin
install_phpmyadmin() {
    echo -e "${CYAN}Installing phpMyAdmin...${NC}"
    apt install -y phpmyadmin php-mbstring php-zip php-gd php-json php-curl
    
    # Configure nginx for phpMyAdmin
    cat > /etc/nginx/conf.d/phpmyadmin.conf <<EOF
server {
    listen 80;
    server_name phpmyadmin.$DOMAIN_NAME;
    
    root /usr/share/phpmyadmin;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
    }
}
EOF
}

# Install VS Code Server
install_vscode() {
    echo -e "${CYAN}Installing VS Code Server...${NC}"
    curl -fsSL https://code-server.dev/install.sh | sh
    
    # Configure VS Code Server
    mkdir -p ~/.config/code-server
    cat > ~/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:8080
auth: password
password: $VSCODE_PASSWORD
cert: false
EOF

    # Create service
    cat > /etc/systemd/system/code-server.service <<EOF
[Unit]
Description=VS Code Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/code-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable code-server
    systemctl start code-server
}

# Main installation process
install_monitoring
install_control_panel
install_litespeed
install_phpmyadmin
install_vscode

# Configure Nginx for React applications
cat > /etc/nginx/conf.d/default.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    root /var/www/html;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Restart Nginx
systemctl restart nginx

# Print installation summary
clear
echo -e "${PURPLE}"
print_centered_box "Installation Complete!"
echo -e "${NC}"

echo -e "${GREEN}Access URLs:${NC}"
echo -e "Website: http://$DOMAIN_NAME"
echo -e "phpMyAdmin: http://phpmyadmin.$DOMAIN_NAME"
echo -e "VS Code Server: http://$DOMAIN_NAME:8080"
echo -e "Grafana: http://$DOMAIN_NAME:3001"

echo -e "\n${GREEN}Credentials:${NC}"
echo -e "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
echo -e "VS Code Password: $VSCODE_PASSWORD"
echo -e "Grafana Default Login: admin/admin"

echo -e "\n${YELLOW}Please make sure to:${NC}"
echo -e "1. Change default passwords"
echo -e "2. Configure SSL certificates"
echo -e "3. Update firewall rules if needed"
echo -e "4. Configure your domain DNS settings"

# Save credentials to a file
cat > ~/zynther_credentials.txt <<EOF
Domain: $DOMAIN_NAME
MySQL Root Password: $MYSQL_ROOT_PASSWORD
VS Code Password: $VSCODE_PASSWORD
Grafana Default Login: admin/admin
EOF

chmod 600 ~/zynther_credentials.txt
