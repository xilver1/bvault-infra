FROM debian:trixie

# Install required dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        curl \
        xorriso && \
    update-ca-certificates && \
    # Proxmox Trixie release key, fetched over HTTPS from the official source
    install -d /etc/apt/keyrings && \
    wget https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg \
        -O /etc/apt/keyrings/proxmox-release-trixie.gpg && \
    printf 'Types: deb\nURIs: http://download.proxmox.com/debian/pve\nSuites: trixie\nComponents: pve-no-subscription\nSigned-By: /etc/apt/keyrings/proxmox-release-trixie.gpg\n' \
        > /etc/apt/sources.list.d/proxmox.sources && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        proxmox-auto-install-assistant && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]