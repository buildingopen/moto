#!/usr/bin/env bash
# moto — top-level installer
# Usage:
#   ./install.sh mac           # set up the Mac side
#   ./install.sh server        # set up the Linux box (run ON the server, or via SSH wrapper)
#   ./install.sh server-remote # run server install over SSH from your Mac

set -euo pipefail

MOTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$MOTO_DIR"

if [[ ! -f .env ]]; then
  echo "❌ .env not found. Run: cp .env.example .env && \$EDITOR .env"
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

target="${1:-}"
case "$target" in
  mac)
    exec bash mac/install.sh
    ;;
  server)
    exec bash server/install.sh
    ;;
  server-remote)
    : "${AX41_HOST:?AX41_HOST must be set in .env}"
    : "${AX41_USER:?AX41_USER must be set in .env}"
    echo "→ Uploading moto/ to $AX41_USER@$AX41_HOST:/opt/moto"
    rsync -az --delete \
      --exclude '.env.local' \
      --exclude '.git' \
      --exclude 'node_modules' \
      --exclude '*.log' \
      "$MOTO_DIR/" "$AX41_USER@$AX41_HOST:/opt/moto/"
    echo "→ Running server/install.sh on $AX41_HOST"
    ssh "$AX41_USER@$AX41_HOST" "cd /opt/moto && bash server/install.sh"
    ;;
  *)
    cat <<EOF
Usage: $0 <target>

Targets:
  mac              Set up Mac (adds \`moto\` CLI, shell functions, launchd job)
  server           Set up Linux box (run this ON the server)
  server-remote    Upload repo to \$AX41_HOST and run server/install.sh over SSH

First-time setup:
  1. cp .env.example .env
  2. \$EDITOR .env
  3. ./install.sh mac
  4. ./install.sh server-remote
EOF
    exit 1
    ;;
esac
