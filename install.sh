#!/usr/bin/env bash
# Install gpumon system-wide. Run as root:
#
#   sudo ./install.sh               install / upgrade and (re)start the collector
#   sudo ./install.sh --uninstall   stop the collector and remove the program
#                                   (data in /var/lib/gpumon is left in place)
#
# Puts the command in /usr/local/bin (already on everyone's PATH), keeps data in
# /var/lib/gpumon, and runs the collector as the systemd service gpumon.service.
set -euo pipefail

BIN=/usr/local/bin/gpumon
DATA=/var/lib/gpumon
DOC=/usr/local/share/doc/gpumon
UNIT=/etc/systemd/system/gpumon.service
SRC="$(cd "$(dirname "$0")" && pwd)"

if [[ $(id -u) -ne 0 ]]; then
    echo "error: run as root (sudo $0)" >&2
    exit 1
fi

if [[ "${1:-}" == "--uninstall" ]]; then
    systemctl disable --now gpumon.service 2>/dev/null || true
    rm -f "$UNIT" "$BIN"
    rm -rf "$DOC"
    systemctl daemon-reload
    echo "Removed gpumon. Data remains in $DATA."
    exit 0
fi

umask 022
install -d -m 755 "$DATA" "$DOC"
# Anyone may create claim files; the sticky bit lets only their owner delete them.
install -d -m 1777 "$DATA/claims"
touch "$DATA/claims/.lock"
chmod 644 "$DATA/claims/.lock"

install -m 755 "$SRC/gpumon" "$BIN.new"
mv -f "$BIN.new" "$BIN"
install -m 644 "$SRC/README.md" "$DOC/README.md"

cat > "$UNIT" <<EOF
[Unit]
Description=gpumon GPU usage collector
After=nvidia-persistenced.service docker.service

[Service]
ExecStart=$BIN collect
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gpumon.service >/dev/null 2>&1
systemctl restart gpumon.service
sleep 2
systemctl --no-pager --lines=0 status gpumon.service | head -3
echo
echo "Installed. Everyone on this machine can now run: gpumon"
