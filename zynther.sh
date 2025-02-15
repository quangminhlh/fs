#!/bin/bash
clear
# Yêu cầu nhập thông tin
read -p "Nhập hostname chính (vd: example.com): " MAIN_DOMAIN
read -p "Nhập email admin: " EMAIL
read -p "Nhập mật khẩu root mới: " ROOT_PASSWORD
read -p "Nhập mật khẩu cPanel mới: " CPANEL_PASSWORD
read -p "Nhập port cho VSCode Server (mặc định 8080): " VSCODE_PORT
VSCODE_PORT=${VSCODE_PORT:-8443}
read -p "Nhập mật khẩu cho VSCode Server: " VSCODE_PASSWORD

# Đổi mật khẩu root
echo "root:$ROOT_PASSWORD" | chpasswd
# Cập nhật hostname
hostnamectl set-hostname $HOSTNAME

# Cập nhật system
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
    npm

sudo systemctl restart nginx apache2 code-server
# Cấu hình firewall cơ bản
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
# Mở port cần thiết
sudo ufw allow 2082/tcp  # WHM
sudo ufw allow 2083/tcp  # WHM SSL
sudo ufw allow 2095/tcp  # phpMyAdmin
sudo ufw allow $VSCODE_PORT/tcp
sudo ufw --force enable
    nodejs \
    npm

# Cài đặt Python trực tiếp
apt install -y python3.12 python3.11 python3.10 python3-pip python3.12-venv

# Thêm pyenv vào PATH
echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
source ~/.bashrc
# Cài đặt pyenv
curl https://pyenv.run | bash
# Tạo symbolic links
ln -sf /usr/bin/python3.12 /usr/local/bin/python
ln -sf /usr/bin/pip3 /usr/local/bin/pip
# Cài đặt pip và Python
sudo apt install -y python3-pip
sudo pip3 install --upgrade pip

# Cài đặt Python packages phổ biến
pip install \
    ipython \
    jupyter \
    numpy \
    pandas \
    matplotlib \
    scikit-learn \
    requests \
    flask \
    django \
    pytest \
    black \
    pylint \
    mypy \
    poetry

# Cài đặt code-server (VSCode)
curl -fsSL https://code-server.dev/install.sh | sh

# Tạo config cho code-server
mkdir -p ~/.config/code-server
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:$VSCODE_PORT
auth: password
password: $VSCODE_PASSWORD
cert: false
EOF

# Cài đặt extensions phổ biến
code-server --install-extension ms-python.python
code-server --install-extension ms-python.vscode-pylance
code-server --install-extension ms-toolsai.jupyter
code-server --install-extension ms-python.isort
code-server --install-extension njpwerner.autodocstring
code-server --install-extension kevinrose.vsc-python-indent
code-server --install-extension formulahendry.code-runner
code-server --install-extension ms-python.black-formatter
code-server --install-extension ms-vscode.cpptools
code-server --install-extension pkief.material-icon-theme
code-server --install-extension zhuangtongfa.material-theme
code-server --install-extension esbenp.prettier-vscode
code-server --install-extension dbaeumer.vscode-eslint
code-server --install-extension eamodio.gitlens
code-server --install-extension christian-kohler.path-intellisense
code-server --install-extension visualstudioexptteam.vscodeintellicode
code-server --install-extension redhat.vscode-yaml
code-server --install-extension mikestead.dotenv
code-server --install-extension yzhang.markdown-all-in-one

# Tạo settings.json cho VSCode
mkdir -p ~/.local/share/code-server/User/
cat > ~/.local/share/code-server/User/settings.json << EOF
{
    "editor.formatOnSave": true,
    "editor.formatOnPaste": true,
    "editor.rulers": [80, 100],
    "editor.minimap.enabled": true,
    "editor.suggestSelection": "first",
    "editor.tabSize": 4,
    "editor.detectIndentation": true,
    "editor.renderWhitespace": "boundary",
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.trimFinalNewlines": true,
    "workbench.colorTheme": "One Dark Pro",
    "workbench.iconTheme": "material-icon-theme",
    "python.formatting.provider": "black",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": true,
    "python.linting.mypyEnabled": true,
}
EOF
# Tạo systemd service cho code-server
# Xóa file service cũ (nếu tồn tại)
sudo rm -f /etc/systemd/system/code-server.service
# Tạo lại file service đúng cấu trúc
cat << EOF | sudo tee /etc/systemd/system/code-server.service
[Unit]
Description=Code Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:${VSCODE_PORT} --auth password --password ${VSCODE_PASSWORD}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
# Reload và kích hoạt dịch vụ
sudo systemctl daemon-reload
sudo systemctl enable --now code-server

# Thêm hostname vào /etc/hosts
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts
# Cấu hình Nginx proxy
cat > /etc/nginx/sites-available/code-server << EOF
server {
    listen 80;
    listen [::]:80;
    server_name _;

    location / {
        proxy_pass http://localhost:$VSCODE_PORT;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
    }
}
EOF

# Enable site và restart Nginx
ln -s /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
systemctl restart nginx


# Cài đặt các package cần thiết
apt install -y curl wget nano git unzip htop

# Tắt một số service không cần thiết
systemctl disable apache2
systemctl stop apache2

# 1. Cài đặt Prometheus
# Tạo user prometheus
sudo useradd --no-create-home --shell /bin/false prometheus

# Tạo thư mục cấu hình và data
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

# Tải và cài đặt Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvf prometheus-2.45.0.linux-amd64.tar.gz

sudo cp prometheus-2.45.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Cấu hình Prometheus
sudo cat << EOF > /etc/prometheus/prometheus.yml
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

sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Tạo systemd service
sudo cat << EOF > /etc/systemd/system/prometheus.service
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

sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

# 2. Cài đặt Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin
sudo useradd --no-create-home --shell /bin/false node_exporter

# Tạo systemd service cho Node Exporter
sudo cat << EOF > /etc/systemd/system/node_exporter.service
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

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# 3. Cài đặt Grafana
sudo apt-get install -y apt-transport-https software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install -y grafana

sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# 4. Cài đặt cPanel (WHM)
sudo mkdir -p /etc/cpanel/apt/sources.list.d
echo "deb http://httpupdate.cpanel.net/apt/ubuntu noble main" | sudo tee /etc/cpanel/apt/sources.list.d/cpanel.list
sudo apt update
sudo apt install cpanel
wget http://httpupdate.cpanel.net/ubuntu/pool/cpanel-perl-536/cpanel-perl-536_5.36.0-2.cp108~u24_amd64.deb
sudo dpkg -i cpanel-perl-536_5.36.0-2.cp108~u24_amd64.deb
sudo apt install -y libfile-fcntllock-perl libnet-ssleay-perl
sudo /usr/local/cpanel/scripts/install_cpanel

# Đợi quá trình cài đặt hoàn tất (có thể mất 1-2 giờ)

# 5. Cấu hình Firewall (UFW)
sudo ufw allow 9090/tcp  # Prometheus
sudo ufw allow 9100/tcp  # Node Exporter
# Download và cài đặt cPanel
cd /home || exit 1
if curl -o latest -L https://securedownloads.cpanel.net/latest; then
    chmod +x latest

    # Chạy cài đặt với các tùy chọn
    ./latest \
# Tạo file cấu hình cPanel
cat > /etc/install_conf << EOF
host: $HOSTNAME
contactemail: $EMAIL
randompass: 0
pass: $CPANEL_PASSWORD
ip-already-configured: 1
EOF

# Download và cài đặt cPanel
cd /home && curl -o latest -L https://securedownloads.cpanel.net/latest
chmod +x latest

# Chạy cài đặt với các tùy chọn
./latest \
--skip-cloudlinux \
--skip-security-advisor \
--skip-selinux \
--force

# Đợi cPanel cài đặt xong

# Cài đặt LiteSpeed
cd /usr/local/cpanel/whostmgr/docroot/cgi
./addon_lsws.cgi

# Cài đặt phpMyAdmin
cd /usr/local/cpanel/whostmgr/docroot/cgi
./addon_phpMyAdmin.cgi

# Cấu hình phpMyAdmin
cat > /usr/local/cpanel/etc/phpMyAdmin/config.inc.php << EOF
<?php
\$cfg['blowfish_secret'] = '$(openssl rand -base64 32)';
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['connect_type'] = 'tcp';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['MaxRows'] = 50;
\$cfg['SendErrorReports'] = 'never';
\$cfg['ShowPhpInfo'] = false;
EOF

# Cấu hình Apache proxy ports cho cPanel và WHM
cat > /etc/apache2/conf.d/whm.conf << EOF
<VirtualHost *:80>
    ServerName $HOSTNAME
    ProxyPass / http://localhost:2082/
    ProxyPassReverse / http://localhost:2082/
</VirtualHost>

<VirtualHost *:443>
    ServerName $HOSTNAME
    SSLEngine On
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
    ProxyPass / https://localhost:2083/
    ProxyPassReverse / https://localhost:2083/
</VirtualHost>
EOF

# Cấu hình LiteSpeed Virtual Host
cat > /usr/local/lsws/conf/vhosts/$HOSTNAME.conf << EOF
docRoot                   \$VH_ROOT/public_html
vhDomain                 $HOSTNAME
adminEmails              $EMAIL
enableGzip               1
enableBr                 1
enableH2                 1
sslCertFile             /etc/ssl/certs/ssl-cert-snakeoil.pem
sslKeyFile              /etc/ssl/private/ssl-cert-snakeoil.key

context / {
  type                   proxy
  handler               proxyHandler
  addDefaultCharset     off
}

rewrite  {
  enable                1
  autoLoadHtaccess      1
}
EOF

# Tối ưu LiteSpeed
cat > /usr/local/lsws/conf/httpd_config.conf << EOF
maxConnections                10000
maxSSLConnections            10000
connTimeout                  300
maxKeepAliveReq             10000
keepAliveTimeout            5
smartKeepAlive              1
gracefulRestartTimeout      300
mime                        conf/mime.properties
showVersionNumber           0
useIpInProxyHeader         1
EOF

# Cài đặt Memcached
yum install memcached -y
systemctl start memcached
systemctl enable memcached

# Cài đặt Redis
yum install redis -y
systemctl start redis
systemctl enable redis

# Tối ưu PHP
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

# Tối ưu MySQL
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

# Cài đặt CloudFlare
/usr/local/cpanel/scripts/install_plugin /usr/local/cpanel/base/frontend/paper_lantern/cloudflare

# Tối ưu kernel parameters
cat >> /etc/sysctl.conf << EOF
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fastopen = 3
EOF
# Apply kernel parameters
sysctl -p

# Cài đặt CSF Firewall
cd /usr/src
rm -fv csf.tgz
wget https://download.configserver.com/csf.tgz
tar -xzf csf.tgz
cd csf
sh install.sh

# Tối ưu CSF
sed -i 's/^TESTING = "1"/TESTING = "0"/' /etc/csf/csf.conf
sed -i 's/^CT_LIMIT = "30"/CT_LIMIT = "60"/' /etc/csf/csf.conf
sed -i 's/^CT_INTERVAL = "30"/CT_INTERVAL = "60"/' /etc/csf/csf.conf

# Restart CSF
csf -r

# Cài đặt ImunifyAV
wget https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh
bash imav-deploy.sh

# Tạo script backup tự động
cat > /root/backup.sh << EOF
#!/bin/bash
/usr/local/cpanel/scripts/pkgacct --skiphomedir $USER
EOF
chmod +x /root/backup.sh

# Thêm cronjob backup
(crontab -l 2>/dev/null; echo "0 2 * * * /root/backup.sh") | crontab -

# Thêm cấu hình proxy cho phpMyAdmin
cat > /etc/apache2/conf.d/phpmyadmin.conf << EOF
<VirtualHost *:80>
    ServerName $HOSTNAME/phpmyadmin
    ProxyPass /phpmyadmin http://localhost:2095/
    ProxyPassReverse /phpmyadmin http://localhost:2095/
</VirtualHost>
EOF

# Restart services
systemctl restart apache2
systemctl restart lsws
/scripts/restartsrv_httpd

echo "Cài đặt hoàn tất. Bạn có thể truy cập:"
echo "WHM: http://$HOSTNAME"
echo "cPanel: http://$HOSTNAME/cpanel"
echo "phpMyAdmin: http://$HOSTNAME/phpmyadmin"
echo "Email admin: $EMAIL"
echo "Cài đặt hoàn tất!"
echo "Truy cập VSCode Server tại: http://your-ip"
echo "Mật khẩu: $VSCODE_PASSWORD"
echo "Python versions đã cài đặt:"
pyenv versions
