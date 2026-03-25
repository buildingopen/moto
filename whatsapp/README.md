# WhatsApp Gateway Setup

Self-hosted WhatsApp Web gateway using [OpenClaw](https://github.com/buildingopen/openclaw-setup), running in Docker.

## Architecture

- **OpenClaw**: open-source WhatsApp Web gateway (Node.js, runs in Docker)
- **clawdbot-ctl**: control script wrapping docker commands
- **safe-wa-send**: safety wrapper that enforces contact lookup before sending

## Prerequisites

- Docker and Docker Compose
- A phone number with WhatsApp active
- WhatsApp Desktop SQLite DB accessible (for `safe-wa-send` contact lookup)

## Setup

### 1. Build the image

```bash
docker build -t clawdbot:latest .
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env with your API keys and config
```

### 3. Create data directory

```bash
mkdir -p /opt/clawdbot/data
```

### 4. Start the container

```bash
docker-compose up -d
```

### 5. Link WhatsApp (QR code scan)

```bash
clawdbot-ctl login
```

Open WhatsApp on your phone -> Settings -> Linked Devices -> Link a Device, then scan the QR code displayed in the terminal.

## CRITICAL: Never destroy the session

**NEVER run `docker-compose down` or `docker-compose up` (without `restart`).** This destroys the WhatsApp session and requires re-linking via QR code.

Always use:
- `clawdbot-ctl restart` - safe restart, preserves session
- `docker restart clawdbot` - equivalent safe restart

If you must change `docker-compose.yml` or `Dockerfile`, use `docker restart clawdbot` after rebuilding the image, NOT `docker-compose down && docker-compose up`.

Only use `docker-compose down/up` if absolutely unavoidable, and be prepared to re-scan the QR code.

## Sending Messages Safely

Never call `clawdbot-ctl send` directly. Always use `safe-wa-send`:

### Step 1: Look up and verify

```bash
safe-wa-send "Contact Name" "Your message here"
```

The script will:
1. Look up the contact JID from the WhatsApp SQLite DB
2. Display the resolved name, JID, and phone number
3. Show the message
4. **Exit without sending**

### Step 2: Review the output

Confirm the displayed phone number matches the intended recipient.

### Step 3: Send with confirmation

```bash
safe-wa-send "Contact Name" "Your message here" --confirmed
```

### Why this workflow exists

Sending to a wrong number can leak sensitive information. `safe-wa-send` enforces a two-step process:
- Contact lookup is always from the WhatsApp DB (never from memory or guesses)
- `@lid` JIDs (which silently fail or reach wrong contacts) are rejected in favor of phone JIDs
- No send happens without the `--confirmed` flag

## Auto-reply policies

Set in the OpenClaw config. Recommended defaults:

```
dmPolicy: disabled
groupPolicy: disabled
```

Keep auto-replies disabled unless you have a specific bot use case. Enabling them on a personal number will auto-reply to all incoming messages.

## Control commands

```
clawdbot-ctl start    Start the container
clawdbot-ctl stop     Stop the container
clawdbot-ctl restart  Restart (preserves WhatsApp session)
clawdbot-ctl logs     Tail container logs
clawdbot-ctl login    Link WhatsApp via QR code
clawdbot-ctl status   Show container status and linked channels
clawdbot-ctl send     Send message (use safe-wa-send instead)
```

## Data persistence

The container data directory is mounted at two paths inside the container:
- `/root/.clawdbot` - WhatsApp session state
- `/root/.openclaw` - OpenClaw config, agent auth tokens

Both point to the same host directory (`CLAWDBOT_DATA_DIR` in your `.env`). Config files for `gh`, `himalaya`, and coding agents are restored from this volume on each container start via `entrypoint.sh`.

## References

- [OpenClaw setup guide](https://github.com/buildingopen/openclaw-setup)
- [OpenClaw docs](https://openclaw.dev)
