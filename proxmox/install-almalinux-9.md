# SOP Lengkap Instalasi AlmaLinux 9 di Proxmox VE

# Daftar Isi

1. Persiapan
2. Upload ISO AlmaLinux
3. Membuat VM Baru
4. Konfigurasi VM
5. Instalasi AlmaLinux 9
6. Konfigurasi Dasar Setelah Install
7. Install QEMU Guest Agent
8. Setup Network
9. Setup SSH dan Firewall
10. Optimasi VM Proxmox
11. Snapshot dan Template
12. Clone VM di Proxmox
13. Clone VM dengan Ukuran Disk Lebih Kecil
14. Error Clone Thin LVM
15. Best Practice Production
16. Troubleshooting

---

# 1. Persiapan

## Requirement Host

| Komponen   | Minimum      |
| ---------- | ------------ |
| Proxmox VE | 8.x          |
| CPU        | VT-x / AMD-V |
| RAM Host   | 8GB          |
| Storage    | 50GB+        |

---

# 2. Upload ISO AlmaLinux

## Download ISO

Website resmi:

* [https://almalinux.org](https://almalinux.org)

Rekomendasi:

```text
AlmaLinux-9-latest-x86_64-minimal.iso
```

---

## Upload ke Proxmox

Masuk:

```text
Datacenter
→ local
→ ISO Images
→ Upload
```

Upload file ISO AlmaLinux.

---

# 3. Membuat VM Baru

Klik:

```text
Create VM
```

---

# 4. Konfigurasi VM

## General

| Field | Value       |
| ----- | ----------- |
| VM ID | 101         |
| Name  | almalinux-9 |

---

## OS

| Field   | Value            |
| ------- | ---------------- |
| ISO     | AlmaLinux ISO    |
| Type    | Linux            |
| Version | 6.x - 2.6 Kernel |

---

## System

| Field           | Recommended        |
| --------------- | ------------------ |
| Machine         | q35                |
| BIOS            | OVMF (UEFI)        |
| SCSI Controller | VirtIO SCSI single |

---

## Disk

| Field         | Recommended |
| ------------- | ----------- |
| Bus           | SCSI        |
| Storage       | local-lvm   |
| Size          | 20G–50G     |
| Cache         | Write Back  |
| SSD Emulation | Enabled     |
| Discard/TRIM  | Enabled     |

---

## CPU

| Field   | Recommended |
| ------- | ----------- |
| Sockets | 1           |
| Cores   | 2–4         |
| Type    | host        |

---

## Memory

| Use Case   | RAM  |
| ---------- | ---- |
| Basic      | 2GB  |
| Docker     | 4GB  |
| Production | 8GB+ |

Enable:

```text
Ballooning Device
```

---

## Network

| Field  | Recommended |
| ------ | ----------- |
| Bridge | vmbr0       |
| Model  | VirtIO      |

---

# 5. Instalasi AlmaLinux 9

Boot VM.

Pilih:

```text
Install AlmaLinux 9
```

---

## Setup Bahasa

Pilih:

```text
English
```

---

## Timezone

Gunakan:

```text
Asia/Jakarta
```

Enable:

```text
Network Time
```

---

## Installation Destination

Gunakan:

```text
Automatic Partitioning
```

Filesystem default:

```text
XFS
```

---

## Network

Enable network.

Set hostname:

```text
alma9.local
```

---

## Root Password

Gunakan password kuat.

Minimal:

```text
16 karakter
```

---

## User Creation

Checklist:

```text
Make this user administrator
```

---

## Begin Installation

Klik:

```text
Begin Installation
```

Tunggu hingga selesai.

---

# 6. Konfigurasi Dasar Setelah Install

# PENTING — Verifikasi Network dan DNS Sebelum Install Package

Pada AlmaLinux minimal install, sering terjadi:

```text
IP address ada
Tetapi DNS tidak terkonfigurasi
```

Akibatnya command seperti:

```bash
dnf install openssh-server -y
```

akan gagal dengan error:

```text
Couldn't resolve host name
```

---

# Recommended Production Setup

Tetap gunakan:

```text
NetworkManager
```

Tetapi disable:

```text
auto DNS management
```

lalu inject manual DNS.

---

## Disable Auto DNS Management

```bash
mkdir -p /etc/NetworkManager/conf.d

cat > /etc/NetworkManager/conf.d/90-dns-none.conf << 'EOF'
[main]
dns=none
EOF
```

---

## Restart NetworkManager

```bash
systemctl restart NetworkManager
```

---

## Inject Manual DNS

```bash
cat > /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
```

---

## Optional — Lock resolv.conf

```bash
chattr +i /etc/resolv.conf
```

Jika ingin edit lagi:

```bash
chattr -i /etc/resolv.conf
```

---

## Test Internet

### Test Connectivity

```bash
ping 8.8.8.8
```

### Test DNS

```bash
ping google.com
```

Jika keduanya berhasil:

baru install package.

---

# PENTING — Konfigurasi SSH Sebelum Reboot

Sangat direkomendasikan mengaktifkan SSH sebelum reboot pertama agar administrasi server lebih mudah dilakukan secara remote.

---

## Install OpenSSH Server

```bash
dnf install openssh-server -y
```

---

## Enable SSH

```bash
systemctl enable --now sshd
```

---

## Verifikasi SSH

```bash
systemctl status sshd
```

Pastikan:

```text
active (running)
```

---

## Allow SSH Firewall

```bash
dnf install firewalld -y
systemctl enable --now firewalld

firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload
```

---

## Cek IP Server

```bash
ip a
```

atau:

```bash
hostname -I
```

---

## Test SSH dari Komputer Lain

```bash
ssh user@IP_SERVER
```

Contoh:

```bash
ssh admin@192.168.1.10
```

---

## Setelah SSH Berhasil

Baru lanjut update system dan reboot.

---

# PENTING — Konfigurasi SSH Sebelum Reboot

Setelah login pertama, sangat direkomendasikan mengaktifkan SSH terlebih dahulu sebelum melakukan reboot atau update besar agar administrasi server lebih mudah dilakukan secara remote.

---

## Install OpenSSH Server

```bash
dnf install openssh-server -y
```

---

## Enable SSH Service

```bash
systemctl enable --now sshd
```

---

## Verifikasi SSH Aktif

```bash
systemctl status sshd
```

Pastikan status:

```text
active (running)
```

---

## Allow SSH di Firewall

Install firewalld jika belum ada:

```bash
dnf install firewalld -y
```

Enable:

```bash
systemctl enable --now firewalld
```

Allow SSH:

```bash
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload
```

---

## Cek IP Server

```bash
ip a
```

atau:

```bash
hostname -I
```

---

## Test SSH dari Komputer Lain

```bash
ssh user@IP_SERVER
```

Contoh:

```bash
ssh admin@192.168.1.10
```

---

## Setelah SSH Berhasil

Baru lakukan update system dan reboot.

---

## Update System

```bash
dnf update -y
```

Reboot:

```bash
reboot
```

---

## Install Basic Tools

```bash
dnf install -y \
wget \
git \
htop \
net-tools \
bash-completion \
zip \
unzip \ 
epel-release \
ncdu
```

---

# 7. Install QEMU Guest Agent

## Install

```bash
dnf install qemu-guest-agent -y
```

---

## Enable Service

```bash
systemctl enable --now qemu-guest-agent
```

---

## Enable dari Proxmox

Masuk:

```text
VM
→ Options
→ QEMU Guest Agent
→ Enabled
```

---

# 8. Setup Network

# PENTING — Recommended Network Production Setup

Untuk environment production seperti:

* Docker Swarm
* Traefik
* Reverse Proxy
* Multi-node infrastructure
* Container workloads

sangat direkomendasikan menggunakan:

```text
Static IP
```

DAN BUKAN:

```text
DHCP
```

karena DHCP dapat menyebabkan:

* IP berubah
* DHCP renew gagal
* SSH disconnect
* routing berubah
* DNS berubah
* container networking bermasalah

---

# Recommended Production Network Configuration

| Komponen       | Recommended |
| -------------- | ----------- |
| NetworkManager | Aktif       |
| IPv4           | Static      |
| IPv6           | Disable     |
| DNS            | Manual      |
| DHCP           | Disable     |
| Interface      | VirtIO      |

---

# Cek Network Interface

```bash
ip a
```

Contoh interface:

```text
enp6s18
```

---

# Cek Connection Profile

```bash
nmcli con show
```

---

# Setup Static IP

## Set IP Address

```bash
nmcli con mod enp6s18 ipv4.addresses 10.10.70.6/24
```

---

## Set Gateway

```bash
nmcli con mod enp6s18 ipv4.gateway 10.10.70.1
```

---

## Set DNS

```bash
nmcli con mod enp6s18 ipv4.dns "1.1.1.1 8.8.8.8"
```

---

## Disable DHCP

```bash
nmcli con mod enp6s18 ipv4.method manual
```

---

## Enable Auto Connect

```bash
nmcli con mod enp6s18 connection.autoconnect yes
```

---

# Disable IPv6

Untuk production VM internal, sangat direkomendasikan disable IPv6 jika tidak digunakan.

```bash
cat > /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

sysctl --system
```

---

# Disable Auto DNS Management

```bash
mkdir -p /etc/NetworkManager/conf.d

cat > /etc/NetworkManager/conf.d/90-dns-none.conf << 'EOF'
[main]
dns=none
EOF
```

---

# Manual DNS Injection

```bash
cat > /etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
```

---

# Optional — Lock resolv.conf

```bash
chattr +i /etc/resolv.conf
```

Unlock jika ingin edit:

```bash
chattr -i /etc/resolv.conf
```

---

# Apply Network Configuration

JANGAN gunakan:

```bash
systemctl restart NetworkManager
```

via remote SSH karena dapat memutus koneksi.

Gunakan:

```bash
nmcli con down enp6s18 && nmcli con up enp6s18
```

---

# Verifikasi Network

```bash
ip a
ip route
ping -c 4 8.8.8.8
ping -c 4 google.com
```

Pastikan:

* IP muncul
* default gateway ada
* DNS resolve normal
* internet berjalan

---

# Best Practice Proxmox Network

## Gunakan

| Komponen  | Recommended |
| --------- | ----------- |
| Bridge    | vmbr0       |
| NIC Model | VirtIO      |
| IP        | Static      |
| DNS       | Manual      |

---

# Sangat Penting

Jangan disable total:

```text
NetworkManager
```

karena AlmaLinux 9 / RHEL9 ecosystem sangat bergantung pada NM.

Recommended:

```text
NetworkManager tetap aktif
Tetapi DNS dikelola manual
```

---

## Cek Interface

```bash
nmcli device status
```

Contoh:

```text
ens18
```

---

## Static IP

```bash
nmcli con mod ens18 \
ipv4.addresses 192.168.1.10/24 \
ipv4.gateway 192.168.1.1 \
ipv4.dns "1.1.1.1 8.8.8.8" \
ipv4.method manual
```

Restart:

```bash
nmcli con down ens18 && nmcli con up ens18
```

---

# 9. Setup SSH dan Firewall

## Install SSH

```bash
dnf install openssh-server -y
```

Enable:

```bash
systemctl enable --now sshd
```

---

## Install Firewall

```bash
dnf install firewalld -y
```

Enable:

```bash
systemctl enable --now firewalld
```

---

## Allow SSH

```bash
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload
```

---

# 10. Optimasi VM Proxmox

## Enable TRIM

```bash
systemctl enable --now fstrim.timer
```

---

## Verifikasi VirtIO

```bash
lsmod | grep virtio
```

---

# 11. Snapshot dan Template

## Snapshot

Masuk:

```text
VM
→ Snapshots
→ Take Snapshot
```

Contoh:

```text
fresh-install
```

---

## Convert VM Menjadi Template

Shutdown VM:

```bash
shutdown now
```

Lalu:

```text
Right Click VM
→ Convert to Template
```

---

# 12. Clone VM di Proxmox

## Jenis Clone

| Type         | Kelebihan               | Kekurangan          |
| ------------ | ----------------------- | ------------------- |
| Full Clone   | Independen              | Besar dan lambat    |
| Linked Clone | Cepat dan hemat storage | Bergantung template |

---

# Recommended

Gunakan:

```text
Linked Clone
```

untuk environment production modern.

---

## Cara Clone

```text
Right Click Template
→ Clone
```

Pilih:

```text
Linked Clone
```

---

# 13. Clone VM dengan Ukuran Disk Lebih Kecil

## Penting

Proxmox tidak bisa langsung:

```text
Clone 300G menjadi 150G
```

karena clone selalu mengikuti ukuran disk source.

---

# Metode Recommended

## Backup dan Restore

---

## Step 1 — Backup VM

```text
VM
→ Backup
```

---

## Step 2 — Restore VM

Saat restore:

```text
Advanced
→ Disk Size
```

Set:

```text
150G
```

---

## Syarat

Used space harus lebih kecil dari target.

Contoh:

| Used | Target | Status |
| ---- | ------ | ------ |
| 40G  | 150G   | Aman   |
| 180G | 150G   | Gagal  |

---

# Untuk AlmaLinux 9

Default filesystem:

```text
XFS
```

XFS:

```text
TIDAK SUPPORT SHRINK
```

Jadi resize kecil tidak bisa langsung.

---

# Rekomendasi Template

Jangan buat template:

```text
300G
```

Gunakan:

```text
20G–30G
```

Lalu resize setelah clone.

---

## Resize Disk Setelah Clone

```bash
qm resize 105 scsi0 +100G
```

---

# 14. Error Clone Thin LVM

## Contoh Error

```text
WARNING: Sum of all thin volume sizes exceeds the size of thin pool
TASK ERROR: clone failed: block job (mirror) error
```

---

# Penyebab

Thin pool overprovision.

Contoh:

| Virtual Allocation | Physical Storage |
| ------------------ | ---------------- |
| 6TB                | 3.4TB            |

Saat full clone:

```text
real allocation terjadi
```

lalu storage tidak cukup.

---

# Cara Cek

```bash
lvs
```

atau:

```bash
lvs -a
```

Lihat:

```text
Data%
Meta%
```

---

# Solusi 1 — Gunakan Linked Clone

Recommended.

Saat clone:

```text
UNSELECT Full Clone
```

Pilih:

```text
Linked Clone
```

---

# Solusi 2 — Hapus Disk Tidak Terpakai

Cek:

```bash
pvesm list local-lvm
```

Hapus:

```text
Unused Disk
```

---

# Solusi 3 — Extend Thin Pool

Cek:

```bash
vgs
lvs
```

---

## Extend

```bash
lvextend -l +100%FREE /dev/pve/data
```

---

# Solusi 4 — Clone ke Storage Lain

Saat clone:

```text
Target Storage
```

ubah ke:

```text
local
```

atau storage lain.

---

# Solusi 5 — Remove EFI Disk

Kadang:

```text
efidisk0
```

menyebabkan clone gagal.

---

## Remove EFI Disk

```text
VM
→ Hardware
→ EFI Disk
→ Remove
```

Lalu clone ulang.

---

## Tambahkan Lagi Setelah Clone

```text
Hardware
→ Add
→ EFI Disk
```

---

# Solusi 6 — Clone via CLI

## Full Clone

```bash
qm clone 101 105 --name alma9-clone --full true
```

---

## Linked Clone

```bash
qm clone 101 105 --name alma9-clone
```

---

# 15. Best Practice Production

# Rekomendasi Kedepannya — Gunakan Cloud-Init Template

Untuk deployment modern di Proxmox, sangat direkomendasikan menggunakan:

```text
Cloud Image + Cloud-Init
```

karena memungkinkan inject otomatis:

* IP address
* DNS
* gateway
* SSH key
* hostname
* username
* password

langsung dari Proxmox.

---

# Kenapa Cloud-Init Lebih Baik

| Feature          | ISO Installer | Cloud-Init |
| ---------------- | ------------- | ---------- |
| Auto DNS         | ❌             | ✅          |
| Auto SSH         | ❌             | ✅          |
| Auto IP          | ❌             | ✅          |
| Clone cepat      | ❌             | ✅          |
| Automation       | ❌             | ✅          |
| Production Ready | ⚠️            | ✅          |

---

# Download AlmaLinux Cloud Image

Contoh:

```text
AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
```

---

# Create Cloud VM

## Create VM

```bash
qm create 9000 --name alma9-cloud --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0
```

---

## Import Disk

```bash
qm importdisk 9000 AlmaLinux-9-GenericCloud-latest.x86_64.qcow2 local-lvm
```

---

## Attach Disk

```bash
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0
```

---

# PENTING — Tambahkan CloudInit Drive

Jika tidak dilakukan, akan muncul error:

```text
No CloudInit Drive found
```

Tambahkan:

```bash
qm set 9000 --ide2 local-lvm:cloudinit
```

---

## Boot Config

```bash
qm set 9000 --boot c --bootdisk scsi0
```

---

## Serial Console

```bash
qm set 9000 --serial0 socket --vga serial0
```

---

# Inject Network

## DHCP

```bash
qm set 9000 --ipconfig0 ip=dhcp
```

---

## Static IP

```bash
qm set 9000 --ipconfig0 ip=192.168.1.10/24,gw=192.168.1.1
```

---

# Inject DNS

```bash
qm set 9000 --nameserver "1.1.1.1 8.8.8.8"
```

---

# Inject User

```bash
qm set 9000 --ciuser admin
```

---

# Inject Password

```bash
qm set 9000 --cipassword PASSWORD_KAMU
```

---

# Inject SSH Key

```bash
qm set 9000 --sshkey ~/.ssh/id_rsa.pub
```

---

# Resize Disk

```bash
qm resize 9000 scsi0 30G
```

---

# Convert Menjadi Template

```bash
qm template 9000
```

---

# Clone Template

```bash
qm clone 9000 101 --name alma9-prod
```

---

# Hasil

Setiap VM clone langsung memiliki:

* network aktif
* DNS aktif
* SSH aktif
* hostname otomatis
* internet langsung jalan
* siap production

---

# Recommended Final Architecture

## Recommended Setup

| Komponen    | Recommended  |
| ----------- | ------------ |
| BIOS        | OVMF UEFI    |
| Machine     | q35          |
| Disk        | VirtIO SCSI  |
| Filesystem  | XFS          |
| Clone       | Linked Clone |
| CPU Type    | host         |
| Guest Agent | Enabled      |
| TRIM        | Enabled      |

---

# Strategy Template

## Base Template

```text
20G–30G
```

---

## Resize Setelah Clone

| Use Case    | Resize |
| ----------- | ------ |
| Web Server  | 40G    |
| Docker Host | 100G   |
| Database    | 300G   |

---

# 16. Troubleshooting

# Kernel Panic Saat Boot

## Penyebab

* CPU type tidak cocok
* ISO corrupt
* RAM terlalu kecil
* VirtIO issue

---

## Solusi

Ganti:

```text
CPU Type
→ x86-64-v2-AES
```

atau:

```text
kvm64
```

---

# VM Tidak Bisa Boot

Cek:

```text
Boot Order
```

Pastikan disk utama berada di urutan pertama.

---

# Network Tidak Terdeteksi

Gunakan:

```text
VirtIO
```

atau:

```text
Intel E1000
```

---

# VM Lambat

Pastikan:

* CPU type = host
* VirtIO disk
* VirtIO network
* Guest Agent aktif
* SSD emulation aktif

---

# Thin Pool Hampir Penuh

Cek:

```bash
lvs
vgs
pvesm status
```

Jika Data%:

```text
>90%
```

segera:

* hapus unused disk
* migrate storage
* extend thin pool
* gunakan linked clone

---

# Kesimpulan

Untuk setup modern Proxmox + AlmaLinux:

## Recommended

* OVMF UEFI
* q35
* VirtIO
* XFS
* Linked Clone
* Template kecil
* Resize setelah clone
* QEMU Guest Agent
* Thin pool monitoring

---

# Final Recommendation

## Jangan:

```text
Buat template 300G
```

## Lakukan:

```text
Template 20G
→ Linked Clone
→ Resize sesuai kebutuhan
```

karena:

```text
Grow = mudah
Shrink = sulit
```
