# shellcheck shell=bash
# zsh-compatible convenience wrappers for claude-tabs

ax()  { claude-tabs new "${1:-main/main}"; }
axc() { claude-tabs newx "${1:-main/main}"; }
axo() { claude-tabs up; }
axl() { claude-tabs ls; }

axk() {
  [[ -z "${1:-}" ]] && { echo "usage: axk project/task" >&2; return 1; }
  claude-tabs kill "$1"
}
