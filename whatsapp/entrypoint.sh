#!/bin/bash
# Restore configs from persisted volume on container start
# The volume is mounted at /root/.clawdbot and /root/.openclaw (same path)

# gh CLI auth
if [ -f /root/.clawdbot/config/gh/hosts.yml ]; then
    mkdir -p /root/.config/gh
    cp /root/.clawdbot/config/gh/hosts.yml /root/.config/gh/hosts.yml
fi

# himalaya IMAP/SMTP config
if [ -f /root/.clawdbot/config/himalaya/config.toml ]; then
    mkdir -p /root/.config/himalaya
    cp /root/.clawdbot/config/himalaya/config.toml /root/.config/himalaya/config.toml
fi

# Claude Code auth
if [ -d /root/.openclaw/config/claude ]; then
    mkdir -p /root/.claude
    cp -r /root/.openclaw/config/claude/* /root/.claude/
fi

# OpenAI Codex auth
if [ -d /root/.openclaw/config/codex ]; then
    mkdir -p /root/.codex
    cp -r /root/.openclaw/config/codex/* /root/.codex/
fi

exec openclaw gateway --allow-unconfigured --port 19000
