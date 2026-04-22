# claude-setup

### Production-grade Claude Code setup, extracted from 500+ real sessions

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-compatible-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)

A complete Claude Code source-of-truth setup: CLAUDE.md templates, 17 safety hooks, 60+ skills, server infrastructure patterns, terminal workflow, WhatsApp/Gmail integration, memory system, and cost tracking. Everything is templated for reuse with no personal data.

---

## Who is this for?

- **Solo developers** using Claude Code daily who want battle-tested guardrails and productivity patterns
- **Teams** standardizing their Claude Code configuration across projects and machines
- **Anyone who's been burned** by Claude running `rm -rf`, pushing secrets, or claiming "should work" without verifying

## What makes this different?

Most Claude Code configs share a single CLAUDE.md. This repo shares the **full setup**: the config that lives in `~/.claude`, the hooks that enforce the rules, the skills that automate workflows, the reusable server-side patterns, and the memory system that makes Claude learn across sessions. Every pattern is extracted from real production use, not hypothetical best practices.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Repo Boundary](#repo-boundary)
- [What's Included](#whats-included)
- [Mac iTerm Workflow](#mac-iterm-workflow)
- [CLAUDE.md Templates](#claudemd-templates)
- [Safety Hooks](#safety-hooks)
- [Skills (40+)](#skills-40)
- [Memory System](#memory-system)
- [Server Infrastructure](#server-infrastructure)
- [WhatsApp & Gmail Integration](#whatsapp--gmail-integration)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Configuration](#configuration)
- [Related Projects](#related-projects)

---

## Quick Start

```bash
git clone https://github.com/buildingopen/claude-setup.git
cd claude-setup
./install.sh          # Symlinks configs into ~/.claude/
```

That's it. The installer detects existing configs, backs them up, resolves `$HOME` paths in hook commands, and installs 17 hooks + 7 scripts + 60+ skills + memory template. Run `./install.sh --copy` for standalone files instead of symlinks.

**After install:**
1. Edit `~/.claude/CLAUDE.md` to match your workflow (search for `<!-- Customize -->` comments)
2. Copy `claude/CLAUDE-project.md` into your project roots
3. Optionally copy `.env.example` to `.env` for API keys used by some hooks/scripts

---

## Repo Boundary

`claude-setup` is the canonical home for your Claude Code setup. Install this repo locally and treat the resulting `~/.claude` as the source of truth for:

- `CLAUDE.md`, `settings.json`, and `.mcp.json`
- Hooks, scripts, skills, and memory templates
- Reusable Mac and server-side patterns in [`mac/`](mac/), [`server/`](server/), [`cron/`](cron/), [`whatsapp/`](whatsapp/), and [`gmail/`](gmail/)

[`moto`](https://github.com/buildingopen/moto) is the specialized remote-ops layer built on top of that setup, not a replacement for it. It packages and extends the core tab/session workflow that now ships here, then adds:

- Mac-side iTerm tab/session orchestration
- Reverse SSH tunnel + SSHFS wiring
- Opinionated remote server bootstrap and recovery
- `moto up`, `moto new`, `moto doctor`, and the full multi-agent remote workflow

Use `claude-setup` by itself for local or lightly customized setups. Add `moto` when you want the full remote workstation layer.

---

## What's Included

| Directory | Contents | Purpose |
|-----------|----------|---------|
| [`claude/`](claude/) | CLAUDE.md, hooks, scripts, skills, memory | Core Claude Code configuration |
| [`mac/`](mac/) | iTerm tab opener, shell aliases, installer, SSH template | Mac-side remote session workflow |
| [`server/`](server/) | Systemd services, safety utils, browser automation, tmux | Shared dev-server foundation used directly or via moto |
| [`whatsapp/`](whatsapp/) | OpenClaw gateway, verified send, SQLite contact lookup | WhatsApp messaging integration |
| [`gmail/`](gmail/) | IMAP checker, multi-account support | Email access for Claude |
| [`cron/`](cron/) | Job templates, health checks, safe-pipeline patterns | Recurring task automation |

---

## CLAUDE.md Templates

Two templates encoding months of iteration on making Claude Code reliable:

- **[`claude/CLAUDE.md`](claude/CLAUDE.md)** - Global config (`~/.claude/CLAUDE.md`). Drop-in template with engineering principles, self-audit checklist, error recovery, communication standards, and quality gates.
- **[`claude/CLAUDE-project.md`](claude/CLAUDE-project.md)** - Per-project config. Tech stack, key files, testing conventions, deploy config. Copy into any project root.

<details>
<summary><strong>Key patterns in the global CLAUDE.md</strong></summary>

| Pattern | What it does |
|---------|-------------|
| **Read First, Code Later** | 80% reading, 20% writing. No changes without understanding context first. |
| **Self-Audit** | No completion claims without fresh verification evidence. Bans "should work now". |
| **Rationalization Red Flags** | Table of thoughts that signal the agent is about to skip process. |
| **Error Recovery** | Data-driven rules from 10,000+ error analysis (e.g., never retry a blocked hook). |
| **Ripple Check** | After every change, audit the diff for env vars, dependencies, breaking changes. |
| **Quality Gate** | Do not return until genuinely 10/10. List flaws before scoring. |

</details>

---

## Safety Hooks

17 hooks wired into `settings.json` that prevent Claude from doing damage. They run automatically on every tool call.

| Hook | Trigger | What It Does |
|------|---------|-------------|
| `block-destructive.sh` | Bash | Blocks `rm -rf /`, `git reset --hard`, `DROP TABLE`, `curl\|bash` |
| `protect-sensitive-files.sh` | Write/Edit | Blocks writes to `.pem`, `.key`, `id_rsa`, credentials |
| `protect-config-files.sh` | Write/Edit | Blocks editing linter/formatter configs to bypass checks |
| `scan-secrets-before-push.sh` | Bash | Runs gitleaks before `git push` |
| `enforce-package-manager.sh` | Bash | Detects lock file, blocks wrong package manager |
| `enforce-server-routing.sh` | Bash | Blocks CPU-heavy tasks locally, routes to dev server |
| `suggest-compact.sh` | Edit/Write/Bash | Counts tool calls, suggests `/compact` at threshold |
| `post-compaction-recall.sh` | Any | Detects post-compaction state, suggests session-recall |
| `cost-tracker.sh` | Stop | Tracks token costs per model/session to `costs.jsonl` |
| `gemini-audit.sh` + `.py` | Stop | Opt-in Gemini quality gate: scores output, blocks if < 10 |
| `block-wa-send.sh` | Bash | Blocks unverified WhatsApp sends (optional, not wired by default) |
| `block-terminal-minimize.sh` | Bash | Blocks AppleScript commands that minimize or hide terminal windows |
| `cc-precompact-hook.sh` | PreCompact | Saves git diff, test results, and loop state before context compaction |
| `cc-postcompact-hook.sh` | PostCompact | Restores saved state into context after compaction |
| `enforce-hetzner-heavy-tasks.sh` | Bash | Blocks CPU-heavy tasks locally (Remotion, ffmpeg, Playwright), routes to dev server |
| `rate-limit-auto-resume.sh` | Stop | Detects rate limit messages and schedules automatic resume via macOS `at` |
| `sandbox-heavy-tasks.sh` | PreToolUse | Intercepts memory-hungry commands (whisper, ffmpeg, torch) and routes through sandbox |

All hooks are pure bash (no external deps beyond `jq`). See [`claude/hooks/README.md`](claude/hooks/README.md) for how hooks work, the JSON protocol, and how to wire them in `settings.json`.

![Hook blocking a destructive command](assets/hook-demo.gif)

**Scripts included:**

| Script | Purpose |
|--------|---------|
| `gemini-fetch.sh` | Fetch blocked URLs via Gemini API (WebFetch fallback) |
| `claude-auto-resume.sh` | Auto-retry on rate limits with exponential backoff |
| `claude-rate-limit-watcher.sh` | Background rate limit monitor daemon |
| `claude-switch.sh` | Switch between multiple Claude accounts |
| `sync-claude-config.sh` | Sync CLAUDE.md across machines via SCP |

---

## Skills (60+)

Slash commands that extend Claude's capabilities. Each skill is a `SKILL.md` file installed to `~/.claude/commands/`. Invoke with `/skill-name` or let Claude detect and use them automatically. Includes `session-learn`, a meta-skill that analyzes past session transcripts to derive new skills and CLAUDE.md rules from real usage patterns.

<details>
<summary><strong>Full skill list by category</strong></summary>

**Shipping & QA:**
`bouncer` (Gemini quality gate), `ship` (pre-merge workflow), `qa` (autonomous testing), `debug` (systematic debugging), `target-loop` (verified iteration engine), `gh-launch` (repo launch checklist)

**Planning & Review:**
`retro` (weekly retrospective), `compass` (strategic planning), `blast-radius` (impact analysis), `deep-audit` (full repo audit via Gemini), `cost` (token spend reporting), `negotiator` (BATNA/ZOPA analysis, message scoring), `product` (UX decision framework)

**Auditing:**
`ui-audit` (UX/product review + wireframe comparison with Playwright screenshots and CSS extraction), `ux-audit` (independent Gemini-powered UX scoring), `seo` (technical SEO 8-dimension audit), `geo` (geographic data validator for aviation/travel)

**Document Generation:**
`pdf`, `docx`, `pptx`, `xlsx` manipulation, `yc-pitch-deck` (investor pitch deck)

**Design & Content:**
`frontend-design`, `slide-design`, `canvas-design`, `algorithmic-art`, `linkedin-copy`, `cold-outreach`, `brand-guidelines` (Anthropic brand), `republic-design` (investor-grade design scoring), `theme-factory` (10 pre-set visual themes), `web-artifacts-builder` (React + shadcn/ui artifacts), `internal-comms` (company newsletters, 3P updates)

**Video & Media:**
`video-edit` (trim, concat, overlays, audio mix, voiceover), `review-video` (frame extraction + visual review), `yc-video` (plan/score/audit startup launch videos), `slack-gif-creator` (animated GIFs optimized for Slack)

**Infrastructure & Ops:**
`deploy` (multi-project), `docker-deploy` (self-hosted), `dns` (DNS API), `health` (system audit), `email-check` (IMAP), `wa` (WhatsApp read/send), `mcp-builder`, `webapp-testing`, `browse` (browser automation), `browser-use` (persistent browser daemon), `post-to-x` (cross-post to X/Twitter)

**Context & Recovery:**
`vault` (context vault ops), `morning` (daily briefing), `recall` (post-compaction recovery), `session-learn` (derive skills from sessions), `issue` (multi-account GitHub issues), `agents` (scan running Claude sessions), `food-finder` (restaurant discovery via Swiggy + Maps)

**Meta:**
`skill-creator` (create new skills), `subagent-templates`, `new-project` (scaffolding), `doc-coauthoring`, `workplan` (multi-step task planning)

</details>

See [`claude/skills/README.md`](claude/skills/README.md) for the full list, SKILL.md format, and how to create your own.

---

## Memory System

An external brain pattern that persists knowledge across Claude Code sessions:

- **`MEMORY.md`** - Concise index (< 200 lines) auto-loaded into every conversation
- **Topic files** - Detailed notes on specific subjects, read on demand
- Claude auto-updates these as it learns preferences, patterns, and corrections

This prevents Claude from repeating mistakes across sessions and lets it build on prior context. See [`claude/memory/README.md`](claude/memory/README.md) for the full pattern.

---

## Server Infrastructure

Templates for running Claude Code on a dedicated dev server (VPS/dedicated). Not needed for local-only setups.

> 🛵 **Need the full packaged remote stack?** See **[moto](https://github.com/buildingopen/moto)** — a specialized setup that builds on this repo's canonical `~/.claude` config and extends the Mac/iTerm/tab workflow shipped here with reverse tunnel, SSHFS, health/status, tmux attach/recovery, and one-command bootstrap.

<details>
<summary><strong>What's in server/</strong></summary>

- **Systemd services** - Chrome headless with CDP, SSHFS mounts, CDP keepalive, Docker-host proxy
- **Safety utilities** - `safe-pipeline` (flock + timeout + cgroup memory cap), `safe-run`, stale process cleanup
- **Browser automation** - Chrome CDP setup guide, bridge keeper for session persistence
- **Multi-account management** - GitHub, Render, Supabase account switching patterns
- **Terminal workflow** - tmux config, bashrc (999K history, aliases), background task queue system

</details>

---

## Mac iTerm Workflow

`claude-setup` now ships the core AX41-style tab workflow directly:

- [`mac/bin/claude-tabs`](mac/bin/claude-tabs) opens new or existing remote sessions as iTerm tabs
- [`mac/install.sh`](mac/install.sh) installs the helper and zsh aliases locally
- [`server/bin/cs`](server/bin/cs) and [`server/bin/cx`](server/bin/cx) provide the tmux attach-or-create launchers on the server

Typical flow:

```bash
# once on the server
scp server/bin/cs server/bin/cx ax41:~/
ssh ax41 'chmod +x ~/cs ~/cx'

# once on the Mac
CLAUDE_REMOTE_HOSTNAME=1.2.3.4 CLAUDE_REMOTE_USER=root bash mac/install.sh
source ~/.zshrc

# everyday usage
ax myproj/feature   # open as a new iTerm tab
axo                 # reopen all remote tmux sessions as tabs
axl                 # list sessions
```

See [`mac/README.md`](mac/README.md) for the full setup.

---

## WhatsApp & Gmail Integration

**WhatsApp** (via [OpenClaw](https://github.com/openclaw/openclaw) gateway):
- Docker-based WhatsApp Web bridge
- Verified send script with SQLite contact lookup (prevents wrong-number sends)
- Direct SQLite DB reading for message history

**Gmail** (via IMAP):
- Multi-account email checking
- Preserves read/unread status (`BODY.PEEK[]` instead of `RFC822`)
- Standalone Python script, stdlib only, no pip dependencies

---

## Architecture

```
~/.claude/
  CLAUDE.md          <- claude/CLAUDE.md (global config)
  settings.json      <- claude/settings.json (hooks + permissions, $HOME resolved)
  .mcp.json          <- claude/.mcp.json (MCP servers)
  hooks/             <- claude/hooks/ (12 safety hooks)
  scripts/           <- claude/scripts/ (5 utility scripts)
  commands/          <- claude/skills/ (40+ slash commands)
  metrics/           <- cost tracking output (costs.jsonl)
  projects/*/memory/ <- external brain (MEMORY.md + topic files)

your-project/
  CLAUDE.md          <- claude/CLAUDE-project.md (per-project config)
```

---

## Requirements

| Requirement | Required? | Used by |
|-------------|-----------|---------|
| [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) | Yes | Everything |
| `jq` | Yes | All hooks (JSON parsing) |
| `python3` | Optional | Gemini audit hook, email checker |
| `gitleaks` | Optional | Secret scanning hook |
| Gemini API key | Optional | `gemini-fetch.sh`, `gemini-audit` |

---

## Configuration

After running `install.sh`:

1. **Edit CLAUDE.md** - Search for `<!-- Customize -->` comments and replace placeholders with your setup (server names, tool routing rules, project paths)
2. **Add project configs** - Copy `claude/CLAUDE-project.md` to each project root and fill in the tech stack section
3. **API keys** (optional) - Copy `.env.example` to `.env` for hooks/scripts that need external APIs

The `settings.json` file has `$HOME` paths pre-resolved by the installer. If you update the repo's `settings.json`, re-run `./install.sh` to pick up changes.

If you later add [`moto`](https://github.com/buildingopen/moto), keep this repo-installed `~/.claude` as the source of truth and let the specialized remote layer consume and extend the workflow already defined here.

---

## Related Projects

Other open-source tools from BuildingOpen:

| Project | Description |
|---------|-------------|
| **[moto](https://github.com/buildingopen/moto)** | 🛵 Specialized remote orchestration layer for this setup — packages the Mac/server tab workflow from this repo, then adds reverse tunnel, SSHFS, health/status, cleanup, and one-command remote workstation bootstrap |
| **[bouncer](https://github.com/buildingopen/bouncer)** | Independent Gemini quality gate that audits Claude Code's output before it can stop |
| **[claude-code-stats](https://github.com/buildingopen/claude-code-stats)** | Spotify Wrapped for Claude Code. Visualize your AI coding stats, token usage, and costs |
| **[claude-wrapped](https://github.com/buildingopen/claude-wrapped)** | Visualize your Claude Code stats with `npx claude-entropy` |
| **[hook-stats](https://github.com/buildingopen/hook-stats)** | Analyze your Claude Code bash command log |
| **[session-recall](https://github.com/buildingopen/session-recall)** | Search and recover context after Claude's automatic compaction |
| **[browse](https://github.com/buildingopen/browse)** | Browser automation CLI with autonomous agent mode via CDP |
| **[openbrowser](https://github.com/buildingopen/openbrowser)** | Give AI your browser. Check email, track orders, download receipts. MCP server + CLI |
| **[openqueen](https://github.com/buildingopen/openqueen)** | Autonomous coding agent controlled by WhatsApp/Telegram. Gemini orchestrates Claude/Codex |
| **[openclaw-setup](https://github.com/buildingopen/openclaw-setup)** | WhatsApp gateway setup guide (subset of this repo's `whatsapp/` directory) |
| **[blast-radius](https://github.com/buildingopen/blast-radius)** | Find all files affected by your changes. One bash script, zero dependencies |
| **[dep-check](https://github.com/buildingopen/dep-check)** | Find dead imports in your project. One bash script |
| **[ai-error-analyzer](https://github.com/buildingopen/ai-error-analyzer)** | 6 rules to reduce wasted AI coding retries |

---

## License

[MIT](LICENSE)
