# ttyd + Zellij + Yazi Installer

Production-ready installer untuk **Debian** dan **Ubuntu** yang secara otomatis menginstall:

- **ttyd** - Web Terminal
- **Zellij** - Modern Terminal Workspace
- **Yazi** - Blazing Fast Terminal File Manager
- Dependency yang direkomendasikan untuk Yazi
- Systemd Service
- Basic Authentication
- Auto Restore Session

---

## Features

- ✅ Idempotent — aman dijalankan berulang kali
- ✅ Auto detect OS (Debian / Ubuntu / Linux Mint / Armbian / Devuan / Raspbian)
- ✅ Auto detect CPU Architecture (x86_64 / ARM64)
- ✅ Dynamic version detection — fetch latest release dari GitHub API
- ✅ Fallback ke hardcoded version jika GitHub API gagal atau unreachable
- ✅ Interactive prompts (TTYD Port / User / Password / Session) — hanya di TTY
- ✅ Non-interactive mode via `--non-interactive` atau saat pipe (`curl | bash`)
- ✅ Environment variable support (`TTYD_PORT`, `TTYD_USER`, `TTYD_PASS`, `SESSION_NAME`)
- ✅ Per-package check — hanya install APT packages yang belum ada
- ✅ Per-binary version check — skip install jika versi sudah latest
- ✅ Yazi config auto-deploy (`theme.toml`, `keymap.toml`, `yazi.toml`)
- ✅ Systemd service version diff — hanya rewrite jika berubah
- ✅ Conditional service enable/restart
- ✅ Full list of Yazi dependencies
- ✅ `--force` untuk paksa reinstall semua
- ✅ CLI flags untuk skip komponen tertentu
- ✅ Debian 11+
- ✅ Debian 12
- ✅ Ubuntu 22.04+
- ✅ Ubuntu 24.04+

---

# Installed Software

| Software | Description |
|-----------|-------------|
| ttyd | Web Terminal |
| Zellij | Terminal Multiplexer |
| Yazi | Terminal File Manager |
| ffmpeg | Media Preview |
| jq | JSON Processor |
| poppler-utils | PDF Preview |
| ripgrep | Fast Search |
| fd | Fast Find |
| fzf | Fuzzy Finder |
| zoxide | Smart cd |
| ImageMagick | Image Preview |
| file | MIME Detection |

---

# Requirements

- Debian / Ubuntu (termasuk derivatives: Linux Mint, Armbian, Devuan, Raspbian)
- Root Access
- Internet Connection

---

# One Click Install

## Interactive Mode (TTY)

Run langsung di terminal:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

Script akan menampilkan prompt interaktif untuk konfigurasi.

## Non-Interactive Mode (Pipe)

```bash
curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh | sudo bash
```

Menggunakan default values atau environment variables.

## CLI Flags

| Flag | Description |
|------|-------------|
| `--force` | Reinstall semua (skip version check) |
| `--skip-apt` | Skip apt package installation |
| `--skip-ttyd` | Skip ttyd |
| `--skip-zellij` | Skip Zellij |
| `--skip-yazi` | Skip Yazi |
| `--skip-config` | Skip Yazi config deployment |
| `--skip-service` | Skip systemd service |
| `--non-interactive` | Skip prompt, gunakan defaults |

---

# Custom Configuration

## Environment Variables

```bash
TTYD_PORT=8080 \
TTYD_USER=myuser \
TTYD_PASS=mypassword \
SESSION_NAME=workspace \
bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

## Single Variable

```bash
TTYD_PORT=8080 bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

---

# Default Configuration

| Variable | Default |
|----------|---------|
| Port | 7681 |
| Username | admin |
| Password | changeme |
| Session | main |

---

# Idempotency

Script aman dijalankan berulang kali:

1. **APT packages** — hanya menginstall yang benar-benar belum ada
2. **Binaries** — cek versi via `--version`, skip jika sudah match
3. **Yazi config** — bandingkan konten file, hanya tulis ulang jika berbeda
4. **Systemd service** — bandingkan dengan yang existing, hanya tulis ulang jika berubah
5. **Service start** — hanya enable/start/restart jika diperlukan

---

# Version Detection

Script akan fetch latest version dari GitHub API secara otomatis:
- ttyd: `https://github.com/tsl0922/ttyd`
- Zellij: `https://github.com/zellij-org/zellij`
- Yazi: `https://github.com/sxyazi/yazi`

Jika API gagal (network issue, rate limit), script fallback ke hardcoded version.

---

# Yazi Config

Script akan otomatis mendistribusikan file konfigurasi Yazi dari `yazi-config/`:

```
~/.config/yazi/
├── theme.toml
├── keymap.toml
└── yazi.toml
```

Config hanya dideploy jika:
- Belum ada file di `~/.config/yazi/`
- File existing berbeda kontennya dengan bundled config
- Atau menggunakan `--force`

> **Note:** Config deployment hanya bekerja saat script dijalankan dari directory lokal (clone). Tidak tersedia saat pipe mode (`curl | bash`).

---

# Access

Open browser:

```
http://SERVER_IP:7681
```

Login menggunakan username dan password yang telah dikonfigurasi.

---

# Service Management

| Command | Description |
|---------|-------------|
| `systemctl status ttyd` | Status |
| `systemctl restart ttyd` | Restart |
| `systemctl stop ttyd` | Stop |
| `systemctl start ttyd` | Start |
| `systemctl enable ttyd` | Enable |
| `systemctl disable ttyd` | Disable |
| `journalctl -u ttyd -f` | Logs |

---

# Zellij Commands

| Command | Description |
|---------|-------------|
| `zellij list-sessions` | List session |
| `zellij attach main` | Attach session |
| `zellij --session mysession` | Create new session |

---

# Yazi Commands

| Command | Description |
|---------|-------------|
| `yazi` | Start Yazi |

---

# Installed Binary

```
/usr/local/bin/ttyd
/usr/local/bin/zellij
/usr/local/bin/yazi
/usr/local/bin/ya
```

---

# Systemd Service

```
/etc/systemd/system/ttyd.service
```

---

# Uninstall

```bash
systemctl stop ttyd
systemctl disable ttyd

rm -f /etc/systemd/system/ttyd.service

rm -f /usr/local/bin/ttyd
rm -f /usr/local/bin/zellij
rm -f /usr/local/bin/yazi
rm -f /usr/local/bin/ya

systemctl daemon-reload
```

---

# License

MIT License

---

# Author

Created by **HaeMeto**

GitHub: https://github.com/HaeMeto

---

## Roadmap

- [ ] HTTPS Support
- [ ] Reverse Proxy Example (Nginx)
- [ ] Reverse Proxy Example (Traefik)
- [ ] Cloudflare Tunnel Guide
- [ ] Auto Update
- [ ] Docker Version
- [ ] Podman Version
- [ ] Multi User Support
- [ ] WebSSH Gateway
