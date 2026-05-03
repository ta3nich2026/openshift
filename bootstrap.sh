#!/bin/bash
set -e

exec > /var/log/bootstrap-full.log 2>&1
echo "[*] Full setup started"

DISK="/dev/vdb"

if [ -b "$DISK" ]; then
  mkdir -p /mnt/pvc

  if ! blkid $DISK; then
    echo "[*] Formatting disk"
    mkfs.ext4 $DISK
  else
    echo "[*] Keeping existing data"
  fi

  mount $DISK /mnt/pvc || true

  grep -q "$DISK" /etc/fstab || \
    echo "$DISK /mnt/pvc ext4 defaults 0 2" >> /etc/fstab
fi

apt-get clean
rm -rf /var/lib/apt/lists/*

for i in {1..5}; do
  apt-get update && break
  sleep 5
done

for i in {1..5}; do
  apt-get install -y docker.io && break
  sleep 5
done

systemctl stop docker containerd || true

mkdir -p /mnt/pvc/docker

if [ ! -L /var/lib/docker ]; then
  rm -rf /var/lib/docker
  ln -s /mnt/pvc/docker /var/lib/docker
fi

systemctl daemon-reexec
systemctl enable --now docker containerd

usermod -aG docker ubuntu

echo "[*] DONE"
