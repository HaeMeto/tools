#!/bin/bash
# Script untuk mengganti Proxmox Enterprise repo ke No-Subscription repo
# Tested on Proxmox VE 8 (Debian 12 "Bookworm" / 13 "Trixie")

set -e

echo "=== Backup repo lama ke /root/backup-apt-sources ==="
mkdir -p /root/backup-apt-sources
cp -a /etc/apt/sources.list.d/* /root/backup-apt-sources/ 2>/dev/null || true

echo "=== Hapus repo enterprise ==="
rm -f /etc/apt/sources.list.d/pve-enterprise.list
rm -f /etc/apt/sources.list.d/pve-enterprise.sources

echo "=== Bersihkan Ceph enterprise source (jika ada) ==="
if grep -q "enterprise.proxmox.com" /etc/apt/sources.list.d/ceph.sources 2>/dev/null; then
    mv /etc/apt/sources.list.d/ceph.sources /root/backup-apt-sources/ceph.sources.enterprise.backup
    echo "deb http://download.proxmox.com/debian/ceph-squid trixie no-subscription" > /etc/apt/sources.list.d/ceph.list
fi

echo "=== Tambahkan PVE no-subscription repo ==="
cat > /etc/apt/sources.list.d/pve-no-subscription.list <<EOF
deb http://download.proxmox.com/debian/pve trixie pve-no-subscription
EOF

echo "=== Update daftar paket ==="
apt update

echo "=== Selesai! Sekarang Proxmox sudah pakai repo no-subscription. ==="
