# Chrome CDP Setup for Claude Code Browser Automation

Claude Code's browser tools (claude-in-chrome, chrome-devtools, authenticated-browser)
connect to Chrome via the Chrome DevTools Protocol (CDP). This guide covers installing
Chrome, launching it headlessly, and wiring up MCP tools.

## Install Chrome

```bash
# Add Google Chrome repo
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
  > /etc/apt/sources.list.d/google-chrome.list
apt update && apt install -y google-chrome-stable

# Install Xvfb for virtual display
apt install -y xvfb
```

## Virtual Display

Chrome needs a display even in headless mode (for extension support). Start Xvfb:

```bash
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99
```

The `chrome-headless.service` systemd unit manages this automatically.

## Chrome Profiles

Create separate profile directories for different purposes:

```bash
# Primary instance: authenticated sessions, MCP tools
mkdir -p /opt/chrome-profiles/primary

# Secondary instance: extension testing, different accounts
mkdir -p /opt/chrome-profiles/secondary
```

## Launch Chrome with CDP

```bash
# Primary on port 9222
google-chrome-stable \
  --remote-debugging-port=9222 \
  --remote-allow-origins=* \
  --user-data-dir=/opt/chrome-profiles/primary \
  --no-first-run \
  --no-default-browser-check \
  --no-sandbox \
  --disable-popup-blocking \
  --start-maximized &
```

## Verify CDP is Working

```bash
# List open tabs
curl http://localhost:9222/json

# Get Chrome version
curl http://localhost:9222/json/version
```

## Docker Access to CDP

If running Claude in a Docker container, the container needs access to the host's CDP
port. Use the `cdp-docker-proxy.service` which runs socat to bridge the Docker network
to the host:

```
Container -> 172.17.0.1:9222 -> socat -> 127.0.0.1:9222 -> Chrome
```

## MCP Tool Routing

| Tool set | CDP Port | Use for |
|----------|----------|---------|
| claude-in-chrome | 9222 | Page reading, clicking, screenshots, navigation |
| chrome-devtools | 9222 | Performance, Lighthouse, network inspection |
| authenticated-browser | 9222 | Playwright scripts, complex waiting logic |

All three connect to the same Chrome instance. The extension-based `claude-in-chrome`
requires the Claude Code Chrome extension installed in that profile.

## Multiple Chrome Instances

Run a second instance on a different port for a separate profile (e.g. with extensions):

```bash
google-chrome-stable \
  --remote-debugging-port=9223 \
  --remote-allow-origins=* \
  --user-data-dir=/opt/chrome-profiles/secondary \
  --no-sandbox &
```

Use `chrome-headless.service` as a template and create a second unit file for port 9223.

## Service Worker Keepalive

MV3 Chrome extensions suspend their service workers after ~30 seconds of inactivity.
This breaks MCP tool connections. The `chrome-bridge-keeper` daemon:

1. Opens a CDP WebSocket to the extension's service worker
2. Sends periodic pings to keep it alive
3. Detects service worker restarts and re-patches the extension
4. Cleans up dead native host sockets

See `chrome-bridge-keeper.py` for the full implementation.

## Troubleshooting

**"Connection refused" on CDP port**: Chrome isn't running or didn't bind to the port.
Check `systemctl status chrome-headless` and `ss -tlnp | grep 9222`.

**Extension service worker suspended**: The bridge-keeper should handle this. If it's
not running: `systemctl status chrome-bridge-keeper`.

**"No tabs found"**: Chrome started but no page is loaded. Navigate to any URL or
open a new tab via CDP: `curl -X PUT http://localhost:9222/json/new`.

**Display errors**: Xvfb not running. Check `ps aux | grep Xvfb` and `echo $DISPLAY`.
