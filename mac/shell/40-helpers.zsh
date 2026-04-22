# shellcheck shell=bash
# (sourced from ~/.zshrc.d/; zsh-compatible syntax)
# moto — extra helpers.

# Create a new AX41 session via a macOS dialog prompt.
axd() {
  local name="${1:-}"
  local task="${2:-main}"

  if [[ -z "$name" ]]; then
    name=$(osascript -e 'text returned of (display dialog "Project name:" default answer "" with title "New moto session")' 2>/dev/null)
    [[ -z "$name" ]] && return 1
    task=$(osascript -e 'text returned of (display dialog "Task (optional):" default answer "main" with title "New session: '"$name"'")' 2>/dev/null)
    [[ -z "$task" ]] && task="main"
  fi
  moto new "$name/$task"
}

# Show queen (q/*) sessions, optionally open them as tabs.
axq() {
  local sessions
  sessions=$(ssh -o ConnectTimeout=5 ax41 'tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^q/"' 2>/dev/null)
  [[ -z "$sessions" ]] && { echo "no queen sessions"; return 0; }
  echo "$sessions"
  if [[ "${1:-}" == "-o" ]]; then
    while IFS= read -r sess; do
      [[ -n "$sess" ]] && moto attach "$sess"
      sleep 0.55
    done <<< "$sessions"
  fi
}
