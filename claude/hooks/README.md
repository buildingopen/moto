# Claude Code Hooks

Hooks let you run custom scripts at key points in Claude Code's tool execution lifecycle. They act as guardrails, auditors, and automation triggers.

## Hook Types

| Event | When it fires | Use case |
|-------|---------------|----------|
| **PreToolUse** | Before a tool executes | Block destructive commands, enforce policies |
| **PostToolUse** | After a tool executes | Log results, trigger follow-up actions |
| **Stop** | When Claude is about to return a final response | Quality gates, cost tracking, audit |

## Wiring Hooks in settings.json

Add hooks to `~/.claude/settings.json` (global) or `.claude/settings.json` (per-project):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/block-destructive.sh"
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/protect-sensitive-files.sh"
          }
        ]
      }
    ],
    "PostToolUse": [],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.claude/hooks/cost-tracker.sh"
          }
        ]
      }
    ]
  }
}
```

The `matcher` field is a regex matched against the tool name. Use `""` or omit for all tools. Use `|` for multiple tools (e.g., `"Write|Edit"`).

## Hook Input Format

Hooks receive JSON on stdin with fields depending on the event type:

**PreToolUse:**
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "rm -rf /tmp/stuff"
  },
  "session_id": "abc123"
}
```

**Stop:**
```json
{
  "last_assistant_message": "Here is the completed code...",
  "session_id": "abc123",
  "model": "claude-sonnet-4-20250514",
  "usage": {
    "input_tokens": 5000,
    "output_tokens": 1200
  },
  "stop_hook_active": false,
  "transcript_path": "/home/user/.claude/projects/.../00abc.jsonl",
  "cwd": "/home/user/my-project"
}
```

## Exit Codes

| Exit code | Meaning |
|-----------|---------|
| **0** | Approve - tool execution proceeds |
| **2** | Block - tool execution is prevented; stdout message shown to Claude |

For Stop hooks, the JSON protocol is used instead:
- `{"decision": "approve"}` on stdout = let Claude respond
- `{"decision": "block", "reason": "..."}` on stdout + exit 2 = feed reason back to Claude

## Testing Hooks Manually

```bash
# Test a PreToolUse hook
echo '{"tool_input":{"command":"rm -rf /"}}' | bash ~/.claude/hooks/block-destructive.sh
echo $?  # Should print 2 (blocked)

# Test with a safe command
echo '{"tool_input":{"command":"ls -la"}}' | bash ~/.claude/hooks/block-destructive.sh
echo $?  # Should print 0 (approved)
```

## Included Hooks

| File | Type | Description |
|------|------|-------------|
| `block-destructive.sh` | PreToolUse (Bash) | Block rm -rf, git reset --hard, DROP TABLE, curl pipe to bash |
| `cost-tracker.sh` | Stop | Track token costs per model per session to costs.jsonl |
| `protect-sensitive-files.sh` | PreToolUse (Write/Edit) | Block writes to .pem, .key, id_rsa, credentials files |
| `protect-config-files.sh` | PreToolUse (Write/Edit) | Block editing linter/formatter configs (.eslintrc, biome.json, etc.) |
| `scan-secrets-before-push.sh` | PreToolUse (Bash) | Run gitleaks before git push, block if secrets found |
| `enforce-package-manager.sh` | PreToolUse (Bash) | Detect lock file, block wrong package manager |
| `suggest-compact.sh` | PreToolUse (Edit/Write/Bash) | Count tool calls per session, suggest /compact at threshold |
| `post-compaction-recall.sh` | PreToolUse (Bash/Read/Edit/Write/Glob/Grep) | Detect post-compaction, suggest session-recall recovery |
| `enforce-server-routing.sh` | PreToolUse (Bash) | Block CPU-heavy tasks locally, suggest dev server |
| `gemini-audit.sh` | Stop | Wrapper: opt-in Gemini quality gate |
| `gemini-audit.py` | Stop | Gemini independent audit implementation |
| `block-wa-send.sh` | PreToolUse (Bash) | Block unverified WhatsApp sends through gateway |

**Note on `block-wa-send.sh`:** This hook is included as a reference but is NOT wired into `settings.json` by default. It is an optional hook for users who run a WhatsApp gateway (e.g., OpenClaw/Clawdbot). To enable it, add a PreToolUse entry for it in your `settings.json` manually.

**Inline hooks in settings.json:** The default `settings.json` also includes a PostToolUse hook that is not a separate file: an inline `jq` command that logs every Bash command to `~/.claude/bash-commands.jsonl`. This is wired directly in `settings.json` as a `"command"` string rather than a standalone script file.
