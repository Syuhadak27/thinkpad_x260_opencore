#!/data/data/com.termux/files/usr/bin/bash
# Build OpenCore EFI -> ISO (untuk boot via Ventoy) + fallback FAT image
# Jalankan dari root repo:  bash build-efi-iso.sh
set -e

ISO="OpenCoreEFI.iso"
IMG="OC-EFI.img"
IMG_SIZE_MB=128

[ -d EFI ] || { echo "ERROR: folder EFI tidak ditemukan. Jalankan dari root repo."; exit 1; }
[ -f EFI/BOOT/BOOTx64.efi ] || { echo "ERROR: EFI/BOOT/BOOTx64.efi tidak ada (Ventoy butuh ini)."; exit 1; }

echo "==> Build $ISO"
rm -f "$ISO"
xorriso -as mkisofs -o "$ISO" -R -J -V OPENCORE_EFI -graft-points '/EFI=EFI' 2>&1 | tail -1

echo "==> Build $IMG (FAT32 fallback)"
rm -f "$IMG"
dd if=/dev/zero of="$IMG" bs=1M count=$IMG_SIZE_MB status=none
mkfs.vfat -F 32 "$IMG" >/dev/null
mcopy -s -i "$IMG" EFI ::/

echo "==> Selesai:"
ls -lh "$ISO" "$IMG"
