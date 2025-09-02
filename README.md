# hgledlan untuk hg680p mode lan

## Instalasi cepat

Jalankan di OpenWrt (root):

```bash
curl -fsSL https://raw.githubusercontent.com/Hnatta/hgledlan/main/installer.sh | sh
```

## Troubleshooting TLS (kalau mbedTLS rewel)

```
curl -fsSL -4 --tlsv1.2 --http1.1 \
  https://raw.githubusercontent.com/Hnatta/hgledlan/main/installer.sh | sh
```
# Langsung Run
```
hgled -r
```

# Opsional 
Timpa di Local Startup sebelum " exit 0 "
```
sleep 2
/usr/sbin/hgledon -power off
/usr/sbin/hgledon -lan off
sleep 20
/usr/sbin/hgled -r
```
