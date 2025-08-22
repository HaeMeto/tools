# 🐳 Docker & Docker Compose Installer

![License](https://img.shields.io/badge/license-MIT-green.svg)
![Status](https://img.shields.io/badge/status-stable-brightgreen.svg)
![Ubuntu](https://img.shields.io/badge/tested%20on-Ubuntu%2020.04%2F22.04-blue.svg)
![Debian](https://img.shields.io/badge/tested%20on-Debian%2011%2F12-blue.svg)
![CentOS](https://img.shields.io/badge/tested%20on-CentOS%207%2F8-orange.svg)
![Rocky](https://img.shields.io/badge/tested%20on-Rocky%20Linux%208%2F9-orange.svg)
![Fedora](https://img.shields.io/badge/tested%20on-Fedora%2038%2F39-purple.svg)
![Arch](https://img.shields.io/badge/tested%20on-Arch%20Linux-lightgrey.svg)

Universal installer script untuk **Docker** dan **Docker Compose**.  
Mendukung berbagai distro Linux: **Debian/Ubuntu, RHEL/CentOS/Alma/Rocky, Fedora, openSUSE/SLES, Arch Linux**.  

Script ini:
- Mengecek versi Docker & Compose saat ini
- Menginstal Docker bila belum ada
- Menginstal **Docker Compose plugin (v2)** bila tersedia
- Fallback ke **binary `docker-compose`** bila plugin tidak ada
- Mengaktifkan service `docker` saat boot
- Menambahkan user ke grup `docker` (opsional)

---

## 📥 Cara Instalasi

Gunakan salah satu perintah berikut:


# Menggunakan curl
```bash
curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/docker/install-docker.sh | bash

# Menggunakan wget
wget -qO- https://raw.githubusercontent.com/HaeMeto/tools/main/docker/install-docker.sh | bash


## ⚙️ Opsi Lanjutan

# 1. Paksa pakai binary docker-compose (bukan plugin)
USE_BINARY_COMPOSE=1 curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/docker/install-docker.sh | bash

# 2. Pin versi binary docker-compose tertentu
USE_BINARY_COMPOSE=1 COMPOSE_VERSION=2.28.1 wget -qO- https://raw.githubusercontent.com/HaeMeto/tools/main/docker/install-docker.sh | bash

# 3. Jangan tambahkan user ke grup docker
SKIP_GROUP=1 curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/docker/install-docker.sh | bash

# 4. Jalankan sebagai root (tanpa sudo)
curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/docker/install-docker.sh | bash


## 🔒 Catatan Keamanan
# ⚠️ Hanya pipe script dari sumber yang kamu percaya.

Untuk ekstra aman, unduh dulu lalu jalankan secara manual:
curl -fsSL -o /tmp/install-docker.sh https://raw.githubusercontent.com/HaeMeto/tools/main/docker/install-docker.sh
bash /tmp/install-docker.sh
