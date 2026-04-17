#!/bin/bash
# dev-sandbox entrypoint — imports the host's public key the first time.
set -e

AUTH_KEYS=/root/.ssh/authorized_keys
if [[ ! -f "$AUTH_KEYS" ]]; then
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  if [[ -f /host-ssh/id_ed25519.pub ]]; then
    cp /host-ssh/id_ed25519.pub "$AUTH_KEYS"
  fi
  chmod 600 "$AUTH_KEYS" 2>/dev/null || true
fi

ssh-keygen -A

exec "$@"
