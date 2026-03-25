#!/usr/bin/env python3
"""
Chrome Bridge Keeper - CDP keepalive + auto-patch action tools.

Does:
- Keep CDP WebSocket open to extension service worker (prevents MV3 suspension)
- Detect service worker restarts (new page ID)
- Auto-run fix-claude-chrome-tools after each (re)connection
- Clean stale sockets (dead processes)

Does NOT:
- Create native hosts directly (fix script handles that)
- Kill live native host processes

Requirements:
  pip install websocket-client

Configuration:
  CDP_PATCH_PORTS    - Ports whose extensions should be patched (default: [9222])
  CDP_KEEPALIVE_PORTS - All ports to keep alive (default: [9222, 9223])
  FIX_SCRIPT         - Path to the patch script (default: /usr/local/bin/fix-claude-chrome-tools)

Only patch the primary port (9222). Patching a secondary port creates a second socket
that can confuse native host socket selection.
"""
import websocket
import json
import urllib.request
import time
import sys
import os
import signal
import logging
import subprocess

# Ports to patch (run fix script after connecting)
CDP_PATCH_PORTS = [9222]
# Ports to keep alive with periodic pings
CDP_KEEPALIVE_PORTS = [9222, 9223]
# Socket directory for native host process sockets
SOCKET_DIR = f"/tmp/claude-mcp-browser-bridge-{os.environ.get('USER', 'root')}/"
HEALTH_CHECK_INTERVAL = 10  # seconds between checks
FIX_SCRIPT = "/usr/local/bin/fix-claude-chrome-tools"
PATCH_COOLDOWN = 30  # seconds between patch attempts

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger('bridge-keeper')

running = True


def signal_handler(sig, frame):
    global running
    log.info("Shutting down...")
    running = False

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)


def get_service_worker_info(cdp_port):
    """Returns (ws_url, page_id) for the extension service worker, or (None, None)."""
    try:
        tabs = json.loads(urllib.request.urlopen(
            f"http://localhost:{cdp_port}/json", timeout=5
        ).read())
        # Find the Claude Code extension service worker tab
        # The extension ID fragment "fcoeoabgf" is from the Claude Code Chrome extension
        sw = [t for t in tabs
              if "fcoeoabgf" in t.get("url", "")
              and "service-worker" in t.get("url", "")]
        if sw:
            return sw[0]["webSocketDebuggerUrl"], sw[0].get("id", "")
    except Exception as e:
        log.debug(f"Cannot reach Chrome CDP on {cdp_port}: {e}")
    return None, None


def clean_stale_sockets():
    """Remove sockets whose processes are dead. Never kill live processes."""
    try:
        for f in os.listdir(SOCKET_DIR):
            if not f.endswith(".sock"):
                continue
            pid_str = f.replace(".sock", "")
            try:
                pid = int(pid_str)
                os.kill(pid, 0)
            except ProcessLookupError:
                path = os.path.join(SOCKET_DIR, f)
                try:
                    os.unlink(path)
                    log.debug(f"Cleaned stale socket {f}")
                except OSError:
                    pass
            except ValueError:
                pass
    except FileNotFoundError:
        pass


def count_live_sockets():
    """Count native host sockets with live processes."""
    count = 0
    try:
        for f in os.listdir(SOCKET_DIR):
            if not f.endswith(".sock"):
                continue
            pid_str = f.replace(".sock", "")
            try:
                pid = int(pid_str)
                os.kill(pid, 0)
                count += 1
            except (ProcessLookupError, ValueError):
                pass
    except FileNotFoundError:
        pass
    return count


def connect_cdp(ws_url):
    """Open a CDP WebSocket to the service worker. Returns the WebSocket or None."""
    try:
        ws = websocket.create_connection(ws_url, timeout=10)
        ws.send(json.dumps({"id": 1, "method": "Runtime.evaluate", "params": {
            "expression": "'bridge-keeper-connected'"
        }}))
        resp = json.loads(ws.recv())
        result = resp.get("result", {}).get("result", {}).get("value", "")
        if result == "bridge-keeper-connected":
            return ws
        log.warning(f"Unexpected CDP response: {result}")
        ws.close()
    except Exception as e:
        log.warning(f"CDP connection failed: {e}")
    return None


def ws_alive(ws, msg_id):
    """Check if the CDP WebSocket is still alive."""
    try:
        ws.send(json.dumps({"id": msg_id, "method": "Runtime.evaluate", "params": {
            "expression": "'ping'"
        }}))
        ws.settimeout(5)
        resp = json.loads(ws.recv())
        return resp.get("result", {}).get("result", {}).get("value") == "ping"
    except Exception:
        return False


def check_patch_status(ws, msg_id):
    """Check if the S handler is patched on this service worker."""
    try:
        ws.send(json.dumps({"id": msg_id, "method": "Runtime.evaluate", "params": {
            "expression": "typeof self.__origS !== 'undefined'"
        }}))
        ws.settimeout(5)
        resp = json.loads(ws.recv())
        return resp.get("result", {}).get("result", {}).get("value") is True
    except Exception:
        return False


def run_fix_script(port=None):
    """Run fix-claude-chrome-tools. Returns True on success."""
    if not os.path.exists(FIX_SCRIPT):
        log.warning(f"Fix script not found: {FIX_SCRIPT}")
        return False
    try:
        cmd = [FIX_SCRIPT]
        if port:
            cmd.append(str(port))
        log.info(f"Running fix script: {' '.join(cmd)}")
        result = subprocess.run(
            cmd,
            capture_output=True, text=True, timeout=30,
            env={**os.environ, "NODE_PATH": "/usr/lib/node_modules"}
        )
        for line in result.stdout.strip().split('\n'):
            if line.strip():
                log.info(f"  fix: {line.strip()}")
        if result.returncode != 0:
            for line in result.stderr.strip().split('\n'):
                if line.strip():
                    log.warning(f"  fix stderr: {line.strip()}")
            return False
        return True
    except subprocess.TimeoutExpired:
        log.warning("Fix script timed out")
        return False
    except Exception as e:
        log.warning(f"Fix script error: {e}")
        return False


def main():
    global running
    log.info(f"Chrome Bridge Keeper starting (patch: {CDP_PATCH_PORTS}, keepalive: {CDP_KEEPALIVE_PORTS})")
    os.makedirs(SOCKET_DIR, mode=0o700, exist_ok=True)
    clean_stale_sockets()

    # Track per-port state
    state = {}
    for port in CDP_KEEPALIVE_PORTS:
        state[port] = {
            'ws': None,
            'msg_id': 100,
            'page_id': None,
            'last_patch_time': 0,
            'patched': False,
            'delay': 2,
        }

    while running:
        clean_stale_sockets()

        for port in CDP_KEEPALIVE_PORTS:
            s = state[port]
            should_patch = port in CDP_PATCH_PORTS

            # Check existing connection
            if s['ws'] is not None:
                s['msg_id'] += 1
                if ws_alive(s['ws'], s['msg_id']):
                    # Check if patch is still applied (only for patch ports)
                    if should_patch and s['patched']:
                        s['msg_id'] += 1
                        if not check_patch_status(s['ws'], s['msg_id']):
                            log.info(f"[{port}] Patch lost, re-applying...")
                            s['patched'] = False
                    # Apply patch if needed
                    if should_patch and not s['patched'] and time.time() - s['last_patch_time'] > PATCH_COOLDOWN:
                        s['last_patch_time'] = time.time()
                        if run_fix_script(port):
                            s['patched'] = True
                            log.info(f"[{port}] Patch applied successfully")
                        else:
                            log.warning(f"[{port}] Patch failed, will retry in {PATCH_COOLDOWN}s")
                    continue

                log.info(f"[{port}] CDP WebSocket lost, reconnecting...")
                try:
                    s['ws'].close()
                except Exception:
                    pass
                s['ws'] = None
                s['patched'] = False
                continue

            # Try to connect
            ws_url, page_id = get_service_worker_info(port)
            if not ws_url:
                time.sleep(s['delay'])
                s['delay'] = min(s['delay'] * 2, 30)
                continue

            # Detect service worker restart
            if s['page_id'] and page_id != s['page_id']:
                log.info(f"[{port}] Service worker restarted (was {s['page_id'][:8]}..., now {page_id[:8]}...)")
                s['patched'] = False

            s['page_id'] = page_id
            ws = connect_cdp(ws_url)
            if ws is None:
                time.sleep(s['delay'])
                s['delay'] = min(s['delay'] * 2, 30)
                continue

            sockets = count_live_sockets()
            log.info(f"[{port}] CDP keepalive established ({sockets} native host sockets)")
            s['ws'] = ws
            s['delay'] = 2

            # Auto-patch after connection
            if should_patch and not s['patched'] and time.time() - s['last_patch_time'] > PATCH_COOLDOWN:
                s['last_patch_time'] = time.time()
                if run_fix_script(port):
                    s['patched'] = True
                    log.info(f"[{port}] Patch applied after (re)connection")

        time.sleep(HEALTH_CHECK_INTERVAL)

    for port in CDP_KEEPALIVE_PORTS:
        if state[port]['ws']:
            try:
                state[port]['ws'].close()
            except Exception:
                pass
    log.info("Chrome Bridge Keeper stopped")


if __name__ == "__main__":
    main()
