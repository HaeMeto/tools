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

- ✅ Install ttyd
- ✅ Install Zellij
- ✅ Install Yazi
- ✅ Install seluruh dependency Yazi
- ✅ Auto detect CPU Architecture (x86_64 / ARM64)
- ✅ Auto membuat Systemd Service
- ✅ Web Terminal dengan mode Writable (`-W`)
- ✅ Basic Authentication
- ✅ Auto membuat Zellij Session
- ✅ Auto Enable & Start Service
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

- Debian / Ubuntu
- Root Access
- Internet Connection

---

# One Click Install

Latest version

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

atau

```bash
curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh | bash
```

Jika menggunakan sudo:

```bash
curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh | sudo bash
```

---

# Custom Configuration

Semua konfigurasi dapat diubah menggunakan Environment Variable.

## Change Port

```bash
TTYD_PORT=8080 bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

---

## Change Username

```bash
TTYD_USER=myuser bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

---

## Change Password

```bash
TTYD_PASS=mypassword bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

---

## Change Session Name

```bash
SESSION_NAME=production bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
```

---

## Multiple Variables

```bash
TTYD_PORT=8080 \
TTYD_USER=admin \
TTYD_PASS=secret123 \
SESSION_NAME=workspace \
bash <(curl -fsSL https://raw.githubusercontent.com/HaeMeto/tools/main/ttyd-zellij-yazi/install.sh)
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

# Access

Open browser

```
http://SERVER_IP:7681
```

Login menggunakan username dan password yang telah dikonfigurasi.

---

# Service Management

Status

```bash
systemctl status ttyd
```

Restart

```bash
systemctl restart ttyd
```

Stop

```bash
systemctl stop ttyd
```

Start

```bash
systemctl start ttyd
```

Enable

```bash
systemctl enable ttyd
```

Disable

```bash
systemctl disable ttyd
```

Logs

```bash
journalctl -u ttyd -f
```

---

# Zellij Commands

List Session

```bash
zellij list-sessions
```

Attach Session

```bash
zellij attach main
```

Create New Session

```bash
zellij --session mysession
```

---

# Yazi

Start Yazi

```bash
yazi
```

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

GitHub:
https://github.com/HaeMeto

---

## Screenshot

> Coming Soon

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
