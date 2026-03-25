# Terminal Workflow: tmux + Claude Code

## Overview

The recommended workflow for running Claude Code on a dev server combines:

1. **tmux** as the window manager - persistent sessions, split panes, works over SSH
2. **Claude as the default shell** in tmux - every new window opens Claude immediately
3. **cq (Claude Queue)** - queue prompts to busy Claude sessions without interrupting them
4. **claude-with-queue** - wrapper that auto-creates a queue input pane when launching Claude

## tmux Configuration

The `tmux.conf` in this directory sets:

- Claude as the default command for new windows
- Mouse off (keyboard-driven)
- vi-mode key bindings
- Status bar with session name
- Large scrollback buffer (50,000 lines)
- Titles that work with iTerm2 control mode

Install:
```bash
cp ../tmux.conf ~/.tmux.conf
tmux source ~/.tmux.conf  # reload if tmux is running
```

## Session Structure

Each project gets its own tmux session:

```bash
tmux new-session -s project-name
# This opens Claude immediately (default-command = claude)
```

Navigate sessions:
```bash
tmux list-sessions        # list all
tmux attach -t project    # attach to session
tmux switch -t project    # switch from within tmux
```

## Queue Workflow (claude-with-queue)

When Claude is busy on a task, you can't type a new prompt. The queue system solves this.

**Setup:**
```bash
cp claude-with-queue.sh ~/.local/bin/claude-with-queue
cp cq.sh /usr/local/bin/cq
chmod +x ~/.local/bin/claude-with-queue /usr/local/bin/cq
```

**How it works:**

1. `claude-with-queue` launches Claude and splits a small input pane at the bottom
2. In tmux: the bottom pane runs `cq-input`, which watches the queue for this session
3. When you type in the bottom pane, it gets queued
4. When Claude finishes its current task, it picks up the next queued prompt

**Queueing from anywhere:**
```bash
cq add "Fix the login bug in auth.ts"
cq add -s project-name "Deploy to staging"
cq ls      # see all queues
cq status  # health check
```

**Queue commands:**
```
cq add [-s SESSION] "prompt"   Queue a prompt
cq ls                          List sessions + queues
cq rm NUM [-s SESSION]         Remove a queued item
cq clear [-s SESSION]          Clear a queue
cq done                        Show completed prompts
cq clean                       Remove stale sessions
```

## iTerm2 Integration (Mac)

If connecting from a Mac terminal with iTerm2, `claude-with-queue` detects iTerm2 and
creates a native horizontal split instead of a tmux split.

The `tmux.conf` sets titles compatible with iTerm2's control mode, so session names
appear in iTerm2's window/tab titles.

## Multi-Session Claude Workflow

Typical setup for working across multiple projects simultaneously:

```bash
# Session per project
tmux new-session -s frontend    # Opens Claude in frontend project dir
tmux new-session -s backend     # Opens Claude in backend project dir
tmux new-session -s infra       # Opens Claude for infra tasks

# Queue work without switching context
cq add -s frontend "Update the dashboard component"
cq add -s backend "Add rate limiting to /api/users"

# Check what's running
cq status
```

## Aliases

Useful shell aliases to add to `~/.bashrc`:

```bash
alias sessions="tmux list-sessions 2>/dev/null || echo 'No sessions'"
alias kill-session="tmux kill-session -t"

# List all sessions with their names
axlist() {
    tmux list-sessions -F "#{session_name}" 2>/dev/null | sort | while read s; do
        echo "  $s"
    done
}
```
