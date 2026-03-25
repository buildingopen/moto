#!/bin/bash
# mount-remote.sh - Mount a remote filesystem via SSHFS
#
# Configure via environment variables or edit the defaults below.
#
# Usage:
#   ./mount-remote.sh              # Mount using configured defaults
#   ./mount-remote.sh unmount      # Unmount
#   ./mount-remote.sh status       # Check if mounted
#
# Environment variables (override defaults):
#   REMOTE_HOST        SSH alias or hostname (from ~/.ssh/config)
#   REMOTE_PATH        Path on the remote machine
#   LOCAL_MOUNT_POINT  Where to mount locally

set -e

# ---- Configure these ----
REMOTE_HOST="${REMOTE_HOST:-<SSH_ALIAS>}"
REMOTE_PATH="${REMOTE_PATH:-<REMOTE_PATH>}"
LOCAL_MOUNT_POINT="${LOCAL_MOUNT_POINT:-<LOCAL_MOUNT_POINT>}"
# -------------------------

CMD="${1:-mount}"

case "$CMD" in
    mount)
        if mountpoint -q "$LOCAL_MOUNT_POINT" 2>/dev/null; then
            echo "Already mounted: $LOCAL_MOUNT_POINT"
            exit 0
        fi
        mkdir -p "$LOCAL_MOUNT_POINT"
        echo "Mounting $REMOTE_HOST:$REMOTE_PATH -> $LOCAL_MOUNT_POINT"
        sshfs \
            -o StrictHostKeyChecking=no \
            -o reconnect \
            -o ServerAliveInterval=15 \
            -o ServerAliveCountMax=3 \
            -o allow_other \
            "${REMOTE_HOST}:${REMOTE_PATH}" "$LOCAL_MOUNT_POINT"
        echo "Mounted."
        ;;

    unmount|umount)
        if ! mountpoint -q "$LOCAL_MOUNT_POINT" 2>/dev/null; then
            echo "Not mounted: $LOCAL_MOUNT_POINT"
            exit 0
        fi
        echo "Unmounting $LOCAL_MOUNT_POINT"
        fusermount -u "$LOCAL_MOUNT_POINT"
        echo "Unmounted."
        ;;

    status)
        if mountpoint -q "$LOCAL_MOUNT_POINT" 2>/dev/null; then
            echo "MOUNTED: $LOCAL_MOUNT_POINT"
            # Quick connectivity test
            if ls "$LOCAL_MOUNT_POINT" > /dev/null 2>&1; then
                echo "STATUS: responsive"
            else
                echo "STATUS: stale (mount exists but not responding)"
                exit 2
            fi
        else
            echo "NOT MOUNTED: $LOCAL_MOUNT_POINT"
            exit 1
        fi
        ;;

    *)
        echo "Usage: $0 [mount|unmount|status]"
        exit 1
        ;;
esac
