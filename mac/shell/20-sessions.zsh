# shellcheck shell=bash
# (sourced from ~/.zshrc.d/; zsh-compatible syntax)
# moto — session shortcuts (zsh functions)
# Wraps the `moto` CLI, plus keeps the classic `ax*` aliases for muscle memory.

# ── Primary commands ────────────────────────────────────────────────
# These are just thin aliases; all logic lives in the `moto` binary.

# Open/attach a Claude session as an iTerm tab.
ax() { moto new "${1:-main/main}"; }
axc() { moto newx "${1:-main/main}"; }
axoc() { moto newo "${1:-main/main}"; }

# Add a tab without attempting to reattach first (= same as `ax` now).
axn()  { moto attach "${1:-main/main}"; }
axnx() { moto newx "${1:-main/main}"; }

axlist() { moto ls; }
axl()    { moto ls; }

axk() {
  [[ -z "${1:-}" ]] && { echo "usage: axk session-name" >&2; return 1; }
  moto kill "$1"
}

# Send an image to the server; prints the remote path (useful for Claude prompts).
aximg() {
  [[ -z "${1:-}" ]] && { echo "usage: aximg PATH" >&2; return 1; }
  moto img "$1"
}

# Open a single fresh iTerm window for one session (legacy).
axwin() {
  local session="${1:-main/main}"
  osascript -e "tell application \"iTerm\"
    create window with default profile
    tell current session of current window
      write text \"moto attach $session\"
    end tell
  end tell" 2>/dev/null || echo "warning: could not control iTerm"
}
