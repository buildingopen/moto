#!/bin/bash
# Block CPU-heavy commands locally - must run on dev server
# DATA-DRIVEN: 260 rejections analyzed. SSH delegation commands are now allowed
# since the whole point is to run heavy tasks on the server, not locally.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Allow SSH commands that delegate TO servers (the correct pattern)
# Customize: replace with your actual server aliases
if echo "$COMMAND" | grep -qiE "^ssh (dev|devserver|hetzner|ax41)(\s|$)"; then
    exit 0
fi

# Heavy tasks that should NOT run locally on Mac
HEAVY_PATTERNS=(
    "npx remotion render"
    "remotion render"
    "npx remotion lambda"
    "playwright.*chromium"
    "puppeteer"
    "chrome-headless-shell"
    "ffmpeg.*-i.*-vf"
    "ffmpeg.*scale="
)

for pattern in "${HEAVY_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$pattern"; then
        echo "BLOCKED: CPU-heavy task detected. Run on your dev server instead:"
        echo ""
        echo "  Wrap with: ssh devserver \"$pattern ...\""
        echo "  For browser automation: use MCP authenticated-browser (already on dev server)"
        echo ""
        echo "Pattern matched: $pattern"
        exit 2
    fi
done

exit 0
