#!/usr/bin/env bash
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

# ==== Privilege helper (root or sudo) ====
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
else
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "❌ Need root or sudo. Run as root or install sudo first."
    exit 1
  fi
fi

# ==== OS / init detection ====
OS_ID="unknown"
OS_ID_LIKE=""
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-unknown}"
  OS_ID_LIKE="${ID_LIKE:-}"
fi

is_like() { echo "$OS_ID $OS_ID_LIKE" | tr ' ' '\n' | grep -qi "$1"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

INIT_SYSTEM="systemd"
if has_cmd systemctl; then
  INIT_SYSTEM="systemd"
elif has_cmd rc-status || [ -d /run/openrc ]; then
  INIT_SYSTEM="openrc"
fi

echo "[0/7] Detected OS: id=${OS_ID} like=${OS_ID_LIKE} init=${INIT_SYSTEM}"

# ==== User / Home detection ====
USER_NAME="$(whoami)"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6 || true)"
if [ -z "${USER_HOME}" ] || [ ! -d "${USER_HOME}" ]; then
  echo "❌ Cannot determine home directory for user: $USER_NAME"
  exit 1
fi

CONFIG_DIR="${USER_HOME}/.config/code-server"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"

# ==== Package install helper ====
pkg_update_install() {
  if has_cmd apt-get; then
    echo "[1/7] Installing dependencies with apt..."
    $SUDO apt-get update -y
    $SUDO apt-get install -y curl ca-certificates coreutils bash
  elif has_cmd dnf; then
    echo "[1/7] Installing dependencies with dnf..."
    $SUDO dnf -y install curl ca-certificates coreutils bash which
  elif has_cmd yum; then
    echo "[1/7] Installing dependencies with yum..."
    $SUDO yum -y install curl ca-certificates coreutils bash which
  elif has_cmd apk; then
    echo "[1/7] Installing dependencies with apk..."
    $SUDO apk update
    # libc6-compat penting untuk binary glibc di Alpine
    $SUDO apk add --no-cache curl ca-certificates coreutils bash libc6-compat
    # Pastikan certs di-update
    $SUDO update-ca-certificates || true
  elif has_cmd zypper; then
    echo "[1/7] Installing dependencies with zypper..."
    $SUDO zypper --non-interactive refresh
    $SUDO zypper --non-interactive install curl ca-certificates coreutils bash
  else
    echo "❌ Unsupported package manager. Install manually: curl, ca-certificates, coreutils, bash"
    exit 1
  fi
}

pkg_update_install

# ==== Install code-server (official script) ====
echo "[2/7] Installing code-server..."
# Gunakan metode standalone agar konsisten lintas distro
curl -fsSL https://code-server.dev/install.sh | $SUDO sh -s -- --method=standalone >/dev/null

# Cari path binary terpasang
CS_BIN="/usr/bin/code-server"
if ! has_cmd code-server; then
  # installer standalone menaruh di /usr/lib/code-server/bin/code-server + symlink
  if [ -x /usr/lib/code-server/bin/code-server ]; then
    $SUDO ln -sf /usr/lib/code-server/bin/code-server /usr/bin/code-server
  fi
fi



# ==== (Optional) Bootstrap config (skip on Debian if diminta sebelumnya) ====
if [ "$OS_ID" = "debian" ]; then
  echo "[3/7] Debian detected → skip warm-up run (as requested)"
else
  echo "[3/7] Warming up code-server to generate defaults..."
  # Jalankan singkat untuk generate folder config default
  if has_cmd runuser; then
    $SUDO runuser -l "$USER_NAME" -c "timeout 5s code-server --bind-addr 127.0.0.1:0 --auth password >/dev/null 2>&1 || true"
  else
    # Fallback jika runuser tidak ada
    timeout 5s code-server --bind-addr 127.0.0.1:0 --auth password >/dev/null 2>&1 || true
  fi
  # Tutup proses kalau masih hidup
  if pgrep -u "$USER_NAME" -f 'code-server' >/dev/null 2>&1; then
    echo "   ⛔ Killing leftover code-server process..."
    $SUDO pkill -u "$USER_NAME" -f 'code-server' || true
  fi
fi

# ==== Write config.yaml ====
echo "[4/7] Writing config.yaml..."
$SUDO -u "$USER_NAME" mkdir -p "$CONFIG_DIR"
$SUDO -u "$USER_NAME" tee "$CONFIG_FILE" >/dev/null <<EOF
bind-addr: 0.0.0.0:${PORT}
auth: password
password: ${PASSWORD}
cert: false
EOF

# ==== Service files (systemd or openrc) ====
if [ "$INIT_SYSTEM" = "systemd" ]; then
  echo "[5/7] Creating systemd service..."
  SERVICE_FILE="/etc/systemd/system/code-server.service"
  $SUDO tee "$SERVICE_FILE" >/dev/null <<EOF
[Unit]
Description=code-server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${USER_NAME}
Environment=HOME=${USER_HOME}
WorkingDirectory=${USER_HOME}
ExecStart=/usr/bin/code-server
Restart=always
RestartSec=2
# Hardening (optional):
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

  echo "[6/7] Enabling and starting systemd service..."
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable code-server
  $SUDO systemctl restart code-server

elif [ "$INIT_SYSTEM" = "openrc" ]; then
  echo "[5/7] Creating OpenRC service (Alpine)..."
  SERVICE_FILE="/etc/init.d/code-server"
  # shellcheck disable=SC2016
  $SUDO tee "$SERVICE_FILE" >/dev/null <<'EOF'
#!/sbin/openrc-run

name="code-server"
description="Run code-server IDE"
command="/usr/bin/code-server"
command_user="${USER_NAME:-root}"
command_background="yes"
pidfile="/run/code-server.pid"
output_log="/var/log/code-server.log"
error_log="/var/log/code-server.log"
command_args=""

depend() {
  need net
}

start_pre() {
  # Ensure log file exists and ownership ok
  touch /var/log/code-server.log
  chown "${command_user}:${command_user}" /var/log/code-server.log || true
}
EOF

  # Inject user into script
  $SUDO sed -i "s|command_user=\"\${USER_NAME:-root}\"|command_user=\"${USER_NAME}\"|g" "$SERVICE_FILE"
  $SUDO chmod +x "$SERVICE_FILE"

  echo "[6/7] Enabling and starting OpenRC service..."
  $SUDO rc-update add code-server default
  $SUDO rc-service code-server restart

else
  echo "[5/7] Unknown init system. Skipping service creation."
  SERVICE_FILE="(no service created; start manually: /usr/bin/code-server)"
fi

# ==== Final check ====
echo "[7/7] Verifying service..."
ACTIVE="unknown"
if [ "$INIT_SYSTEM" = "systemd" ] && has_cmd systemctl; then
  if systemctl --no-pager --quiet is-active code-server; then ACTIVE="active"; fi
elif [ "$INIT_SYSTEM" = "openrc" ] && has_cmd rc-service; then
  if rc-service code-server status >/dev/null 2>&1; then ACTIVE="active"; fi
fi

if [ "$ACTIVE" = "active" ]; then
  echo "✅ code-server installed and running!"
  echo "🌐 Access: http://<your-server-ip>:${PORT}"
  echo "👤 User:   ${USER_NAME}"
  echo "🔐 Password: ${PASSWORD}"
  echo "🗂  Config file: ${CONFIG_FILE}"
  echo "🧩 Service: ${SERVICE_FILE}"
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    echo "📜 Logs:   sudo journalctl -u code-server -f"
  else
    echo "📜 Logs:   tail -f /var/log/code-server.log"
  fi
else
  echo "⚠️  code-server service is not active."
  if [ "$INIT_SYSTEM" = "systemd" ]; then
    echo "   Check: sudo journalctl -u code-server -f"
  elif [ "$INIT_SYSTEM" = "openrc" ]; then
    echo "   Check: tail -f /var/log/code-server.log"
  fi
fi
