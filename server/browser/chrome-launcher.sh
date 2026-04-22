#!/bin/bash
# chrome-launcher.sh — start Xvfb and launch Chrome with a persistent logged-in
# profile and CDP enabled so agents (inside Docker, via cdp-docker-proxy) can
# drive it instead of needing to log in themselves.
#
# Session cookies live in /root/.config/authenticated-chrome.
# Use /root/authenticated-browser/vnc-login.sh to log in interactively once.

set -u

# Start Xvfb on :98 if not running.
if ! pgrep -f "Xvfb :98" > /dev/null; then
    Xvfb :98 -screen 0 1280x800x24 &
    sleep 1
fi

export DISPLAY=:98
export TZ="${TZ:-Europe/Berlin}"

# Optional: route Chrome through proxy (set PROXY_URL in /opt/moto/.env).
PROXY_ARG=()
if [[ -f /opt/moto/.env ]]; then
  # shellcheck disable=SC1091
  source /opt/moto/.env
fi
if [[ -n "${PROXY_URL:-}" ]] && [[ ",${PROXY_APPLIES_TO:-}," == *",authenticated-chrome,"* ]]; then
  PROXY_ARG=(--proxy-server="$PROXY_URL")
fi

exec google-chrome-stable \
    --user-data-dir=/root/.config/authenticated-chrome \
    --no-sandbox \
    --disable-gpu \
    --remote-debugging-port=9222 \
    --remote-debugging-address=127.0.0.1 \
    --disable-background-timer-throttling \
    --disable-renderer-backgrounding \
    --disable-backgrounding-occluded-windows \
    --no-first-run \
    --disable-sync \
    --lang=en-US \
    --start-maximized \
    --window-size=1280,800 \
    --window-position=0,0 \
    --remote-allow-origins=* \
    "${PROXY_ARG[@]}"
