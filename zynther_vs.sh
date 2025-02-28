#!/bin/bash

# Script cài đặt VS Code Server (Phiên bản web và plugin SSH)
# Tác giả: Claude
# Ngày: 28/02/2025

set -e

echo "=== Script cài đặt VS Code Server và VS Code SSH Plugin ==="
echo "Script này sẽ cài đặt:"
echo "1. VS Code Server (Code Server Web)"
echo "2. VS Code SSH Extension Server"
echo ""

# Kiểm tra và cài đặt các công cụ cần thiết
install_dependencies() {
    echo "Kiểm tra và cài đặt các gói phụ thuộc..."
    
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y curl wget git nodejs npm unzip
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL/Fedora
        sudo yum install -y curl wget git nodejs npm unzip
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        sudo pacman -Sy curl wget git nodejs npm unzip
    else
        echo "Hệ điều hành không được hỗ trợ. Vui lòng cài đặt thủ công: curl, wget, git, nodejs, npm, unzip"
        exit 1
    fi
    
    echo "Đã cài đặt xong các gói phụ thuộc."
}

# Cài đặt Code Server (VS Code phiên bản web)
install_code_server() {
    echo "Bắt đầu cài đặt Code Server (VS Code Web)..."
    
    # Kiểm tra version mới nhất
    VERSION=$(curl -s https://api.github.com/repos/coder/code-server/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    
    if [ -z "$VERSION" ]; then
        echo "Không thể lấy phiên bản mới nhất. Sử dụng phiên bản mặc định."
        VERSION="v4.16.1"
    fi
    
    echo "Cài đặt Code Server phiên bản $VERSION"
    
    # Tải và cài đặt
    curl -fsSL https://code-server.dev/install.sh | sh
    
    # Cấu hình Code Server
    echo "Nhập port cho Code Server (mặc định: 8080):"
    read custom_port
    custom_port=${custom_port:-8080}
    
    echo "Nhập mật khẩu cho Code Server (để trống để tạo ngẫu nhiên):"
    read -s custom_password
    if [ -z "$custom_password" ]; then
        custom_password=$(openssl rand -hex 16)
        echo "Đã tạo mật khẩu ngẫu nhiên."
    else
        echo "Đã sử dụng mật khẩu tùy chỉnh."
    fi
    
    mkdir -p ~/.config/code-server
    cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 127.0.0.1:${custom_port}
auth: password
password: ${custom_password}
cert: false
EOF
    
    # Cài đặt service để chạy code-server khi khởi động
    cat > /tmp/code-server.service << EOF
[Unit]
Description=Code Server
After=network.target

[Service]
Type=simple
User=$(whoami)
ExecStart=/usr/bin/code-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    sudo mv /tmp/code-server.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable code-server
    sudo systemctl start code-server
    
    echo "Code Server đã được cài đặt và khởi động tại http://127.0.0.1:${custom_port}"
    echo "Mật khẩu được lưu trong ~/.config/code-server/config.yaml"
}

# Cài đặt VS Code SSH Server (Remote - SSH)
install_vscode_ssh_server() {
    echo "Bắt đầu cài đặt VS Code SSH Server..."
    
    # Tạo thư mục bin
    mkdir -p ~/.vscode-server/bin
    cd ~/.vscode-server/bin
    
    # Lấy commit hash mới nhất từ VS Code
    COMMIT_ID=$(curl -s https://update.code.visualstudio.com/api/commits/stable/server-linux-x64 | grep -o '"([^"]*)"' | sed 's/"//g')
    
    if [ -z "$COMMIT_ID" ]; then
        echo "Không thể lấy commit ID. Sử dụng commit mặc định."
        COMMIT_ID="252e5463d60e63238250799aef7375787f68b4ee"
    fi
    
    echo "Sử dụng VS Code commit: $COMMIT_ID"
    
    # Tạo thư mục cho commit
    mkdir -p "$COMMIT_ID"
    cd "$COMMIT_ID"
    
    # Tải VS Code Server
    wget -q -O vscode-server-linux-x64.tar.gz \
        "https://update.code.visualstudio.com/commit:$COMMIT_ID/server-linux-x64/stable"
    
    # Giải nén
    tar -xzf vscode-server-linux-x64.tar.gz --strip-components=1
    rm vscode-server-linux-x64.tar.gz
    
    # Tạo node file
    touch 0
    
    # Cài đặt extensions
    EXTENSIONS_DIR=~/.vscode-server/extensions
    mkdir -p "$EXTENSIONS_DIR"
    
    echo "VS Code SSH Server đã được cài đặt thành công."
    echo "Khi bạn kết nối qua SSH từ VS Code Desktop, server sẽ được sử dụng tự động."
}

# Cài đặt công cụ để truy cập từ xa
setup_remote_access() {
    echo "Cài đặt truy cập từ xa (tùy chọn)..."
    
    # Cài đặt và cấu hình SSH
    if [ -f /etc/debian_version ]; then
        sudo apt install -y openssh-server
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y openssh-server
    elif [ -f /etc/arch-release ]; then
        sudo pacman -Sy openssh
    fi
    
    # Bắt đầu và kích hoạt SSH
    sudo systemctl enable sshd
    sudo systemctl start sshd
    
    # Cài đặt Nginx để proxy Code Server (tùy chọn)
    echo "Bạn có muốn cài đặt Nginx để proxy Code Server ra internet không? (y/n)"
    read install_nginx
    
    if [ "$install_nginx" = "y" ]; then
        # Cài đặt Nginx
        if [ -f /etc/debian_version ]; then
            sudo apt install -y nginx certbot python3-certbot-nginx
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y nginx certbot python3-certbot-nginx
        elif [ -f /etc/arch-release ]; then
            sudo pacman -Sy nginx certbot certbot-nginx
        fi
        
        # Tạo cấu hình Nginx
        echo "Nhập tên miền của bạn (ví dụ: code.example.com):"
        read domain_name
        
        sudo cat > /etc/nginx/conf.d/code-server.conf << EOF
server {
    listen 80;
    server_name $domain_name;
    
    location / {
        proxy_pass http://localhost:${custom_port};
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
    }
}
EOF
        
        # Khởi động lại Nginx
        sudo systemctl enable nginx
        sudo systemctl restart nginx
        
        # Cài đặt SSL
        echo "Bạn có muốn cài đặt SSL với Let's Encrypt không? (y/n)"
        read install_ssl
        
        if [ "$install_ssl" = "y" ]; then
            sudo certbot --nginx -d "$domain_name"
        fi
        
        echo "Đã cấu hình Nginx! Bạn có thể truy cập Code Server tại https://$domain_name"
    fi
}

# Khởi chạy các chức năng
main() {
    install_dependencies
    
    echo "Chọn các thành phần để cài đặt:"
    echo "1) Cài đặt cả Code Server Web và VS Code SSH Server"
    echo "2) Chỉ cài đặt Code Server Web"
    echo "3) Chỉ cài đặt VS Code SSH Server"
    read -p "Lựa chọn của bạn (1-3): " choice
    
    case $choice in
        1)
            install_code_server
            install_vscode_ssh_server
            ;;
        2)
            install_code_server
            ;;
        3)
            install_vscode_ssh_server
            ;;
        *)
            echo "Lựa chọn không hợp lệ"
            exit 1
            ;;
    esac
    
    echo "Bạn có muốn cài đặt truy cập từ xa (SSH và Nginx)? (y/n)"
    read setup_remote
    
    if [ "$setup_remote" = "y" ]; then
        setup_remote_access
    fi
    
    echo "=== Cài đặt hoàn tất ==="
    echo "Hướng dẫn:"
    echo "- Code Server web có thể truy cập tại http://127.0.0.1:${custom_port}"
    echo "- Để sử dụng VS Code SSH, kết nối từ VS Code Desktop bằng Remote SSH extension"
}

# Chạy script
main
