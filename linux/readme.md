# code-server Multi‑Distro Installer

Simple, hardened installer to run [code-server](https://github.com/coder/code-server) as a service across popular Linux distros (Ubuntu/Debian, RHEL/CentOS/Fedora, Alpine, openSUSE). Automatically detects package manager and init system (systemd or OpenRC) and applies sane defaults.

---

## ✨ Features

* Auto-detects `apt`, `dnf`/`yum`, `apk`, or `zypper`
* Installs minimal deps (`curl`, `ca-certificates`, `coreutils`, `bash`, plus `libc6-compat` on Alpine)
* Uses official code-server installer (standalone method)
* Writes `~/.config/code-server/config.yaml`
* Creates a service: **systemd** (most distros) or **OpenRC** (Alpine)
* Safe defaults: `bind-addr 0.0.0.0:<PORT>`, password auth, no self-signed cert

> You can place this installer in any repo and rename it freely. Examples below assume the file name `install-code-server.sh` at the repository root.

---

## 📦 Requirements

* Linux x86\_64/arm64 with internet access
* `sudo` (when running as non-root)
* Port available (default `8081`)

---

## 🚀 Quick Start

### 1) One-liner install (download + run)

Replace `<PASSWORD>` and optional `<PORT>`:

```bash
bash -c "$(curl -fsSL  https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh)" -- <PASSWORD> [PORT]
```

or with `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh \
 | bash -s -- <PASSWORD> [PORT]
```

> **Tip:** Use a strong password. You can generate one quickly:
>
> ```bash
> openssl rand -base64 24
> ```

### 2) Manual download then run

```bash
curl -fsSLo install-code-server.sh \
  https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh
chmod +x install-code-server.sh
./install-code-server.sh <PASSWORD> [PORT]
```

After success, open:

```
http://<your-server-ip>:<PORT>
```

---

## 🧭 Supported Distros & Init Systems

* **Ubuntu / Debian** — `apt` + **systemd**
* **RHEL / CentOS / Rocky / Alma / Fedora** — `dnf`/`yum` + **systemd**
* **Alpine** — `apk` + **OpenRC** (service under `/etc/init.d/code-server`)
* **openSUSE** — `zypper` + **systemd**

The script detects and configures accordingly. Alpine receives `libc6-compat` automatically for glibc-compiled binaries.

---

## ⚙️ Usage

```bash
./install-code-server.sh <PASSWORD> [PORT]
```

Arguments:

* `<PASSWORD>` (required) — authentication password for code-server
* `[PORT]` (optional) — default `8081`

Example:

```bash
./install-code-server.sh 'S3cReT-P@ss' 8081
```

Outputs (on success):

* Config: `~/.config/code-server/config.yaml`
* Service:

  * systemd: `/etc/systemd/system/code-server.service`
  * OpenRC: `/etc/init.d/code-server`

---

## 🔐 Security Notes

* **Do not** expose password-auth directly to the internet without a reverse proxy + TLS.
* Prefer binding to localhost and proxying:

  ```yaml
  # ~/.config/code-server/config.yaml
  bind-addr: 127.0.0.1:8081
  auth: password
  password: <YOUR_PASSWORD>
  cert: false
  ```
* Put code-server behind **Traefik**, **Caddy**, or **Nginx** with HTTPS and access controls (IP allowlists, OIDC, etc.).

---

## 🔁 Manage the Service

### systemd (Ubuntu/Debian/RHEL/Fedora/openSUSE)

```bash
sudo systemctl status code-server
sudo systemctl restart code-server
sudo journalctl -u code-server -f
```

### OpenRC (Alpine)

```bash
sudo rc-service code-server status
sudo rc-service code-server restart
tail -f /var/log/code-server.log
```

---

## 🌐 Reverse Proxy Examples

### Traefik v3 (file provider)

```yaml
# traefik/dynamic/code-server.yaml
http:
  routers:
    code:
      rule: Host(`code.example.com`)
      entryPoints: [websecure]
      tls: { certResolver: letsencrypt }
      service: code
  services:
    code:
      loadBalancer:
        servers:
          - url: "http://127.0.0.1:8081"
```

### Nginx

```nginx
server {
  listen 443 ssl http2;
  server_name code.example.com;
  ssl_certificate     /etc/letsencrypt/live/code.example.com/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/code.example.com/privkey.pem;

  location / {
    proxy_pass http://127.0.0.1:8081;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

---

## 🧹 Uninstall

1. Stop & disable service

   * systemd:

     ```bash
     sudo systemctl disable --now code-server
     sudo rm -f /etc/systemd/system/code-server.service
     sudo systemctl daemon-reload
     ```
   * OpenRC:

     ```bash
     sudo rc-update del code-server default
     sudo rc-service code-server stop || true
     sudo rm -f /etc/init.d/code-server
     ```
2. Remove config (optional)

   ```bash
   rm -rf ~/.config/code-server
   ```
3. Remove code-server binaries (standalone install)

   ```bash
   sudo rm -rf /usr/lib/code-server /usr/bin/code-server
   ```

---

## 🛠 Troubleshooting

* **Service not active**

  * systemd: `sudo journalctl -u code-server -f`
  * OpenRC: `tail -f /var/log/code-server.log`
* **Port already in use**

  * Change port in `~/.config/code-server/config.yaml` and restart the service
* **Alpine startup issues**

  * Ensure `libc6-compat` is installed (the script does this automatically)
* **Password forgotten**

  * Edit the `password:` in `~/.config/code-server/config.yaml` and restart the service

---

## 🔏 Verify Download (optional but recommended)

If you publish checksums for the installer, users can verify:

```bash
curl -fsSLO https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh
curl -fsSLO https://raw.githubusercontent.com/HaeMeto/tools/main/linux/install-code-server.sh.sha256
sha256sum -c install-code-server.sh.sha256
```

Generate checksum when releasing:

```bash
sha256sum install-code-server.sh > install-code-server.sh.sha256
```

---

## 📄 License

MIT (or your choice). Remember to include `LICENSE` in the repo.

---

## 🤝 Contributing

1. Fork and create a feature branch
2. Keep shellcheck clean (`shellcheck install-code-server.sh`)
3. Test on at least one Debian/Ubuntu and one RHEL/Alpine
4. Open a PR with details (distro, logs, changes)

---

## 🙋 FAQ

**Q: Can I run behind Cloudflare Tunnel or Traefik?**
A: Yes. Bind code-server to `127.0.0.1:<PORT>` and terminate TLS at your proxy/tunnel.

**Q: Does it support ARM (Raspberry Pi)?**
A: Yes, as long as code-server provides binaries for your arch and distro (the official installer handles it).

**Q: How do I change the port later?**
A: Edit `~/.config/code-server/config.yaml` → `bind-addr` and restart the service.

**Q: Can I use passwordless (auth none)?**
A: Possible, but **strongly discouraged** unless fully isolated behind an authenticated reverse proxy.
