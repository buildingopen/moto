#!/bin/bash
# claude-with-queue - Wrap Claude with a background task queue pane
#
# In tmux:    creates a small split pane running cq-input
# In iTerm2:  creates a native horizontal split via AppleScript
# Other:      just runs claude without a queue pane
#
# Install:
#   cp claude-with-queue.sh ~/.local/bin/claude-with-queue
#   chmod +x ~/.local/bin/claude-with-queue
#
# Usage: claude-with-queue [claude args...]
# Or replace your 'claude' alias to point to this script.

# Path to the real claude binary - adjust for your install location
# Linux:  /usr/local/bin/claude  or  ~/.local/bin/claude
# Mac:    /opt/homebrew/bin/claude
REAL_CLAUDE="${CLAUDE_BIN:-/usr/local/bin/claude}"
CQ_INPUT="${CQ_INPUT:-$HOME/.local/bin/cq-input}"

# Non-interactive modes: skip queue pane
for arg in "$@"; do
    case "$arg" in
        -p|--print|--help|--version|-v)
            exec env ENABLE_BACKGROUND_TASKS=1 "$REAL_CLAUDE" "$@"
            ;;
    esac
done

# Already have a CQ_PANE marker: skip split (prevents recursive splits)
if [ "$CQ_PANE_ACTIVE" = "1" ]; then
    exec env ENABLE_BACKGROUND_TASKS=1 "$REAL_CLAUDE" "$@"
fi

export CQ_PANE_ACTIVE=1

# Detect iTerm2 (Mac) by checking env vars and process tree
is_iterm() {
    [ "$TERM_PROGRAM" = "iTerm.app" ] && return 0
    [ -n "$ITERM_SESSION_ID" ] && return 0
    [ "$LC_TERMINAL" = "iTerm2" ] && return 0
    local pid=$$
    while [ "$pid" != "1" ] && [ -n "$pid" ]; do
        case "$(ps -o comm= -p "$pid" 2>/dev/null)" in
            *iTerm*) return 0 ;;
        esac
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    done
    return 1
}

if [ -n "$TMUX" ]; then
    # Inside tmux: create a small split pane at the bottom for the queue
    tmux split-window -v -l 1 "$CQ_INPUT"
    tmux select-pane -t '{previous}'
    exec env ENABLE_BACKGROUND_TASKS=1 "$REAL_CLAUDE" "$@"

elif is_iterm; then
    # Mac iTerm2: create a native horizontal split pane
    osascript -e '
        tell application "iTerm2"
            tell current session of current tab of current window
                split horizontally with default profile command "'"$CQ_INPUT"'"
            end tell
            tell current tab of current window
                select (item 1 of sessions)
            end tell
        end tell
    ' &
    sleep 0.5
    exec env ENABLE_BACKGROUND_TASKS=1 "$REAL_CLAUDE" "$@"

else
    # Other terminal: just run claude without queue pane
    exec env ENABLE_BACKGROUND_TASKS=1 "$REAL_CLAUDE" "$@"
fi
