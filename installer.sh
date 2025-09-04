#!/bin/sh
# install-hgledlan.sh — OpenWrt one-shot installer via ZIP
# - Download ZIP
# - Extract
# - Run repo installer.sh
# - Cleanup (ZIP + extracted dir)

set -e

ZIP_URL="https://github.com/Hnatta/hgledlan/archive/refs/heads/main.zip"
WORKDIR="/tmp/hgledlan-$$"
ZIP_FILE="$WORKDIR/main.zip"
EXTRACT_DIR="$WORKDIR/extract"
REPO_DIR="$EXTRACT_DIR/hgledlan-main"

log() { printf "%s\n" "$*"; }
die() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

need_root() { [ "$(id -u)" -eq 0 ] || die "jalankan sebagai root"; }

have() { command -v "$1" >/dev/null 2>&1; }

fetch_zip() {
  log ">> Mengunduh ZIP..."
  mkdir -p "$WORKDIR"
  if have curl; then
    # dua percobaan: normal, lalu fallback (ipv4 + tlsv1.2 + http/1.1)
    curl -fsSL --connect-timeout 10 --retry 3 -o "$ZIP_FILE" "$ZIP_URL" \
    || curl -fsSL -4 --tlsv1.2 --http1.1 -o "$ZIP_FILE" "$ZIP_URL" \
    || die "gagal mengunduh ZIP (curl)"
  elif have wget; then
    wget -q -O "$ZIP_FILE" "$ZIP_URL" \
    || wget -q --no-check-certificate -O "$ZIP_FILE" "$ZIP_URL" \
    || die "gagal mengunduh ZIP (wget)"
  else
    die "butuh curl atau wget"
  fi
}

ensure_unzip() {
  if have unzip; then
    UNZIP="unzip -q"
    return
  fi
  if have bsdtar; then
    UNZIP="bsdtar -xf"
    return
  fi
  if have opkg; then
    log ">> Memasang 'unzip' via opkg..."
    opkg update || true
    opkg install unzip || die "opkg gagal memasang unzip"
    UNZIP="unzip -q"
  else
    die "tidak ada unzip/bsdtar dan tidak bisa memasang via opkg"
  fi
}

extract_zip() {
  log ">> Mengekstrak ZIP..."
  mkdir -p "$EXTRACT_DIR"
  # pilih perintah ekstrak sesuai ketersediaan
  if echo "$UNZIP" | grep -q bsdtar; then
    bsdtar -xf "$ZIP_FILE" -C "$EXTRACT_DIR"
  else
    unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"
  fi
  [ -d "$REPO_DIR" ] || die "folder repo tidak ditemukan di dalam ZIP"
}

run_installer() {
  log ">> Menjalankan installer bawaan repo..."
  cd "$REPO_DIR" || die "gagal cd ke $REPO_DIR"
  [ -f installer.sh ] || die "installer.sh tidak ada di repo ZIP"
  # pastikan bisa dieksekusi
  chmod +x installer.sh || true
  sh ./installer.sh
}

cleanup() {
  log ">> Cleanup..."
  rm -rf "$WORKDIR"
  log ">> Selesai."
}

main() {
  need_root
  fetch_zip
  ensure_unzip
  extract_zip
  run_installer
  cleanup
}

main "$@"
