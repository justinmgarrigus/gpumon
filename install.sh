#!/usr/bin/env bash
# Install gpumon into a world-readable location and keep the collector running
# via the invoking user's crontab (no root needed).
#
#   ./install.sh               install / upgrade and (re)start the collector
#   ./install.sh --uninstall   stop the collector and remove the cron entries
#                              (data is left in place; delete it by hand)
#
# GPUMON_PREFIX overrides the install location (default /var/tmp/gpumon).
set -euo pipefail

PREFIX="${GPUMON_PREFIX:-/var/tmp/gpumon}"
SRC="$(cd "$(dirname "$0")" && pwd)"
TAG="# gpumon-collector"

remove_cron() {
    (crontab -l 2>/dev/null | grep -vF "$TAG" || true) | crontab -
}

if [[ "${1:-}" == "--uninstall" ]]; then
    remove_cron
    [[ -x "$PREFIX/gpumon" ]] && "$PREFIX/gpumon" stop || true
    echo "Removed cron entries. Data remains in $PREFIX/data."
    exit 0
fi

if [[ -e "$PREFIX" && "$(stat -c %u "$PREFIX")" != "$(id -u)" ]]; then
    echo "error: $PREFIX exists and belongs to another user" >&2
    exit 1
fi

umask 022
mkdir -p "$PREFIX/data"
chmod 755 "$PREFIX" "$PREFIX/data"

# Stop an older collector so the new code takes over.
[[ -x "$PREFIX/gpumon" ]] && "$PREFIX/gpumon" stop >/dev/null 2>&1 || true

sed "s|^DEFAULT_DATA_DIR = .*|DEFAULT_DATA_DIR = \"$PREFIX/data\"|" "$SRC/gpumon" > "$PREFIX/gpumon.new"
chmod 755 "$PREFIX/gpumon.new"
mv -f "$PREFIX/gpumon.new" "$PREFIX/gpumon"
cp "$SRC/README.md" "$PREFIX/README.md"
chmod 644 "$PREFIX/README.md"

# @reboot starts it after boot; the periodic entry restarts it if it ever dies
# (a second copy exits immediately because the first holds the lock).
CMD="$PREFIX/gpumon collect -q >/dev/null 2>&1"
remove_cron
(crontab -l 2>/dev/null || true; echo "@reboot sleep 60; $CMD $TAG"; echo "*/10 * * * * $CMD $TAG") | crontab -

# Start now, detached from this shell.
sleep 1
setsid nohup "$PREFIX/gpumon" collect -q >/dev/null 2>&1 < /dev/null &
sleep 2
"$PREFIX/gpumon" status
echo
echo "Installed. Everyone on this machine can run:  $PREFIX/gpumon"
echo "Suggested alias:  alias gpumon=$PREFIX/gpumon"
