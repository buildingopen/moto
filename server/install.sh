#!/usr/bin/env bash
# claude-setup integrated moto workflow — server installer (run on Linux as root)
set -euo pipefail

[[ "$EUID" -ne 0 ]] && { echo "❌ run as root (sudo -i)"; exit 1; }

MOTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="${MOTO_RUNTIME_DIR:-/opt/moto}"
cd "$MOTO_DIR"

if [[ ! -f .env ]]; then
  echo "❌ .env not found in $MOTO_DIR"
  exit 1
fi

# shellcheck disable=SC1091
set -a; source .env; set +a
: "${MAC_USER:?set MAC_USER in .env}"
: "${MAC_REVERSE_PORT:=2222}"
: "${NODE_MODULES_GC_DAYS:=14}"

# Test / staged-install flags. All default to off (= do everything).
#   SKIP_OS_INSTALL=1        skip apt-get install of tmux/socat/chrome/docker
#   SKIP_DOCKER_COMPOSE=1    don't run `docker compose up` at the end
#   SKIP_SYSTEMD_ENABLE=1    don't `systemctl enable/start` units (just install them)
#   FORCE=1                  overwrite existing files without backup
: "${SKIP_OS_INSTALL:=0}"
: "${SKIP_DOCKER_COMPOSE:=0}"
: "${SKIP_SYSTEMD_ENABLE:=0}"

echo "━━━ moto server install ━━━"
echo "  checkout dir:           $MOTO_DIR"
echo "  runtime dir:            $RUNTIME_DIR"
echo "  mac user:              $MAC_USER"
echo "  reverse port:          $MAC_REVERSE_PORT"
echo "  SKIP_OS_INSTALL:       $SKIP_OS_INSTALL"
echo "  SKIP_DOCKER_COMPOSE:   $SKIP_DOCKER_COMPOSE"
echo "  SKIP_SYSTEMD_ENABLE:   $SKIP_SYSTEMD_ENABLE"
echo

# Keep /opt/moto-compatible helper paths working even when the repo lives elsewhere.
if [[ "$MOTO_DIR" != "$RUNTIME_DIR" ]]; then
  install -d "$(dirname "$RUNTIME_DIR")"
  if [[ -e "$RUNTIME_DIR" && ! -L "$RUNTIME_DIR" ]]; then
    current_runtime="$(readlink -f "$RUNTIME_DIR" 2>/dev/null || true)"
    if [[ "$current_runtime" != "$MOTO_DIR" ]]; then
      echo "❌ $RUNTIME_DIR already exists and is not this checkout"
      echo "   move it aside or rerun with MOTO_RUNTIME_DIR pointing elsewhere"
      exit 1
    fi
  fi
  ln -sfn "$MOTO_DIR" "$RUNTIME_DIR"
  echo "✓ linked runtime dir: $RUNTIME_DIR -> $MOTO_DIR"
fi

# ── 1. OS packages ──────────────────────────────────────────────────
if [[ "$SKIP_OS_INSTALL" != "1" ]]; then
  echo "→ installing OS packages..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    tmux socat sshfs fuse3 \
    xvfb curl wget jq \
    earlyoom \
    ca-certificates gnupg lsb-release \
    rsync \
    iproute2
else
  echo "→ SKIP_OS_INSTALL=1 — skipping apt-get"
fi

# Disable systemd-oomd if present — earlyoom is what we enable, and running
# both OOM-killers simultaneously leads to unpredictable kills. tmux-server's
# OOMScoreAdjust=-900 only reliably protects us against a single OOM daemon.
if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-oomd\.service'; then
  if systemctl is-active --quiet systemd-oomd 2>/dev/null; then
    echo "  → disabling systemd-oomd (replaced by earlyoom)"
    systemctl disable --now systemd-oomd 2>/dev/null || true
  fi
fi

# ── 2. Docker (if missing) ──────────────────────────────────────────
if [[ "$SKIP_OS_INSTALL" != "1" ]] && ! command -v docker >/dev/null; then
  echo "→ installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  # shellcheck disable=SC1091
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
    $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# ── 3. Google Chrome (for authenticated-chrome) ─────────────────────
if [[ "$SKIP_OS_INSTALL" != "1" ]] && ! command -v google-chrome-stable >/dev/null; then
  echo "→ installing Google Chrome..."
  wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt-get install -y -qq /tmp/chrome.deb
  rm -f /tmp/chrome.deb
fi

# ── 4. Install bin scripts (safe: preserve local overrides) ─────────
# Preserve any existing file at the target that is marked with `MOTO_KEEP_LOCAL`
# or that predates moto and differs from the repo version. Pass --force to
# overwrite unconditionally.
FORCE="${FORCE:-0}"
[[ "${1:-}" == "--force" ]] && FORCE=1

safe_install() {
  local src="$1" dst="$2"
  if [[ -e "$dst" ]] && [[ "$FORCE" != "1" ]]; then
    if grep -q 'MOTO_KEEP_LOCAL' "$dst" 2>/dev/null; then
      echo "  • skip $dst (MOTO_KEEP_LOCAL marker present)"
      return 0
    fi
    if ! cmp -s "$src" "$dst"; then
      echo "  ⚠ $dst already exists and differs from repo version"
      echo "    backup:  $dst → $dst.pre-moto.$(date +%s)"
      cp -a "$dst" "$dst.pre-moto.$(date +%s)"
    fi
  fi
  install -m 0755 "$src" "$dst"
  echo "  ✓ $dst"
}

echo "→ installing scripts..."
safe_install server/bin/cs                    /root/cs
safe_install server/bin/cx                    /root/cx
safe_install server/bin/co                    /root/co
safe_install server/bin/check-mac-mounts      /usr/local/bin/check-mac-mounts
safe_install server/bin/chrome-bridge-keeper  /usr/local/bin/chrome-bridge-keeper
safe_install server/bin/cleanup-stale         /usr/local/bin/cleanup-stale
safe_install server/bin/kill-claude-orphans   /usr/local/bin/kill-claude-orphans
safe_install server/bin/node-modules-gc       /usr/local/bin/node-modules-gc
safe_install server/bin/moto-reboot-recovery  /usr/local/bin/moto-reboot-recovery

# Authenticated-chrome helpers
install -d /root/authenticated-browser
safe_install server/browser/chrome-launcher.sh /root/authenticated-browser/chrome-launcher.sh
safe_install server/browser/vnc-login.sh       /root/authenticated-browser/vnc-login.sh
safe_install server/browser/backup-profile.sh  /root/authenticated-browser/backup-profile.sh

# /root/images for moto img
install -d /root/images

# ── 5. Mac SSH config on server (Host mac → localhost:$MAC_REVERSE_PORT) ──
install -d -m 700 /root/.ssh
if ! grep -q '^Host mac$' /root/.ssh/config 2>/dev/null; then
  cat >> /root/.ssh/config <<EOF

Host mac
  HostName localhost
  Port $MAC_REVERSE_PORT
  User $MAC_USER
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  IdentityFile /root/.ssh/id_ed25519
  IdentitiesOnly yes
EOF
  chmod 600 /root/.ssh/config
  echo "✓ /root/.ssh/config: added Host mac"
fi

# Generate key if missing and tell user to add it on the Mac
if [[ ! -f /root/.ssh/id_ed25519 ]]; then
  ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519 -C "moto-server-$(hostname)"
  echo
  echo "⚠  NEW SSH KEY GENERATED. Add this to ~/.ssh/authorized_keys on your Mac:"
  echo
  cat /root/.ssh/id_ed25519.pub
  echo
fi

# ── 6. Mount points ─────────────────────────────────────────────────
install -d /mnt/mac /mnt/mac-claude

# Allow 'allow_other' in fuse
if ! grep -q '^user_allow_other' /etc/fuse.conf 2>/dev/null; then
  echo 'user_allow_other' >> /etc/fuse.conf
fi

# ── 7. systemd units ────────────────────────────────────────────────
echo "→ installing systemd units..."
for unit in server/systemd/*.service server/systemd/*.timer; do
  [[ -f "$unit" ]] || continue
  dst="/etc/systemd/system/$(basename "$unit")"
  if [[ -e "$dst" ]] && [[ "$FORCE" != "1" ]] && ! cmp -s "$unit" "$dst"; then
    echo "  ⚠ $dst differs from repo — backing up"
    cp -a "$dst" "$dst.pre-moto.$(date +%s)"
  fi
  cp "$unit" "$dst"
done

if [[ "$SKIP_SYSTEMD_ENABLE" == "1" ]]; then
  echo "→ SKIP_SYSTEMD_ENABLE=1 — units installed but not enabled/started"
else
  systemctl daemon-reload

  # Enable + start
  for unit in \
    tmux-server.service \
    authenticated-chrome.service \
    chrome-bridge-keeper.service \
    cdp-docker-proxy.service \
    mac-mount-check.timer \
    moto-cleanup.timer \
    node-modules-gc.timer \
    moto-reboot-recovery.service \
    earlyoom.service; do
    systemctl enable "$unit" 2>/dev/null || true
    # Only start timers/services that are safe to (re)start now
    case "$unit" in
      *.timer|earlyoom.service|tmux-server.service|cdp-docker-proxy.service|authenticated-chrome.service|chrome-bridge-keeper.service)
        systemctl restart "$unit" 2>/dev/null || true
        ;;
    esac
  done
fi

# ── 8. Docker compose stack ─────────────────────────────────────────
if [[ "$SKIP_DOCKER_COMPOSE" == "1" ]]; then
  echo "→ SKIP_DOCKER_COMPOSE=1 — skipping docker compose up"
else
echo "→ preflight: port availability..."
declare -A want_ports=(
  ["3001"]="runtime-api"
  ["2223"]="dev-sandbox"
  ["8118"]="proxy"
)
conflicts=0
for port in "${!want_ports[@]}"; do
  if ss -ltn "sport = :$port" 2>/dev/null | grep -q LISTEN; then
    echo "  ⚠ port $port (${want_ports[$port]}) already in use:"
    ss -ltnp "sport = :$port" 2>/dev/null | tail -n +2 | head -3
    conflicts=$((conflicts + 1))
  fi
done
if (( conflicts > 0 )) && [[ "$FORCE" != "1" ]]; then
  echo
  echo "  ⚠ $conflicts port(s) already bound. moto containers would fail to start."
  echo "    Options:"
  echo "      1. Stop the conflicting services on those ports"
  echo "      2. Edit server/docker/compose.yaml to use different host ports"
  echo "      3. Re-run with FORCE=1 to start anyway (conflicting services won't start)"
  echo "    Skipping docker compose up."
else
  echo "→ starting docker compose stack..."
  cd "$MOTO_DIR/server/docker"
  docker compose up -d --remove-orphans
  cd "$MOTO_DIR"
fi
fi

# ── 9. Initial mount attempt ────────────────────────────────────────
if [[ "$SKIP_SYSTEMD_ENABLE" == "1" ]]; then
  echo "→ SKIP_SYSTEMD_ENABLE=1 — skipping initial mount attempt"
else
  echo "→ attempting initial SSHFS mount of Mac..."
  /usr/local/bin/check-mac-mounts || true
fi

echo
echo "✓ moto server install complete."
echo
echo "Next steps:"
echo "  1. If a new SSH key was shown above, add it to your Mac's ~/.ssh/authorized_keys"
echo "  2. On your Mac, run: launchctl kickstart -k gui/\$UID/sh.buildingopen.moto.reverse-tunnel"
echo "  3. Test: ssh mac 'hostname' (from this server)"
echo "  4. Install the agent CLIs you plan to use:"
echo "       npm i -g @anthropic-ai/claude-code && claude /login   # for moto new"
echo "       npm i -g @openai/codex                                # for moto newx"
echo "       npm i -g opencode                                     # for moto newo"
echo "  5. moto doctor (from your Mac)"
