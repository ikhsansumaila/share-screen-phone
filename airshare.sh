#!/usr/bin/env bash
# Jalankan receiver AirPlay. Opsi lewat environment variable:
#   NAME=RuangRapat  PIN=1234  FULLSCREEN=0  RES=1920x1080@60  ./airshare.sh
NAME="${NAME:-AirShare-$(hostname)}"
RES="${RES:-1920x1080@60}"
args=(-n "$NAME" -nh -s "$RES" -vsync no)
[ "${FULLSCREEN:-1}" = "1" ] && args+=(-fs)
[ -n "${PIN:-}" ] && args+=(-pin "$PIN")
command -v uxplay >/dev/null || { echo "uxplay belum terpasang. Jalankan ./install-ubuntu.sh"; exit 1; }
echo "Receiver aktif dengan nama: $NAME  (Ctrl+C untuk berhenti)"
exec uxplay "${args[@]}" "$@"
