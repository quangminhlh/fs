#!/bin/bash
clear
# Định nghĩa màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hiển thị banner
echo -e "${BLUE}
╔══════════════════════════════════════════════════════════════╗
║                      🚀 ${YELLOW}𝓩𝔂𝓷𝓽𝓱𝓮𝓻 𝓦𝓮𝓫𝓼𝓲𝓽𝓮 🚀                   ║
║                 Installation & Setup Script                  ║
╚══════════════════════════════════════════════════════════════╝
${NC}"

# Kiểm tra phiên bản Ubuntu
if [ "$(lsb_release -rs)" != "22.04" ]; then
    echo -e "${RED}❌ Lỗi: Script này chỉ hỗ trợ Ubuntu 22.04 LTS${NC}"
    exit 1
fi

# Kiểm tra quyền root
if [ "$EUID" -ne  ]; then
    echo -e "${RED}❌ Vui lòng chạy script với quyền root${NC}"
    exit 1
fi

# Cảnh báo trước khi cài đặt
echo -e "${YELLOW}
⚠️  CẢNH BÁO: Script này sẽ thực hiện các thay đổi hệ thống quan trọng
🔐 Đảm bảo bạn đã backup dữ liệu trước khi tiếp tục!
${NC}"

read -p "Bạn có muốn tiếp tục? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Nhập thông tin cấu hình
echo -e "${GREEN}📝 Nhập thông tin cấu hình:${NC}"
read -p "🌐 Tên miền (VD: example.com): " DOMAIN
read -p "🔑 MySQL Root Password: " MYSQL_ROOT_PASSWORD
read -p "📊 Grafana Admin Password: " GRAFANA_PASS
read -p "💻 VS Code Server Password: " VSCODE_PASS
read -p "🔌 Port cho VS Code Server (mặc định 8484): " VSCODE_PORT
VSCODE_PORT=${VSCODE_PORT:-8484}

# Menu chọn control panel
echo -e "${GREEN}🎛️ Chọn control panel:${NC}"
PS3="👉 Nhập lựa chọn: "
options=("cPanel" "CyberPanel" "aaPanel" "Thoát")
select opt in "${options[@]}"
do
    case $opt in
        "cPanel")
            PANEL="cpanel"
            break
            ;;
        "CyberPanel")
            PANEL="cyberpanel"
            break
            ;;
        "aaPanel")
            PANEL="aapanel"
            break
            ;;
        "Thoát")
            exit 0
            ;;
        *) echo "❌ Lựa chọn không hợp lệ";;
    esac
done

# Cài đặt Fail2Ban để chống DDOS
echo -e "${YELLOW}🛡️ Cài đặt Fail2Ban...${NC}"
apt install -y fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/bantime  = 10m/bantime  = 1h/' /etc/fail2ban/jail.local
sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local
systemctl restart fail2ban

# Cập nhật hệ thống
echo -e "${YELLOW}🔄 Cập nhật hệ thống...${NC}"
apt update && apt upgrade -y
apt install -y curl wget ufw git unzip

# Cài đặt Prometheus và Grafana
echo -e "${YELLOW}📊 Cài đặt Prometheus và Grafana...${NC}"
# Cài đặt Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.47.2/prometheus-2.47.2.linux-amd64.tar.gz
tar xvfz prometheus-*.tar.gz
mv prometheus-*/prometheus /usr/local/bin/
mv prometheus-*/promtool /usr/local/bin/
mkdir /etc/prometheus
mv prometheus-*/console_libraries /etc/prometheus/
mv prometheus-*/consoles /etc/prometheus/

# Tạo service Prometheus
cat <<EOF > /etc/systemd/system/prometheus.service
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

# Cài đặt Grafana
apt install -y apt-transport-https software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | tee -a /etc/apt/sources.list.d/grafana.list
apt update
apt install -y grafana
sed -i "s/;http_port = 3000/http_port = 3001/" /etc/grafana/grafana.ini
systemctl start grafana-server
systemctl enable grafana-server

# Cài đặt control panel
case $PANEL in
    "cyberpanel")
        clear
        echo -e "${YELLOW}🛠️ Cài đặt CyberPanel...${NC}"
        
        # Kiểm tra kết nối Internet
        if ! ping -c 1 google.com &> /dev/null; then
            echo -e "${RED}❌ Lỗi: Không có kết nối Internet!${NC}"
            exit 1
        fi

        # Xác nhận cài đặt
        read -p "Bạn có chắc chắn muốn cài đặt CyberPanel? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi

        # Tải và chạy script cài đặt
        echo -e "${YELLOW}📥 Tải script cài đặt CyberPanel...${NC}"
        if ! (curl -sS https://cyberpanel.net/install.sh || wget -q -O - https://cyberpanel.net/install.sh) | sh; then
            echo -e "${RED}❌ Lỗi: Cài đặt CyberPanel không thành công!${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Cài đặt CyberPanel hoàn tất!${NC}"
        ;;

    "aapanel")
        clear
        # Thiết lập giá trị mặc định
        AAPANEL_PORT_DEFAULT=7800
        echo -e "${YELLOW}🛠️ Thiết lập aaPanel...${NC}"
        
        # Nhập thông tin
        read -p "🔐 Nhập tài khoản admin cho aaPanel (mặc định: admin): " AAPANEL_USER
        AAPANEL_USER=${AAPANEL_USER:-admin}
        read -p "🔐 Nhập mật khẩu admin cho aaPanel (tối thiểu 8 ký tự): " AAPANEL_PASS
        read -p "🔌 Nhập port cho aaPanel (mặc định: $AAPANEL_PORT_DEFAULT): " AAPANEL_PORT
        AAPANEL_PORT=${AAPANEL_PORT:-$AAPANEL_PORT_DEFAULT}

        # Kiểm tra port đang sử dụng
        while ss -tuln | grep -q ":${AAPANEL_PORT} "; do
            echo -e "${RED}❌ Port $AAPANEL_PORT đã được sử dụng!${NC}"
            read -p "Vui lòng nhập port khác: " AAPANEL_PORT
        done

        # Tải script cài đặt mới nhất
        echo -e "${YELLOW}📥 Tải script cài đặt aaPanel...${NC}"
        wget -O aapanel-install.sh http://www.aapanel.com/script/install-ubuntu_6.0_en.sh || {
            echo -e "${RED}❌ Lỗi khi tải script cài đặt aaPanel!${NC}"
            exit 1
        }

        # Thực thi script cài đặt
        bash aapanel-install.sh <<< "y" 

        # Chờ dịch vụ khởi động
        echo -e "${YELLOW}⏳ Đợi 15 giây để aaPanel khởi động...${NC}"
        sleep 15

        # Cài đặt Expect để tự động nhập mật khẩu
        apt install -y expect

        # Thiết lập mật khẩu và port bằng Expect
        echo -e "${YELLOW}🔧 Thiết lập mật khẩu và port cho aaPanel...${NC}"
        /usr/bin/expect <<EOF
spawn bt 5
expect "Enter panel password:"
send "$AAPANEL_PASS\r"
expect "Re-enter panel password:"
send "$AAPANEL_PASS\r"
expect eof
EOF

        /usr/bin/expect <<EOF
spawn bt 6
expect "Enter port:"
send "$AAPANEL_PORT\r"
expect eof
EOF

        # Khởi động lại aaPanel
        bt 1
        bt 3

        AAPANEL_LINK="http://$(curl -s icanhazip.com):$AAPANEL_PORT"
        ;;
        
    "cpanel")
        clear
        echo -e "${YELLOW}🛠️ Cài đặt cPanel...${NC}"

        # Kiểm tra kết nối Internet
        if ! ping -c 1 google.com &> /dev/null; then
            echo -e "${RED}❌ Lỗi: Không có kết nối Internet!${NC}"
            exit 1
        fi

        # Xác nhận cài đặt
        read -p "Bạn có chắc chắn muốn cài đặt cPanel? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi

        # Tải script cài đặt
        echo -e "${YELLOW}📥 Tải script cài đặt cPanel...${NC}"
        cd /home
        if ! wget https://securedownloads.cpanel.net/latest; then
            echo -e "${RED}❌ Lỗi: Không thể tải script cài đặt cPanel!${NC}"
            exit 1
        fi

        # Cài đặt cPanel
        echo -e "${YELLOW}⚙️ Đang cài đặt cPanel...${NC}"
        sh latest

        echo -e "${GREEN}✅ Cài đặt cPanel hoàn tất!${NC}"
        ;;
esac

# Cài đặt Nginx và phpMyAdmin
echo -e "${YELLOW}🛠️ Cài đặt Nginx và phpMyAdmin...${NC}"
apt install -y nginx
apt install -y phpmyadmin
ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin
systemctl restart nginx

# Cài đặt VS Code Server
echo -e "${YELLOW}💻 Cài đặt VS Code Server...${NC}"
curl -fsSL https://code-server.dev/install.sh | sh
cat <<EOF > /lib/systemd/system/code-server.service
[Unit]
Description=Code Server
After=nginx.service

[Service]
User=root
WorkingDirectory=/root/
Environment=PASSWORD=$VSCODE_PASS
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:$VSCODE_PORT

[Install]
WantedBy=default.target
EOF
systemctl daemon-reload
systemctl start code-server
systemctl enable code-server

# Cấu hình firewall
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow $VSCODE_PORT/tcp
ufw allow 3001/tcp
ufw --force enable

clear
echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════╗
║                  🎉 CÀI ĐẶT THÀNH CÔNG! 🎉                  ║
╚══════════════════════════════════════════════════════════════╝
${NC}"

echo -e "${YELLOW}📋 Thông tin truy cập:${NC}"
echo -e "${BLUE}
+------------------------------------------+
| 🌐 Trang web chính: http://$DOMAIN         |
| 📊 phpMyAdmin:     http://$DOMAIN/phpmyadmin
| 💻 VS Code Server: http://$DOMAIN:$VSCODE_PORT
| 📈 Grafana:        http://$DOMAIN:3001     "

if [ "$PANEL" = "aapanel" ]; then
    echo -e "|------------------------------------------|"
    echo -e "| 🛠️ ${YELLOW}aaPanel Admin:${BLUE} $AAPANEL_LINK       "
    echo -e "| 🛠️ ${YELLOW}Hoặc sử dụng IP: http://$(curl -s icanhazip.com):$AAPANEL_PORT"
    echo -e "| 🛠️ ${YELLOW}Username:${BLUE}      $AAPANEL_USER             "
    echo -e "| 🛠️ ${YELLOW}Password:${BLUE}      $AAPANEL_PASS             "
    echo -e "| 🛠️ ${YELLOW}Port:${BLUE}          $AAPANEL_PORT               "
fi

echo -e "+------------------------------------------+
🔑 Thông tin đăng nhập:
- MySQL Root: root / $MYSQL_ROOT_PASSWORD
- VS Code:     Password: $VSCODE_PASS
- Grafana:     admin / $GRAFANA_PASS
${NC}"
