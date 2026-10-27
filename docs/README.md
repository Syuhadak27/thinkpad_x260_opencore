# Boot hachintos.raw / OpenCore via Ventoy (Tanpa Merusak Ventoy)

> Dokumentasi hasil diskusi internal + referensi:
> - Repo ini: EFI OpenCore untuk ThinkPad X260
> - [Ventoy Discussion #1361 — MacOS installation via ventoy](https://github.com/ventoy/Ventoy/discussions/1361)

## Konteks

Sudah terbukti work (metode referensi):

```
USB/HDD di-burn pakai balenaEtcher dari hachintos.raw
→ salin folder EFI (repo ini) ke partisi ESP hasil burning
→ boot UEFI → OpenCore → macOS jalan
```

Sekarang ingin mencoba hal yang sama di **HDD enclosure yang sudah berisi Ventoy**,
tanpa menghapus/mengubah installasi Ventoy yang sudah ada.

## Prinsip

Ventoy tidak boleh disentuh (tidak perlu install ulang, tidak perlu format).
Yang dilakukan hanyalah **menambah file** di partisi data Ventoy, lalu
chainload OpenCore dari sana. Installasi Ventoy tetap utuh 100%.

Catatan penting hasil discussion #1361:

- **OpenCore TIDAK bisa dibaca dari partisi exFAT/NTFS.**
  Buktinya: user `sticky-note` menaruh `EFI/OC/OpenCore.efi` di partisi data
  Ventoy, lalu gagal dengan:
  ```
  OC: Failed to load configuration!
  ```
  OpenCore hanya punya driver FAT bawaan — `config.plist` tidak bisa dibaca
  dari exFAT/NTFS. Artinya **partisi tempat EFI harus berupa FAT32** (atau EFI
  harus berada di dalam ESP ber-FAT di dalam sebuah image, lihat Metode B).

## Metode A — OpenCoreEFI di-ISO-kan (paling simpel, versi rvvh472)

1. Buat `.iso` dari folder `EFI` (pakai PowerISO / AnyBurn / `genisoimage`):
   ```bash
   genisoimage -o OpenCoreEFI.iso -R -J EFI/
   ```
2. Salin `OpenCoreEFI.iso` ke partisi data Ventoy (exFAT/NTFS tidak masalah,
   karena yang dibaca Ventoy adalah ISO-nya, bukan OpenCore langsung).
3. Boot UEFI (bukan Legacy/CSM), **Secure Boot OFF**.
4. Pilih `OpenCoreEFI.iso` di menu Ventoy → OpenCore jalan → pilih target macOS.

- ✅ Ventoy utuh, ISO bisa > 4GB, partisi data boleh exFAT/NTFS.
- ✅ Sudah pernah dipakai untuk clean install macOS Monterey (rvvh472).
- ❌ EFI "dibekukan" di ISO — mau edit `config.plist`/kext harus bikin ISO ulang.

## Metode B — Suntik EFI ke ESP di dalam file image hachintos (rekomendasi untuk kasus ini)

Kalau yang dicoba adalah `hachintos.raw` (image macOS siap pakai):

1. Update Ventoy dulu agar file `.img` dikenali (non-destruktif, data aman):
   - Windows: `Ventoy2Disk.exe` → tab **Update**
   - Linux: `sudo ./Ventoy2Disk.sh -u /dev/sdX`
2. Rename agar Ventoy menampilkannya (Ventoy hanya menampilkan ISO/WIM/IMG/VHD/EFI):
   ```
   hachintos.raw  →  hachintos.img
   ```
3. Suntikkan EFI repo ini ke **ESP di dalam file image** (Linux):
   ```bash
   sudo losetup -fP --show hachintos.img      # misal /dev/loop0
   sudo mkdir -p /mnt/esp
   sudo mount /dev/loop0p1 /mnt/esp           # p1 biasanya ESP (FAT)

   sudo mv /mnt/esp/EFI /mnt/esp/EFI.bak      # backup EFI bawaan image
   sudo cp -r /path/ke/EFI /mnt/esp/          # salin EFI repo ini

   sudo umount /mnt/esp
   sudo losetup -d /dev/loop0
   ```
   Di Windows pakai DiskGenius / OSFMount (mount partisi dalam file, read-write).
4. Salin `hachintos.img` ke partisi data Ventoy, boot UEFI, pilih dari menu Ventoy.

- ✅ OpenCore berjalan dari ESP FAT di dalam image → terhindar dari
  `OC: Failed to load configuration!`.
- ✅ Partisi data Ventoy tetap exFAT/NTFS, ISO lain tetap bisa > 4GB.
- ⚠️ **Experimental.** Tidak ada konfirmasi di discussion #1361 bahwa boot
  image macOS *besar* sebagai file penuh via Ventoy selalu berhasil, dan
  semua tulisan macOS jatuh ke file `.img` di atas exFAT — oke untuk testing,
  tidak disarankan untuk daily use (lambat, risiko korupsi).

## Metode C — img berisi EFI partition + APFS sebagai partisi asli (versi hexman1999, paling "benar")

Ini pola yang paling mirip dengan pengalaman balenaEtcher, dan terkonfirmasi
berhasil di discussion #1361:

1. Saat install Ventoy, sisakan ruang kosong di akhir disk untuk partisi macOS.
2. Clone **hanya partisi ESP** yang berisi OpenCore menjadi file `.img` kecil:
   ```bash
   # misal ESP lama di /dev/sdX1
   sudo dd if=/dev/sdX1 of=/path/ventoy/oc-esp.img bs=1M status=progress
   ```
3. Buat partisi APFS (installer macOS / hasil restore) di sisa ruang disk
   enclosure, memakai Disk Utility di macOS (bisa dari USB hachintos yang sudah work).
4. Boot UEFI → pilih `oc-esp.img` di menu Ventoy → OpenCore mendeteksi
   partisi APFS asli di disk yang sama → boot macOS.

- ✅ macOS berada di partisi asli (bukan file), performa & keamanan write normal.
- ✅ Bisa punya beberapa versi OC/installer (tinggal buat beberapa `.img` EFI).
- ⚠️ Sedikit lebih ribet, perlu menyisakan partisi khusus.

## Metode D — alternatif "one-for-all" (versi halal-beef)

Format partisi data Ventoy (bukan VTOYEFI!) jadi **FAT32**, lalu taruh folder
`EFI` + installer macOS langsung di sana, dan chainload `OpenCore.efi` lewat
F2 browser / custom boot entry Ventoy.

- ✅ Simpel, OpenCore baca config dengan normal (FAT32).
- ❌ FAT32 → semua ISO lain di Ventoy dibatasi **< 4GB**. Karena itu Metode B/C
  lebih disukai.

## Checklist Boot

- [ ] Boot mode **UEFI** (matikan CSM/Legacy)
- [ ] **Secure Boot OFF** (OpenCore unsigned; shim Ventoy hanya untuk distro Linux)
- [ ] Ventoy sudah versi terbaru (update non-destruktif)
- [ ] EFI berada di filesystem **FAT** (ESP di dalam image / FAT32), bukan exFAT/NTFS
- [ ] Kalau gagal, cek: `OC: Failed to load configuration!` → hampir pasti masalah
      filesystem (exFAT/NTFS) atau `config.plist` tidak selevel dengan folder `OC`

## Alternatif kalau gagal total

- Convert ke VHDX dan pakai vhdboot plugin Ventoy:
  ```bash
  qemu-img convert -O vhdx hachintos.img hachintos.vhdx
  ```
- Memdisk mode (`Ctrl+d` di menu Ventoy) — butuh RAM ≥ ukuran image, jarang muat.
- Untuk pemakaian serius: tetap jalur balenaEtcher/dd ke disk polos, atau
  install macOS proper dari installer (Metode C).

## Ringkasan keputusan

| Kebutuhan | Metode |
|---|---|
| Coba cepat, EFI jarang berubah | **A** (EFI di-ISO-kan) |
| Pakai hachintos.raw + EFI repo, tanpa sentuh Ventoy | **B** (suntik EFI ke ESP dalam image) |
| Dipakai harian di HDD enclosure | **C** (oc-esp.img + partisi APFS asli) |
