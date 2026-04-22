# Reboot recovery

What happens when the server reboots (hardware fault, kernel update, RAM
pressure cycling into a reset, you running `reboot` by hand)?

## The recovery chain

```
┌─────────────────────────────────────────┐
│  boot                                    │
│    │                                     │
│    ▼                                     │
│  network-online.target + docker.service  │
│    │                                     │
│    ▼                                     │
│  tmux-server.service (MemoryLow=16G)     │  ← empty but alive
│    │                                     │
│    ▼                                     │
│  authenticated-chrome.service (Xvfb+CDP) │
│  chrome-bridge-keeper.service            │
│  cdp-docker-proxy.service                │
│    │                                     │
│    ▼                                     │
│  mac-mount-check.timer (30s interval)    │  ← tries SSHFS every 30s
│  moto-cleanup.timer (10min interval)     │
│  node-modules-gc.timer (nightly)         │
│    │                                     │
│    ▼                                     │
│  moto-reboot-recovery.service (oneshot)  │  ← runs exactly once
│    ├─ waits up to 90s for Mac tunnel     │
│    ├─ runs check-mac-mounts twice        │
│    ├─ docker compose up -d               │
│    └─ verifies CDP, restarts if needed   │
│                                          │
│  (your Docker containers are already     │
│   up because they have                   │
│   `restart: unless-stopped`)             │
└─────────────────────────────────────────┘
```

## What you get back automatically

- ✅ tmux server (empty sessions)
- ✅ Docker containers (proxy, runtime-api, dev-sandbox, cloudflared)
- ✅ SSHFS mount of Mac (as soon as Mac reverse tunnel is up)
- ✅ authenticated-chrome + CDP
- ✅ Cleanup timers rearmed

## What you need to do manually

Just run `moto up` on the Mac. It reattaches all *active* sessions and
reopens every tab.

If specific sessions had running Claude/Codex processes, those were killed
by the reboot. `moto up` recreates the tmux sessions (names are `new-session
-A` — attach or create), and each tab will start Claude/Codex fresh.

## If the reverse tunnel never comes back

Symptom: `/mnt/mac-claude` is empty, `ssh mac` hangs.

```bash
# On the Mac:
launchctl kickstart -k gui/$UID/sh.buildingopen.moto.reverse-tunnel
tail -f ~/Library/Logs/moto-reverse-tunnel.log
```

If it still fails, check that your Mac's sshd allows the server's SSH key:

```bash
ssh ax41 'cat /root/.ssh/id_ed25519.pub'   # copy this
# on the Mac:
grep -q 'moto-server' ~/.ssh/authorized_keys && echo present || echo ABSENT
```

## If you want sessions to *also* survive

Tmux sessions don't persist across machine reboots by default. If you need
long-running processes to survive, use:

- `tmux-resurrect` / `tmux-continuum` (classic)
- or run the work in a container with a named volume instead of in tmux

moto deliberately keeps tmux as "session-slot holder" only — the processes
inside are agents, which should be restartable at any time.
