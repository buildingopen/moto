# moto — architecture

## Physical layout

```
        ┌───────────────────────────┐
        │          YOUR MAC         │
        │  (laptop, may sleep/move) │
        │                           │
        │   iTerm ─┐                │
        │          │ AppleScript    │
        │          ▼                │
        │   moto CLI                │
        │      │                    │
        │      ▼                    │
        │   ssh ax41 (ControlMaster)│
        │   ssh -R 2222:localhost:22 (reverse tunnel via launchd)
        │                           │
        └───────────┬───────────────┘
                    │ public internet
                    ▼
        ┌───────────────────────────┐
        │      YOUR LINUX BOX       │
        │     (AX41, always on)     │
        │                           │
        │   sshd :22                │
        │   sshd reverse :2222 → Mac│
        │                           │
        │   tmux-server.service     │
        │     └─ sessions …         │
        │                           │
        │   authenticated-chrome :9222 (CDP, via Xvfb :98)
        │   cdp-docker-proxy :9222 on 172.17.0.1
        │                           │
        │   sshfs:                  │
        │     /mnt/mac        ← ssh mac (reverse)
        │     /mnt/mac-claude ← ssh mac (reverse)
        │                           │
        │   docker compose:         │
        │     moto-proxy (3proxy)   │
        │     moto-runtime-api :3001│
        │     moto-dev-sandbox :2223│
        │     moto-cloudflared      │
        └───────────────────────────┘
```

## Key mechanics

### 1. The Mac is the source of truth for `~/.claude`

Instead of syncing with rsync, `cron`, or Dropbox, the server **mounts** the
Mac's `~/.claude` via SSHFS through the reverse tunnel. When you edit
`~/.claude/CLAUDE.md` on the Mac, every running Claude session on the server
reads the new version on the next file open — zero sync step.

The mount is kept healthy by `mac-mount-check.timer` which runs every 30s and
`fusermount -u` + re-`sshfs` on any stale mount.

### 2. Tmux is OOM-immune

`tmux-server.service` sets `MemoryLow=16G` and `OOMScoreAdjust=-900`. Combined
with `earlyoom.service`, any runaway process gets killed long before tmux and
its children (your 20+ agent sessions) are touched.

### 3. One iTerm window, many tabs

The Mac's `moto up` (in zsh: `axo`) does this dance:

1. Detaches all existing tmux clients on the server
2. Lists sessions sorted by activity
3. `pkill iTerm`, reopens it
4. For each session, creates a tab running `ssh -t ax41 ./cs NAME -CC`. The
   `-CC` flag puts tmux into **ControlCC mode**, so iTerm treats the tmux
   session as a native window — you get tab titles, scrollback, Cmd-arrow, etc.
5. Waits 12s, then retries any sessions that didn't attach (up to 5 rounds,
   then a final single-pass for stubborn ones)

This is idempotent: calling `moto up` at any time reconstructs the exact same
window layout on your Mac.

### 4. Logged-in browser for agents

`authenticated-chrome.service` runs Chrome under `Xvfb :98` with a persistent
profile at `/root/.config/authenticated-chrome`. CDP is exposed on `:9222`.
Because Docker-network agents can't reach `127.0.0.1:9222` on the host,
`cdp-docker-proxy.service` uses `socat` to re-expose it on `172.17.0.1:9222`,
the Docker bridge gateway.

Log in once via VNC (`server/browser/vnc-login.sh`) — your cookies,
localStorage, and 2FA'd sessions persist across reboots because the profile
directory is persistent.

### 5. Residential IP egress (optional)

When `PROXY_URL` is set, `docker compose --profile proxy up -d` starts a
3proxy sidecar. Agent containers set `HTTP_PROXY=http://moto-proxy:8118`,
which rewrites all outbound traffic through your residential provider
(Bright Data, Smartproxy, Oxylabs, etc.).

### 6. Auto-cleanup

- `moto-cleanup.timer` every 10min: kills orphan `next-server` (CPU > 50%,
  ppid=1), orphan chrome (> 2h), stale tmux clients.
- `node-modules-gc.timer` nightly: deletes `node_modules/` directories untouched
  for 14+ days.
- `kill-claude-orphans` nightly: kills `http.server`, `tsx watch`, `next dev`,
  `vite --` processes older than 24h.

### 7. Reboot recovery

`moto-reboot-recovery.service` runs exactly once after boot, after Docker and
network are up. It:

1. Waits up to 90s for the Mac reverse tunnel to come back
2. Runs `check-mac-mounts` twice (SSHFS remount)
3. `docker compose up -d --remove-orphans`
4. Verifies CDP at `:9222`; if it doesn't respond, restarts
   `authenticated-chrome.service`

Tmux sessions survive automatically because the tmux server itself is
restarted by its own systemd unit and sessions were started by
`cs`/`cx`/`co`, which use `new-session -A` (attach-or-create). They're
empty until you re-run `moto up` — but tmux state persists, so prior
scrollback and the Claude CLI process come back cleanly *if* they were
still alive before the reboot (they won't be, because the box rebooted —
but the session *slots* are restored automatically when `./cs NAME` is re-run).
