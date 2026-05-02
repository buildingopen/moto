#!/usr/bin/env bash
set -euo pipefail

# Record a reproducible terminal demo using asciinema + agg
# Usage: ./docs/demos/record.sh <feature>
#   feature = whatsapp | install | moto-cli | hook-block | skills | memory | server | sidecar

FEATURE="${1:-}"
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$DEMO_DIR/../.." && pwd)"
CAST_DIR="/tmp/moto-demos"
mkdir -p "$CAST_DIR"

if [[ -z "$FEATURE" ]]; then
  echo "Usage: $0 <feature>"
  echo "Available features:"
  ls "$REPO_ROOT"/docs/demos/*.demo.sh 2>/dev/null | xargs -n1 basename | sed 's/.demo.sh//' | sed 's/^/  - /'
  exit 1
fi

DEMO_SCRIPT="$REPO_ROOT/docs/demos/$FEATURE.demo.sh"
CAST_FILE="$CAST_DIR/$FEATURE.cast"
GIF_FILE="$REPO_ROOT/assets/demos/$FEATURE.gif"

if [[ ! -f "$DEMO_SCRIPT" ]]; then
  echo "Demo script not found: $DEMO_SCRIPT"
  echo "Create it first, then re-run."
  exit 1
fi

command -v asciinema >/dev/null 2>&1 || { echo "Install asciinema first: brew install asciinema"; exit 1; }

echo "Recording $FEATURE → $CAST_FILE"
asciinema rec "$CAST_FILE" --command "bash $DEMO_SCRIPT" --title "moto: $FEATURE"

if command -v agg >/dev/null 2>&1; then
  mkdir -p "$(dirname "$GIF_FILE")"
  echo "Converting to GIF → $GIF_FILE"
  agg "$CAST_FILE" "$GIF_FILE" --cols 100 --rows 30 --font-size 14
  echo "Done: $GIF_FILE"
else
  echo "asciinema recording saved: $CAST_FILE"
  echo "Install agg to convert to GIF: brew install agg"
fi
