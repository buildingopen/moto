#!/usr/bin/env bash
set -euo pipefail

MAC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$MAC_DIR/.." && pwd)"

BIN_DIR="${CLAUDE_REMOTE_BIN_DIR:-$HOME/.local/bin}"
ZSH_D="$HOME/.zshrc.d"
SSH_CONFIG="$HOME/.ssh/config"
SSH_ALIAS="${CLAUDE_REMOTE_SSH_HOST:-ax41}"

mkdir -p "$BIN_DIR" "$ZSH_D" "$HOME/.ssh/sockets"

ln -sf "$REPO_DIR/mac/bin/claude-tabs" "$BIN_DIR/claude-tabs"

for f in "$REPO_DIR"/mac/shell/*.zsh; do
    [ -f "$f" ] || continue
    ln -sf "$f" "$ZSH_D/$(basename "$f")"
done

if ! grep -q 'CLAUDE-SETUP:zshrc.d' "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" <<'EOF'

# CLAUDE-SETUP:zshrc.d — load claude-setup shell helpers
for _claude_setup_f in "$HOME"/.zshrc.d/*.zsh(N); do
  [[ -r "$_claude_setup_f" ]] && source "$_claude_setup_f"
done
unset _claude_setup_f
EOF
fi

touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

if [ -n "${CLAUDE_REMOTE_HOSTNAME:-}" ] && [ -n "${CLAUDE_REMOTE_USER:-}" ]; then
    if ! grep -q "^Host $SSH_ALIAS$" "$SSH_CONFIG"; then
        {
            echo ""
            echo "# claude-setup remote host"
            sed \
                -e "s|__REMOTE_ALIAS__|$SSH_ALIAS|g" \
                -e "s|__REMOTE_HOSTNAME__|$CLAUDE_REMOTE_HOSTNAME|g" \
                -e "s|__REMOTE_USER__|$CLAUDE_REMOTE_USER|g" \
                -e "s|__REMOTE_SSH_KEY__|${CLAUDE_REMOTE_SSH_KEY:-~/.ssh/id_ed25519}|g" \
                "$REPO_DIR/mac/ssh/config.d/claude-remote.conf"
        } >> "$SSH_CONFIG"
    fi
fi

cat <<EOF
Installed:
  - $BIN_DIR/claude-tabs
  - shell aliases in $ZSH_D

Next:
  1. source ~/.zshrc
  2. Ensure your server has ~/cs (and optionally ~/cx) from server/bin/
  3. Run: ax myproj/feature

SSH host alias:
  ${SSH_ALIAS}
EOF
