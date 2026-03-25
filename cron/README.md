# Cron Job Patterns

Safe, observable scheduling patterns for server automation.

## Core principle: wrap everything in safe-pipeline

Never run a cron job bare. Always wrap with `safe-pipeline` (or at minimum `flock` + `timeout`).

`safe-pipeline` provides three guarantees:
1. **No overlaps** (flock): skips the run if the previous one is still running
2. **Memory cap** (cgroup): caps the process tree to prevent runaway memory
3. **Timeout** (timeout): kills the job after a maximum runtime

```bash
# bare cron (dangerous)
0 * * * * /usr/local/bin/my-script.sh

# wrapped cron (safe)
0 * * * * safe-pipeline /usr/local/bin/my-script.sh
```

## safe-pipeline vs safe-run

- `safe-pipeline` - for cron jobs (adds flock on top of timeout + cgroup)
- `safe-run` - for interactive one-off heavy commands (timeout + cgroup, no flock)

Both scripts live in `server/safety/` in this repo. They need to be installed to a location on `$PATH` (e.g., `/usr/local/bin/`) so cron jobs and interactive shells can find them. The repo's `install.sh` handles this, or you can copy them manually.

## flock: prevent overlapping runs

If you cannot use `safe-pipeline`, use `flock` directly:

```bash
LOCKFILE=/var/lock/my-script.lock
flock -n "$LOCKFILE" /usr/local/bin/my-script.sh
```

`-n` makes flock non-blocking: if the lock is held, the command exits immediately (the running job is not killed).

## Log output to files

Never discard cron output. Pipe to a log file so you can debug failures:

```bash
0 * * * * safe-pipeline /usr/local/bin/my-script.sh >> /var/log/my-script.log 2>&1
```

Rotate logs with `logrotate` or truncate in the script itself:

```bash
# Truncate log if over 10 MB at start of script
LOG=/var/log/my-script.log
if [ -f "$LOG" ] && [ "$(stat -c%s "$LOG")" -gt $((10 * 1024 * 1024)) ]; then
    tail -n 1000 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi
```

## Health check pattern

Run a lightweight health check every few minutes. The check script should:
1. Test each critical service
2. Log pass/fail with timestamp
3. Optionally alert (email, Slack, webhook) on failure

See `examples/health-check.sh` for a template.

## Backup pattern

Database backups should:
1. Write to a dated filename
2. Test the backup is non-empty
3. Prune old backups (keep last N)
4. Log result with timestamp

See `examples/backup-db.sh` for a template.

## Orphan process cleanup

Long-running automation (browser automation, ffmpeg, rendering) can leave orphan processes when they crash. Run a cleanup job every few minutes to kill stale processes.

See `examples/kill-stale-processes.sh` for a template.

## Example crontab

See `examples/crontab.example` for a fully annotated example crontab.

## Setting up cron

```bash
# Edit your crontab
crontab -e

# View current crontab
crontab -l

# System-wide cron (runs as root)
# /etc/cron.d/my-service  (one file per service)
```

## Crontab syntax reference

```
# ┌───────── minute (0 - 59)
# │ ┌───────── hour (0 - 23)
# │ │ ┌───────── day of month (1 - 31)
# │ │ │ ┌───────── month (1 - 12)
# │ │ │ │ ┌───────── day of week (0 - 7, 0 and 7 = Sunday)
# │ │ │ │ │
# * * * * *  command

*/5 * * * *   every 5 minutes
0 * * * *     every hour (at :00)
0 0 * * *     daily at midnight
0 0 * * 0     weekly on Sunday at midnight
0 0 1 * *     monthly on the 1st at midnight
```

## Timezone

Cron uses the system timezone. To use a specific timezone:

```bash
# At the top of your crontab
CRON_TZ=UTC
```

Or set system timezone: `timedatectl set-timezone UTC`
