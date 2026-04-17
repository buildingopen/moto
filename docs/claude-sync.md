# Claude config sync — why SSHFS, not rsync

The Mac's `~/.claude` is the source of truth. The server reads it live via
SSHFS at `/mnt/mac-claude`. No sync step.

## Why not rsync / git / Dropbox?

Claude Code writes to `~/.claude/history.jsonl`, `file-history/`, `.cache/`,
and `debug/` **continuously while a session is running** — sometimes at tens
of writes per second. Any sync tool that periodically copies the directory
will either:

1. **Race with Claude's writes** → corrupted `history.jsonl` (JSONL parsing
   breaks on a partial line).
2. **Overwrite fresh server-side state** with stale client-side state → you
   lose the latest turns.
3. **Double-write** (rsync in both directions with conflict resolution) → you
   get `CLAUDE.md.local-conflict-2026-04-16.md` files.

Git doesn't work at all: `history.jsonl` is ~6 MB and grows daily, `cache/`
has thousands of tiny files, and your MCP credentials shouldn't be in git.

## Why SSHFS works

With SSHFS:
- Every read on the server is a real-time read from the Mac (cached briefly).
- Every write on the server is a real-time write to the Mac.
- There's only one copy of the data — no sync, no conflict.
- FUSE handles the "file in use by multiple processes" semantics correctly
  because it's really one filesystem.

## The reverse-tunnel architecture

The Mac isn't always reachable from the server directly (NAT, DHCP, you moved
to a coffee shop). So:

```
Mac launchd   ──── ssh -R 2222:localhost:22 ──►   server:2222
                                                   (sshd listens here)

server sshfs ──── ssh mac (= localhost:2222) ──►   Mac sshd
```

The Mac initiates the tunnel; the server uses it passively. Any time the Mac
wakes up or gets a new IP, launchd re-establishes the tunnel within ~10s, and
`mac-mount-check.timer` re-mounts within 30s.

## What if the Mac is asleep?

`/mnt/mac-claude` will become unresponsive. `mac-mount-check.timer`:
1. Detects the stale mount (`ls /mnt/mac-claude/CLAUDE.md` times out).
2. `fusermount -u`s it.
3. Re-mounts as soon as the Mac is back.

During the gap, **Claude sessions on the server still run fine** — they've
already loaded `CLAUDE.md` and your skills into memory. Only brand-new file
reads will fail until the Mac is back.

## What gets mounted

Two mounts, configured in `server/bin/check-mac-mounts`:

| Server mount      | Mac path                   | Purpose                        |
|-------------------|----------------------------|--------------------------------|
| `/mnt/mac-claude` | `~/.claude`                | The whole Claude config        |
| `/mnt/mac`        | `~/` (the Mac home dir)    | Full Mac access from the server|

The full home mount is what lets `aximg` (copy image to server) and
`moto img` work — but it's also a footgun (you can `rm -rf ~/Desktop` from a
server terminal). Keep an eye on that.

## If you want the opposite direction

Mount the server on your Mac:

```bash
brew install macfuse sshfs
mkdir -p ~/mnt/ax41
sshfs ax41:/root ~/mnt/ax41
```

This isn't used by moto but can be handy.
