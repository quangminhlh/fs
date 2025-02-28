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
║                    🚀 ${YELLOW}𝓥𝓢 𝓒𝓸𝓭𝓮 𝓢𝓮𝓻𝓿𝓮𝓻 🚀                     ║
║                 Installation & Setup Script                  ║
╚══════════════════════════════════════════════════════════════╝
${NC}"

# Kiểm tra phiên bản Ubuntu
if [ "$(lsb_release -rs)" != "22.04" ]; then
    echo -e "${RED}❌ Lỗi: Script này chỉ hỗ trợ Ubuntu 22.04 LTS${NC}"
    exit 1
fi

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Vui lòng chạy script với quyền root${NC}"
    exit 1
fi

# Cảnh báo trước khi cài đặt
echo -e "${YELLOW}
⚠️  CẢNH BÁO: Script này sẽ thực hiện các thay đổi hệ thống quan trọng
🔐 Đảm bảo bạn đã backup dữ liệu trước khi tiếp tục!
${NC}"

read -p "Bạn có muốn tiếp tục? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Nhập thông tin cấu hình
echo -e "${GREEN}📝 Nhập thông tin cấu hình cho VS Code Server:${NC}"
read -p "🔑 VS Code Server Password: " VSCODE_PASS
read -p "🔌 Port cho VS Code Server (mặc định 8484): " VSCODE_PORT
VSCODE_PORT=${VSCODE_PORT:-8484}

# Cập nhật hệ thống tối thiểu cần thiết và cài đặt các công cụ cần thiết
echo -e "${YELLOW}🔄 Cài đặt các công cụ cần thiết...${NC}"
apt update -y
apt install -y curl wget ufw git unzip -y

# Cài đặt VS Code Server
echo -e "${YELLOW}💻 Cài đặt VS Code Server...${NC}"
curl -fsSL https://code-server.dev/install.sh | sh
cat <<EOF > /lib/systemd/system/code-server.service
[Unit]
Description=Code Server
After=network.target

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

# Cấu hình firewall cho VS Code Server port
echo -e "${YELLOW}Firewall: Mở port cho VS Code Server...${NC}"
ufw allow $VSCODE_PORT/tcp
ufw --force enable

clear
echo -e "${GREEN}
╔══════════════════════════════════════════════════════════════╗
║                  🎉 CÀI ĐẶT VS CODE SERVER THÀNH CÔNG! 🎉                  ║
╚══════════════════════════════════════════════════════════════╝
${NC}"

echo -e "${YELLOW}📋 Thông tin truy cập VS Code Server:${NC}"
echo -e "${BLUE}
+------------------------------------------+
| 💻 VS Code Server: http://<Your_Server_IP>:$VSCODE_PORT
+------------------------------------------+
🔑 Thông tin đăng nhập VS Code Server:
- Password: $VSCODE_PASS
${NC}"

echo -e "${YELLOW}⚠️ Lưu ý:${NC}
${YELLOW}Bạn cần thay thế ${RED}<Your_Server_IP>${YELLOW} bằng địa chỉ IP hoặc tên miền của server.${NC}"
