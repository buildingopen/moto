# Server Setup for the Integrated Remote Workflow

This directory contains the Linux-side runtime for the full `claude-setup` remote workflow. The recommended install path is from the repo root:

```bash
cp .env.example .env
$EDITOR .env
./install.sh server-remote
```

That syncs this repo to `AX41_HOST:/opt/moto` by default and runs [`server/install.sh`](install.sh) remotely as root.

If you are already on the Linux box, run:

```bash
bash server/install.sh
```

The installer keeps `/opt/moto` as the default runtime path for compatibility with the bundled helpers and systemd units, even when the checkout lives somewhere else.

## What lives here

- `bin/` - tmux launchers (`cs`, `cx`, `co`) plus maintenance helpers
- `browser/` - authenticated Chrome launcher and profile backup helpers
- `docker/` - runtime API, proxy, sandbox, and optional tunnel compose stack
- `systemd/` - units and timers for tmux, Chrome, cleanup, reboot recovery, and mount health
- `terminal/` - tmux config and queue helpers
- `test/` - smoke-test helpers for the server-side runtime

Pair this with [`mac/bin/moto`](../mac/bin/moto) on the Mac. [`mac/bin/claude-tabs`](../mac/bin/claude-tabs) remains available as a compatibility wrapper.

## Prerequisites

- Ubuntu 22.04+ or Debian 12+
- systemd
- Docker (for cdp-docker-proxy)
- `socat` (`apt install socat`)
- `fuse` + `sshfs` (`apt install sshfs`)
- Google Chrome stable (`apt install google-chrome-stable` after adding Google repo)
- Python 3.9+ with `websocket-client` (`pip install websocket-client`)
- `tmux` (`apt install tmux`)

## What `server/install.sh` installs

- `/root/cs`, `/root/cx`, `/root/co` plus the maintenance helpers under `/usr/local/bin`
- `Host mac` SSH config on the server, backed by the reverse tunnel from your Mac
- `/mnt/mac` and `/mnt/mac-claude` SSHFS mount points
- systemd units for `tmux-server`, `authenticated-chrome`, cleanup timers, reboot recovery, and mount health
- Docker compose services from [`server/docker/`](docker/)
- authenticated Chrome helpers under `/root/authenticated-browser`

After install, your normal entry point is from the Mac:

```bash
moto doctor
moto new hello/world
moto up
```

## Manual / cherry-pick install

If you do not want the full packaged workflow, you can still reuse pieces from this directory directly.

### Install just the tmux launchers

```bash
cp bin/cs /root/cs
cp bin/cx /root/cx
cp bin/co /root/co
chmod +x /root/cs /root/cx /root/co
```

### Install just the systemd units

```bash
cp systemd/*.service systemd/*.timer /etc/systemd/system/
systemctl daemon-reload
```

## Key Concepts

**Memory safety**: All cron jobs and heavy scripts run through `safe-pipeline` (flock + timeout + 16GB cgroup cap). This prevents overlapping runs, runaway memory, and stuck processes.

**Chrome CDP**: Two Chrome instances serve different purposes. The primary instance (port 9222) holds authenticated sessions. A secondary instance (port 9223) can load extensions. The bridge-keeper daemon keeps service workers alive and auto-patches the MCP extension.

**SSHFS mounts**: Mounting a remote machine's home directory enables Claude Code to read files on the remote as if they were local. The mount-check timer automatically remounts stale SSHFS connections.

**Multi-account**: GitHub, Render, and Supabase all support multiple accounts via token switching. See `multi-account/` for patterns.
