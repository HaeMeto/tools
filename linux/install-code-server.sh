#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Universal code-server Installer
# =========================================================
#
# Features:
# - User install mode (default)
# - Root/global install mode (--root)
# - Force replace mode (--force)
# - Kill process using same port
# - Disable existing code-server service
# - Ubuntu / Debian
# - AlmaLinux / Rocky / RHEL / CentOS
# - Standalone GitHub release install
# - SELinux compatible
# - Systemd service
#
# =========================================================
#
# Examples:
#
# USER:
# curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
# | bash -s -- MyPassword123
#
# ROOT:
# curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
# | sudo bash -s -- --root MyPassword123
#
# FORCE:
# curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
# | sudo bash -s -- --root --force MyPassword123
#
# CUSTOM PORT:
# curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
# | sudo bash -s -- --root --force MyPassword123 9090
#
# =========================================================

ROOT_MODE=false
FORCE_MODE=false

# =========================================================
# Parse Flags
# =========================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)
            ROOT_MODE=true
            shift
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

# =========================================================
# Args
# =========================================================

if [ $# -lt 1 ]; then
    echo "❌ Password required"
    echo
    echo "Usage:"
    echo "  $0 [--root] [--force] <PASSWORD> [PORT]"
    exit 1
fi

PASSWORD="$1"
PORT="${2:-8081}"

# =========================================================
# Validate Port
# =========================================================

if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid port: $PORT"
    exit 1
fi

# =========================================================
# Environment Check
# =========================================================

echo "[0/12] Checking environment..."

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

    INSTALL_DIR="/opt/code-server"
    BIN_FILE="/usr/local/bin/code-server"

    CONFIG_DIR="/root/.config/code-server"
    CONFIG_FILE="${CONFIG_DIR}/config.yaml"

    SERVICE_FILE="/etc/systemd/system/code-server.service"

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

    INSTALL_DIR="${USER_HOME}/.local/lib/code-server"
    BIN_FILE="${USER_HOME}/.local/bin/code-server"

    CONFIG_DIR="${USER_HOME}/.config/code-server"
    CONFIG_FILE="${CONFIG_DIR}/config.yaml"

    SYSTEMD_DIR="${USER_HOME}/.config/systemd/user"
    SERVICE_FILE="${SYSTEMD_DIR}/code-server.service"

fi

# =========================================================
# Temp Directory
# =========================================================

TMP_DIR="/var/tmp/code-server-installer"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# =========================================================
# Detect OS
# =========================================================

echo "[1/12] Detecting OS..."

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

echo "[2/12] Installing dependencies..."

if [ "$PKG_MANAGER" = "apt" ]; then

    apt update

    apt install -y \
        curl \
        wget \
        tar \
        gzip \
        jq \
        lsof

else

    ${PKG_MANAGER} install -y \
        curl \
        wget \
        tar \
        gzip \
        jq \
        lsof \
        policycoreutils-python-utils || true

fi

# =========================================================
# Force Cleanup
# =========================================================

echo "[3/12] Force cleanup..."

if [ "$FORCE_MODE" = true ]; then

    echo "   Force mode enabled"

    if command -v lsof >/dev/null 2>&1; then

        PORT_PID="$(lsof -ti tcp:${PORT} || true)"

        if [ -n "${PORT_PID}" ]; then

            echo "   Killing process on port ${PORT}:"

            for pid in ${PORT_PID}; do
                echo "      PID ${pid}"
                kill -9 "${pid}" || true
            done
        fi
    fi

    systemctl disable --now code-server >/dev/null 2>&1 || true
    systemctl reset-failed code-server >/dev/null 2>&1 || true

fi

# =========================================================
# Detect Architecture
# =========================================================

echo "[4/12] Detecting architecture..."

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

echo "[5/12] Fetching latest release..."

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

echo "[6/12] Cleaning old installation..."

systemctl stop code-server >/dev/null 2>&1 || true
systemctl disable code-server >/dev/null 2>&1 || true

rm -f "$SERVICE_FILE"

# remove old symlink loop
if [ -L "$BIN_FILE" ]; then
    rm -f "$BIN_FILE"
fi

# remove old install
rm -rf "$INSTALL_DIR"

# cleanup possible broken symlink inside install
rm -f /opt/code-server/bin/code-server || true

mkdir -p "$(dirname "$INSTALL_DIR")"
mkdir -p "$(dirname "$BIN_FILE")"

# =========================================================
# Download
# =========================================================

echo "[7/12] Downloading code-server..."

curl -fL "$DOWNLOAD_URL" -o "$TMP_FILE"

if [ ! -f "$TMP_FILE" ]; then
    echo "❌ Download failed"
    exit 1
fi

# =========================================================
# Extract
# =========================================================

echo "[8/12] Extracting package..."

tar -xzf "$TMP_FILE" -C "$TMP_DIR"

EXTRACTED_DIR="${TMP_DIR}/code-server-${VERSION_NO_V}-linux-${ARCH}"

if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "❌ Extraction failed"
    exit 1
fi

mv "$EXTRACTED_DIR" "$INSTALL_DIR"

# =========================================================
# Create Binary Symlink
# =========================================================

REAL_BINARY="${INSTALL_DIR}/bin/code-server"

if [ ! -f "$REAL_BINARY" ]; then
    echo "❌ Binary not found: $REAL_BINARY"
    exit 1
fi

chmod +x "$REAL_BINARY"

# remove broken symlink first
rm -f "$BIN_FILE"

ln -s "$REAL_BINARY" "$BIN_FILE"

# =========================================================
# SELinux Fix
# =========================================================

if command -v restorecon >/dev/null 2>&1; then
    restorecon -Rv "$INSTALL_DIR" || true
fi

if command -v chcon >/dev/null 2>&1; then
    chcon -Rt bin_t "$INSTALL_DIR" || true
fi

# =========================================================
# Create Config
# =========================================================

echo "[9/12] Creating config..."

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

echo "[10/12] Creating service..."

if [ "$ROOT_MODE" = true ]; then

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
ExecStart=${REAL_BINARY} --config ${CONFIG_FILE}
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
ExecStart=${REAL_BINARY} --config ${CONFIG_FILE}
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

echo "[11/12] Starting service..."

if [ "$ROOT_MODE" = true ]; then

    systemctl daemon-reload
    systemctl reset-failed code-server >/dev/null 2>&1 || true
    systemctl enable --now code-server

else

    sudo loginctl enable-linger "$USER_NAME"

    systemctl --user daemon-reload
    systemctl --user reset-failed code-server >/dev/null 2>&1 || true
    systemctl --user enable --now code-server

fi

sleep 5

# =========================================================
# Firewall
# =========================================================

echo "[12/12] Configuring firewall..."

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
    echo "📂 Install  : ${INSTALL_DIR}"
    echo "⚙️ Config   : ${CONFIG_FILE}"
    echo "🧩 Binary   : ${BIN_FILE}"
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
