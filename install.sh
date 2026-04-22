#!/bin/bash
# install.sh - claude-setup entry point
#
# Usage:
#   ./install.sh                     Install ~/.claude from this repo
#   ./install.sh --copy             Copy instead of symlink for local install
#   ./install.sh local [--copy]     Explicit local install
#   ./install.sh mac                Install the integrated moto Mac workflow
#   ./install.sh server             Install the integrated moto server stack
#   ./install.sh server-remote      Upload to the remote box and run server/install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

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

usage() {
    cat <<EOF
Usage: $0 [mode]

Modes:
  local [--symlink|--copy]   Install ~/.claude from this repo (default)
  mac                        Install the integrated moto Mac workflow
  server                     Install the integrated moto server stack
  server-remote              Upload the repo to the remote box and run server/install.sh

Legacy local modes:
  --symlink                  Same as: $0 local --symlink
  --copy                     Same as: $0 local --copy
EOF
}

require_env() {
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        err ".env not found. Run: cp .env.example .env && \$EDITOR .env"
        exit 1
    fi

    set -a
    # shellcheck disable=SC1091
    source "$SCRIPT_DIR/.env"
    set +a
}

install_file() {
    local src="$1"
    local dst="$2"
    local mode="$3"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Existing file: $dst (backing up to ${dst}.bak)"
        cp "$dst" "${dst}.bak"
    fi

    if [ "$mode" = "--symlink" ]; then
        ln -sf "$src" "$dst"
    else
        cp -f "$src" "$dst"
    fi
}

install_dir() {
    local src="$1"
    local dst="$2"
    local mode="$3"

    if [ "$mode" = "--symlink" ]; then
        mkdir -p "$dst"
        for f in "$src"/*; do
            if [ -d "$f" ]; then
                install_dir "$f" "$dst/$(basename "$f")" "$mode"
            elif [ -f "$f" ]; then
                ln -sf "$f" "$dst/$(basename "$f")"
            fi
        done
    else
        cp -rf "$src"/* "$dst/" 2>/dev/null || true
    fi
}

fix_settings() {
    local src="$SCRIPT_DIR/claude/settings.json"
    local dst="$CLAUDE_DIR/settings.json"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Existing settings.json found. Merging hooks..."
        info "Review $src and manually merge hooks into $dst"
        info "Key sections: hooks.PreToolUse, hooks.Stop, hooks.PostToolUse"
        return
    fi

    sed "s|\\\$HOME|$HOME|g" "$src" > "$dst"
    ok "settings.json installed (with resolved \$HOME paths)"
}

install_local() {
    local mode="${1:---symlink}"

    case "$mode" in
        --symlink|--copy) ;;
        *)
            err "Unknown local install mode: $mode"
            usage
            exit 1
            ;;
    esac

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

    info "Creating ~/.claude directories..."
    mkdir -p "$CLAUDE_DIR"/{hooks,scripts,commands,metrics,memory}

    echo ""
    echo "============================================"
    echo "  claude-setup installer"
    echo "  Mode: $mode"
    echo "============================================"
    echo ""

    info "Installing CLAUDE.md..."
    install_file "$SCRIPT_DIR/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md" "$mode"
    ok "CLAUDE.md -> $CLAUDE_DIR/CLAUDE.md"

    info "Installing settings.json..."
    fix_settings

    info "Installing .mcp.json..."
    install_file "$SCRIPT_DIR/claude/.mcp.json" "$CLAUDE_DIR/.mcp.json" "$mode"
    ok ".mcp.json -> $CLAUDE_DIR/.mcp.json"

    info "Installing hooks..."
    for hook in "$SCRIPT_DIR"/claude/hooks/*.sh "$SCRIPT_DIR"/claude/hooks/*.py; do
        [ -f "$hook" ] || continue
        install_file "$hook" "$CLAUDE_DIR/hooks/$(basename "$hook")" "$mode"
        chmod +x "$CLAUDE_DIR/hooks/$(basename "$hook")"
    done
    ok "$(find "$SCRIPT_DIR/claude/hooks" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) | wc -l | tr -d ' ') hooks installed"

    info "Installing scripts..."
    for script in "$SCRIPT_DIR"/claude/scripts/*.sh; do
        [ -f "$script" ] || continue
        install_file "$script" "$CLAUDE_DIR/scripts/$(basename "$script")" "$mode"
        chmod +x "$CLAUDE_DIR/scripts/$(basename "$script")"
    done
    ok "$(find "$SCRIPT_DIR/claude/scripts" -maxdepth 1 -type f -name '*.sh' | wc -l | tr -d ' ') scripts installed"

    info "Installing skills..."
    for skill_dir in "$SCRIPT_DIR"/claude/skills/*/; do
        [ -d "$skill_dir" ] || continue
        install_dir "$skill_dir" "$CLAUDE_DIR/commands/$(basename "$skill_dir")" "$mode"
    done
    ok "$(find "$SCRIPT_DIR/claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ') skills installed to ~/.claude/commands/"

    info "Installing memory template..."
    project_dir="$CLAUDE_DIR/projects/-$(echo "$HOME" | tr '/' '-' | sed 's/^-//')/memory"
    if [ ! -f "$project_dir/MEMORY.md" ]; then
        mkdir -p "$project_dir"
        install_file "$SCRIPT_DIR/claude/memory/MEMORY.md" "$project_dir/MEMORY.md" "$mode"
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
    echo "  3. Copy .env.example to .env and fill in API keys / remote stack config"
    echo "  4. Copy claude/CLAUDE-project.md to your project roots"
    echo ""

    if ! command -v gitleaks >/dev/null 2>&1; then
        warn "gitleaks not installed. scan-secrets-before-push.sh needs it."
        echo "  Install: brew install gitleaks / go install github.com/gitleaks/gitleaks/v8@latest"
    fi

    echo ""
    info "Optional: Install the integrated remote stack:"
    echo "  ./install.sh mac"
    echo "  ./install.sh server-remote"
    echo ""
}

install_server_remote() {
    require_env

    : "${AX41_HOST:?AX41_HOST must be set in .env}"
    : "${AX41_USER:?AX41_USER must be set in .env}"

    local target_dir="${MOTO_REMOTE_DIR:-/opt/moto}"

    info "Uploading claude-setup to $AX41_USER@$AX41_HOST:$target_dir"
    rsync -az --delete \
        --exclude '.env.local' \
        --exclude '.git' \
        --exclude 'node_modules' \
        --exclude '*.log' \
        "$SCRIPT_DIR/" "$AX41_USER@$AX41_HOST:$target_dir/"

    info "Running server/install.sh on $AX41_HOST"
    # shellcheck disable=SC2029
    ssh "$AX41_USER@$AX41_HOST" "cd $target_dir && bash server/install.sh"
}

main() {
    local command="${1:-local}"

    case "$command" in
        --symlink|--copy)
            install_local "$command"
            ;;
        local)
            shift || true
            install_local "${1:---symlink}"
            ;;
        mac)
            exec bash "$SCRIPT_DIR/mac/install.sh"
            ;;
        server)
            shift || true
            exec bash "$SCRIPT_DIR/server/install.sh" "$@"
            ;;
        server-remote)
            install_server_remote
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            if [[ -z "$command" ]]; then
                install_local "--symlink"
            else
                err "Unknown mode: $command"
                usage
                exit 1
            fi
            ;;
    esac
}

main "$@"
