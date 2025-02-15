#!/bin/bash
set -e  # Dừng script nếu có lỗi xảy ra

# Yêu cầu nhập thông tin với icon
read -p "🔧 Nhập hostname chính (vd: example.com): " MAIN_DOMAIN
read -p "📧 Nhập email admin: " EMAIL
read -p "🔑 Nhập mật khẩu root mới: " ROOT_PASSWORD
read -p "🛠️ Nhập mật khẩu cPanel mới: " CPANEL_PASSWORD
read -p "🔐 Nhập port cho VSCode Server (mặc định 8443): " VSCODE_PORT
VSCODE_PORT=${VSCODE_PORT:-8443}
read -p "🔑 Nhập mật khẩu cho VSCode Server: " VSCODE_PASSWORD

# Đổi mật khẩu root
echo "root:$ROOT_PASSWORD" | chpasswd

# Cập nhật hostname
hostnamectl set-hostname $MAIN_DOMAIN

# Cập nhật hệ thống
apt update && apt upgrade -y

# Cài đặt các dependency cần thiết
apt install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    libncursesw5-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev \
    nodejs \
    npm \
    curl wget nano git unzip htop

# Cấu hình firewall cơ bản
ufw allow ssh
ufw allow http
ufw allow https
ufw allow 2082/tcp  # WHM
ufw allow 2083/tcp  # WHM SSL
ufw allow 2095/tcp  # phpMyAdmin
ufw allow $VSCODE_PORT/tcp
ufw --force enable

# Cài đặt Python
apt install -y python3.12 python3.11 python3.10 python3-pip python3.12-venv

# Cấu hình pyenv
curl https://pyenv.run | bash
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Cài đặt Python packages
pip3 install --upgrade pip
pip3 install \
    ipython jupyter numpy pandas matplotlib scikit-learn \
    requests flask django pytest black pylint mypy poetry

# Cài đặt code-server (VSCode)
curl -fsSL https://code-server.dev/install.sh | sh

# Cấu hình code-server
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:$VSCODE_PORT
auth: password
password: $VSCODE_PASSWORD
cert: false
EOF

# Cài extensions VSCode
code-server --install-extension ms-python.python
code-server --install-extension ms-python.vscode-pylance
code-server --install-extension ms-toolsai.jupyter

# Tạo service cho code-server
cat > /etc/systemd/system/code-server.service << EOF
[Unit]
Description=Code Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:$VSCODE_PORT --auth password --password $VSCODE_PASSWORD
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now code-server

# Cài đặt Prometheus
useradd --no-create-home --shell /bin/false prometheus
mkdir /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /var/lib/prometheus

wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvf prometheus-2.45.0.linux-amd64.tar.gz
cp prometheus-2.45.0.linux-amd64/prometheus /usr/local/bin/
cp prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

cat > /etc/systemd/system/prometheus.service << EOF
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

systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

# Cài đặt Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvf node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
useradd --no-create-home --shell /bin/false node_exporter

cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Cài đặt Grafana
apt-get install -y apt-transport-https software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana
systemctl start grafana-server
systemctl enable grafana-server

# Cài đặt cPanel
cd /root
curl -o latest -L https://securedownloads.cpanel.net/latest
chmod +x latest
./latest --skip-cloudlinux --skip-upcp --force

# Cấu hình post-install
/usr/local/cpanel/scripts/install_cpanel

# Cài đặt LiteSpeed
/usr/local/cpanel/whostmgr/docroot/cgi/addon_lsws.cgi auto

# Cấu hình PHP
cat > /usr/local/lib/php.ini << EOF
memory_limit = 512M
max_execution_time = 300
max_input_time = 300
post_max_size = 50M
upload_max_filesize = 50M
max_input_vars = 5000
realpath_cache_size = 10M
realpath_cache_ttl = 7200
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=4000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
opcache.enable_cli=1
EOF

# Cấu hình MySQL
cat > /etc/my.cnf << EOF
[mysqld]
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_log_buffer_size = 8M
innodb_file_per_table = 1
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
max_connections = 1000
query_cache_size = 128M
query_cache_limit = 2M
EOF

# Cài đặt CSF Firewall
cd /usr/src
wget https://download.configserver.com/csf.tgz
tar -xzf csf.tgz
cd csf
sh install.sh

# Cấu hình CSF
sed -i 's/TESTING = "1"/TESTING = "0"/' /etc/csf/csf.conf
csf -r

# Tắt Apache nếu dùng LiteSpeed
systemctl stop apache2
systemctl disable apache2

# Hoàn tất
echo "=========================================="
echo "Cài đặt hoàn tất!"
echo "WHM: https://$MAIN_DOMAIN:2087"
echo "cPanel: https://$MAIN_DOMAIN:2083"
echo "VSCode Server: http://$MAIN_DOMAIN:$VSCODE_PORT"
echo "Mật khẩu VSCode: $VSCODE_PASSWORD"
echo "=========================================="
