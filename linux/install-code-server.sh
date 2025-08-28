#!/bin/bash

set -e

# ==== Ambil password dari argumen ====
if [ -z "$1" ]; then
  echo "❌ Error: Password belum diberikan."
  echo "Cara pakai: ./install-code-server.sh <PASSWORD>"
  exit 1
fi

PASSWORD="$1"

# ==== Konfigurasi lainnya ====
PORT=8081
USER_NAME=$(whoami)
HOME_DIR="/home"
CONFIG_DIR="/root/.config/code-server"
SERVICE_FILE="/etc/systemd/system/code-server.service"

echo "[1/6] Installing dependencies..."
sudo apt update
sudo apt install -y curl

echo "[2/6] Installing code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

echo "[3/6] Generate default config by running once..."
runuser -l "$USER_NAME" -c "code-server --auth password || true"

echo "[4/6] Modify config.yaml..."
CONFIG_FILE="$CONFIG_DIR/config.yaml"

# Ganti bind-addr, auth, password, dan cert secara aman
sed -i "s/^bind-addr:.*/bind-addr: 0.0.0.0:$PORT/" "$CONFIG_FILE"
sed -i "s/^auth:.*/auth: password/" "$CONFIG_FILE"
sed -i "s/^password:.*/password: $PASSWORD/" "$CONFIG_FILE"
sed -i "s/^cert:.*/cert: false/" "$CONFIG_FILE"

echo "[5/6] Creating systemd service..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$HOME_DIR
ExecStart=/usr/bin/code-server
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "[6/6] Enabling and starting service..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable code-server
sudo systemctl restart code-server

echo "✅ code-server installed and running!"
echo "🌐 Access: http://<your-server-ip>:$PORT"
echo "🔐 Password: $PASSWORD"
