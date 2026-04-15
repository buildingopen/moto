# Server Setup for Claude Code Dev Server

This directory contains everything needed to turn a dedicated Linux server into a productive Claude Code environment with browser automation, safe execution wrappers, SSHFS mounts, and multi-account tooling.

## Workflow

The setup this repo encodes:

```
Mac (iTerm2)
  └── dev()  ──── SSH ──── Linux dev server (49.213.x.x or similar)
                               ├── tmux: fitness-assessment  → happy claude
                               ├── tmux: floom-internal      → happy claude
                               └── tmux: second-brain        → happy claude

Mobile (iOS/Android)
  └── Happy app  ──── HTTPS ──── same tmux sessions (via happy.slopus.com)
```

**What this gives you:**
- One command (`dev`) from Mac opens one iTerm2 tab per running tmux session, each attached
- Sessions persist through SSH disconnects — close your laptop, work continues
- Mobile access via Happy: send prompts, watch output, get notified when Claude is done
- On every server reboot, sessions auto-start per git repo and launch `happy claude`
- Auth is managed by `setup-claude-auth.sh` — push credentials from Mac Keychain, no OAuth pain

**Day-to-day:**
```bash
dev           # connect from Mac — opens one tab per session
devs          # list sessions without attaching
ssh dev       # plain SSH if you prefer
```

**Re-authentication** (credentials expire ~1 year):
```bash
./server/setup-claude-auth.sh dev
```

---

## Prerequisites

- Ubuntu 22.04+ or Debian 12+
- systemd
- Docker (for cdp-docker-proxy)
- `socat` (`apt install socat`)
- `fuse` + `sshfs` (`apt install sshfs`)
- Google Chrome stable (`apt install google-chrome-stable` after adding Google repo)
- Python 3.9+ with `websocket-client` (`pip install websocket-client`)
- `tmux` (`apt install tmux`)

## Directory Structure

```
server/
  systemd/          Systemd unit files for Chrome, SSHFS mounts, health checks
  safety/           Memory-capped execution wrappers (safe-pipeline, safe-run)
  browser/          Chrome CDP setup, keepalive daemon
  sshfs/            Remote filesystem mount scripts
  multi-account/    gh, render, supabase account switching patterns
  terminal/         tmux config, Claude queue workflow
  tmux.conf         Drop-in tmux configuration
  bashrc            Generic .bashrc with useful patterns
```

## Quick Deploy

### 0. Authenticate Claude Code (Max/Pro plan, from your Mac)

Logging in to Claude Code on a headless Linux server via the normal OAuth flow is broken: the authorization code gets mangled on paste, and even when it succeeds the TUI shows a sign-in screen on every startup because `hasCompletedOnboarding` is missing from `~/.claude.json`.

The fix: push credentials from your Mac directly.

```bash
# Run from your Mac, after logging in to Claude Code locally
./setup-claude-auth.sh dev   # replace "dev" with your SSH alias
```

This copies your OAuth credentials from the macOS Keychain to the server and marks onboarding complete in `~/.claude.json`. Claude Code reads the credentials file natively — no env var needed. After that, `ssh dev && claude` works with no prompts.

If you're using an API key instead of a Max/Pro plan, skip this step and set `ANTHROPIC_API_KEY` in the server's `~/.bashrc`.

### 1. Install safety wrappers
```bash
cp safety/safe-pipeline /usr/local/bin/safe-pipeline
cp safety/safe-run /usr/local/bin/safe-run
cp safety/kill-stale-tests.sh /usr/local/bin/kill-stale-tests.sh
chmod +x /usr/local/bin/safe-pipeline /usr/local/bin/safe-run /usr/local/bin/kill-stale-tests.sh
cp safety/memory-guard.slice /etc/systemd/system/memory-guard.slice
systemctl daemon-reload
```

### 2. Install Chrome services
```bash
cp systemd/chrome-headless.service /etc/systemd/system/
cp systemd/chrome-bridge-keeper.service /etc/systemd/system/
# Edit unit files to set your CHROME_PROFILE_DIR and CDP_PORT
systemctl daemon-reload
systemctl enable --now chrome-headless chrome-bridge-keeper
```

### 3. Install SSHFS mount (optional, for multi-machine setups)
```bash
cp systemd/sshfs-mount.service /etc/systemd/system/
# Edit: set REMOTE_HOST, REMOTE_PATH, LOCAL_MOUNT_POINT
systemctl daemon-reload
systemctl enable --now sshfs-mount
cp systemd/mount-check.service /etc/systemd/system/
cp systemd/mount-check.timer /etc/systemd/system/
systemctl enable --now mount-check.timer
```

### 4. Install browser keepalive
```bash
cp browser/chrome-bridge-keeper.py /usr/local/bin/chrome-bridge-keeper
chmod +x /usr/local/bin/chrome-bridge-keeper
cp systemd/chrome-bridge-keeper.service /etc/systemd/system/
systemctl enable --now chrome-bridge-keeper
```

### 5. Terminal workflow
```bash
cp terminal/tmux.conf ~/.tmux.conf
# Add useful aliases from terminal/ scripts to your ~/.bashrc
cp server/bashrc ~/.bashrc  # or source it from your existing ~/.bashrc
```

### 6. Auto-start sessions on boot (optional)

Starts one tmux session per git repo in `/root` on every server reboot, each running `happy claude`:

```bash
cp terminal/start-claude-sessions.sh /usr/local/bin/start-claude-sessions.sh
chmod +x /usr/local/bin/start-claude-sessions.sh
(crontab -l 2>/dev/null; echo "@reboot /usr/local/bin/start-claude-sessions.sh") | crontab -
```

Replace `happy claude` with `claude` if you're not using Happy for mobile access.

### 7. Mobile access with Happy (optional)

[Happy](https://github.com/slopus/happy) gives you a mobile/web interface to control
Claude Code sessions on the server.

```bash
npm install -g happy
# Then start sessions with: happy claude
# Or set as default in ~/.tmux.conf: set -g default-command "happy claude"
```

## Key Concepts

**Memory safety**: All cron jobs and heavy scripts run through `safe-pipeline` (flock + timeout + 16GB cgroup cap). This prevents overlapping runs, runaway memory, and stuck processes.

**Chrome CDP**: Two Chrome instances serve different purposes. The primary instance (port 9222) holds authenticated sessions. A secondary instance (port 9223) can load extensions. The bridge-keeper daemon keeps service workers alive and auto-patches the MCP extension.

**SSHFS mounts**: Mounting a remote machine's home directory enables Claude Code to read files on the remote as if they were local. The mount-check timer automatically remounts stale SSHFS connections.

**Multi-account**: GitHub, Render, and Supabase all support multiple accounts via token switching. See `multi-account/` for patterns.
