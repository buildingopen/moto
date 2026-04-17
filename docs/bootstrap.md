# Bootstrap a fresh Linux box

For a brand-new Hetzner / Vultr / DigitalOcean / OVH box. Tested on Debian 12
and Ubuntu 22.04+.

## 0. Before you start

- Grab root SSH access to the fresh box.
- Your Mac needs:
  - Homebrew
  - iTerm2 (not the built-in Terminal — we rely on iTerm's tmux `-CC` integration)
  - `ssh` with ControlMaster
  - Remote Login (sshd) enabled: **System Settings → General → Sharing → Remote Login**

## 1. Clone on your Mac

```bash
git clone https://github.com/buildingopen/moto.git ~/moto
cd ~/moto
cp .env.example .env
$EDITOR .env
```

Fill in at minimum:
- `MAC_USER`
- `AX41_HOST` (the new box's public IP)
- `AX41_USER=root`
- `AX41_SSH_KEY=~/.ssh/id_ed25519` (or whatever key has root access to the new box)

## 2. Install on the Mac

```bash
./install.sh mac
```

This adds `~/.local/bin/moto`, sources shell functions into `~/.zshrc`, adds a
`Host ax41` block to `~/.ssh/config`, and loads the launchd agent for the
reverse tunnel.

## 3. Install on the server

The easy path (recommended):

```bash
./install.sh server-remote
```

This `rsync`s the repo to `$AX41_HOST:/opt/moto` and runs `server/install.sh`
remotely as root.

The first-time install will:
- Install `tmux`, `socat`, `sshfs`, `xvfb`, `earlyoom`, Docker, Google Chrome
- Drop scripts into `/root/` and `/usr/local/bin/`
- Write the systemd units and enable them
- Mount the Mac's `~/.claude` at `/mnt/mac-claude`
- Generate an SSH key on the server **if missing**, and print the public key

If the installer printed a new public key, add it to your Mac's
`~/.ssh/authorized_keys`:

```bash
# On the Mac:
echo 'ssh-ed25519 AAAA... moto-server-hostname' >> ~/.ssh/authorized_keys
```

## 4. Kick the reverse tunnel

```bash
# On the Mac:
launchctl kickstart -k gui/$UID/sh.buildingopen.moto.reverse-tunnel
```

Verify from the server:

```bash
ssh ax41 'ssh mac hostname'
# → should print your Mac's hostname
```

## 5. Run `moto doctor`

```bash
# On the Mac:
moto doctor
```

Every check should be green. If `reverse tunnel` is down, the SSH server on
your Mac is likely not running, or your `~/.ssh/authorized_keys` doesn't have
the server's key.

## 6. Create your first session

```bash
moto new hello/world
# → iTerm opens a new tab with Claude Code running on the server.
```

From now on, `moto up` will always restore your full set of sessions into one
iTerm window.

## 7. (Optional) Browser login

If you want agents to use Google / LinkedIn / GitHub as a logged-in user, see
[browser-login.md](browser-login.md).

## 8. (Optional) Residential proxy

If you want outbound agent traffic on a residential IP, see
[proxy.md](proxy.md).
