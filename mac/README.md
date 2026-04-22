# Mac iTerm Workflow

This directory contains the Mac-side control plane for the integrated remote workflow in this repo:

- Open new Claude, Codex, or OpenCode sessions as tabs in iTerm
- Restore all active remote tmux sessions into one iTerm window
- Manage the reverse tunnel and the Mac-side shell/SSH wiring

## What ships here

- `bin/moto` - primary CLI for opening, restoring, diagnosing, and managing remote sessions
- `bin/claude-tabs` - compatibility wrapper for the older tab-only command surface
- `install.sh` - links the CLIs into `~/.local/bin`, installs zsh aliases, SSH config, and the reverse-tunnel launchd agent
- `shell/*.zsh` - `ax`, `axc`, `axo`, `axk`, `axl`, and related helpers
- `launchd/sh.buildingopen.moto.reverse-tunnel.plist` - persistent reverse SSH tunnel
- `ssh/config.d/moto.conf` - SSH config template with ControlMaster enabled

## Install on the Mac

From the repo root:

```bash
cp .env.example .env
$EDITOR .env
./install.sh
./install.sh mac
source ~/.zshrc
```

At minimum, set:

- `MAC_USER`
- `AX41_HOST`
- `AX41_USER`
- `AX41_SSH_KEY` if you do not use `~/.ssh/id_ed25519`

Optional:

- `AX41_SSH_HOST=ax41`
- `MOTO_BIN_DIR=$HOME/.local/bin`
- `MAC_REVERSE_PORT=2222`

## Usage

Shell aliases:

```bash
ax project/task      # open Claude as a new tab
axc project/task     # open Codex as a new tab
axo                  # reopen all tmux sessions as tabs
axl                  # list remote sessions
axk project/task     # kill one remote session
```

Direct CLI usage:

```bash
moto new project/task
moto newx project/task
moto newo project/task
moto up
moto ls
moto kill project/task
moto doctor
```

Compatibility:

```bash
claude-tabs new project/task
claude-tabs newx project/task
claude-tabs up
claude-tabs ls
claude-tabs kill project/task
```

## Notes

- The CLI defaults to SSH host alias `ax41`. Override with `AX41_SSH_HOST`.
- Session names are normalized to `project/task`. Passing `project` becomes `project/main`.
- New sessions open as new tabs in the iTerm window with the most tabs, not as new windows.
- The server-side pieces are installed by [`../server/install.sh`](../server/install.sh) or `./install.sh server-remote` from the repo root.
