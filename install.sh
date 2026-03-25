#!/bin/bash
# install.sh - Set up claude-setup configuration
#
# Usage: ./install.sh [--symlink | --copy]
#   --symlink: Create symlinks to this repo (default, keeps config in sync with git)
#   --copy: Copy files (standalone, no dependency on this repo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MODE="${1:---symlink}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Pre-flight checks ---

if ! command -v claude >/dev/null 2>&1; then
    warn "Claude Code CLI not found. Install from: https://docs.anthropic.com/en/docs/claude-code"
fi

if ! command -v jq >/dev/null 2>&1; then
    err "jq is required (used by hooks). Install: brew install jq / apt install jq"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 not found. Gemini audit hook and email-check.py need it."
fi

# --- Create directories ---

info "Creating ~/.claude directories..."
mkdir -p "$CLAUDE_DIR"/{hooks,scripts,commands,metrics,memory}

# --- Install function ---

install_file() {
    local src="$1"
    local dst="$2"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Existing file: $dst (backing up to ${dst}.bak)"
        cp "$dst" "${dst}.bak"
    fi

    if [ "$MODE" = "--symlink" ]; then
        ln -sf "$src" "$dst"
    else
        cp -f "$src" "$dst"
    fi
}

install_dir() {
    local src="$1"
    local dst="$2"

    if [ "$MODE" = "--symlink" ]; then
        # Symlink individual files and recurse into subdirectories
        mkdir -p "$dst"
        for f in "$src"/*; do
            if [ -d "$f" ]; then
                install_dir "$f" "$dst/$(basename "$f")"
            elif [ -f "$f" ]; then
                ln -sf "$f" "$dst/$(basename "$f")"
            fi
        done
    else
        cp -rf "$src"/* "$dst/" 2>/dev/null || true
    fi
}

# --- Fix $HOME in settings.json ---

fix_settings() {
    local src="$SCRIPT_DIR/claude/settings.json"
    local dst="$CLAUDE_DIR/settings.json"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Existing settings.json found. Merging hooks..."
        # Don't overwrite, just inform
        info "Review $src and manually merge hooks into $dst"
        info "Key sections: hooks.PreToolUse, hooks.Stop, hooks.PostToolUse"
        return
    fi

    # Replace $HOME with actual home path (generates a standalone copy, not a symlink).
    # Re-run install.sh after updating settings.json in the repo to pick up changes.
    sed "s|\\\$HOME|$HOME|g" "$src" > "$dst"
    ok "settings.json installed (with resolved \$HOME paths)"
}

# --- Install components ---

echo ""
echo "============================================"
echo "  claude-setup installer"
echo "  Mode: $MODE"
echo "============================================"
echo ""

# CLAUDE.md
info "Installing CLAUDE.md..."
install_file "$SCRIPT_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
ok "CLAUDE.md -> $CLAUDE_DIR/CLAUDE.md"

# Settings
info "Installing settings.json..."
fix_settings

# MCP config
info "Installing .mcp.json..."
install_file "$SCRIPT_DIR/claude/.mcp.json" "$CLAUDE_DIR/.mcp.json"
ok ".mcp.json -> $CLAUDE_DIR/.mcp.json"

# Hooks
info "Installing hooks..."
for hook in "$SCRIPT_DIR"/claude/hooks/*.sh "$SCRIPT_DIR"/claude/hooks/*.py; do
    [ -f "$hook" ] || continue
    install_file "$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")"
    chmod +x "$CLAUDE_DIR/hooks/$(basename "$hook")"
done
ok "$(ls "$SCRIPT_DIR"/claude/hooks/*.sh "$SCRIPT_DIR"/claude/hooks/*.py 2>/dev/null | wc -l | tr -d ' ') hooks installed"

# Scripts
info "Installing scripts..."
for script in "$SCRIPT_DIR"/claude/scripts/*.sh; do
    [ -f "$script" ] || continue
    install_file "$script" "$CLAUDE_DIR/scripts/$(basename "$script")"
    chmod +x "$CLAUDE_DIR/scripts/$(basename "$script")"
done
ok "$(ls "$SCRIPT_DIR"/claude/scripts/*.sh 2>/dev/null | wc -l | tr -d ' ') scripts installed"

# Skills
info "Installing skills..."
for skill_dir in "$SCRIPT_DIR"/claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    install_dir "$skill_dir" "$CLAUDE_DIR/commands/$skill_name"
done
ok "$(ls -d "$SCRIPT_DIR"/claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ') skills installed to ~/.claude/commands/"

# Memory template (installed to Claude Code's project-scoped memory directory)
info "Installing memory template..."
project_dir="$CLAUDE_DIR/projects/-$(echo "$HOME" | tr '/' '-' | sed 's/^-//')/memory"
if [ ! -f "$project_dir/MEMORY.md" ]; then
    mkdir -p "$project_dir"
    install_file "$SCRIPT_DIR/claude/memory/MEMORY.md" "$project_dir/MEMORY.md"
    ok "MEMORY.md template installed to $project_dir/"
else
    warn "MEMORY.md already exists at $project_dir/, skipping (not overwriting your data)"
fi

echo ""
echo "============================================"
echo "  Installation complete!"
echo "============================================"
echo ""
info "Next steps:"
echo "  1. Edit ~/.claude/CLAUDE.md to match your workflow"
echo "  2. Review ~/.claude/settings.json hook paths"
echo "  3. Copy .env.example to .env and fill in API keys"
echo "  4. Copy claude/CLAUDE-project.md to your project roots"
echo ""

if ! command -v gitleaks >/dev/null 2>&1; then
    warn "gitleaks not installed. scan-secrets-before-push.sh needs it."
    echo "  Install: brew install gitleaks / go install github.com/gitleaks/gitleaks/v8@latest"
fi

echo ""
info "Optional: Install Gemini audit (quality gate):"
echo "  pip3 install google-genai"
echo "  touch ~/.claude/.gemini-audit-enabled"
echo "  export GEMINI_API_KEY=your_key_here"
echo ""
info "Optional: Install session-recall (transcript recovery):"
echo "  npm install -g session-recall"
echo ""
