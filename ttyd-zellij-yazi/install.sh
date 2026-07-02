#!/usr/bin/env bash
set -Eeuo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
TTYD_VERSION="1.7.7"
ZELLIJ_VERSION="0.44.3"
YAZI_VERSION="25.5.31"

TTYD_PORT="${TTYD_PORT:-7681}"
TTYD_USER="${TTYD_USER:-admin}"
TTYD_PASS="${TTYD_PASS:-changeme}"
SESSION_NAME="${SESSION_NAME:-main}"

FORCE=0
SKIP_PKGS=0
SKIP_TTYD=0
SKIP_ZELLIJ=0
SKIP_YAZI=0
SKIP_CONFIG=0
SKIP_SERVICE=0
NON_INTERACTIVE=0

# ─── Helpers ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
skip()  { echo -e "${YELLOW}[SKIP]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*"; }
banner(){ echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

usage() {
 cat <<EOF
Usage: $0 [FLAGS]

Flags:
 --force Reinstall all components regardless of existing version
 --skip-packages Skip system package installation (alias: --skip-apt)
 --skip-ttyd Skip ttyd installation
 --skip-zellij Skip Zellij installation
 --skip-yazi Skip Yazi installation
 --skip-config Skip Yazi config deployment
 --skip-service Skip systemd service creation
 --non-interactive Don't prompt, use defaults or environment variables

Environment variables (also set via interactive prompts):
 TTYD_PORT [7681]
 TTYD_USER [admin]
 TTYD_PASS [changeme]
 SESSION_NAME [main]
EOF
 exit 0
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--force) FORCE=1 ;;
 --skip-packages|--skip-apt|--skip-pkgs) SKIP_PKGS=1 ;;
		--skip-ttyd) SKIP_TTYD=1 ;;
		--skip-zellij) SKIP_ZELLIJ=1 ;;
		--skip-yazi) SKIP_YAZI=1 ;;
		--skip-config) SKIP_CONFIG=1 ;;
		--skip-service) SKIP_SERVICE=1 ;;
		--non-interactive) NON_INTERACTIVE=1 ;;
		-h|--help) usage ;;
		*) err "Unknown flag: $1"; usage ;;
	esac
	shift
done

# ─── OS Detection ─────────────────────────────────────────────────────────────
log "Detecting OS..."

if [ ! -f /etc/os-release ]; then
 err "Cannot detect OS. /etc/os-release not found."
 exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

IS_DEB=0
IS_EL=0

case "$ID" in
 debian|ubuntu|linuxmint|raspbian|armbian|devuan)
 IS_DEB=1
 ok "OS: $NAME ($VERSION_CODENAME)"
 ;;
 almalinux|rocky|rhel|centos|fedora|ol)
 IS_EL=1
 ok "OS: $NAME ${VERSION_ID:-}"
 ;;
 *)
 err "Unsupported OS: $ID. This script supports Debian/Ubuntu and RHEL derivatives (AlmaLinux, Rocky, etc.)"
 exit 1
 ;;
esac

if [ "$IS_EL" -eq 1 ] && [ "$IS_DEB" -eq 0 ]; then
 log "Detected RHEL-family system. Enabling EPEL..."
 if ! rpm -q epel-release >/dev/null 2>&1; then
 dnf install -y -q epel-release 2>/dev/null || \
 yum install -y -q epel-release 2>/dev/null || \
 warn "Could not enable EPEL. Some packages may not be available."
 else
 ok "EPEL already enabled"
 fi
fi

[[ $EUID -eq 0 ]] || { err "Please run as root."; exit 1; }

# ─── Arch Detection ───────────────────────────────────────────────────────────
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
		err "Unsupported architecture: $ARCH"
		exit 1
		;;
esac

log "Architecture: $ARCH"
ok "Architecture supported"

# ─── Fetch Latest Versions ────────────────────────────────────────────────────
get_latest_github_tag() {
	local repo="$1"
	local tag
	tag=$(curl -fsS --connect-timeout 5 --max-time 10 \
		"https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
		| jq -r '.tag_name // empty' 2>/dev/null) || true
	if [ -z "$tag" ] || [ "$tag" = "null" ]; then
		return 1
	fi
	echo "$tag"
}

if command -v jq >/dev/null 2>&1 && command -v curl >/dev/null 2>&1; then
	log "Fetching latest versions from GitHub..."

	LATEST_TTYD=$(get_latest_github_tag "tsl0922/ttyd" || true)
	if [ -n "$LATEST_TTYD" ]; then
		ok "Latest ttyd: $LATEST_TTYD"
		TTYD_VERSION="$LATEST_TTYD"
	else
		warn "Cannot fetch ttyd version, using default: $TTYD_VERSION"
	fi

	LATEST_ZELLIJ=$(get_latest_github_tag "zellij-org/zellij" || true)
	if [ -n "$LATEST_ZELLIJ" ]; then
		LATEST_ZELLIJ="${LATEST_ZELLIJ#v}"
		ok "Latest Zellij: v$LATEST_ZELLIJ"
		ZELLIJ_VERSION="$LATEST_ZELLIJ"
	else
		warn "Cannot fetch Zellij version, using default: $ZELLIJ_VERSION"
	fi

	LATEST_YAZI=$(get_latest_github_tag "sxyazi/yazi" || true)
	if [ -n "$LATEST_YAZI" ]; then
		LATEST_YAZI="${LATEST_YAZI#v}"
		ok "Latest Yazi: v$LATEST_YAZI"
		YAZI_VERSION="$LATEST_YAZI"
	else
		warn "Cannot fetch Yazi version, using default: $YAZI_VERSION"
	fi
else
	warn "jq or curl not found; using hardcoded versions. Install curl and jq for auto-update detection."
fi

banner

# ─── Interactive Prompts ──────────────────────────────────────────────────────
if [ "$NON_INTERACTIVE" -eq 0 ] && [ -t 0 ]; then
	log "Interactive mode: configure ttyd credentials"
	echo

	read -rp "Port       [$TTYD_PORT]: " input
	TTYD_PORT="${input:-$TTYD_PORT}"

	read -rp "Username   [$TTYD_USER]: " input
	TTYD_USER="${input:-$TTYD_USER}"

	read -rsp "Password   [$TTYD_PASS]: " input
	echo
	TTYD_PASS="${input:-$TTYD_PASS}"

	read -rp "Session    [$SESSION_NAME]: " input
	SESSION_NAME="${input:-$SESSION_NAME}"

	echo
	banner
else
	log "Non-interactive mode: using defaults or environment variables"
	log "  Port: $TTYD_PORT | User: $TTYD_USER | Pass: **** | Session: $SESSION_NAME"
	banner
fi

# ─── Temp Workdir ─────────────────────────────────────────────────────────────
WORKDIR=""
cleanup() { [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

ensure_workdir() {
	if [ -z "$WORKDIR" ]; then
		WORKDIR="$(mktemp -d)"
	fi
}

# ─── Package Manager Detection ─────────────────────────────────────────────────
# Detect package manager and setup per-family package lists
if [ "$IS_DEB" -eq 1 ]; then
 PKG_MANAGER="apt-get"
 PKG_QUERY="dpkg -s"
 PKG_CACHE_FILE="/var/cache/apt/pkgcache.bin"
 COMMON_PKGS=(curl wget tar unzip xz-utils ca-certificates nano)
 OPTIONAL_PKGS=(ffmpeg jq poppler-utils file fd-find ripgrep fzf zoxide imagemagick btop ncdu)
elif [ "$IS_EL" -eq 1 ]; then
 PKG_MANAGER="dnf"
 PKG_QUERY="rpm -q"
 PKG_CACHE_FILE="/var/cache/dnf/packages.db"
 # Prefer dnf, fallback to yum for older systems
 command -v dnf >/dev/null 2>&1 || PKG_MANAGER="yum"
 COMMON_PKGS=(curl wget tar unzip xz ca-certificates nano)
 # ffmpeg not in standard RHEL repos; imagemagick → ImageMagick (case diff)
 OPTIONAL_PKGS=(jq poppler-utils file fd-find ripgrep fzf zoxide ImageMagick btop ncdu)
fi

# ─── Package Installation ─────────────────────────────────────────────────────
install_packages() {
 if [ "$SKIP_PKGS" -eq 1 ]; then
 skip "System packages (--skip-packages)"
 return
 fi

 log "Checking system packages..."

 local missing=()
 for pkg in "${COMMON_PKGS[@]}" "${OPTIONAL_PKGS[@]}"; do
 if $PKG_QUERY "$pkg" >/dev/null 2>&1; then
 continue
 fi
 missing+=("$pkg")
 done
 # "rpm -q ImageMagick" requires exact case; try lowercase too for EL
 if [ "$IS_EL" -eq 1 ]; then
 local extra=()
 for pkg in "${missing[@]}"; do
 if [ "$pkg" = "ImageMagick" ] && $PKG_QUERY imagemagick >/dev/null 2>&1; then
 continue
 fi
 extra+=("$pkg")
 done
 missing=("${extra[@]}")
 fi

 if [ ${#missing[@]} -eq 0 ]; then
 ok "All packages already installed"
 else
 if [ -f "$PKG_CACHE_FILE" ]; then
 local cache_age=99999
 local cache_mtime
 cache_mtime=$(stat -c %Y "$PKG_CACHE_FILE" 2>/dev/null || echo 0)
 if [ "$cache_mtime" -gt 0 ]; then
 local now
 now=$(date +%s)
 cache_age=$(( (now - cache_mtime) / 3600 ))
 fi
 fi

 if [ "${cache_age:-99999}" -gt 12 ]; then
 log "Updating package cache..."
 if [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
 $PKG_MANAGER makecache -q 2>/dev/null || true
 else
 $PKG_MANAGER update -qq
 fi
 else
 ok "Package cache is recent (${cache_age:-?} hours old), skipping update"
 fi

 log "Installing missing packages: ${missing[*]}"
 $PKG_MANAGER install -y -q "${missing[@]}"
 ok "Packages installed"
 fi

 if [ "$IS_DEB" -eq 1 ] && command -v fdfind >/dev/null && ! command -v fd >/dev/null; then
 log "Creating fd symlink (debian fd-find workaround)..."
 ln -sf "$(command -v fdfind)" /usr/local/bin/fd
 ok "fd symlink created"
 fi

 if [ "$IS_EL" -eq 1 ]; then
 if ! command -v ffmpeg >/dev/null 2>&1; then
 warn "ffmpeg not found. Yazi media preview will be limited."
 warn "Install via RPMFusion: dnf install --nogpgcheck https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm"
 warn " dnf install --nogpgcheck https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm"
 warn " dnf install ffmpeg"
 fi
 fi
}

# Suppress unused variable warning
true "${OPTIONAL_PKGS[@]}"

# ─── Version Check ────────────────────────────────────────────────────────────
# Returns 0 if installed version matches expected, 1 otherwise
check_binary_version() {
	local bin="$1"
	local expected="$2"

	if [ ! -x "$bin" ]; then
		return 1
	fi

	local actual
	actual=$("$bin" --version 2>&1 | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1) || return 1

	if [ "$actual" = "$expected" ]; then
		return 0
	fi
	return 1
}

# ─── Install: ttyd ────────────────────────────────────────────────────────────
install_ttyd() {
	if [ "$SKIP_TTYD" -eq 1 ]; then
		skip "ttyd (--skip-ttyd)"
		return
	fi

	log "Checking ttyd $TTYD_VERSION..."

	if [ "$FORCE" -eq 0 ] && check_binary_version /usr/local/bin/ttyd "$TTYD_VERSION"; then
		ok "ttyd $TTYD_VERSION already installed"
		return
	fi

	if [ "$FORCE" -eq 1 ]; then
		log "Force reinstalling ttyd..."
	else
		log "Installing ttyd $TTYD_VERSION..."
	fi

	ensure_workdir
	wget -q "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/${TTYD_FILE}" -O "$WORKDIR/ttyd"
	install -Dm755 "$WORKDIR/ttyd" /usr/local/bin/ttyd
	ok "ttyd $TTYD_VERSION installed"
}

# ─── Install: Zellij ──────────────────────────────────────────────────────────
install_zellij() {
	if [ "$SKIP_ZELLIJ" -eq 1 ]; then
		skip "Zellij (--skip-zellij)"
		return
	fi

	log "Checking Zellij $ZELLIJ_VERSION..."

	if [ "$FORCE" -eq 0 ] && check_binary_version /usr/local/bin/zellij "$ZELLIJ_VERSION"; then
		ok "Zellij $ZELLIJ_VERSION already installed"
		return
	fi

	if [ "$FORCE" -eq 1 ]; then
		log "Force reinstalling Zellij..."
	else
		log "Installing Zellij $ZELLIJ_VERSION..."
	fi

	ensure_workdir
	wget -q "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/${ZELLIJ_FILE}" -O "$WORKDIR/zellij.tar.gz"
	tar -xzf "$WORKDIR/zellij.tar.gz" -C "$WORKDIR"
	install -Dm755 "$WORKDIR/zellij" /usr/local/bin/zellij
	ok "Zellij $ZELLIJ_VERSION installed"
}

# ─── Install: Yazi ────────────────────────────────────────────────────────────
install_yazi() {
	if [ "$SKIP_YAZI" -eq 1 ]; then
		skip "Yazi (--skip-yazi)"
		return
	fi

	log "Checking Yazi $YAZI_VERSION..."

	local yazi_ok=0
	if [ "$FORCE" -eq 0 ] && check_binary_version /usr/local/bin/yazi "$YAZI_VERSION" \
		&& [ -x /usr/local/bin/ya ]; then
		yazi_ok=1
	fi

	if [ "$yazi_ok" -eq 1 ]; then
		ok "Yazi $YAZI_VERSION already installed"
		return
	fi

	if [ "$FORCE" -eq 1 ]; then
		log "Force reinstalling Yazi..."
	else
		log "Installing Yazi $YAZI_VERSION..."
	fi

 ensure_workdir
 wget -q "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/${YAZI_FILE}" -O "$WORKDIR/yazi.zip"
 unzip -qo "$WORKDIR/yazi.zip" -d "$WORKDIR/yazi-extract"

 YDIR="$WORKDIR/yazi-extract/${YAZI_FILE%.zip}"
 if [ ! -d "$YDIR" ]; then
 YDIR="$(find "$WORKDIR/yazi-extract" -maxdepth 1 -mindepth 1 -type d -name 'yazi-*' | head -n1)"
 fi
 if [ ! -d "$YDIR" ]; then
 err "Cannot find Yazi directory after extraction"
 exit 1
 fi

 install -Dm755 "$YDIR/yazi" /usr/local/bin/yazi
 install -Dm755 "$YDIR/ya" /usr/local/bin/ya
 ok "Yazi $YAZI_VERSION installed"
}

# ─── Deploy Yazi Config ───────────────────────────────────────────────────────
deploy_yazi_config() {
 if [ "$SKIP_CONFIG" -eq 1 ]; then
 skip "Yazi config (--skip-config)"
 return
 fi

 local yazi_conf_dir="${HOME:-/root}/.config/yazi"
 local src_dir=""

 local script_dir
 script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")" 2>/dev/null || echo "")"

 if [ -n "$script_dir" ] && [ -d "$script_dir/yazi-config" ]; then
 src_dir="$script_dir/yazi-config"
 else
 log "Fetching Yazi config from GitHub..."
 ensure_workdir
 src_dir="$WORKDIR/yazi-config-fetched"
 mkdir -p "$src_dir"
 local base_url="https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/yazi-config"
 for f in theme.toml keymap.toml yazi.toml; do
 curl -fsSL --connect-timeout 5 --max-time 10 "${base_url}/${f}" -o "$src_dir/$f" 2>/dev/null || \
 warn "Failed to fetch $f from GitHub"
 done
 fi

 if [ ! -d "$src_dir" ] || [ -z "$(ls -A "$src_dir"/*.toml 2>/dev/null)" ]; then
 warn "No Yazi config files found. Skipping config deployment."
 return
 fi

 log "Deploying Yazi config to $yazi_conf_dir..."
 mkdir -p "$yazi_conf_dir"

 local deployed=0
 local skipped=0

 for f in "$src_dir"/*.toml; do
 local fname
 fname="$(basename "$f")"
 local dst="$yazi_conf_dir/$fname"

 if [ "$FORCE" -eq 0 ] && [ -f "$dst" ]; then
 if cmp -s "$f" "$dst"; then
 ((skipped++)) || true
 continue
 fi
 warn "Config $fname differs — overwriting"
 fi

 cp "$f" "$dst"
 ((deployed++)) || true
 done

 if [ "$deployed" -eq 0 ] && [ "$skipped" -gt 0 ]; then
 ok "Yazi config already up-to-date ($skipped files skipped)"
 else
 ok "Yazi config deployed ($deployed files installed)"
 fi
}

# ─── Systemd Service ──────────────────────────────────────────────────────────
write_systemd_service() {
	if [ "$SKIP_SERVICE" -eq 1 ]; then
		skip "Systemd service (--skip-service)"
		return
	fi

	local service_file="/etc/systemd/system/ttyd.service"
	local service_changed=0

	log "Setting up systemd service..."

	local new_service
	new_service=$(cat <<EOF
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
)

	if [ -f "$service_file" ]; then
		local existing
		existing=$(cat "$service_file")
		if [ "$existing" = "$new_service" ]; then
			ok "Systemd service unchanged"
		else
			service_changed=1
			log "Systemd service config changed — updating..."
			echo "$new_service" > "$service_file"
			ok "Systemd service updated"
		fi
	else
		service_changed=1
		log "Creating systemd service..."
		echo "$new_service" > "$service_file"
		ok "Systemd service created"
	fi

	systemctl daemon-reload

	if systemctl is-enabled --quiet ttyd 2>/dev/null; then
		ok "Service already enabled"
	else
		log "Enabling ttyd service..."
		systemctl enable ttyd
		ok "Service enabled"
	fi

	if [ "$service_changed" -eq 1 ]; then
		log "Restarting ttyd service (config changed)..."
		systemctl restart ttyd
		ok "Service restarted"
	elif ! systemctl is-active --quiet ttyd 2>/dev/null; then
		log "Starting ttyd service..."
		systemctl start ttyd
		ok "Service started"
	else
		ok "Service already running"
	fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo
log "Starting ttyd + Zellij + Yazi installation"
banner

install_packages
banner
install_ttyd
install_zellij
install_yazi
banner
deploy_yazi_config
banner
write_systemd_service
banner

# ─── Summary ──────────────────────────────────────────────────────────────────
echo
echo -e "${GREEN}===== Installation Complete =====${NC}"
echo

# ------- Print versions -------
echo "┌─ Installed Binaries ──────────────────────────"
echo "│"
for bin in ttyd zellij yazi ya; do
	if [ -x "/usr/local/bin/$bin" ]; then
 ver=$("/usr/local/bin/$bin" --version 2>&1 | head -n1)
		printf "│ %-8s %s\n" "$bin:" "$ver"
	else
		printf "│ %-8s (not installed)\n" "$bin:"
	fi
done
echo "│"
echo "└───────────────────────────────────────────────"
echo

# ------- Server IP -------
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "SERVER_IP")
echo -e "  ${CYAN}URL:${NC}      http://${SERVER_IP}:${TTYD_PORT}"
echo -e "  ${CYAN}Username:${NC}  ${TTYD_USER}"
echo -e "  ${CYAN}Password:${NC}  ${TTYD_PASS}"
echo -e "  ${CYAN}Session:${NC}   ${SESSION_NAME}"
echo

echo "┌─ Useful Commands ─────────────────────────────"
echo "│"
echo "│ systemctl status ttyd"
echo "│ journalctl -u ttyd -f"
echo "│ zellij list-sessions"
echo "│ yazi"
echo "│"
echo "└───────────────────────────────────────────────"
echo
