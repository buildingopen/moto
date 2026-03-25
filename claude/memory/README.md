# Memory System

The memory system is Claude Code's external brain. It persists knowledge across conversations, preventing repeated mistakes and accelerating future work.

## What is Auto-Loaded?

Every Claude conversation automatically loads **MEMORY.md** (first ~200 lines) into the system context. This happens before your task begins.

**Path:** MEMORY.md lives at `~/.claude/projects/<project-hash>/memory/MEMORY.md` (Claude Code's project-scoped directory), not at `~/.claude/memory/`. Each project gets its own memory directory based on a hash of the project path.

## How to Use Memory

### MEMORY.md (The Index)
- Keep it under 200 lines
- Acts as a table of contents, not a detailed database
- Sections: Project Paths, Key Contacts, Writing Preferences, Communication Format, Corrections, Infrastructure
- Link to topic files for deep details: `See memory/servers.md for details`
- Auto-loaded into every session

### Topic Files
- Store detailed, stable information in dedicated files
- Examples: `visual-verification.md`, `whatsapp-reading.md`, `logos.md`, `servers.md`
- Only created when you have recurring patterns worth saving
- Not auto-loaded (Claude reads them on demand when relevant)

## What to Save

**YES - Save these:**
- Architectural decisions ("Use dev server for Chrome automation, laptop for CLI only")
- User preferences ("No em dashes", "TLDR first, tables over paragraphs")
- Recurring solutions ("Use Glob to verify paths before Read")
- Contact information (phone, JID, role)
- Project paths and deployment URLs
- Warnings ("NEVER recreate clawdbot container")
- Lessons from corrections (user corrects agent → immediate save)

**NO - Don't save these:**
- Session-specific context (conversation history, temporary variables)
- Unverified information (guesses, assumptions)
- Duplicates of CLAUDE.md (global rules already loaded)
- File contents (link to files instead: `/path/to/file.md`)
- Temporary todos or work-in-progress lists

## How Claude Updates Memory

### When Corrections Happen (IMMEDIATE)
1. User corrects agent on something factual
2. Agent saves the correction to MEMORY.md or topic file
3. Future sessions use the correction without delay

Example: User says "Actually, that's Portland, not Seattle."
- Immediate save to MEMORY.md: `User is based in Portland (moved from Seattle).`
- This prevents future agents from making the same mistake

### When Patterns Emerge (AFTER CONFIRMATION)
1. Agent notices a pattern (e.g., "user always wants X, never wants Y")
2. After 2+ confirmations across sessions, save to MEMORY.md
3. Future sessions use the pattern proactively

Example: "User always asks for ripple checks. After 3 sessions of this pattern, save to CLAUDE.md."

## File Structure

```
claude/memory/
├── README.md (this file - explains the system)
├── MEMORY.md (auto-loaded index, <200 lines)
├── examples/
│   ├── visual-verification.md (template)
│   ├── whatsapp-reading.md (template)
│   └── logos.md (template)
└── [topic files created as needed]
    ├── servers.md
    ├── deployment.md
    └── ...
```

## Best Practices

- **Keep MEMORY.md scannable** - Use tables, bullet points, short lines
- **Link aggressively** - "See memory/whatsapp-reading.md for full query examples"
- **Update after every correction** - Don't batch memory updates
- **Review before creating new topic files** - Check if content fits in MEMORY.md first
- **No speculation** - Only save verified facts and user-confirmed preferences
- **Version your decisions** - "As of 2026-03-25: we use X instead of Y because Z"

## Tools That Read Memory

- **Every Claude session** - Loads MEMORY.md automatically
- **`recall_search`** - Search session transcripts across all conversations
- **`recall_recent`** - Get last N messages from any previous session
- **`recall_report`** - Analyze error patterns, retries, corrections

These `recall_*` MCP tools require `session-recall` to be installed: `npm install -g session-recall`. Without it, you can still search transcripts manually with `grep` in `~/.claude/projects/*/`.

See `~/.claude/projects/*/` for raw JSONL transcripts (never deleted by compaction).
