#!/bin/bash
set -euo pipefail

cd proxmox-auto-install-assistant-docker

ISO=iso/proxmox-ve_9.2-1.iso
ISO_URL=https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso

mkdir -p iso iso/output

[ -f "$ISO" ] || wget -O "$ISO" "$ISO_URL"
[ -f secrets/pve-1/answer.toml ] || { echo "ERROR: render.sh compute first (secrets/pve-1/answer.toml missing)" >&2; exit 1; }

docker build -t proxmox-auto-installer .

docker run --rm \
  -v "$PWD/iso:/iso:ro" \
  -v "$PWD/secrets:/answers:ro" \
  -v "$PWD/iso/output:/out" \
  proxmox-auto-installer:latest \
    /iso/proxmox-ve_9.2-1.iso \
    pve-1