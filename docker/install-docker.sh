#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Universal Docker + Docker Compose installer (multi-distro)
# - Checks versions first, then installs based on distro/version
# - Supports: Debian/Ubuntu, RHEL/CentOS/Alma/Rocky, Fedora,
#             openSUSE/SLES, Arch Linux
# - Prefers docker compose plugin; falls back to docker-compose binary
# ============================================================

need_sudo() {
  if [ "$(id -u)" -ne 0 ]; then echo "sudo"; else echo ""; fi
}

SUDO=$(need_sudo)

log() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; }

# ---- 1) Show current versions (if any) ----
show_versions() {
  echo "=== Current versions ==="
  if command -v docker >/dev/null 2>&1; then
    docker --version || true
  else
    echo "Docker: not installed"
  fi

  # Prefer `docker compose version`
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose version || true
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose --version || true
  else
    echo "Docker Compose: not installed"
  fi
  echo "========================"
}
show_versions

# ---- 2) Detect OS / Version ----
if [ ! -f /etc/os-release ]; then
  err "/etc/os-release tidak ditemukan. Distro tidak terdeteksi."
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

ID=${ID:-unknown}
VERSION_ID=${VERSION_ID:-unknown}
log "Detected: ID=${ID}, VERSION_ID=${VERSION_ID}"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  armv7l) ARCH=armhf ;;
  *) warn "Arsitektur $ARCH belum diuji. Mencoba lanjut."; ARCH=$(uname -m) ;;
esac

# ---- 3) Install helpers per-family ----
install_debian_ubuntu() {
  log "Installing Docker on Debian/Ubuntu family"
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl gnupg lsb-release

  # Keyring path
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/${ID}/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  CODENAME=$(lsb_release -cs || echo "")
  if [ -z "$CODENAME" ]; then
    # fallback for some minimal images
    case "$VERSION_ID" in
      12) CODENAME=bookworm ;;
      11) CODENAME=bullseye ;;
      10) CODENAME=buster ;;
      24.04) CODENAME=noble ;;
      22.04) CODENAME=jammy ;;
      20.04) CODENAME=focal ;;
      *) CODENAME=$(awk -F= '/VERSION_CODENAME/{print $2}' /etc/os-release || echo stable) ;;
    esac
  fi

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${CODENAME} stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin || {
    # Buildx plugin optional; ignore if not found
    warn "docker-buildx-plugin tidak tersedia, lanjut."
  }
  # Try compose plugin first
  if $SUDO apt-get install -y docker-compose-plugin; then
    log "Compose plugin installed."
  else
    warn "docker-compose-plugin tidak tersedia. Installing standalone docker-compose binary."
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_rhel_like() {
  # RHEL/CentOS/Alma/Rocky
  PM=$(command -v dnf || true)
  [ -z "$PM" ] && PM=$(command -v yum || true)
  if [ -z "$PM" ]; then
    err "Tidak menemukan dnf/yum."
    exit 1
  fi

  log "Installing Docker on RHEL-like (using $PM)"
  $SUDO $PM -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true

  $SUDO $PM -y install dnf-plugins-core || true
  $SUDO $PM config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true

  $SUDO $PM -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin || {
    warn "docker-buildx-plugin tidak tersedia, lanjut."
  }

  # Try compose plugin first
  if $SUDO $PM -y install docker-compose-plugin; then
    log "Compose plugin installed."
  else
    warn "docker-compose-plugin tidak tersedia. Installing standalone docker-compose binary."
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_fedora() {
  log "Installing Docker on Fedora"
  $SUDO dnf -y install dnf-plugins-core || true
  $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || true

  $SUDO dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin || {
    warn "docker-buildx-plugin tidak tersedia, lanjut."
  }

  if $SUDO dnf -y install docker-compose-plugin; then
    log "Compose plugin installed."
  else
    warn "docker-compose-plugin tidak tersedia. Installing standalone docker-compose binary."
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_suse() {
  # openSUSE / SLES
  log "Installing Docker on openSUSE/SLES"
  if ! command -v zypper >/dev/null 2>&1; then
    err "zypper tidak ditemukan."
    exit 1
  fi
  $SUDO zypper --non-interactive refresh || true
  $SUDO zypper --non-interactive install ca-certificates curl || true

  # Add repo
  . /etc/os-release
  # Use openSUSE Leap/Tumbleweed detection
  if [[ "${ID_LIKE:-}" == *"suse"* ]] || [[ "$ID" == "opensuse-leap" ]] || [[ "$ID" == "opensuse-tumbleweed" ]] || [[ "$ID" == "sles" ]]; then
    $SUDO zypper --non-interactive addrepo https://download.docker.com/linux/sles/docker-ce.repo || true
  fi

  $SUDO zypper --non-interactive install docker-ce docker-ce-cli containerd.io || {
    # Some SUSE variants package as 'docker'
    warn "docker-ce tidak tersedia, mencoba paket 'docker' bawaan distro."
    $SUDO zypper --non-interactive install docker || true
  }

  # Compose plugin availability varies on SUSE; try plugin then fallback
  if $SUDO zypper --non-interactive install docker-compose-plugin; then
    log "Compose plugin installed."
  else
    warn "docker-compose-plugin tidak tersedia. Installing standalone docker-compose binary."
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_arch() {
  log "Installing Docker on Arch Linux"
  if ! command -v pacman >/dev/null 2>&1; then
    err "pacman tidak ditemukan."
    exit 1
  fi
  $SUDO pacman -Syu --noconfirm
  $SUDO pacman -S --noconfirm docker docker-compose || {
    # Arch repos often ship `docker-compose` v2 as python/binary; accept it.
    warn "Install docker-compose dari repos Arch mungkin berbeda (v1/v2 wrapper)."
  }
  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_compose_binary() {
  # Fallback to standalone docker-compose binary (v2 or latest stable v1 shim)
  local VER="2.29.7" # pilih versi stabil; ubah bila perlu
  local URL="https://github.com/docker/compose/releases/download/v${VER}/docker-compose-$(uname -s)-$(uname -m)"
  log "Installing docker-compose binary v${VER}"
  $SUDO curl -L "$URL" -o /usr/local/bin/docker-compose
  $SUDO chmod +x /usr/local/bin/docker-compose
}

# ---- 4) Decide whether to install ----
install_if_missing() {
  local need_install_docker=0
  local need_install_compose=0

  if ! command -v docker >/dev/null 2>&1; then
    need_install_docker=1
  fi

  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    :
  elif command -v docker-compose >/dev/null 2>&1; then
    :
  else
    need_install_compose=1
  fi

  if [ "$need_install_docker" -eq 0 ] && [ "$need_install_compose" -eq 0 ]; then
    log "Docker & Docker Compose sudah terpasang. Tidak ada tindakan."
    return
  fi

  case "$ID" in
    debian|ubuntu)
      install_debian_ubuntu
      ;;
    rhel|centos|rocky|almalinux)
      install_rhel_like
      ;;
    fedora)
      install_fedora
      ;;
    opensuse*|sles)
      install_suse
      ;;
    arch)
      install_arch
      ;;
    *)
      warn "Distro $ID belum didukung otomatis. Mencoba installer Debian/Ubuntu sebagai fallback."
      install_debian_ubuntu
      ;;
  esac
}

install_if_missing

# ---- 5) Post-install info & group docker ----
if command -v docker >/dev/null 2>&1; then
  if ! groups "$USER" | grep -q '\bdocker\b'; then
    warn "User '$USER' belum masuk grup 'docker'. Menambahkan..."
    $SUDO usermod -aG docker "$USER" || warn "Gagal menambahkan user ke grup docker. Abaikan jika tak perlu."
    warn "Anda mungkin perlu logout/login agar grup 'docker' aktif."
  fi
fi

echo
show_versions
log "Selesai."
