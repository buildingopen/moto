#!/bin/bash
# start-claude-sessions.sh - Auto-start one tmux session per git repo on boot
#
# Usage: Install via cron:
#   @reboot /usr/local/bin/start-claude-sessions.sh
#
# On boot, finds every git repo under /root (maxdepth 2), creates a named
# tmux session for each one (named after the repo directory), cds into it,
# and runs "happy claude" to start a Claude Code session with mobile access.
#
# Idempotent: skips repos that already have a running tmux session.
#
# Requires:
#   - tmux
#   - happy (npm install -g happy) or replace with: claude
#   - Git repos as direct subdirectories of /root

set -euo pipefail

# Small delay to let the system fully boot before spawning sessions
sleep 5

find /root -maxdepth 2 -name ".git" -type d 2>/dev/null \
    | sed 's|/.git$||' \
    | sort \
    | while read -r repo; do
        name=$(basename "$repo")
        # Skip if a session with this name already exists
        if tmux has-session -t "$name" 2>/dev/null; then
            continue
        fi
        tmux new-session -d -s "$name" -c "$repo" "happy claude"
    done
