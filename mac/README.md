# Mac iTerm Workflow

This directory contains the Mac-side pieces for the AX41-style remote session workflow:

- Open new Claude or Codex sessions as tabs in iTerm
- Re-open all remote tmux sessions into tabs
- Keep the command surface small enough to copy into an existing setup

## What ships here

- `bin/claude-tabs` - CLI for opening, restoring, listing, and killing remote sessions
- `install.sh` - links the CLI into `~/.local/bin` and installs zsh aliases
- `shell/20-sessions.zsh` - `ax`, `axo`, `axl`, `axk`, `axc` wrappers
- `ssh/config.d/claude-remote.conf` - SSH config template with ControlMaster enabled

## Server-side requirements

On the remote box, install the matching tmux launchers from this repo:

```bash
scp server/bin/cs server/bin/cx ax41:~/
ssh ax41 'chmod +x ~/cs ~/cx'
```

Those launchers create-or-attach to tmux sessions with `tmux -CC`, which is what lets iTerm treat them as native tabs.

## Install on the Mac

If you already have an SSH alias such as `Host ax41`, you only need:

```bash
bash mac/install.sh
source ~/.zshrc
```

If you want the installer to add the SSH alias for you, pass the remote host values:

```bash
CLAUDE_REMOTE_HOSTNAME=1.2.3.4 \
CLAUDE_REMOTE_USER=root \
CLAUDE_REMOTE_SSH_HOST=ax41 \
bash mac/install.sh
source ~/.zshrc
```

Optional:

- `CLAUDE_REMOTE_SSH_KEY=~/.ssh/id_ed25519`
- `CLAUDE_REMOTE_BIN_DIR=$HOME/.local/bin`

## Usage

```bash
ax project/task      # open Claude as a new tab
axc project/task     # open Codex as a new tab
axo                  # reopen all tmux sessions as tabs
axl                  # list remote sessions
axk project/task     # kill one remote session
```

Direct CLI usage:

```bash
claude-tabs new project/task
claude-tabs newx project/task
claude-tabs up
claude-tabs ls
claude-tabs kill project/task
```

## Notes

- The helper defaults to SSH host alias `ax41`. Override with `CLAUDE_REMOTE_SSH_HOST`.
- Session names are normalized to `project/task`. Passing `project` becomes `project/main`.
- New sessions open as new tabs in the iTerm window with the most tabs, not as new windows.

If you want the full packaged remote workstation with reverse tunnel, SSHFS, health/status, and recovery, use `moto` on top of this setup.
