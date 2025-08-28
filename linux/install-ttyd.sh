#!/bin/bash
# Script install ttyd + setup service lightweight

USER=admin
PASS=pas12345
PORT=8082

echo "===> Update system..."
apt update && apt upgrade -y

echo "===> Install dependencies..."
apt install -y build-essential cmake git libjson-c-dev libwebsockets-dev

echo "===> Clone & build ttyd..."
git clone https://github.com/tsl0922/ttyd.git /tmp/ttyd
cd /tmp/ttyd
mkdir build && cd build
cmake ..
make
make install

echo "===> Generate systemd service..."
cat > /etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=ttyd - Web Terminal
After=network.target

[Service]
ExecStart=/usr/local/bin/ttyd -p $PORT -c $USER:$PASS bash
Restart=always
User=root
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF

echo "===> Enable & Start ttyd service..."
systemctl daemon-reload
systemctl enable ttyd
systemctl start ttyd

echo "===> Completed!"
echo "Akses terminal web di: http://$(hostname -I | awk '{print $1}'):$PORT"
echo "Login: $USER / $PASS"
