#!/bin/bash
# check-mounts.sh - Health check and auto-remount for SSHFS mounts
#
# Run via systemd timer (mount-check.timer) every 30 seconds.
# Detects stale mounts and remounts them automatically.
#
# Configure MOUNT_POINTS as an array of "ssh_alias:remote_path:local_mount_point" triplets.

# ---- Configure your mounts here ----
# Format: "SSH_ALIAS:REMOTE_PATH:LOCAL_MOUNT_POINT"
MOUNT_POINTS=(
    # Example: "<SSH_ALIAS>:<REMOTE_PATH>:<LOCAL_MOUNT_POINT>"
    # "<SSH_ALIAS>:/Users/username:/mnt/remote-home"
)
# -------------------------------------

LOG_FILE="/var/log/mount-check.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    echo "[$TIMESTAMP] $*" | tee -a "$LOG_FILE"
}

remount() {
    local host="$1"
    local remote="$2"
    local local_mp="$3"

    log "Remounting $host:$remote -> $local_mp"

    # Force unmount stale mount
    fusermount -u "$local_mp" 2>/dev/null || true
    sleep 1

    # Remount
    sshfs \
        -o StrictHostKeyChecking=no \
        -o reconnect \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=3 \
        -o allow_other \
        "${host}:${remote}" "$local_mp" 2>&1 | tee -a "$LOG_FILE"

    if mountpoint -q "$local_mp"; then
        log "Remount succeeded: $local_mp"
    else
        log "ERROR: Remount failed: $local_mp"
    fi
}

if [ ${#MOUNT_POINTS[@]} -eq 0 ]; then
    # No mounts configured, nothing to check
    exit 0
fi

for entry in "${MOUNT_POINTS[@]}"; do
    IFS=':' read -r host remote local_mp <<< "$entry"

    if [ -z "$host" ] || [ -z "$remote" ] || [ -z "$local_mp" ]; then
        log "WARNING: Invalid mount entry: $entry"
        continue
    fi

    mkdir -p "$local_mp"

    if ! mountpoint -q "$local_mp"; then
        log "Mount missing: $local_mp - mounting"
        remount "$host" "$remote" "$local_mp"
        continue
    fi

    # Test if mount is actually responsive (not just stale)
    if ! timeout 5 ls "$local_mp" > /dev/null 2>&1; then
        log "Mount stale: $local_mp - remounting"
        remount "$host" "$remote" "$local_mp"
    fi
done
