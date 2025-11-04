#!/bin/bash
# Script install ttyd + setup service lightweight (root shell)

USER=admin
PASS=pas12345
PORT=8082

echo "===> Update system..."
apt update -y && apt upgrade -y

echo "===> Install dependencies..."
apt install -y build-essential cmake git libjson-c-dev libwebsockets-dev

echo "===> Clone & build ttyd..."
rm -rf /tmp/ttyd
git clone https://github.com/tsl0922/ttyd.git /tmp/ttyd
cd /tmp/ttyd
mkdir build && cd build
cmake ..
make -j$(nproc)
make install

echo "===> Create systemd service..."
cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=ttyd - Web Terminal (Root Shell)
After=network.target

[Service]
ExecStart=/usr/local/bin/ttyd -p ${PORT} -c ${USER}:${PASS} bash
Restart=always
# Pastikan ttyd berjalan sebagai root
User=root
Group=root
WorkingDirectory=/root
# Tambahkan environment agar login penuh
Environment=HOME=/root
Environment=USER=root
Environment=SHELL=/bin/bash
# Jika systemd menggunakan protect defaults, disable
NoNewPrivileges=no
ProtectSystem=off
ProtectHome=off

[Install]
WantedBy=multi-user.target
EOF

echo "===> Enable & Start ttyd service..."
systemctl daemon-reload
systemctl enable ttyd
systemctl restart ttyd

IP=$(hostname -I | awk '{print $1}')
echo "===> Completed!"
echo "Akses terminal web di: http://${IP}:${PORT}"
echo "Login: ${USER} / ${PASS}"
