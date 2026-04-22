#!/usr/bin/env bash
# moto — residential proxy sidecar smoke test (tinyproxy).
#
# Builds ./server/docker/proxy and proves:
#   A. PROXY_URL parser handles http / https / socks5, with and without auth.
#   B. Empty PROXY_URL → listener up, direct egress works.
#   C. Chained PROXY_URL pointing at a second tinyproxy → traffic actually
#      flows through the parent (the parent's own logs show the forwarded
#      request). This is the strict proof the upstream directive engages.
#
# No real residential provider needed. Runs in isolation on $HOST.
#   HOST=ax41 ./server/test/proxy-smoke.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

HOST="${HOST:-}"
if [[ -z "$HOST" ]] && [[ -f .env ]]; then
  set -a; source .env; set +a
  HOST="${AX41_HOST:-}"
fi
: "${HOST:?set HOST=... or AX41_HOST in .env}"

TAG="moto-proxy-smoke-$$"
TEST_DIR="/tmp/$TAG"
NET="$TAG-net"

echo "━━━ moto proxy sidecar smoke test ━━━"
echo "  host:    $HOST"
echo "  tag:     $TAG"
echo

cleanup() {
  # shellcheck disable=SC2087
  ssh "$HOST" bash -s <<EOSH >/dev/null 2>&1 || true
docker ps -aq --filter "name=^${TAG}" | xargs -r docker rm -f
docker network rm $NET 2>/dev/null || true
rm -rf $TEST_DIR
EOSH
}
trap cleanup EXIT

echo "→ syncing proxy build context to $HOST:$TEST_DIR ..."
ssh "$HOST" "mkdir -p $TEST_DIR"
rsync -az --delete server/docker/proxy/ "$HOST:$TEST_DIR/proxy/"

echo "→ running smoke test on $HOST ..."

# shellcheck disable=SC2087
ssh "$HOST" bash <<SSHEOF
set -euo pipefail
cd $TEST_DIR

docker build -q -t ${TAG}:img ./proxy >/dev/null
echo "  ✓ image built"

docker network create $NET >/dev/null
echo "  ✓ test network: $NET"

# ── Case A: parser variants (5 cases) ────────────────────────────────
declare -a CASES=(
  "http://u:p@10.254.254.254:8080|upstream http://10.254.254.254:8080 (user: u)"
  "http://10.254.254.254:8080|upstream http://10.254.254.254:8080 (no auth)"
  "https://a:b@10.254.254.254:443|upstream https://10.254.254.254:443 (user: a)"
  "socks5://u:p@10.254.254.254:1080|upstream socks5://10.254.254.254:1080 (user: u)"
  "|PROXY_URL empty"
)

parser_fails=0
for entry in "\${CASES[@]}"; do
  url="\${entry%%|*}"
  expect="\${entry#*|}"
  name="${TAG}-p-\$(echo -n "\$url" | md5sum | cut -c1-8)"
  docker run -d --name "\$name" -e PROXY_URL="\$url" ${TAG}:img >/dev/null
  sleep 0.6
  if docker logs "\$name" 2>&1 | grep -qF "\$expect"; then
    echo "  ✓ parse [\${url:-<empty>}] → '\$expect'"
  else
    echo "  ✗ parse [\${url:-<empty>}] → expected '\$expect', got:"
    docker logs "\$name" 2>&1 | sed 's/^/        /'
    parser_fails=\$((parser_fails + 1))
  fi
  docker rm -f "\$name" >/dev/null
done
[[ \$parser_fails -gt 0 ]] && { echo "  ✗ \$parser_fails parse case(s) failed"; exit 1; }

# ── Case B: empty PROXY_URL → direct egress fetches example.com ─────
B="${TAG}-direct"
docker run -d --name \$B --network $NET ${TAG}:img >/dev/null
sleep 1
rc=0
docker run --rm --network "container:\$B" curlimages/curl:8.10.1 \\
  -fsS --max-time 8 -x http://127.0.0.1:8118 http://example.com/ >/dev/null 2>&1 || rc=\$?
if [[ \$rc -eq 0 ]]; then
  echo "  ✓ direct egress: PROXY_URL empty → example.com fetched through sidecar"
else
  echo "  ✗ direct egress failed (curl rc=\$rc)"
  docker logs \$B 2>&1 | sed 's/^/      /'
  exit 1
fi
docker rm -f \$B >/dev/null

# ── Case C: chained upstream actually forwards through parent ───────
# Parent: plain tinyproxy forward (no upstream)
P="${TAG}-parent"
docker run -d --name \$P --network $NET -e PROXY_URL= ${TAG}:img >/dev/null

# Child: tinyproxy with PROXY_URL pointing at parent
C="${TAG}-child"
docker run -d --name \$C --network $NET -e PROXY_URL="http://\$P:8118" ${TAG}:img >/dev/null
sleep 1

# Clear parent logs baseline
parent_before=\$(docker logs \$P 2>&1 | wc -l)

rc=0
docker run --rm --network "container:\$C" curlimages/curl:8.10.1 \\
  -fsS --max-time 8 -o /dev/null \\
  -x http://127.0.0.1:8118 http://example.com/ 2>/dev/null || rc=\$?

if [[ \$rc -ne 0 ]]; then
  echo "  ✗ chained request failed (curl rc=\$rc)"
  echo "    child logs:"
  docker logs \$C 2>&1 | tail -10 | sed 's/^/      /'
  echo "    parent logs:"
  docker logs \$P 2>&1 | tail -10 | sed 's/^/      /'
  exit 1
fi

parent_logs=\$(docker logs \$P 2>&1)
# Parent must have seen a GET for example.com. If the child bypassed the
# upstream directive (the bug we're hunting), parent's log count would
# still match the baseline.
if echo "\$parent_logs" | grep -qE 'Request.*example\.com|Connect.*example\.com'; then
  parent_after=\$(echo "\$parent_logs" | wc -l)
  echo "  ✓ chained upstream: parent saw the forwarded request (log lines \$parent_before → \$parent_after)"
else
  echo "  ✗ chained upstream: parent saw NO example.com request — upstream directive was ignored"
  echo "    parent logs:"
  echo "\$parent_logs" | tail -15 | sed 's/^/      /'
  exit 1
fi

echo
echo "  ✓ ALL PROXY SMOKE CHECKS PASSED"
SSHEOF

echo
echo "✓ proxy sidecar smoke test PASSED"
