#!/bin/sh
# installer.sh — OpenWrt installer untuk Hnatta/hgledlan
# Langkah: download ZIP -> extract -> copy files/ -> chmod -> patch rc.local -> cleanup
# Kompatibel BusyBox (OpenWrt); tanpa rekursi/loop.

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
    return
  fi
  log ">> Memasang unzip via opkg..."
  opkg update || true
  opkg install unzip || { echo "Gagal memasang unzip"; exit 1; }
}

extract_zip() {
  log ">> Mengekstrak ZIP..."
  unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"
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
  # pastikan rc.local ada dan executable
  if [ ! -f "$RC_LOCAL" ]; then
    printf '#!/bin/sh\n' > "$RC_LOCAL"
    chmod +x "$RC_LOCAL"
  fi

  # Hapus blok lama dan baris 'exit 0' lama (kompatibel BusyBox awk)
  awk 'BEGIN{skip=0}
       /^# >>> hgledlan start$/ {skip=1; next}
       /^# <<< hgledlan end$/   {skip=0; next}
       { if (!skip && $0 !~ /^[[:space:]]*exit 0[[:space:]]*$/) print }' "$RC_LOCAL" > "$RC_LOCAL.tmp"

  # Tambahkan blok baru + exit 0
  cat >> "$RC_LOCAL.tmp" <<'EOF'
# >>> hgledlan start
sleep 2
/usr/sbin/hgledon -power off || true
/usr/sbin/hgledon -lan off   || true
sleep 20
/usr/sbin/hgled -r           || true
# <<< hgledlan end
exit 0
EOF

  mv "$RC_LOCAL.tmp" "$RC_LOCAL"
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
  log ">> Instalasi hgledlan selesai. Kamu bisa reboot, atau jalankan sekarang: /usr/sbin/hgled -r"
}

main "$@"
