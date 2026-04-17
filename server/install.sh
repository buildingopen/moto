#!/usr/bin/env bash
# moto — server installer (run on the Linux box, as root)
set -euo pipefail

[[ "$EUID" -ne 0 ]] && { echo "❌ run as root (sudo -i)"; exit 1; }

MOTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$MOTO_DIR"

if [[ ! -f .env ]]; then
  echo "❌ .env not found in $MOTO_DIR"
  exit 1
fi

set -a; source .env; set +a
: "${MAC_USER:?set MAC_USER in .env}"
: "${MAC_REVERSE_PORT:=2222}"
: "${NODE_MODULES_GC_DAYS:=14}"

echo "━━━ moto server install ━━━"
echo "  mac user:        $MAC_USER"
echo "  reverse port:    $MAC_REVERSE_PORT"
echo

# ── 1. OS packages ──────────────────────────────────────────────────
echo "→ installing OS packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  tmux socat sshfs fuse3 \
  xvfb curl wget jq \
  earlyoom \
  ca-certificates gnupg lsb-release \
  rsync

# ── 2. Docker (if missing) ──────────────────────────────────────────
if ! command -v docker >/dev/null; then
  echo "→ installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
    $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# ── 3. Google Chrome (for authenticated-chrome) ─────────────────────
if ! command -v google-chrome-stable >/dev/null; then
  echo "→ installing Google Chrome..."
  wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  apt-get install -y -qq /tmp/chrome.deb
  rm -f /tmp/chrome.deb
fi

# ── 4. Install bin scripts ──────────────────────────────────────────
echo "→ installing scripts to /usr/local/bin and /root..."
install -m 0755 server/bin/cs                 /root/cs
install -m 0755 server/bin/cx                 /root/cx
install -m 0755 server/bin/co                 /root/co
install -m 0755 server/bin/check-mac-mounts   /usr/local/bin/check-mac-mounts
install -m 0755 server/bin/chrome-bridge-keeper /usr/local/bin/chrome-bridge-keeper
install -m 0755 server/bin/cleanup-stale      /usr/local/bin/cleanup-stale
install -m 0755 server/bin/kill-claude-orphans /usr/local/bin/kill-claude-orphans
install -m 0755 server/bin/node-modules-gc    /usr/local/bin/node-modules-gc
install -m 0755 server/bin/moto-reboot-recovery /usr/local/bin/moto-reboot-recovery

# Authenticated-chrome helpers
install -d /root/authenticated-browser
install -m 0755 server/browser/chrome-launcher.sh /root/authenticated-browser/chrome-launcher.sh
install -m 0755 server/browser/vnc-login.sh       /root/authenticated-browser/vnc-login.sh
install -m 0755 server/browser/backup-profile.sh  /root/authenticated-browser/backup-profile.sh

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
  cp "$unit" "/etc/systemd/system/$(basename "$unit")"
done

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

# ── 8. Docker compose stack ─────────────────────────────────────────
echo "→ starting docker compose stack..."
cd "$MOTO_DIR/server/docker"
docker compose up -d --remove-orphans
cd "$MOTO_DIR"

# ── 9. Initial mount attempt ────────────────────────────────────────
echo "→ attempting initial SSHFS mount of Mac..."
/usr/local/bin/check-mac-mounts || true

echo
echo "✓ moto server install complete."
echo
echo "Next steps:"
echo "  1. If a new SSH key was shown above, add it to your Mac's ~/.ssh/authorized_keys"
echo "  2. On your Mac, run: launchctl kickstart -k gui/\$UID/sh.buildingopen.moto.reverse-tunnel"
echo "  3. Test: ssh mac 'hostname' (from this server)"
echo "  4. moto doctor (from your Mac)"
