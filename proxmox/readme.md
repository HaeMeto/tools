
# Fix Proxmox Repo (No-Subscription)

Script sederhana untuk menghapus repository **Enterprise Proxmox** (yang membutuhkan lisensi berbayar) dan menggantinya dengan repository **No-Subscription**.  
Cocok untuk instalasi Proxmox VE tanpa lisensi, agar bisa melakukan update paket tanpa error `401 Unauthorized`.
---

## 📌 Fitur
- Backup semua file repository lama ke `/root/backup-apt-sources/`
- Menghapus repository:
  - `pve-enterprise.list`
  - `pve-enterprise.sources`
- Menghapus atau mengganti `ceph.sources` jika masih mengarah ke `enterprise.proxmox.com`
- Menambahkan repository resmi **no-subscription**:
  - `http://download.proxmox.com/debian/pve trixie pve-no-subscription`
  - `http://download.proxmox.com/debian/ceph-squid trixie no-subscription`

---

## 🚀 Cara Pakai
1. Clone repo atau copy file `fix-proxmox-repo.sh` ke server Proxmox:
   ```bash
   Cuma biar lebih aman biasanya ditulis lengkap seperti ini:
   curl -s https://raw.githubusercontent.com/HaeMeto/tools/main/fix-proxmox-repo.sh | bash
   Atau kalau kamu pakai wget:
   wget -qO- https://raw.githubusercontent.com/HaeMeto/tools/main/fix-proxmox-repo.sh | bash
