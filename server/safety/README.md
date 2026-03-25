# Safety: Memory Guards and Safe Execution Wrappers

Claude Code agents run long tasks autonomously. Without guardrails, a single runaway
process (whisper transcription, Playwright crawl, video rendering) can OOM the server
and kill every other session.

## The Problem

- Autonomous agents don't know when to stop
- ML models, headless browsers, and build tools can easily consume 20-50GB RAM
- Overlapping cron runs compound the problem
- Stuck processes block future runs indefinitely

## The Solution

Three layers of protection:

### 1. memory-guard.slice (systemd cgroup)

A systemd slice that caps memory at a configured limit. Any process run inside this
slice is killed by the kernel if the slice total exceeds `MemoryMax`.

Install:
```bash
cp memory-guard.slice /etc/systemd/system/
systemctl daemon-reload
```

Tune `MemoryMax` and `MemoryHigh` in the file to match your server's RAM.

### 2. safe-pipeline (flock + timeout + cgroup)

Wraps a command with:
- `flock`: only one instance of a given command runs at a time (prevents overlapping crons)
- `timeout`: kills the command after `PIPELINE_TIMEOUT` (default: 2h)
- `systemd-run --slice=memory-guard.slice`: runs inside the memory cap

Usage:
```bash
safe-pipeline node scripts/scrape.js
PIPELINE_TIMEOUT=30m safe-pipeline python sync.py
```

Install:
```bash
cp safe-pipeline /usr/local/bin/safe-pipeline
chmod +x /usr/local/bin/safe-pipeline
```

### 3. safe-run (cgroup only, no flock)

Like safe-pipeline but without the flock. Use for one-off heavy commands that you
run manually and don't need deduplication for.

```bash
safe-run ffmpeg -i input.mp4 output.mp4
safe-run whisper --model small audio.mp3
```

Install:
```bash
cp safe-run /usr/local/bin/safe-run
chmod +x /usr/local/bin/safe-run
```

### 4. kill-stale-tests.sh

Kills test runner processes (vitest, jest, mocha) that have been running longer than
60 minutes. Run via cron hourly:

```
0 * * * * /usr/local/bin/kill-stale-tests.sh
```

Install:
```bash
cp kill-stale-tests.sh /usr/local/bin/kill-stale-tests.sh
chmod +x /usr/local/bin/kill-stale-tests.sh
```

## Recommended Cron Layout

```cron
# Memory-safe pipeline runs
*/5 * * * * safe-pipeline /opt/scripts/sync-data.sh

# Clean up stale test processes
0 * * * * /usr/local/bin/kill-stale-tests.sh
```

## Tuning

| Server RAM | MemoryMax | MemoryHigh | PIPELINE_TIMEOUT |
|------------|-----------|------------|-----------------|
| 16 GB      | 12G       | 10G        | 1h              |
| 32 GB      | 24G       | 20G        | 2h              |
| 64 GB      | 48G       | 40G        | 4h              |

Set `PIPELINE_TIMEOUT` as an env var in crontab or the calling service.
