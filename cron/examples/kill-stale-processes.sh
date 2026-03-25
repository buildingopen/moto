#!/bin/bash
# kill-stale-processes.sh - Clean up orphan and stale processes
#
# Browser automation, media processing, and rendering jobs can leave orphan
# processes when they crash or are abandoned. This script kills processes
# that match configured patterns and have been running longer than a threshold.
#
# Configuration via environment variables:
#   STALE_PROCESS_PATTERNS   Space-separated list of pgrep patterns to check
#   STALE_MAX_RUNTIME_MINS   Kill processes older than this many minutes (default: 60)
#   STALE_DRY_RUN            Set to "1" to log without killing (default: 0)
#   LOG_FILE                 Log file path (default: /var/log/kill-stale.log)
#
# Example STALE_PROCESS_PATTERNS:
#   "chrome-headless-shell playwright-chromium ffmpeg remotion"

set -euo pipefail

PATTERNS="${STALE_PROCESS_PATTERNS:-}"
MAX_MINS="${STALE_MAX_RUNTIME_MINS:-60}"
DRY_RUN="${STALE_DRY_RUN:-0}"
LOG_FILE="${LOG_FILE:-/var/log/kill-stale.log}"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

if [ -z "$PATTERNS" ]; then
  log "No STALE_PROCESS_PATTERNS configured, nothing to check."
  exit 0
fi

KILLED=0
CHECKED=0

for pattern in $PATTERNS; do
  # Get PIDs matching this pattern
  pids=$(pgrep -f "$pattern" 2>/dev/null || true)
  if [ -z "$pids" ]; then
    continue
  fi

  for pid in $pids; do
    # Skip if the process no longer exists
    [ -d "/proc/$pid" ] || continue

    # Get process start time and calculate runtime in minutes
    start_seconds=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo 0)
    now_seconds=$(date +%s)
    runtime_mins=$(( (now_seconds - start_seconds) / 60 ))
    cmd=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ' | cut -c1-80 || echo "(unknown)")

    CHECKED=$((CHECKED + 1))

    if [ "$runtime_mins" -ge "$MAX_MINS" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        log "DRY_RUN  would kill PID $pid (${runtime_mins}m): $cmd"
      else
        log "KILLING  PID $pid (${runtime_mins}m, pattern: $pattern): $cmd"
        kill -TERM "$pid" 2>/dev/null || true
        # Give it 5 seconds to exit cleanly, then force-kill
        sleep 5
        if [ -d "/proc/$pid" ]; then
          log "FORCE    PID $pid did not exit, sending SIGKILL"
          kill -KILL "$pid" 2>/dev/null || true
        fi
        KILLED=$((KILLED + 1))
      fi
    else
      log "OK       PID $pid (${runtime_mins}m, pattern: $pattern): $cmd"
    fi
  done
done

log "SUMMARY  checked=$CHECKED killed=$KILLED (dry_run=${DRY_RUN}, max_runtime=${MAX_MINS}m)"
