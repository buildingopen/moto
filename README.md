# moto 🛵

> Your Mac is the remote control. A Linux box is the garage. **One command brings every agent window back.**

`moto` is an opinionated, reproducible setup for running an army of AI coding agents (Claude Code, Codex, opencode) on a big Linux box, controlled from your Mac, with:

- 🪟 **One iTerm window, many tabs** — every agent session as a tab, restored with one command after a reboot, laptop close, or Mac sleep
- 🔐 **Full-access Mac tunnel** — the server can read/write your Mac's `~/.claude` live over SSHFS (reverse tunnel), so your local config is the source of truth
- 🍎 **`moto`** — one command from the Mac: `moto up` reopens everything, `moto new` spawns a new session, `moto kill` cleans up
- ♻️ **Reboot / OOM survival** — `tmux` is OOM-immune, containers auto-restart, SSHFS re-mounts every 30s, stale processes are reaped nightly
- 🌐 **Residential-IP egress** — drop-in proxy container, all agent traffic rewritten through your provider of choice
- 🧰 **Code-execution sandboxes** — pre-wired containers for rendering, Node dev servers, and a logged-in headless Chrome with CDP exposed on the Docker bridge
- 🧹 **Auto-cleanup** — orphan `next dev` / `tsx watch` / Chrome / old `node_modules` are garbage-collected so the box doesn't rot

Built by [@federicodeponte](https://github.com/federicodeponte) to run 20+ concurrent Claude sessions on a Hetzner AX41 without ever babysitting the box.

---

## 60-second quickstart

```bash
git clone https://github.com/buildingopen/moto.git
cd moto
cp .env.example .env
$EDITOR .env              # fill in AX41_HOST, MAC_USER, etc.

./install.sh mac          # on your Mac
./install.sh server       # via SSH on your Linux box
```

Then from the Mac:

```bash
moto up                   # reopen every tmux session in ONE iTerm window
moto new myproj/feature   # spawn a fresh Claude session
moto ls                   # list active sessions
moto kill myproj/feature  # kill one
```

---

## Architecture

```
┌────────────────────────────── YOUR MAC ──────────────────────────────┐
│                                                                      │
│   iTerm (one window, N tabs)        ~/.claude  (source of truth)     │
│        │                                 ▲                           │
│        │ tmux -CC (ControlCC)            │ sshfs reverse mount       │
│        │ over SSH ControlMaster          │                           │
│        ▼                                 │                           │
│   moto CLI  ──── ssh ax41 ────► ax41:22  │   ◄── ssh -R 2222 ─┐      │
│                                          │        Mac sshd     │      │
└──────────────────────────────────────────┼─────────────────────┼──────┘
                                           │                     │
┌──────────────────────── YOUR LINUX BOX ──┼─────────────────────┼──────┐
│                                          ▼                     │      │
│   /mnt/mac-claude  (FUSE view of Mac ~/.claude)                 │      │
│                                                                 │      │
│   tmux-server.service (MemoryLow=16G, OOMScoreAdjust=-900)      │      │
│     ├─ tmux session  myproj/feature  → claude                   │      │
│     ├─ tmux session  other/main      → codex                    │      │
│     └─ ... (each a tab in your Mac iTerm)                       │      │
│                                                                 │      │
│   authenticated-chrome.service     → Xvfb :98 + Chrome :9222 ◄──┤      │
│   chrome-bridge-keeper.service     → CDP keepalive              │      │
│   cdp-docker-proxy.service         → 172.17.0.1:9222 for agents │      │
│                                                                 │      │
│   mac-mount-check.timer   → every 30s: remount if stale ────────┘      │
│   moto-cleanup.timer      → every 10min: reap orphans                  │
│   node-modules-gc.timer   → nightly: rm old node_modules               │
│                                                                        │
│   docker compose: ┌──────────────────────────────────────────┐         │
│                   │ proxy  (residential IP egress, all-in)   │         │
│                   │ runtime-api  (node execution sandbox)    │         │
│                   │ dev-sandbox  (sshd + node, port 2223)    │         │
│                   │ cloudflared  (outbound public tunnels)   │         │
│                   └──────────────────────────────────────────┘         │
└────────────────────────────────────────────────────────────────────────┘
```

See [`docs/architecture.md`](docs/architecture.md) for the full diagram.

---

## What `moto` does differently

| Problem | Typical solution | `moto` |
|---|---|---|
| Laptop sleeps, agents die | Run on laptop, restart | Agents live in `tmux` on server, Mac just attaches |
| Server OOM kills your session | `oom_score_adj` guesses | `tmux-server.service` reserves 16 GB + `OOMScoreAdjust=-900`; `earlyoom` picks someone else |
| Claude config drifts between machines | `rsync` / Dropbox / git | SSHFS reverse mount — the Mac *is* the filesystem |
| Re-opening 20 windows is tedious | Shell for-loop | `moto up` — kills iTerm, creates one window, opens every session as a tab, retries stubborn ones 5× |
| Agents get rate-limited by IP | Random VPN | Dedicated proxy container; only outbound agent traffic is rewritten |
| Agents need to use logged-in services | New login per session | Shared `authenticated-chrome` with CDP — agents attach, don't log in |
| Reboot nukes everything | `docker-compose up` by hand | All services are systemd-managed with `Restart=on-failure`, containers are `--restart unless-stopped` |

---

## Requirements

**Mac**: macOS 13+, iTerm2, Homebrew, `ssh` (ControlMaster), OpenSSH server (for reverse tunnel).

**Server**: Debian 12 / Ubuntu 22.04+, root or sudo, ≥16 GB RAM recommended, public IPv4. Tested on Hetzner AX41.

---

## Commands

```
moto up              # restore all sessions in one iTerm window (idempotent)
moto new NAME        # create session NAME (format: project/task)
moto attach NAME     # attach existing session as a new iTerm tab
moto ls              # list server sessions
moto kill NAME       # kill a session
moto status          # server health: tmux count, mount status, chrome, containers
moto img PATH        # scp an image to the server and print its remote path
moto logs            # tail moto-cleanup + mac-mount-check logs
moto down            # detach all clients (leaves sessions running)
moto doctor          # diagnose the setup
```

Legacy aliases (`ax`, `axo`, `axn`, `axk`, `axl`, `axwin`, `aximg`, `axd`, `axq`) are preserved — see [`mac/shell/20-sessions.zsh`](mac/shell/20-sessions.zsh).

---

## Documentation

- [Architecture](docs/architecture.md) — how the pieces fit
- [Bootstrap a fresh server](docs/bootstrap.md) — zero-to-moto on a new box
- [Browser login](docs/browser-login.md) — how to log `authenticated-chrome` into Google/GitHub/LinkedIn
- [Residential proxy setup](docs/proxy.md) — Bright Data, Smartproxy, or generic SOCKS5
- [Reboot recovery](docs/reboot-recovery.md) — what happens when the box comes back up
- [Claude config sync (why SSHFS)](docs/claude-sync.md) — why not rsync/git

---

## License

MIT © Federico de Ponte. See [LICENSE](LICENSE).
