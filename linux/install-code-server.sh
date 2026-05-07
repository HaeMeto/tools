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
# - Safer temp handling (/var/tmp)
# - Systemd service
#
# =========================================================
#
# INSTALLATION EXAMPLES
# =========================================================
#
# ---------------------------------------------------------
# USER MODE (recommended)
# ---------------------------------------------------------
#
# Install to:
#   ~/.local/lib/code-server
#
# Binary:
#   ~/.local/bin/code-server
#
# Run:
#
#   curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
#   | bash -s -- MyPassword123
#
# Custom port:
#
#   curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
#   | bash -s -- MyPassword123 9090
#
# ---------------------------------------------------------
# ROOT MODE
# ---------------------------------------------------------
#
# Install to:
#   /opt/code-server
#
# Binary:
#   /usr/local/bin/code-server
#
# Run:
#
#   curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
#   | sudo bash -s -- --root MyPassword123
#
# Custom port:
#
#   curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
#   | sudo bash -s -- --root MyPassword123 9090
#
# =========================================================
#
# ACCESS
# =========================================================
#
# Default:
#
#   http://SERVER_IP:8081
#
# Example:
#
#   http://192.168.1.10:8081
#
# =========================================================
#
# SERVICE COMMANDS
# =========================================================
#
# USER MODE:
#
#   systemctl --user status code-server
#   systemctl --user restart code-server
#   journalctl --user -u code-server -f
#
# ROOT MODE:
#
#   systemctl status code-server
#   systemctl restart code-server
#   journalctl -u code-server -f
#
# =========================================================

ROOT_MODE=false

# =========================================================
# Parse Flags
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

echo "[0/11] Checking environment..."

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
# Temp Directory
# =========================================================

TMP_DIR="/var/tmp/code-server-installer"

mkdir -p "$TMP_DIR"
chmod 777 "$TMP_DIR"

# =========================================================
# Detect OS
# =========================================================

echo "[1/11] Detecting OS..."

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

echo "[2/11] Installing dependencies..."

if [ "$PKG_MANAGER" = "apt" ]; then

    apt update

    apt install -y \
        curl \
        wget \
        tar \
        gzip \
        jq

else

    ${PKG_MANAGER} install -y \
        curl \
        wget \
        tar \
        gzip \
        jq

fi

# =========================================================
# Detect Architecture
# =========================================================

echo "[3/11] Detecting architecture..."

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
# Fetch Latest Release
# =========================================================

echo "[4/11] Fetching latest release..."

LATEST_VERSION="$(
    curl -fsSL https://api.github.com/repos/coder/code-server/releases/latest \
    | jq -r '.tag_name'
)"

if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
    echo "❌ Failed to fetch latest release"
    exit 1
fi

echo "   Latest version: ${LATEST_VERSION}"

VERSION_NO_V="${LATEST_VERSION#v}"

FILE_NAME="code-server-${VERSION_NO_V}-linux-${ARCH}.tar.gz"

DOWNLOAD_URL="https://github.com/coder/code-server/releases/download/${LATEST_VERSION}/${FILE_NAME}"

TMP_FILE="${TMP_DIR}/${FILE_NAME}"

# =========================================================
# Cleanup Old Installation
# =========================================================

echo "[5/11] Cleaning old installation..."

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
# Download
# =========================================================

echo "[6/11] Downloading code-server..."

curl -fL "$DOWNLOAD_URL" -o "$TMP_FILE"

if [ ! -f "$TMP_FILE" ]; then
    echo "❌ Download failed"
    exit 1
fi

# =========================================================
# Extract
# =========================================================

echo "[7/11] Extracting package..."

tar -xzf "$TMP_FILE" -C "$TMP_DIR"

EXTRACTED_DIR="${TMP_DIR}/code-server-${VERSION_NO_V}-linux-${ARCH}"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "❌ Extraction failed"
    exit 1
fi

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

echo "[8/11] Creating config..."

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

echo "[9/11] Creating service..."

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

echo "[10/11] Starting service..."

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

echo "[11/11] Configuring firewall..."

if command -v firewall-cmd >/dev/null 2>&1; then

    firewall-cmd --permanent --add-port=${PORT}/tcp || true
    firewall-cmd --reload || true

elif command -v ufw >/dev/null 2>&1; then

    ufw allow ${PORT}/tcp || true

fi

# =========================================================
# Cleanup Temp
# =========================================================

rm -rf "$TMP_DIR"

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

    if [ "$ROOT_MODE" = true ]; then
        journalctl -u code-server --no-pager -n 50
    else
        journalctl --user -u code-server --no-pager -n 50
    fi

    exit 1

fi
