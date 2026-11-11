#!/usr/bin/env bash
# Pasang receiver AirPlay (UxPlay) di Ubuntu/Debian.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"

apt-get update
apt-get install -y uxplay avahi-daemon \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl
systemctl enable --now avahi-daemon

# Buka port AirPlay kalau ufw aktif
if command -v ufw >/dev/null && ufw status | grep -q "Status: active"; then
  ufw allow 5353/udp
  ufw allow 7000:7100/tcp
  ufw allow 6000:7011/udp
fi
echo "Selesai. Jalankan: ./airshare.sh"
