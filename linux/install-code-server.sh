#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Universal code-server installer
# Supports:
# - Ubuntu / Debian
# - AlmaLinux / RockyLinux / RHEL / CentOS Stream
#
# Usage:
#   ./install-code-server.sh <PASSWORD> [PORT]
#
# Example:
#   ./install-code-server.sh MyStrongPass123 8081
# =========================================================

# ==== Args ====
if [ $# -lt 1 ]; then
  echo "❌ Error: Password required."
  echo "Usage: $0 <PASSWORD> [PORT]"
  exit 1
fi

PASSWORD="$1"
PORT="${2:-8081}"

echo "[0/8] Checking environment..."

if ! command -v sudo >/dev/null 2>&1; then
  echo "❌ sudo is required."
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

# ==== Detect OS ====
echo "[1/8] Detecting operating system..."

if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  echo "❌ Cannot detect OS."
  exit 1
fi

OS_ID="${ID,,}"
OS_LIKE="${ID_LIKE:-}"

echo "   Detected OS: ${PRETTY_NAME}"

PKG_MANAGER=""
INSTALL_CMD=""

if [[ "$OS_ID" =~ (ubuntu|debian) ]] || [[ "$OS_LIKE" =~ debian ]]; then
  PKG_MANAGER="apt"
  INSTALL_CMD="sudo apt install -y"
elif [[ "$OS_ID" =~ (almalinux|rocky|rhel|centos|fedora) ]] || [[ "$OS_LIKE" =~ (rhel|fedora) ]]; then
  if command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    INSTALL_CMD="sudo dnf install -y"
  else
    PKG_MANAGER="yum"
    INSTALL_CMD="sudo yum install -y"
  fi
else
  echo "❌ Unsupported OS: ${OS_ID}"
  exit 1
fi

# ==== Cleanup old installation ====
echo "[2/8] Cleaning old installation..."

if systemctl list-unit-files | grep -q "^code-server.service"; then
  echo "   ⚠️  Existing code-server service found."

  sudo systemctl stop code-server || true
  sudo systemctl disable code-server || true

  sudo rm -f "$SERVICE_FILE"

  sudo systemctl daemon-reload
fi

# Remove package
if command -v code-server >/dev/null 2>&1; then
  echo "   ⚠️  Removing old package..."

  if [ "$PKG_MANAGER" = "apt" ]; then
    sudo apt remove --purge -y code-server || true
  else
    sudo ${PKG_MANAGER} remove -y code-server || true
  fi
fi

# Remove config
if [ -d "$CONFIG_DIR" ]; then
  echo "   ⚠️  Removing old config..."
  sudo rm -rf "$CONFIG_DIR"
fi

echo "   ✅ Cleanup completed."

# ==== Install dependencies ====
echo "[3/8] Installing dependencies..."

if [ "$PKG_MANAGER" = "apt" ]; then
  sudo apt update
  ${INSTALL_CMD} curl wget tar gzip
else
  ${INSTALL_CMD} curl wget tar gzip
fi

# ==== Install code-server ====
echo "[4/8] Installing code-server..."

curl -fsSL https://code-server.dev/install.sh | sh

# ==== Create config ====
echo "[5/8] Writing config.yaml..."

sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"

sudo -u "$USER_NAME" tee "$CONFIG_FILE" >/dev/null <<EOF
bind-addr: 0.0.0.0:${PORT}
auth: password
password: ${PASSWORD}
cert: false
EOF

sudo chown -R "$USER_NAME":"$USER_NAME" "$CONFIG_DIR"

# ==== Create systemd service ====
echo "[6/8] Creating systemd service..."

CODE_SERVER_BIN="$(command -v code-server)"

if [ -z "$CODE_SERVER_BIN" ]; then
  echo "❌ code-server binary not found."
  exit 1
fi

sudo tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
User=${USER_NAME}
Group=${USER_NAME}
Environment=HOME=${USER_HOME}
WorkingDirectory=${USER_HOME}
ExecStart=${CODE_SERVER_BIN}
Restart=always
RestartSec=3

# Hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# ==== Enable service ====
echo "[7/8] Enabling service..."

sudo systemctl daemon-reload
sudo systemctl enable --now code-server

sleep 2

# ==== Firewall ====
echo "[8/8] Configuring firewall..."

if command -v firewall-cmd >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-port=${PORT}/tcp || true
  sudo firewall-cmd --reload || true
  echo "   ✅ firewalld updated."
elif command -v ufw >/dev/null 2>&1; then
  sudo ufw allow ${PORT}/tcp || true
  echo "   ✅ ufw updated."
else
  echo "   ⚠️  No supported firewall detected."
fi

# ==== Status ====
echo
if systemctl --quiet is-active code-server; then
  SERVER_IP="$(hostname -I | awk '{print $1}')"

  echo "================================================="
  echo "✅ code-server installed successfully!"
  echo "================================================="
  echo "🌐 URL      : http://${SERVER_IP}:${PORT}"
  echo "👤 User     : ${USER_NAME}"
  echo "🔐 Password : ${PASSWORD}"
  echo "🗂  Config   : ${CONFIG_FILE}"
  echo "🧩 Service  : ${SERVICE_FILE}"
  echo
  echo "📋 Commands:"
  echo "   sudo systemctl status code-server"
  echo "   sudo journalctl -u code-server -f"
  echo "   sudo systemctl restart code-server"
  echo "================================================="
else
  echo "❌ code-server service failed to start."
  echo
  echo "Check logs with:"
  echo "sudo journalctl -u code-server -f"
  exit 1
fi
