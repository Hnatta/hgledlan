#!/bin/sh
# installer.sh — OpenWrt installer untuk Hnatta/hgledlan
# Langkah: download ZIP -> extract -> copy files/ -> chmod -> patch rc.local -> cleanup

set -eu

ZIP_URL="https://github.com/Hnatta/hgledlan/archive/refs/heads/main.zip"
WORKDIR="$(mktemp -d /tmp/hgledlan.XXXXXX)"
ZIP_FILE="$WORKDIR/main.zip"
EXTRACT_DIR="$WORKDIR/extract"
REPO_DIR="$EXTRACT_DIR/hgledlan-main"
RC_LOCAL="/etc/rc.local"

log() { printf "%s\n" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

need_root() {
  [ "$(id -u)" -eq 0 ] || { echo "Harus dijalankan sebagai root"; exit 1; }
}

fetch_zip() {
  log ">> Mengunduh ZIP..."
  mkdir -p "$EXTRACT_DIR"
  if have curl; then
    curl -fsSL --connect-timeout 10 --retry 3 -o "$ZIP_FILE" "$ZIP_URL" \
    || { opkg update >/dev/null 2>&1 || true; opkg install ca-bundle ca-certificates >/dev/null 2>&1 || true; curl -fsSL -o "$ZIP_FILE" "$ZIP_URL"; }
  elif have wget; then
    wget -q -O "$ZIP_FILE" "$ZIP_URL" \
    || { opkg update >/dev/null 2>&1 || true; opkg install ca-bundle ca-certificates >/dev/null 2>&1 || true; wget -q -O "$ZIP_FILE" "$ZIP_URL"; }
  else
    opkg update || true
    opkg install wget-ssl || opkg install wget || true
    wget -q -O "$ZIP_FILE" "$ZIP_URL"
  fi
}

ensure_unzip() {
  if have unzip; then
    UNZIP=unzip
  elif have bsdtar; then
    UNZIP=bsdtar
  else
    log ">> Memasang unzip via opkg..."
    opkg update || true
    opkg install unzip || { echo "Gagal memasang unzip"; exit 1; }
    UNZIP=unzip
  fi
}

extract_zip() {
  log ">> Mengekstrak ZIP..."
  if [ "$UNZIP" = "bsdtar" ]; then
    bsdtar -xf "$ZIP_FILE" -C "$EXTRACT_DIR"
  else
    unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"
  fi
  [ -d "$REPO_DIR/files" ] || { echo "folder files/ tidak ditemukan di dalam ZIP"; exit 1; }
}

install_files() {
  log ">> Menyalin berkas ke root (/)..."
  # copy isi folder files/ (titik di akhir penting untuk copy hidden files)
  cp -a "$REPO_DIR/files/." / 2>/dev/null || cp -R "$REPO_DIR/files/"* /
  # normalisasi EOL + izin eksekusi
  for f in /usr/sbin/hgled /usr/sbin/hgledon; do
    [ -f "$f" ] && { sed -i 's/\r$//' "$f" 2>/dev/null || true; chmod +x "$f" 2>/dev/null || true; }
  done
}

patch_rc_local() {
  log ">> Menambahkan startup di rc.local..."
  if [ ! -f "$RC_LOCAL" ]; then
    printf '#!/bin/sh\n' > "$RC_LOCAL"
    chmod +x "$RC_LOCAL"
  fi
  # hapus block lama (jika ada) dan baris exit 0 agar tidak dobel
  sed -i '/^# >>> hgledlan start$/, /^# <<< hgledlan end$/d' "$RC_LOCAL"
  sed -i '/^[[:space:]]*exit 0[[:space:]]*$/d' "$RC_LOCAL"
  # tambahkan block baru + exit 0
  cat >> "$RC_LOCAL" <<'EOF'
# >>> hgledlan start
sleep 2
/usr/sbin/hgledon -power off || true
/usr/sbin/hgledon -lan off   || true
sleep 20
/usr/sbin/hgled -r           || true
# <<< hgledlan end
EOF
  echo "exit 0" >> "$RC_LOCAL"
}

cleanup() {
  log ">> Bersih-bersih file unduhan..."
  rm -rf "$WORKDIR"
}

main() {
  need_root
  fetch_zip
  ensure_unzip
  extract_zip
  install_files
  patch_rc_local
  cleanup
  log ">> Instalasi hgledlan selesai. Kamu bisa reboot, atau jalankan: /usr/sbin/hgled -r"
}

main "$@"
