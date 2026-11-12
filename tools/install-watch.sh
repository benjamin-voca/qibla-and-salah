#!/usr/bin/env bash
# Sideload the app onto a USB-connected Garmin watch (MTP).
# Usage: tools/install-watch.sh [device]   (default: vivoactive5)
set -euo pipefail
DEV=${1:-vivoactive5}
cd "$(dirname "$0")/.."
PRG=bin/Namaz-$DEV.prg
monkeyc -f monkey.jungle -d "$DEV" -y ~/.Garmin/ConnectIQ/developer_key.der -o "$PRG" 2>&1 | grep -v "launcher icon"

JMTPFS=$(nix build --no-link --print-out-paths nixpkgs#jmtpfs)/bin/jmtpfs
MNT=$(mktemp -d)
trap 'fusermount -u "$MNT" 2>/dev/null; rmdir "$MNT"' EXIT

echo "Waiting for the watch (plug it in)..."
watch_present() {
  for d in /sys/bus/usb/devices/*; do
    [ "$(cat "$d/idVendor" 2>/dev/null)" = 091e ] && return 0
  done
  return 1
}
until watch_present; do sleep 1; done
sleep 3  # let MTP come up
"$JMTPFS" "$MNT" >/dev/null
APPS=$(find "$MNT" -maxdepth 3 -type d -path "*/GARMIN/Apps" -o -maxdepth 3 -type d -path "*/GARMIN/APPS" | head -1)
[ -n "$APPS" ] || { echo "GARMIN/APPS not found on the watch"; ls -R "$MNT" | head; exit 1; }
cp "$PRG" "$APPS/Namaz.prg"
sync
echo "Installed $PRG -> $APPS/Namaz.prg"
