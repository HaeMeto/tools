#!/bin/bash
set -euo pipefail

# ==== Usage & Args ====
# ./install-code-server.sh <PASSWORD> [PORT]
if [ $# -lt 1 ]; then
  echo "❌ Error: Password required."
  echo "Usage: $0 <PASSWORD> [PORT]"
  exit 1
fi

PASSWORD="$1"
PORT="${2:-8081}"

echo "[0/6] Checking environment..."
if ! command -v sudo >/dev/null 2>&1; then
  echo "❌ sudo is required. Please install or run as a user with sudo privileges."
  exit 1
fi

USER_NAME="$(whoami)"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
if [ -z "${USER_HOME}" ] || [ ! -d "${USER_HOME}" ]; then
  echo "❌ Cannot determine home directory for user: $USER_NAME"
  exit 1
fi

CONFIG_DIR="${USER_HOME}/.config/code-server"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
SERVICE_FILE="/etc/systemd/system/code-server.service"

# === [PRE-STEP] Bersihkan jika ada instalasi lama ===
echo "[PRE] Checking existing code-server installation..."
if systemctl list-unit-files | grep -q "code-server.service"; then
  echo "   ⚠️  Old code-server found. Removing..."
  sudo systemctl stop code-server || true
  sudo systemctl disable code-server || true
  sudo rm -f "$SERVICE_FILE"
  sudo systemctl daemon-reload
fi

if dpkg -l | grep -q code-server; then
  echo "   ⚠️  Removing old code-server package..."
  sudo apt remove --purge -y code-server || true
fi

if [ -d "$CONFIG_DIR" ]; then
  echo "   ⚠️  Removing old config directory..."
  sudo rm -rf "$CONFIG_DIR"
fi

echo "   ✅ Cleanup done (or skipped if nothing installed)."

# === [1/6] Install dependencies ===
echo "[1/6] Installing dependencies..."
sudo apt update
sudo apt install -y curl coreutils

# === [2/6] Install code-server baru ===
echo "[2/6] Installing code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

# === [3/6] Generate config tanpa jalankan sementara ===
echo "[3/6] Writing config.yaml..."
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"
sudo -u "$USER_NAME" tee "$CONFIG_FILE" >/dev/null <<EOF
bind-addr: 0.0.0.0:${PORT}
auth: password
password: ${PASSWORD}
cert: false
EOF
sudo chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR"

# === [4/6] Buat systemd service ===
echo "[4/6] Creating systemd service..."
sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=${USER_NAME}
Environment=HOME=${USER_HOME}
WorkingDirectory=${USER_HOME}
ExecStart=/usr/bin/code-server
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# === [5/6] Enable & Start service ===
echo "[5/6] Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable --now code-server

sleep 1
if systemctl --no-pager --quiet is-active code-server; then
  echo "✅ code-server installed and running!"
  echo "🌐 Access: http://<your-server-ip>:${PORT}"
  echo "👤 User:   ${USER_NAME}"
  echo "🔐 Password: ${PASSWORD}"
  echo "🗂  Config file: ${CONFIG_FILE}"
  echo "🧩 Systemd service: ${SERVICE_FILE}"
else
  echo "⚠️  code-server service is not active. Check logs using:"
  echo "    sudo journalctl -u code-server -f"
fi
