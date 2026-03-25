#!/bin/bash
# Kill test runner processes (vitest, jest, mocha) running longer than 60 minutes.
# Prevents orphan test workers from accumulating after interrupted Claude sessions.
#
# Usage: run from cron hourly
#   0 * * * * /usr/local/bin/kill-stale-tests.sh
#
# Add process names to the list as needed for your stack.

for proc in vitest jest mocha; do
  pgrep -f "$proc" | while read pid; do
    elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d " ")
    if [ -n "$elapsed" ] && [ "$elapsed" -gt 3600 ]; then
      echo "$(date): Killing stale $proc (PID $pid, running ${elapsed}s)" >> /var/log/kill-stale-tests.log
      kill -9 "$pid" 2>/dev/null
    fi
  done
done
