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

echo "[1/6] Installing dependencies..."
sudo apt update
sudo apt install -y curl coreutils

echo "[2/6] Installing code-server..."
curl -fsSL https://code-server.dev/install.sh | sh

# ==== DETEKSI OS ====
OS_NAME=$(grep "^ID=" /etc/os-release | cut -d= -f2 | tr -d '"')

if [[ "$OS_NAME" == "debian" ]]; then
  echo "[3/6] Skip running code-server on Debian (generate config skipped)"
else
  echo "[3/6] Running code-server once to generate default config..."
  runuser -l "$USER_NAME" -c "timeout 5s code-server --bind-addr 127.0.0.1:0 --auth password >/dev/null 2>&1 || true"

  if pgrep -u "$USER_NAME" -f 'code-server' >/dev/null 2>&1; then
    echo "   ⛔ Killing leftover code-server process..."
    pkill -u "$USER_NAME" -f 'code-server' || true
  fi
fi

echo "[4/6] Writing config.yaml..."
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"
sudo -u "$USER_NAME" tee "$CONFIG_FILE" >/dev/null <<EOF
bind-addr: 0.0.0.0:${PORT}
auth: password
password: ${PASSWORD}
cert: false
EOF

echo "[5/6] Creating systemd service..."
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
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

echo "[6/6] Enabling and starting service..."
sudo systemctl daemon-reload
sudo systemctl enable code-server
sudo systemctl restart code-server

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
