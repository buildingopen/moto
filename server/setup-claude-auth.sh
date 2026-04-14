#!/bin/bash
# setup-claude-auth.sh - Push Claude Code auth from your Mac to a Linux dev server
#
# Usage: ./setup-claude-auth.sh [ssh-alias]
#   ssh-alias defaults to "dev"
#
# Run this from your Mac after provisioning a new server.
# Requires: Claude Code installed and logged in on this Mac.
#
# What it does:
#   1. Extracts your OAuth credentials from the macOS Keychain
#   2. Copies them to the server as ~/.claude/.credentials.json
#   3. Sets ANTHROPIC_AUTH_TOKEN in ~/.bashrc (reads from credentials file at login)
#   4. Marks onboarding complete in ~/.claude.json so the theme picker doesn't block startup
#
# Background: Claude Code's headless OAuth flow on Linux is broken — the authorization
# code gets mangled on paste, and even when auth succeeds the TUI shows a sign-in screen
# because hasCompletedOnboarding is missing from ~/.claude.json. This script bypasses
# the entire flow by pushing credentials directly from the Mac Keychain.

set -euo pipefail

SERVER="${1:-dev}"

# Validate SSH alias — only allow safe hostname/alias characters
if ! [[ "$SERVER" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo -e "\033[0;31m[ERROR]\033[0m Invalid SSH alias: '$SERVER'. Use only letters, numbers, dots, hyphens, underscores." >&2
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# --- 1. Extract credentials from macOS Keychain ---

info "Reading Claude Code credentials from macOS Keychain..."

CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
if [ -z "$CREDS" ]; then
    err "No Claude Code credentials found in Keychain. Log in to Claude Code on this Mac first, then re-run."
fi

# Validate that the JSON parses and contains the expected key
if ! echo "$CREDS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'claudeAiOauth' not in d or 'accessToken' not in d['claudeAiOauth']:
    raise KeyError('claudeAiOauth.accessToken missing')
" 2>/dev/null; then
    err "Could not parse access token from credentials. Keychain entry may be malformed. Try: security find-generic-password -s 'Claude Code-credentials' -w"
fi

ok "Credentials extracted."

# --- 2. Verify SSH connection ---

info "Connecting to $SERVER..."
ssh -o ConnectTimeout=10 "$SERVER" "echo ok" > /dev/null 2>&1 || err "Cannot connect to $SERVER. Check your SSH config."
ok "Connected to $SERVER"

# --- 3. Copy credentials file ---

info "Copying credentials to $SERVER:~/.claude/.credentials.json..."
printf '%s\n' "$CREDS" | ssh -o ConnectTimeout=10 "$SERVER" "umask 0077; mkdir -p ~/.claude; cat > ~/.claude/.credentials.json; chmod 600 ~/.claude/.credentials.json"
ok ".credentials.json installed"

# --- 4. Set ANTHROPIC_AUTH_TOKEN in .bashrc ---
# Read the token dynamically from the credentials file at login rather than storing
# the literal token value. This keeps ~/.bashrc free of credential plaintext and
# automatically picks up refreshed tokens without re-running this script.

info "Setting ANTHROPIC_AUTH_TOKEN in ~/.bashrc on $SERVER..."
# Use bash -s + heredoc to safely inject the dynamic token line without quoting nightmares.
# The token is sourced from the credentials file at each login — no literal token in .bashrc.
ssh -o ConnectTimeout=10 "$SERVER" 'bash -s' <<'REMOTESCRIPT'
touch ~/.bashrc
sed -i '/^export ANTHROPIC_AUTH_TOKEN=/d' ~/.bashrc
cat >> ~/.bashrc <<'BASHLINE'
export ANTHROPIC_AUTH_TOKEN=$(python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.claude/.credentials.json'))); print(d['claudeAiOauth']['accessToken'])" 2>/dev/null)
BASHLINE
REMOTESCRIPT
ok "ANTHROPIC_AUTH_TOKEN set in ~/.bashrc (reads from credentials file)"

# --- 5. Mark onboarding complete in ~/.claude.json ---
# Without this, Claude Code shows a theme picker on every startup because
# hasCompletedOnboarding is absent from the config, regardless of auth state.

info "Marking onboarding complete on $SERVER..."
ssh -o ConnectTimeout=10 "$SERVER" "python3 - <<'PYEOF'
import json, os, subprocess

path = os.path.expanduser('~/.claude.json')
d = json.load(open(path)) if os.path.exists(path) else {}

try:
    ver = subprocess.check_output(['claude', '--version'], text=True).split()[0]
except Exception:
    ver = 'unknown'

d['hasCompletedOnboarding'] = True
d['lastOnboardingVersion'] = ver

with open(path, 'w') as f:
    json.dump(d, f, indent=2)
os.chmod(path, 0o600)

print(f'Onboarding marked complete for Claude Code {ver}')
PYEOF"
ok "~/.claude.json updated"

# --- 6. Verify ---

info "Verifying auth on $SERVER..."
RESULT=$(ssh -o ConnectTimeout=10 "$SERVER" "claude auth status 2>/dev/null" 2>/dev/null || true)
if [ -z "$RESULT" ]; then
    err "Auth verification failed: 'claude auth status' returned no output. Is Claude Code installed on $SERVER?"
fi
if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('loggedIn') else 1)" 2>/dev/null; then
    EMAIL=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('email','unknown'))" 2>/dev/null || echo "unknown")
    ok "Authenticated as $EMAIL"
else
    echo "Auth status: $RESULT"
    err "Auth verification failed. Try running 'claude auth status' on the server manually."
fi

echo ""
echo "============================================"
echo "  Claude Code auth configured on $SERVER"
echo "============================================"
echo ""
echo "  ssh $SERVER"
echo "  claude"
echo ""
echo "Note: The credentials file expires in ~1 year. Re-run this script to refresh."
