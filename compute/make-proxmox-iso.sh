#!/bin/bash
set -eu
cd proxmox-auto-install-assistant-docker

if [[ ! -d iso ]]; then
    mkdir iso
fi
[ -f iso/proxmox-ve_9.2-1.iso ] || wget -O iso/proxmox-ve_9.2-1.iso https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.isodocker build -t proxmox-auto-installer .
chmod +x entrypoint.sh
docker run --rm \
  -v $PWD/iso:/iso:ro \
  -v $PWD/secrets:/answers:ro \
  -v $PWD/iso/output:/out \
  proxmox-auto-installer:latest \
    /iso/proxmox-ve_9.2-1.iso \
    pve-1

