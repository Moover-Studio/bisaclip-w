#!/usr/bin/env bash
# Bagian Ubuntu dari installer Windows: dipanggil oleh install-windows.ps1 sebagai root di WSL2.
#   bash install-in-wsl.sh <sumber> [--lib=bisaclip-library.tar.gz] [--no-cuda]
# <sumber> = folder hasil git clone (di drive Windows) atau folder paket berisi bisaclip-app.tar.gz.
# Pasang baru: kode → /var/www/bisaclip, lalu install/setup-wsl.sh & library musik/SFX/preset.
# Update (sudah terpasang): hanya kode yang diganti; storage/ previews/ downloads/ avatars/ tidak disentuh.
# Aplikasi sengaja dijalankan dari /var/www (disk Linux), bukan dari drive Windows (/mnt/c) yang sangat lambat.
set -euo pipefail

SRC="${1:?folder sumber}"; shift
APP=/var/www/bisaclip
LIB=""
PASS=()
for a in "$@"; do
  case "$a" in
    --lib=*) LIB="${a#--lib=}" ;;
    *) PASS+=("$a") ;;
  esac
done

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31m✗ %s\033[0m\n' "$*"; exit 1; }

[[ $EUID -eq 0 ]] || die "Harus dijalankan sebagai root."
command -v rsync >/dev/null 2>&1 || { apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq rsync >/dev/null; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if [[ -f "$SRC/config.php" ]]; then
  CODE="$SRC"
  VER="$(git -C "$SRC" log -1 --format='%h %cd' --date=short 2>/dev/null || echo 'folder lokal')"
elif [[ -f "$SRC/bisaclip-app.tar.gz" ]]; then
  CODE="$TMP/app"
  mkdir -p "$CODE"
  tar --warning=no-unknown-keyword -xzf "$SRC/bisaclip-app.tar.gz" -C "$CODE"
  VER="$(cat "$SRC/VERSION" 2>/dev/null || echo paket)"
else
  die "Kode aplikasi tidak ditemukan di $SRC"
fi
[[ -f "$CODE/config.php" ]] || die "Isi sumber tidak valid."
mkdir -p "$APP"

# Pemasangan pertama yang belum pernah selesai tetap dianggap baru (penanda ditulis di akhir)
FRESH=1; [[ -f "$APP/storage/.windows-installed" ]] && FRESH=0
if [[ -f "$APP/config.php" ]]; then
  say "Update BisaClip (data di laptop ini tetap)…"
  BK="/root/BisaClip-backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BK"
  find "$APP/storage" -maxdepth 1 -type f \( -name '*.json' -o -name '*.key' \) -exec cp -p {} "$BK/" \; 2>/dev/null || true
  ok "Cadangan pengaturan: $BK"
else
  say "Memasang BisaClip ke $APP…"
fi
# Kode diganti; folder data dikecualikan (file bawaan di dalamnya, mis. .htaccess, hanya ditambah kalau belum ada)
rsync -rlt --exclude '/.git/' --exclude '*.tar.gz' --exclude '*.zip' \
  --exclude '/storage/' --exclude '/previews/' --exclude '/downloads/' --exclude '/avatars/' "$CODE/" "$APP/"
for d in storage previews downloads avatars; do
  [[ -d "$CODE/$d" ]] && { mkdir -p "$APP/$d"; rsync -rlt --ignore-existing "$CODE/$d/" "$APP/$d/"; }
done
# File dari drive Windows tidak membawa izin Linux: rapikan (folder 755, file 644, skrip bisa dijalankan)
find "$APP" \( -path "$APP/storage" -o -path "$APP/previews" -o -path "$APP/downloads" -o -path "$APP/avatars" \) -prune \
  -o -type d -exec chmod 755 {} + -o -type f -exec chmod 644 {} +
chmod 755 "$APP"/install/*.sh "$APP"/install/windows/*.sh "$APP"/tools/*.py 2>/dev/null || true
# Jaga-jaga kalau git di Windows mengubah akhir baris skrip jadi CRLF (lihat .gitattributes)
sed -i 's/\r$//' "$APP"/install/*.sh "$APP"/install/windows/*.sh "$APP"/tools/*.py
ok "Kode: $VER"

# Model AI yang ikut di file library (opsi --with-models di Mac) dipasang duluan supaya tidak diunduh ulang
if [[ -n "$LIB" && -f "$LIB" ]] && tar -tzf "$LIB" 2>/dev/null | grep -q '^storage/models/'; then
  mkdir -p "$TMP/lib" "$APP/storage/models"
  tar --warning=no-unknown-keyword -xzf "$LIB" -C "$TMP/lib" storage/models
  rsync -a --ignore-existing "$TMP/lib/storage/models/" "$APP/storage/models/"
  ok "Model AI dari file library"
fi

# Tool, Apache, Python, model (yang belum ada) + cek sistem
bash "$APP/install/setup-wsl.sh" "${PASS[@]+"${PASS[@]}"}"

if [[ -n "$LIB" && -f "$LIB" ]]; then
  say "Memasang library musik, SFX & preset…"
  bash "$APP/install/import-library.sh" "$LIB"
fi
# Pemasangan baru: kompresi H.264 (HEVC butuh codec tambahan di Windows)
if [[ $FRESH -eq 1 ]]; then
  php -r '$f=$argv[1]; $s=json_decode((string)@file_get_contents($f),true); $s=is_array($s)?$s:[]; $s["clip_codec"]="h264";
    file_put_contents($f, json_encode($s, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE));' "$APP/storage/settings.json"
  ok "Kompresi clip: H.264 (bisa diubah di Pengaturan)"
fi
date > "$APP/storage/.windows-installed"
chown -R www-data:www-data "$APP"/{storage,downloads,previews,avatars}
ok "BisaClip siap"
