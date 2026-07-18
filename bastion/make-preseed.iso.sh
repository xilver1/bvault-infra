#!/usr/bin/env bash
#
# make-preseed-iso.sh
#
# Remaster a Debian netinst ISO with an embedded preseed.cfg.
# Run under WSL. Requires: xorriso, 7zip (or bsdtar), cpio, gzip, isolinux.
#   sudo apt install xorriso p7zip-full cpio isolinux
#
# Usage:
#   ./make-preseed-iso.sh debian-13.1.0-amd64-netinst.iso preseed.cfg bootstrap.sh
#
# Output ISO contains TS_AUTHKEY and ADMIN_PASSWORD_HASH in plaintext (in both
# preseed.cfg and bootstrap.sh). It is a secret. Shred it once the USB is written.

set -euo pipefail

ISO_IN="${1:?usage: $0 <netinst.iso> <preseed.cfg> <bootstrap.sh>}"
PRESEED="${2:?usage: $0 <netinst.iso> <preseed.cfg> <bootstrap.sh>}"
BOOTSTRAP="${3:?usage: $0 <netinst.iso> <preseed.cfg> <bootstrap.sh>}"

ISO_OUT="preseed-$(basename "$ISO_IN")"
WORK="$(mktemp -d)"
ISOFILES="$WORK/isofiles"

cleanup() { chmod -R +w "$WORK" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

[[ -f "$ISO_IN"    ]] || { echo "no such ISO: $ISO_IN"; exit 1; }
[[ -f "$PRESEED"   ]] || { echo "no such preseed: $PRESEED"; exit 1; }
[[ -f "$BOOTSTRAP" ]] || { echo "no such bootstrap: $BOOTSTRAP"; exit 1; }

# --- extract ----------------------------------------------------------------
echo ">> extracting $ISO_IN"
7z x -o"$ISOFILES" "$ISO_IN" > /dev/null
chmod -R +w "$ISOFILES"

[[ -f "$ISOFILES/install.amd/initrd.gz" ]] || {
    echo "ERROR: install.amd/initrd.gz not found - is this an amd64 netinst?"; exit 1; }

# --- inject preseed + bootstrap into the initrd -----------------------------
# d-i automatically reads /preseed.cfg from the initrd root. bootstrap.sh rides
# along at the same level, so late_command finds it at /bootstrap.sh during
# install (initrd is mounted as /). cpio -A appends; feed it both names.
echo ">> injecting preseed.cfg + bootstrap.sh into initrd"
gunzip "$ISOFILES/install.amd/initrd.gz"
STAGE="$WORK/stage"
mkdir -p "$STAGE"
cp "$PRESEED"   "$STAGE/preseed.cfg"
cp "$BOOTSTRAP" "$STAGE/bootstrap.sh"
( cd "$STAGE" && printf '%s\n' preseed.cfg bootstrap.sh \
    | cpio -H newc -o -A -F "$ISOFILES/install.amd/initrd" 2>/dev/null )
gzip "$ISOFILES/install.amd/initrd"

# --- boot menu --------------------------------------------------------------
# The initrd preseed is ONLY read by the text installer. Booting the graphical
# installer ignores it entirely. So: one entry, text mode, zero timeout.
echo ">> rewriting boot menus"
cat > "$ISOFILES/boot/grub/grub.cfg" <<'GRUB'
set default=0
set timeout=0

menuentry 'Automated install' {
    set background_color=black
    linux /install.amd/vmlinuz auto=true priority=critical vga=788 --- quiet
    initrd /install.amd/initrd.gz
}
GRUB

# BIOS path, in case the box ever boots CSM.
if [[ -d "$ISOFILES/isolinux" ]]; then
    cat > "$ISOFILES/isolinux/isolinux.cfg" <<'ISOLINUX'
default auto
label auto
    kernel /install.amd/vmlinuz
    append auto=true priority=critical vga=788 initrd=/install.amd/initrd.gz --- quiet
prompt 0
timeout 1
ISOLINUX
fi

# --- checksums --------------------------------------------------------------
echo ">> regenerating md5sum.txt"
( cd "$ISOFILES" && \
  find -follow -type f ! -name md5sum.txt -print0 | xargs -0 md5sum > md5sum.txt )

# --- isohybrid MBR ----------------------------------------------------------
MBR="/usr/lib/ISOLINUX/isohdpfx.bin"
if [[ ! -f "$MBR" ]]; then
    echo ">> isohdpfx.bin not found, deriving from source ISO"
    MBR="$WORK/isohdpfx.bin"
    dd if="$ISO_IN" bs=1 count=432 of="$MBR" status=none
fi

# --- rebuild ----------------------------------------------------------------
# BIOS (isolinux) + UEFI (boot/grub/efi.img) El Torito entries. Dropping the
# second one gives you a stick that will not boot on a UEFI-only machine.
echo ">> building $ISO_OUT"
xorriso -as mkisofs \
    -o "$ISO_OUT" \
    -isohybrid-mbr "$MBR" \
    -c isolinux/boot.cat \
    -b isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -r -J -joliet-long \
    -V "DEBIAN_PRESEED" \
    "$ISOFILES" 2>/dev/null

echo
echo "built: $ISO_OUT"
echo
echo "This ISO contains secrets in plaintext. After writing the USB:"
echo "  shred -u $ISO_OUT $PRESEED $BOOTSTRAP"