# Demo GIFs

This repo is powerful but dense. Every major feature should have a 10–30 second GIF showing the happy path.

## Hero demo (top of main README)

`assets/demos/hero.gif` — the full 30-second pitch:
```
moto new myproj/feature
# → iTerm spawns 4 tabs
# → SSH to remote
# → tmux session attaches
# → Claude starts in context
```

## Feature demos

| Feature | Target file | What to record |
|---------|-------------|----------------|
| **WhatsApp setup** | `assets/demos/whatsapp-setup.gif` | `clawdbot-ctl login` → QR code → phone scan → `safe-wa-send "Name" "test"` → verify output → `--confirmed` send |
| **Install** | `assets/demos/install.gif` | `git clone … && cd moto && ./install.sh` → hooks installed → skills symlinked |
| **Safety hook block** | `assets/demos/hook-block.gif` | Claude tries `rm -rf /` → hook intercepts → red error |
| **moto CLI** | `assets/demos/moto-cli.gif` | `moto ls` → `moto new proj` → `moto up` → tabs restore |
| **Skills** | `assets/demos/skills.gif` | `/cost` → `/bouncer` → `/qa` in a Claude session |
| **Memory** | `assets/demos/memory.gif` | Claude updates `MEMORY.md` → next session recalls preference |
| **Server bootstrap** | `assets/demos/server.gif` | `./install.sh server-remote` → systemd units → `moto doctor` |
| **Sidecar** | `assets/demos/sidecar.gif` | `ai-sidecar --provider groq --prompt "review this diff"` |

## Recording workflow

We use [asciinema](https://asciinema.org/) + [agg](https://github.com/asciinema/agg) so demos are reproducible from shell scripts.

```bash
# 1. Install tools
brew install asciinema agg

# 2. Record a demo
./docs/demos/record.sh whatsapp

# 3. Convert to GIF
agg /tmp/demo-whatsApp.cast assets/demos/whatsapp-setup.gif
```

Each feature directory can include a `demo.sh` script that automates the steps (using `expect` or just echo + sleep) so the GIF is consistent across re-records.

## Standards

- **Max 30 seconds** — cut dead time with editing
- **Terminal size**: 100×30 or smaller (readable on mobile)
- **Font**: 14pt+ monospaced
- **No secrets** — blur API keys, phone numbers, and hostnames
- **Color**: keep syntax highlighting; use a dark theme
