#!/usr/bin/env bash
# moto — orchestrates an isolated container test on the server.
#
# Runs from your Mac: syncs the repo to the server, spins up a fresh
# debian:12 container, executes server/install.sh inside it with test
# flags, and tears it down. Does NOT touch the host system.
#
# Usage:
#   ./server/test/run-container-test.sh          # uses $AX41_HOST from .env
#   HOST=ax41 ./server/test/run-container-test.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

HOST="${HOST:-}"
if [[ -z "$HOST" ]] && [[ -f .env ]]; then
  set -a; source .env; set +a
  HOST="${AX41_HOST:-}"
fi
: "${HOST:?set HOST=... or AX41_HOST in .env}"

TEST_DIR="/tmp/moto-test-$(date +%s)"
CNAME="moto-test-$$"

echo "━━━ moto isolated container test ━━━"
echo "  host:      $HOST"
echo "  test dir:  $TEST_DIR"
echo "  container: $CNAME"
echo

echo "→ rsync repo to $HOST:$TEST_DIR ..."
ssh "$HOST" "mkdir -p $TEST_DIR"
rsync -az --delete \
  --exclude=.git \
  --exclude=node_modules \
  --exclude='.env' \
  ./ "$HOST:$TEST_DIR/"

cleanup() {
  echo
  echo "→ cleaning up container + test dir..."
  ssh "$HOST" "docker rm -f $CNAME >/dev/null 2>&1 || true; rm -rf $TEST_DIR" || true
}
trap cleanup EXIT

echo "→ running in-container test on $HOST ..."
echo "  (this pulls debian:12 on first run, installs packages, and validates)"
echo

# shellcheck disable=SC2087
ssh "$HOST" bash <<SSHEOF
set -euo pipefail
cd $TEST_DIR
docker run --rm --name $CNAME \\
  -v $TEST_DIR:/opt/moto \\
  -w /opt/moto \\
  debian:12 \\
  bash server/test/in-container.sh
SSHEOF

rc=$?
echo
if [[ $rc -eq 0 ]]; then
  echo "✓ moto container test PASSED"
else
  echo "✗ moto container test FAILED (exit $rc)"
fi
exit $rc
