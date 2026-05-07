#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Universal code-server Installer
# =========================================================
#
# Features:
# - User install mode (default)
# - Root/global install mode (--root)
# - Ubuntu / Debian
# - AlmaLinux / Rocky / RHEL / CentOS
# - Standalone GitHub release install
# - Systemd service
#
# =========================================================
#
# USER MODE (recommended)
# -----------------------
# Install:
#   ~/.local/lib/code-server
#
# Binary:
#   ~/.local/bin/code-server
#
# Service:
#   systemctl --user
#
# =========================================================
#
# ROOT MODE
# ----------
# Install:
#   /opt/code-server
#
# Binary:
#   /usr/local/bin/code-server
#
# Service:
#   systemctl
#
# =========================================================
#
# Usage:
#
# USER MODE:
#   ./install-code-server.sh <PASSWORD> [PORT]
#
# ROOT MODE:
#   sudo ./install-code-server.sh --root <PASSWORD> [PORT]
#
# Example:
#
# User mode:
#   ./install-code-server.sh MyPassword123 8081
#
# Root mode:
#   sudo ./install-code-server.sh --root MyPassword123 8081
#
# =========================================================

ROOT_MODE=false

# =========================================================
# Parse flags
# =========================================================

if [[ "${1:-}" == "--root" ]]; then
    ROOT_MODE=true
    shift
fi

# =========================================================
# Args
# =========================================================

if [ $# -lt 1 ]; then
    echo "❌ Password required"
    echo
    echo "Usage:"
    echo "  $0 [--root] <PASSWORD> [PORT]"
    exit 1
fi

PASSWORD="$1"
PORT="${2:-8081}"

# =========================================================
# Environment Check
# =========================================================

echo "[0/10] Checking environment..."

if ! command -v sudo >/dev/null 2>&1; then
    echo "❌ sudo is required"
    exit 1
fi

CURRENT_USER="$(whoami)"

# =========================================================
# Root Mode
# =========================================================

if [ "$ROOT_MODE" = true ]; then

    echo "   Install mode: ROOT"

    if [ "$EUID" -ne 0 ]; then
        echo "❌ Root mode requires sudo/root"
        exit 1
    fi

    USER_NAME="root"
    USER_HOME="/root"

    INSTALL_BASE="/opt"
    BIN_DIR="/usr/local/bin"

    CONFIG_DIR="/root/.config/code-server"
    CONFIG_FILE="${CONFIG_DIR}/config.yaml"

    SERVICE_FILE="/etc/systemd/system/code-server.service"

# =========================================================
# User Mode
# =========================================================

else

    echo "   Install mode: USER"

    if [ "$CURRENT_USER" = "root" ]; then
        echo "❌ Do not run user mode as root"
        echo "👉 Use normal user"
        echo "👉 Or use --root"
        exit 1
    fi

    USER_NAME="$CURRENT_USER"

    USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

    INSTALL_BASE="${USER_HOME}/.local/lib"
    BIN_DIR="${USER_HOME}/.local/bin"

    CONFIG_DIR="${USER_HOME}/.config/code-server"
    CONFIG_FILE="${CONFIG_DIR}/config.yaml"

    SYSTEMD_DIR="${USER_HOME}/.config/systemd/user"
    SERVICE_FILE="${SYSTEMD_DIR}/code-server.service"

fi

# =========================================================
# Detect OS
# =========================================================

echo "[1/10] Detecting OS..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "❌ Cannot detect OS"
    exit 1
fi

OS_ID="${ID,,}"
OS_LIKE="${ID_LIKE:-}"

echo "   OS: ${PRETTY_NAME}"

PKG_MANAGER=""

if [[ "$OS_ID" =~ (ubuntu|debian) ]] || [[ "$OS_LIKE" =~ debian ]]; then

    PKG_MANAGER="apt"

elif [[ "$OS_ID" =~ (almalinux|rocky|rhel|centos|fedora) ]] || [[ "$OS_LIKE" =~ (rhel|fedora) ]]; then

    if command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi

else

    echo "❌ Unsupported OS"
    exit 1

fi

# =========================================================
# Install Dependencies
# =========================================================

echo "[2/10] Installing dependencies..."

if [ "$PKG_MANAGER" = "apt" ]; then

    sudo apt update

    sudo apt install -y \
        curl \
        wget \
        tar \
        gzip \
        jq

else

    sudo ${PKG_MANAGER} install -y \
        curl \
        wget \
        tar \
        gzip \
        jq

fi

# =========================================================
# Detect Architecture
# =========================================================

echo "[3/10] Detecting architecture..."

ARCH="$(uname -m)"

case "$ARCH" in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        echo "❌ Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "   Architecture: $ARCH"

# =========================================================
# Get Latest Release
# =========================================================

echo "[4/10] Fetching latest release..."

LATEST_VERSION="$(
    curl -fsSL https://api.github.com/repos/coder/code-server/releases/latest \
    | jq -r '.tag_name'
)"

if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
    echo "❌ Failed to get latest version"
    exit 1
fi

echo "   Latest version: ${LATEST_VERSION}"

VERSION_NO_V="${LATEST_VERSION#v}"

FILE_NAME="code-server-${VERSION_NO_V}-linux-${ARCH}.tar.gz"

DOWNLOAD_URL="https://github.com/coder/code-server/releases/download/${LATEST_VERSION}/${FILE_NAME}"

TMP_FILE="/tmp/${FILE_NAME}"

# =========================================================
# Cleanup Old Install
# =========================================================

echo "[5/10] Cleaning old installation..."

if [ "$ROOT_MODE" = true ]; then

    systemctl stop code-server >/dev/null 2>&1 || true
    systemctl disable code-server >/dev/null 2>&1 || true

    rm -f "$SERVICE_FILE"

else

    systemctl --user stop code-server >/dev/null 2>&1 || true
    systemctl --user disable code-server >/dev/null 2>&1 || true

fi

rm -rf "${INSTALL_BASE}/code-server"
rm -f "${BIN_DIR}/code-server"

mkdir -p "$INSTALL_BASE"
mkdir -p "$BIN_DIR"

# =========================================================
# Download & Install
# =========================================================

echo "[6/10] Installing code-server..."

echo "   Downloading ${FILE_NAME}..."

curl -fL "$DOWNLOAD_URL" -o "$TMP_FILE"

echo "   Extracting..."

tar -xzf "$TMP_FILE" -C /tmp

EXTRACTED_DIR="/tmp/code-server-${VERSION_NO_V}-linux-${ARCH}"

mv "$EXTRACTED_DIR" "${INSTALL_BASE}/code-server"

ln -sf \
    "${INSTALL_BASE}/code-server/bin/code-server" \
    "${BIN_DIR}/code-server"

# =========================================================
# PATH
# =========================================================

if [ "$ROOT_MODE" = false ]; then

    if ! grep -q '.local/bin' "${USER_HOME}/.bashrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${USER_HOME}/.bashrc"
    fi

    export PATH="${BIN_DIR}:$PATH"

fi

# =========================================================
# Create Config
# =========================================================

echo "[7/10] Creating config..."

mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_FILE" <<EOF
bind-addr: 0.0.0.0:${PORT}
auth: password
password: ${PASSWORD}
cert: false
EOF

# =========================================================
# Create Service
# =========================================================

echo "[8/10] Creating service..."

if [ "$ROOT_MODE" = true ]; then

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/code-server
Restart=always
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

else

mkdir -p "$SYSTEMD_DIR"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/code-server
Restart=always
RestartSec=5

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full

[Install]
WantedBy=default.target
EOF

fi

# =========================================================
# Start Service
# =========================================================

echo "[9/10] Starting service..."

if [ "$ROOT_MODE" = true ]; then

    systemctl daemon-reload
    systemctl enable --now code-server

else

    sudo loginctl enable-linger "$USER_NAME"

    systemctl --user daemon-reload
    systemctl --user enable --now code-server

fi

sleep 3

# =========================================================
# Firewall
# =========================================================

echo "[10/10] Configuring firewall..."

if command -v firewall-cmd >/dev/null 2>&1; then

    sudo firewall-cmd --permanent --add-port=${PORT}/tcp || true
    sudo firewall-cmd --reload || true

elif command -v ufw >/dev/null 2>&1; then

    sudo ufw allow ${PORT}/tcp || true

fi

# =========================================================
# Status
# =========================================================

echo

if [ "$ROOT_MODE" = true ]; then

    ACTIVE_CMD="systemctl is-active --quiet code-server"

else

    ACTIVE_CMD="systemctl --user is-active --quiet code-server"

fi

if eval "$ACTIVE_CMD"; then

    SERVER_IP="$(hostname -I | awk '{print $1}')"

    echo "=================================================="
    echo "✅ code-server installed successfully"
    echo "=================================================="
    echo "🌐 URL      : http://${SERVER_IP}:${PORT}"
    echo "👤 User     : ${USER_NAME}"
    echo "🔐 Password : ${PASSWORD}"
    echo
    echo "📂 Install  : ${INSTALL_BASE}/code-server"
    echo "⚙️ Config   : ${CONFIG_FILE}"
    echo "🧩 Binary   : ${BIN_DIR}/code-server"
    echo

    if [ "$ROOT_MODE" = true ]; then

        echo "📋 Commands:"
        echo
        echo "systemctl status code-server"
        echo "systemctl restart code-server"
        echo "journalctl -u code-server -f"

    else

        echo "📋 Commands:"
        echo
        echo "systemctl --user status code-server"
        echo "systemctl --user restart code-server"
        echo "journalctl --user -u code-server -f"

    fi

    echo
    echo "=================================================="

else

    echo "❌ code-server failed to start"

    exit 1

fi
