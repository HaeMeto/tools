#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

# ============================================================
# Universal Docker + Docker Compose installer (multi-distro)
# - Idempotent: aman dipanggil berulang
# - Bisa dipipe langsung dari GitHub (curl/wget | bash)
# - Prefer 'docker compose' (plugin), fallback ke binary docker-compose
# - Dukung: Debian/Ubuntu, RHEL/CentOS/Alma/Rocky, Fedora, openSUSE/SLES, Arch
# - Variabel opsional:
#     SKIP_GROUP=1           -> jangan tambah user ke grup docker
#     USE_BINARY_COMPOSE=1   -> paksa pakai binary docker-compose
#     COMPOSE_VERSION=2.29.7 -> pin versi binary docker-compose
# ============================================================

need_sudo() { if [ "$(id -u)" -ne 0 ]; then echo "sudo"; fi; }
SUDO="$(need_sudo || true)"

log()  { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; }

# ---- 0) Preflight: tools minimum untuk fetch key/repo ----
ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Perlu '$1' terpasang."; exit 1; }
}

# ---- 1) Tampilkan versi saat ini ----
show_versions() {
  echo "=== Current versions ==="
  if command -v docker >/dev/null 2>&1; then
    docker --version || true
  else
    echo "Docker: not installed"
  fi

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

# ---- 2) Deteksi OS ----
if [ ! -f /etc/os-release ]; then
  err "/etc/os-release tidak ditemukan. Tidak bisa deteksi distro."
  exit 1
fi
. /etc/os-release
ID="${ID:-unknown}"
VERSION_ID="${VERSION_ID:-unknown}"
log "Detected: ID=${ID}, VERSION_ID=${VERSION_ID}"

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  armv7l) ARCH=armhf ;;
  *) warn "Arsitektur $ARCH belum diuji; lanjut percobaan." ;;
esac

# ---- 3) Installer per-family ----
install_compose_binary() {
  local VER="${COMPOSE_VERSION:-2.29.7}"
  local URL="https://github.com/docker/compose/releases/download/v${VER}/docker-compose-$(uname -s)-$(uname -m)"
  log "Installing docker-compose binary v${VER}"
  ensure_cmd curl
  $SUDO curl -fL "$URL" -o /usr/local/bin/docker-compose
  $SUDO chmod +x /usr/local/bin/docker-compose
}

install_debian_ubuntu() {
  log "Installing Docker on Debian/Ubuntu"
  $SUDO apt-get update -y
  $SUDO apt-get install -y ca-certificates curl gnupg lsb-release
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg

  CODENAME="$(lsb_release -cs 2>/dev/null || true)"
  if [ -z "${CODENAME}" ]; then
    CODENAME="$(awk -F= '/VERSION_CODENAME/{print $2}' /etc/os-release || echo stable)"
  fi

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${ID} ${CODENAME} stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null

  $SUDO apt-get update -y
  $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin || warn "buildx plugin tidak tersedia."

  if [ "${USE_BINARY_COMPOSE:-0}" != "1" ]; then
    if $SUDO apt-get install -y docker-compose-plugin; then
      log "Compose plugin installed."
    else
      warn "docker-compose-plugin tidak tersedia; fallback ke binary."
      install_compose_binary
    fi
  else
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_rhel_like() {
  # RHEL/CentOS/Rocky/Alma
  local PM
  PM="$(command -v dnf || true)"; [ -z "$PM" ] && PM="$(command -v yum || true)"
  [ -z "$PM" ] && { err "Tidak menemukan dnf/yum."; exit 1; }

  log "Installing Docker on RHEL-like (using $PM)"
  $SUDO $PM -y remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
  $SUDO $PM -y install dnf-plugins-core || true
  $SUDO $PM config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || true
  $SUDO $PM -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin || warn "buildx plugin tidak tersedia."

  if [ "${USE_BINARY_COMPOSE:-0}" != "1" ]; then
    if $SUDO $PM -y install docker-compose-plugin; then
      log "Compose plugin installed."
    else
      warn "docker-compose-plugin tidak tersedia; fallback ke binary."
      install_compose_binary
    fi
  else
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_fedora() {
  log "Installing Docker on Fedora"
  $SUDO dnf -y install dnf-plugins-core || true
  $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || true
  $SUDO dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin || warn "buildx plugin tidak tersedia."

  if [ "${USE_BINARY_COMPOSE:-0}" != "1" ]; then
    if $SUDO dnf -y install docker-compose-plugin; then
      log "Compose plugin installed."
    else
      warn "docker-compose-plugin tidak tersedia; fallback ke binary."
      install_compose_binary
    fi
  else
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_suse() {
  log "Installing Docker on openSUSE/SLES"
  if ! command -v zypper >/dev/null 2>&1; then err "zypper tidak ditemukan."; exit 1; fi
  $SUDO zypper --non-interactive refresh || true
  $SUDO zypper --non-interactive install ca-certificates curl || true

  # Repo Docker untuk SLES (dipakai juga oleh beberapa varian openSUSE)
  $SUDO zypper --non-interactive addrepo https://download.docker.com/linux/sles/docker-ce.repo || true
  $SUDO zypper --non-interactive install docker-ce docker-ce-cli containerd.io || {
    warn "docker-ce tidak tersedia; coba paket 'docker' bawaan."
    $SUDO zypper --non-interactive install docker || true
  }

  if [ "${USE_BINARY_COMPOSE:-0}" != "1" ]; then
    if $SUDO zypper --non-interactive install docker-compose-plugin; then
      log "Compose plugin installed."
    else
      warn "docker-compose-plugin tidak tersedia; fallback ke binary."
      install_compose_binary
    fi
  else
    install_compose_binary
  fi

  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

install_arch() {
  log "Installing Docker on Arch Linux"
  if ! command -v pacman >/dev/null 2>&1; then err "pacman tidak ditemukan."; exit 1; fi
  $SUDO pacman -Syu --noconfirm
  $SUDO pacman -S --noconfirm docker || true
  if [ "${USE_BINARY_COMPOSE:-0}" = "1" ]; then
    install_compose_binary
  else
    # Repos Arch sering menyediakan paket docker-compose (variasi implementasi)
    $SUDO pacman -S --noconfirm docker-compose || warn "Paket docker-compose tidak tersedia; coba binary."
    command -v docker-compose >/dev/null 2>&1 || install_compose_binary
  fi
  $SUDO systemctl enable docker
  $SUDO systemctl restart docker
}

# ---- 4) Apakah perlu install? ----
need_install_docker=0
need_install_compose=0

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
  show_versions
  exit 0
fi

# ---- 5) Jalankan installer sesuai distro ----
case "$ID" in
  debian|ubuntu)                install_debian_ubuntu ;;
  rhel|centos|rocky|almalinux)  install_rhel_like ;;
  fedora)                       install_fedora ;;
  opensuse*|sles)               install_suse ;;
  arch)                         install_arch ;;
  *)
    warn "Distro $ID belum didukung otomatis. Mencoba path Debian/Ubuntu sebagai fallback."
    install_debian_ubuntu
    ;;
esac

# ---- 6) Tambahkan user ke grup docker (opsional) ----
if command -v docker >/dev/null 2>&1; then
  if [ "${SKIP_GROUP:-0}" != "1" ]; then
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
      warn "Menambahkan user '$USER' ke grup 'docker'..."
      $SUDO usermod -aG docker "$USER" || warn "Gagal menambahkan user ke grup docker."
      warn "Logout/Login diperlukan agar perubahan grup berlaku."
    fi
  fi
fi

echo
show_versions
log "Selesai."
