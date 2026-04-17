#!/usr/bin/env bash
# moto — Mac installer
set -euo pipefail

MOTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MOTO_DIR"

if [[ ! -f .env ]]; then
  echo "❌ .env not found in $MOTO_DIR"
  exit 1
fi

set -a; source .env; set +a
: "${AX41_HOST:?set AX41_HOST in .env}"
: "${AX41_USER:?set AX41_USER in .env}"
: "${MAC_REVERSE_PORT:=2222}"

echo "━━━ moto Mac install ━━━"
echo "  AX41:            $AX41_USER@$AX41_HOST"
echo "  Reverse port:    $MAC_REVERSE_PORT"
echo

# ── 1. Install `moto` binary ────────────────────────────────────────
BIN_DIR="${MOTO_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$BIN_DIR"
ln -sf "$MOTO_DIR/mac/bin/moto" "$BIN_DIR/moto"
ln -sf "$MOTO_DIR/mac/bin/moto" "$BIN_DIR/mt"
echo "✓ linked moto (and mt) to $BIN_DIR"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "  ⚠ add $BIN_DIR to PATH in your shell profile" ;;
esac

# ── 2. Install shell functions ──────────────────────────────────────
ZSH_D="$HOME/.zshrc.d"
mkdir -p "$ZSH_D"
for f in "$MOTO_DIR"/mac/shell/*.zsh; do
  ln -sf "$f" "$ZSH_D/$(basename "$f")"
done
echo "✓ linked shell functions into $ZSH_D"

# Ensure ~/.zshrc sources ~/.zshrc.d/*.zsh
if ! grep -q 'MOTO:zshrc.d' ~/.zshrc 2>/dev/null; then
  cat >> ~/.zshrc <<'EOF'

# MOTO:zshrc.d — load moto shell functions
for _moto_f in "$HOME/.zshrc.d/"*.zsh; do
  [[ -r "$_moto_f" ]] && source "$_moto_f"
done
unset _moto_f
EOF
  echo "✓ added loader stanza to ~/.zshrc"
fi

# ── 3. SSH config (Host ax41 + ControlMaster) ───────────────────────
SSH_CONFIG="$HOME/.ssh/config"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"
mkdir -p "$HOME/.ssh/sockets"
if ! grep -q '^Host ax41$' "$SSH_CONFIG"; then
  # Render template with env values
  {
    echo ""
    echo "# ── moto: AX41 ─────────────────────────────────────────────"
    sed -e "s|__AX41_HOST__|$AX41_HOST|g" \
        -e "s|__AX41_USER__|$AX41_USER|g" \
        -e "s|__AX41_SSH_KEY__|${AX41_SSH_KEY:-~/.ssh/id_ed25519}|g" \
        "$MOTO_DIR/mac/ssh/config.d/moto.conf"
  } >> "$SSH_CONFIG"
  echo "✓ added 'Host ax41' to ~/.ssh/config"
else
  echo "• ~/.ssh/config already has 'Host ax41' — left untouched"
fi

# ── 4. launchd: reverse SSH tunnel so server can reach Mac ──────────
PLIST_SRC="$MOTO_DIR/mac/launchd/sh.buildingopen.moto.reverse-tunnel.plist"
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

# ── 5. Check Remote Login (sshd) is enabled ─────────────────────────
if ! sudo -n systemsetup -getremotelogin 2>/dev/null | grep -qi on; then
  echo
  echo "⚠ Remote Login (sshd) may be OFF on your Mac."
  echo "  Enable: System Settings → General → Sharing → Remote Login"
  echo "  Without it, the server cannot SSH back to reach ~/.claude."
fi

echo
echo "✓ moto installed on Mac."
echo "  Next:  source ~/.zshrc && moto doctor"
