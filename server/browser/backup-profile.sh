#!/bin/bash
# backup-profile.sh — tarball the authenticated-chrome profile.
# Cookies, localStorage, IndexedDB survive reboots via this snapshot.

set -u
BACKUP_DIR="${BACKUP_DIR:-/root/authenticated-browser/profile-backups}"
PROFILE_DIR="/root/.config/authenticated-chrome"

mkdir -p "$BACKUP_DIR"
ts=$(date '+%Y%m%d-%H%M%S')
out="$BACKUP_DIR/chrome-profile-$ts.tgz"

echo "→ snapshotting $PROFILE_DIR → $out"
tar --warning=no-file-changed -czf "$out" -C "$(dirname "$PROFILE_DIR")" "$(basename "$PROFILE_DIR")" \
  && echo "✓ $(du -h "$out" | cut -f1)  $out" \
  || echo "⚠ backup exited non-zero (likely: profile changed during tar — file is still usable)"

# Keep last 10 only.
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'chrome-profile-*.tgz' -printf '%T@ %p\n' 2>/dev/null \
  | sort -rn \
  | awk 'NR > 10 {sub(/^[^ ]+ /, ""); print}' \
  | while IFS= read -r old; do
      rm -v -- "$old"
    done
