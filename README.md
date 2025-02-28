# 🛠️ **Zynther Setup Script** 🖥️

Chào mừng đến với repository **Zynther**, công cụ giúp bạn thiết lập nhanh chóng các hệ thống web, giám sát mạng, cPanel, và VSCode Server một cách đơn giản chỉ bằng một dòng lệnh!

## 🔥 **Giới Thiệu**

**Zynther.sh** là một script shell giúp bạn cài đặt và cấu hình nhanh các dịch vụ như:
- Web Server (Apache/Nginx)
- Giám sát mạng
- Cài đặt cPanel
- Cài đặt và cấu hình VSCode Server
- Và nhiều công cụ hữu ích khác

### 📦 **Cài Đặt (cho Ubuntu 22.04_64bit)** 

Để cài đặt và sử dụng script, chỉ cần thực hiện các bước dưới đây:

```bash
# Clone repository về máy
git clone https://github.com/quangminhlh/fs.git

# Cấp quyền cho file setup
chmod +x ./fs/zynther.sh

# Thực thi file setup
./fs/zynther.sh
```

### **Cài đặt bản Mini**
```bash
# Clone repository về máy
git clone https://github.com/quangminhlh/fs.git

# Cấp quyền cho file setup
chmod +x ./fs/zynther_mini.sh

# Thực thi file setup
./fs/zynther_mini.sh
```

### **Cài đặt bản Panel Minecraft**
```bash
# Clone repository về máy
git clone https://github.com/quangminhlh/fs.git

# Cấp quyền cho file setup
chmod +x ./fs/zmine.sh

# Thực thi file setup
./fs/zmine.sh
```

### **Cài đặt bản VSCODE-SERVER**
```bash
# Clone repository về máy
git clone https://github.com/quangminhlh/fs.git

# Cấp quyền cho file setup
chmod +x ./fs/zmine.sh

# Thực thi file setup
./fs/zmine.sh
```

## 📌 **Nếu bạn vừa cài lại hệ điều hành cho server và không kết nối được SSH**
Lỗi này xảy ra khi SSH phát hiện rằng khóa máy chủ mà bạn đang kết nối đã thay đổi. Điều này có thể do:
1. **Máy chủ thay đổi khóa SSH** (do cài đặt lại, cập nhật, v.v.).
2. **Tấn công Man-in-the-Middle (MITM)**, nơi một bên thứ ba có thể đang giả mạo máy chủ.

## 🛠️ **Cách Sửa Lỗi**
### **1. Xóa khóa SSH cũ**
Để xóa khóa cũ của máy chủ và giải quyết lỗi, bạn có thể sử dụng lệnh sau trong terminal của bạn:

```bash
ssh-keygen -R ip_server_của_bạn
