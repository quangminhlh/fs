#!/bin/bash

# Định nghĩa màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Vui lòng chạy script với quyền root${NC}"
    exit 1
fi

# Cảnh báo trước khi gỡ cài đặt
echo -e "${YELLOW}
⚠️  CẢNH BÁO: Script này sẽ gỡ cài đặt các thành phần đã được cài đặt bởi script cài đặt trước đó.
🔐 Đảm bảo bạn đã backup dữ liệu trước khi tiếp tục!
${NC}"

read -p "Bạn có muốn tiếp tục gỡ cài đặt? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Gỡ cài đặt Fail2Ban
echo -e "${YELLOW}🛡️ Gỡ cài đặt Fail2Ban...${NC}"
systemctl stop fail2ban
systemctl disable fail2ban
apt remove -y fail2ban

# Gỡ cài đặt Prometheus
echo -e "${YELLOW}📊 Gỡ cài đặt Prometheus...${NC}"
systemctl stop prometheus
systemctl disable prometheus
rm -f /etc/systemd/system/prometheus.service
rm -rf /usr/local/bin/prometheus
rm -rf /usr/local/bin/promtool
rm -rf /etc/prometheus
rm -rf /var/lib/prometheus

# Gỡ cài đặt Grafana
echo -e "${YELLOW}📈 Gỡ cài đặt Grafana...${NC}"
systemctl stop grafana-server
systemctl disable grafana-server
apt remove -y grafana
rm -f /etc/apt/sources.list.d/grafana.list
apt update

# Gỡ cài đặt control panel (CyberPanel, aaPanel, cPanel)
echo -e "${YELLOW}🎛️ Gỡ cài đặt Control Panel...${NC}"

if [ -f /usr/local/CyberCP/bin/cyberpanel ]; then
    echo -e "${YELLOW}🛠️ Gỡ cài đặt CyberPanel...${NC}"
    /usr/local/CyberCP/bin/cyberpanel uninstall
    rm -rf /usr/local/CyberCP
elif [ -f /www/server/panel/pyenv/bin/python3 ]; then
    echo -e "${YELLOW}🛠️ Gỡ cài đặt aaPanel...${NC}"
    /www/server/panel/pyenv/bin/python3 /www/server/panel/uninstall.py
    rm -rf /www/server
elif [ -f /usr/local/cpanel/scripts/uninstall ]; then
    echo -e "${YELLOW}🛠️ Gỡ cài đặt cPanel...${NC}"
    /usr/local/cpanel/scripts/uninstall
    rm -rf /usr/local/cpanel
fi

# Gỡ cài đặt Nginx và phpMyAdmin
echo -e "${YELLOW}🛠️ Gỡ cài đặt Nginx và phpMyAdmin...${NC}"
systemctl stop nginx
systemctl disable nginx
apt remove -y nginx phpmyadmin
rm -f /var/www/html/phpmyadmin

# Gỡ bỏ các rule firewall đã thêm
echo -e "${YELLOW}🔥 Gỡ bỏ các rule firewall...${NC}"
ufw delete allow 80/tcp
ufw delete allow 443/tcp
ufw delete allow 3001/tcp
ufw delete allow $VSCODE_PORT/tcp
ufw disable

# Xóa các gói cài đặt bổ sung
echo -e "${YELLOW}🗑️ Xóa các gói cài đặt bổ sung...${NC}"
apt autoremove -y curl wget git unzip apt-transport-https software-properties-common

echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════╗
║ 🎉 GỠ CÀI ĐẶT THÀNH CÔNG! (Trừ VS Code Server) 🎉 ║
╚══════════════════════════════════════════════════════════════╝
${NC}"
