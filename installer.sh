#!/bin/sh
# Pasang hgledon/hgled dan tambahkan ke /etc/rc.local (tanpa init.d)
# Pakai: curl -fsSL https://raw.githubusercontent.com/Hnatta/hgledlan/main/installer.sh | sh
set -eu

REPO_BASE="${REPO_BASE:-https://raw.githubusercontent.com/Hnatta/hgledlan/main}"

say(){ echo "[hgledlan] $*"; }
[ "$(id -u)" = "0" ] || { say "Harus dijalankan sebagai root"; exit 1; }

fetch_bin(){  # untuk B I N A R I (jangan di-sed)
  src="$1"; dst="$2"
  mkdir -p "$(dirname "$dst")"
  say "ambil(bin) $src -> $dst"
  curl -fsSL "$REPO_BASE/$src" -o "$dst"
  chmod +x "$dst"
}

# --- salin binari ---
fetch_bin files/usr/sbin/hgledon /usr/sbin/hgledon
fetch_bin files/usr/sbin/hgled   /usr/sbin/hgled

# --- siapkan /etc/rc.local kalau belum ada ---
if [ ! -f /etc/rc.local ]; then
  say "buat /etc/rc.local baru"
  cat > /etc/rc.local <<'NEWRC'
#!/bin/sh
# custom startup here
exit 0
NEWRC
  chmod +x /etc/rc.local
fi

# --- hapus blok lama (jika ada), lalu sisipkan blok baru sebelum 'exit 0' ---
BLOCK_START='# >>> hgledlan start'
BLOCK_END='# <<< hgledlan end'
sed -i "/^$BLOCK_START\$/,/^$BLOCK_END\$/d" /etc/rc.local

BLOCK_CONTENT=$(cat <<'BLK'
# >>> hgledlan start
sleep 2
/usr/sbin/hgledon -power off || true
/usr/sbin/hgledon -lan off   || true
sleep 20
/usr/sbin/hgled -r           || true
# <<< hgledlan end
BLK
)

if grep -qE '^exit 0$' /etc/rc.local; then
  awk -v blk="$BLOCK_CONTENT" '
    BEGIN{put=0}
    /^exit 0$/ && !put {print blk; put=1}
    {print}
    END{if(!put){print blk; print "exit 0"}}
  ' /etc/rc.local > /etc/rc.local.new && mv /etc/rc.local.new /etc/rc.local
else
  printf '%s\nexit 0\n' "$BLOCK_CONTENT" >> /etc/rc.local
fi
chmod +x /etc/rc.local

# --- jalankan SEKALI sekarang ---
if /usr/sbin/hgled -r >/dev/null 2>&1; then
  say "Jalankan: /usr/sbin/hgled -r  ✅"
else
  say "Jalankan: /usr/sbin/hgled -r  ❌ (abaikan jika perangkat belum mendukung)"
fi

say "Selesai ✅
- Binari: /usr/sbin/hgledon, /usr/sbin/hgled
- Startup otomatis sudah ditambahkan ke /etc/rc.local
- Tes manual: /usr/sbin/hgled -r
- Edit startup: vi /etc/rc.local (blok ditandai hgledlan)"
