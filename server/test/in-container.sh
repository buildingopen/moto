#!/usr/bin/env bash
# moto — in-container verification script.
#
# Runs inside a vanilla debian:12 container to validate that server/install.sh
# succeeds on a clean box. Does NOT require systemd or nested docker.
#
# Invoked by server/test/run-container-test.sh but can be run standalone:
#   docker run --rm -it -v $(pwd):/opt/moto -w /opt/moto debian:12 \
#     bash server/test/in-container.sh
set -euo pipefail

REPO=/opt/moto
cd "$REPO"

echo "━━━ moto container test ━━━"
echo "  uname: $(uname -a)"
echo "  os:    $(. /etc/os-release; echo "$PRETTY_NAME")"
echo

# Minimal .env so install.sh can source it
cat > .env <<'EOF'
MAC_USER=testuser
AX41_HOST=test.example.com
AX41_USER=root
AX41_SSH_KEY=~/.ssh/id_ed25519
MAC_REVERSE_PORT=2222
EOF

pass=0
fail=0
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✓ $name"
    pass=$((pass + 1))
  else
    echo "  ✗ $name"
    fail=$((fail + 1))
  fi
}

# Ensure apt, curl, wget are available (should be, but some base images are minimal)
apt-get update -qq
apt-get install -y -qq curl wget ca-certificates gnupg lsb-release procps iproute2 rsync >/dev/null

# ── Phase 1: run the real installer with staged flags ────────────────
echo "── Phase 1: server/install.sh SKIP_SYSTEMD_ENABLE=1 SKIP_DOCKER_COMPOSE=1 ──"
SKIP_SYSTEMD_ENABLE=1 SKIP_DOCKER_COMPOSE=1 bash server/install.sh

echo
echo "── Phase 2: file layout checks ──"
check "/root/cs installed"                     test -x /root/cs
check "/root/cx installed"                     test -x /root/cx
check "/root/co installed"                     test -x /root/co
check "/usr/local/bin/check-mac-mounts"        test -x /usr/local/bin/check-mac-mounts
check "/usr/local/bin/chrome-bridge-keeper"    test -x /usr/local/bin/chrome-bridge-keeper
check "/usr/local/bin/cleanup-stale"           test -x /usr/local/bin/cleanup-stale
check "/usr/local/bin/kill-claude-orphans"     test -x /usr/local/bin/kill-claude-orphans
check "/usr/local/bin/node-modules-gc"         test -x /usr/local/bin/node-modules-gc
check "/usr/local/bin/moto-reboot-recovery"    test -x /usr/local/bin/moto-reboot-recovery
check "/root/authenticated-browser/chrome-launcher.sh" test -x /root/authenticated-browser/chrome-launcher.sh
check "/root/images/ dir"                      test -d /root/images
check "/mnt/mac/ dir"                          test -d /mnt/mac
check "/mnt/mac-claude/ dir"                   test -d /mnt/mac-claude
check "/root/.ssh/config has 'Host mac'"       grep -q '^Host mac$' /root/.ssh/config
check "/root/.ssh/id_ed25519 generated"        test -f /root/.ssh/id_ed25519
check "/etc/fuse.conf has user_allow_other"    grep -q '^user_allow_other' /etc/fuse.conf

echo
echo "── Phase 3: systemd unit files installed ──"
for u in tmux-server.service authenticated-chrome.service chrome-bridge-keeper.service \
         cdp-docker-proxy.service mac-mount-check.timer mac-mount-check.service \
         moto-cleanup.timer moto-cleanup.service node-modules-gc.timer \
         node-modules-gc.service moto-reboot-recovery.service; do
  check "unit $u"   test -f "/etc/systemd/system/$u"
done

echo
echo "── Phase 4: unit file syntax (systemd-analyze verify) ──"
# Install just the systemd package so the verify tool is available
apt-get install -y -qq systemd >/dev/null
for u in /etc/systemd/system/*.service /etc/systemd/system/*.timer; do
  [[ -f "$u" ]] || continue
  name=$(basename "$u")
  # verify reports "ExecStart= script not executable" as an error in chroots
  # without a running systemd; filter those to keep signal.
  if systemd-analyze verify "$u" 2>&1 \
       | grep -v 'not executable' \
       | grep -v 'Cannot add dependency' \
       | grep -E 'ERROR|FATAL|Failed|Unknown' >/dev/null; then
    echo "  ✗ $name has real errors"
    systemd-analyze verify "$u" 2>&1 | sed 's/^/      /'
    fail=$((fail + 1))
  else
    echo "  ✓ $name"
    pass=$((pass + 1))
  fi
done

echo
echo "── Phase 5: installed scripts parse cleanly (bash -n) ──"
for s in /root/cs /root/cx /root/co \
         /usr/local/bin/check-mac-mounts /usr/local/bin/chrome-bridge-keeper \
         /usr/local/bin/cleanup-stale /usr/local/bin/kill-claude-orphans \
         /usr/local/bin/node-modules-gc /usr/local/bin/moto-reboot-recovery \
         /root/authenticated-browser/chrome-launcher.sh; do
  check "bash -n $s"   bash -n "$s"
done

echo
echo "── Phase 6: docker compose config validates ──"
# Need docker CLI for this (already installed by install.sh via apt).
if command -v docker >/dev/null && docker compose version >/dev/null 2>&1; then
  if (cd server/docker && docker compose config >/dev/null 2>&1); then
    echo "  ✓ compose.yaml validates"
    pass=$((pass + 1))
  else
    echo "  ✗ compose.yaml invalid"
    (cd server/docker && docker compose config 2>&1) | sed 's/^/      /'
    fail=$((fail + 1))
  fi
else
  echo "  • docker CLI unavailable (test container likely) — skipping"
fi

echo
echo "━━━ summary ━━━"
echo "  pass: $pass"
echo "  fail: $fail"
[[ $fail -eq 0 ]]
