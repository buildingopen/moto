#!/bin/bash
# dev-sandbox entrypoint — imports the host root user's public key(s) on first boot.
# /host-ssh is a read-only bind of the host's /root/.ssh (see compose.yaml).
set -e

AUTH_KEYS=/root/.ssh/authorized_keys
if [[ ! -f "$AUTH_KEYS" ]]; then
  mkdir -p /root/.ssh
  chmod 700 /root/.ssh
  : > "$AUTH_KEYS"

  # Prefer the host's existing authorized_keys (what already grants access to the host).
  if [[ -f /host-ssh/authorized_keys ]]; then
    cat /host-ssh/authorized_keys >> "$AUTH_KEYS"
  fi

  # Fallback: concat any *.pub files present.
  shopt -s nullglob
  for k in /host-ssh/*.pub; do
    cat "$k" >> "$AUTH_KEYS"
  done

  # De-duplicate while preserving order.
  if [[ -s "$AUTH_KEYS" ]]; then
    awk '!seen[$0]++' "$AUTH_KEYS" > "$AUTH_KEYS.tmp" && mv "$AUTH_KEYS.tmp" "$AUTH_KEYS"
  fi
  chmod 600 "$AUTH_KEYS" 2>/dev/null || true

  if [[ ! -s "$AUTH_KEYS" ]]; then
    echo "⚠ dev-sandbox: no public keys found in /host-ssh — you won't be able to SSH in." >&2
    echo "  Add a public key to the host's /root/.ssh/authorized_keys and restart." >&2
  fi
fi

ssh-keygen -A

exec "$@"
