#!/bin/sh
# Pasang hgledon/hgled + service di OpenWrt
# Pakai: curl -fsSL https://raw.githubusercontent.com/Hnatta/hgledlan/main/installer.sh | sh
set -eu
REPO_BASE="${REPO_BASE:-https://raw.githubusercontent.com/Hnatta/hgledlan/main}"

say(){ echo "[hgledlan] $*"; }
[ "$(id -u)" = "0" ] || { say "Harus dijalankan sebagai root"; exit 1; }

fetch_txt(){ src="$1"; dst="$2"; mode="${3:-}"; mkdir -p "$(dirname "$dst")"
  say "ambil $src -> $dst"; curl -fsSL "$REPO_BASE/$src" -o "$dst"
  sed -i 's/\r$//' "$dst" 2>/dev/null || true; [ "$mode" = "+x" ] && chmod +x "$dst"; }
fetch_bin(){ src="$1"; dst="$2"; mkdir -p "$(dirname "$dst")"
  say "ambil(bin) $src -> $dst"; curl -fsSL "$REPO_BASE/$src" -o "$dst"; chmod +x "$dst"; }

# biner
fetch_bin files/usr/sbin/hgledon /usr/sbin/hgledon
fetch_bin files/usr/sbin/hgled   /usr/sbin/hgled
# service + config
fetch_txt files/etc/init.d/hg-led /etc/init.d/hg-led +x
if curl -fsI "$REPO_BASE/files/etc/default/hg-led" >/dev/null 2>&1; then
  fetch_txt files/etc/default/hg-led /etc/default/hg-led
fi

# enable + start
/etc/init.d/hg-led stop >/dev/null 2>&1 || true
/etc/init.d/hg-led enable
/etc/init.d/hg-led start

say "Selesai ✅"
cat <<'EOF'
== Terpasang ==
- /usr/sbin/hgledon
- /usr/sbin/hgled
- Service: /etc/init.d/hg-led  (atur delay di /etc/default/hg-led)

Perintah berguna:
  /etc/init.d/hg-led restart
  /etc/init.d/hg-led status 2>/dev/null || true
  logread | tail -n 50
EOF
