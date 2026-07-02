#!/usr/bin/env bash
set -Eeuo pipefail

TTYD_VERSION="1.7.7"
ZELLIJ_VERSION="0.44.3"
YAZI_VERSION="25.5.31"

TTYD_PORT="${TTYD_PORT:-7681}"
TTYD_USER="${TTYD_USER:-admin}"
TTYD_PASS="${TTYD_PASS:-changeme}"
SESSION_NAME="${SESSION_NAME:-main}"

[[ $EUID -eq 0 ]] || { echo "Please run as root."; exit 1; }

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64)
    TTYD_FILE="ttyd.x86_64"
    ZELLIJ_FILE="zellij-x86_64-unknown-linux-musl.tar.gz"
    YAZI_FILE="yazi-x86_64-unknown-linux-musl.zip"
    ;;
  aarch64|arm64)
    TTYD_FILE="ttyd.aarch64"
    ZELLIJ_FILE="zellij-aarch64-unknown-linux-musl.tar.gz"
    YAZI_FILE="yazi-aarch64-unknown-linux-musl.zip"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

apt update
apt install -y \
  curl wget tar unzip xz-utils ca-certificates \
  ffmpeg jq poppler-utils file fd-find ripgrep \
  fzf zoxide imagemagick

if command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
  ln -sf "$(command -v fdfind)" /usr/local/bin/fd
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "Installing ttyd..."
wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/${TTYD_FILE}"
install -Dm755 "$TTYD_FILE" /usr/local/bin/ttyd

echo "Installing Zellij..."
wget -q "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/${ZELLIJ_FILE}"
tar -xzf "$ZELLIJ_FILE"
install -Dm755 zellij /usr/local/bin/zellij

echo "Installing Yazi..."
wget -q "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/${YAZI_FILE}"
unzip -q "$YAZI_FILE"
YDIR="$(find . -maxdepth 1 -type d -name 'yazi-*' | head -n1)"
install -Dm755 "$YDIR/yazi" /usr/local/bin/yazi
install -Dm755 "$YDIR/ya" /usr/local/bin/ya

cat >/etc/systemd/system/ttyd.service <<EOF
[Unit]
Description=ttyd + Zellij Web Terminal
After=network.target

[Service]
User=root
WorkingDirectory=/root
Environment=TERM=xterm-256color
ExecStart=/usr/local/bin/ttyd -W -p ${TTYD_PORT} -c ${TTYD_USER}:${TTYD_PASS} bash
Restart=always
RestartSec=3
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ttyd

echo
echo "===== Installed ====="
ttyd --version || true
zellij --version || true
yazi --version || true
echo
echo "URL: http://SERVER_IP:${TTYD_PORT}"
echo "Username: ${TTYD_USER}"
echo "Password: ${TTYD_PASS}"
echo
echo "Useful commands:"
echo " systemctl status ttyd"
echo " journalctl -u ttyd -f"
echo " zellij list-sessions"
echo " yazi"
