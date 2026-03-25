# Server Setup for Claude Code Dev Server

This directory contains everything needed to turn a dedicated Linux server into a productive Claude Code environment with browser automation, safe execution wrappers, SSHFS mounts, and multi-account tooling.

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
```

## Key Concepts

**Memory safety**: All cron jobs and heavy scripts run through `safe-pipeline` (flock + timeout + 16GB cgroup cap). This prevents overlapping runs, runaway memory, and stuck processes.

**Chrome CDP**: Two Chrome instances serve different purposes. The primary instance (port 9222) holds authenticated sessions. A secondary instance (port 9223) can load extensions. The bridge-keeper daemon keeps service workers alive and auto-patches the MCP extension.

**SSHFS mounts**: Mounting a remote machine's home directory enables Claude Code to read files on the remote as if they were local. The mount-check timer automatically remounts stale SSHFS connections.

**Multi-account**: GitHub, Render, and Supabase all support multiple accounts via token switching. See `multi-account/` for patterns.
