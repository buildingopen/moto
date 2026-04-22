#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${AX41_HOST:=${CLAUDE_REMOTE_HOSTNAME:-}}"
: "${AX41_USER:=${CLAUDE_REMOTE_USER:-}}"
: "${AX41_SSH_HOST:=ax41}"
: "${MAC_REVERSE_PORT:=2222}"

[[ -n "${AX41_HOST:-}" ]] || { echo "❌ AX41_HOST not set. Copy .env.example to .env or export AX41_HOST=..." ; exit 1; }
[[ -n "${AX41_USER:-}" ]] || { echo "❌ AX41_USER not set. Copy .env.example to .env or export AX41_USER=..." ; exit 1; }

echo "━━━ claude-setup Mac install (integrated moto workflow) ━━━"
echo "  AX41:            $AX41_USER@$AX41_HOST"
echo "  SSH alias:       $AX41_SSH_HOST"
echo "  Reverse port:    $MAC_REVERSE_PORT"
echo

BIN_DIR="${MOTO_BIN_DIR:-${CLAUDE_REMOTE_BIN_DIR:-$HOME/.local/bin}}"
mkdir -p "$BIN_DIR"
ln -sf "$REPO_DIR/mac/bin/moto" "$BIN_DIR/moto"
ln -sf "$REPO_DIR/mac/bin/moto" "$BIN_DIR/mt"
ln -sf "$REPO_DIR/mac/bin/claude-tabs" "$BIN_DIR/claude-tabs"
echo "✓ linked moto, mt, and claude-tabs to $BIN_DIR"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "  ⚠ add $BIN_DIR to PATH in your shell profile" ;;
esac

ZSH_D="$HOME/.zshrc.d"
mkdir -p "$ZSH_D"
for f in "$REPO_DIR"/mac/shell/*.zsh; do
  ln -sf "$f" "$ZSH_D/$(basename "$f")"
done
echo "✓ linked shell functions into $ZSH_D"

if ! grep -q 'CLAUDE-SETUP:MOTO:zshrc.d' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" <<'EOF'

# CLAUDE-SETUP:MOTO:zshrc.d — load integrated remote shell functions
for _moto_f in "$HOME"/.zshrc.d/*.zsh(N); do
  [[ -r "$_moto_f" ]] && source "$_moto_f"
done
unset _moto_f
EOF
  echo "✓ added loader stanza to ~/.zshrc"
fi

SSH_CONFIG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
mkdir -p "$HOME/.ssh/sockets"
if ! grep -q "^Host $AX41_SSH_HOST$" "$SSH_CONFIG"; then
  {
    echo ""
    echo "# ── claude-setup: integrated moto host ─────────────────────"
    sed -e "s|__AX41_HOST__|$AX41_HOST|g" \
        -e "s|__AX41_USER__|$AX41_USER|g" \
        -e "s|__AX41_SSH_KEY__|${AX41_SSH_KEY:-~/.ssh/id_ed25519}|g" \
        "$REPO_DIR/mac/ssh/config.d/moto.conf" | sed "s/^Host ax41$/Host $AX41_SSH_HOST/"
  } >> "$SSH_CONFIG"
  echo "✓ added 'Host $AX41_SSH_HOST' to ~/.ssh/config"
else
  echo "• ~/.ssh/config already has 'Host $AX41_SSH_HOST' — left untouched"
fi

PLIST_SRC="$REPO_DIR/mac/launchd/sh.buildingopen.moto.reverse-tunnel.plist"
PLIST_DST="$HOME/Library/LaunchAgents/sh.buildingopen.moto.reverse-tunnel.plist"
mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|__AX41_HOST__|$AX41_HOST|g" \
    -e "s|__AX41_USER__|$AX41_USER|g" \
    -e "s|__MAC_REVERSE_PORT__|$MAC_REVERSE_PORT|g" \
    -e "s|__HOME__|$HOME|g" \
    "$PLIST_SRC" > "$PLIST_DST"

launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
echo "✓ loaded reverse-tunnel LaunchAgent ($PLIST_DST)"

if ! sudo -n systemsetup -getremotelogin 2>/dev/null | grep -qi on; then
  echo
  echo "⚠ Remote Login (sshd) may be OFF on your Mac."
  echo "  Enable: System Settings → General → Sharing → Remote Login"
  echo "  Without it, the server cannot SSH back to reach ~/.claude."
fi

echo
echo "✓ integrated remote workflow installed on Mac."
echo "  Next: source ~/.zshrc && moto doctor"
