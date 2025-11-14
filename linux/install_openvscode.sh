#!/bin/bash

# ============================
#  USAGE
# chmod +x install_openvscode.sh
# ./install_openvscode.sh 8080 mytoken123
# ============================

# ============================
#  CONFIG
# ============================
PORT="${1:-3000}"          # Argumen 1 = port (default 3000)
TOKEN="${2:-secret123}"    # Argumen 2 = token (default secret123)
INSTALL_DIR="/opt/openvscode-server"
SERVICE_NAME="openvscode-server"

# ============================
#  DOWNLOAD BINARY
# ============================
echo "[*] Downloading latest OpenVSCode Server..."

LATEST_URL=$(curl -s https://api.github.com/repos/gitpod-io/openvscode-server/releases/latest \
  | grep browser_download_url \
  | grep linux-x64.tar.gz \
  | cut -d '"' -f 4)

wget -O /tmp/openvscode.tar.gz "$LATEST_URL"

echo "[*] Extracting..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf /tmp/openvscode.tar.gz -C "$INSTALL_DIR" --strip-components=1

# ============================
#  CREATE SYSTEMD SERVICE
# ============================
echo "[*] Creating systemd service..."

cat >/etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=OpenVSCode Server (OSS)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/bin/openvscode-server \
    --port $PORT \
    --without-connection-token \
    --connection-token "$TOKEN" \
    --host 0.0.0.0 \
    --disable-telemetry

Restart=always
RestartSec=10

# CPUQuota=80%
MemoryMax=2G

[Install]
WantedBy=multi-user.target
EOF

# ============================
#  ENABLE & START
# ============================
systemctl daemon-reload
systemctl enable $SERVICE_NAME
systemctl restart $SERVICE_NAME

echo
echo "======================================="
echo "OpenVSCode Server installed & running!"
echo "Port  : $PORT"
echo "Token : $TOKEN"
echo "URL   : http://YOUR-IP:$PORT/?t=$TOKEN"
echo "======================================="
