# SSHFS: Mount Remote Filesystems for Multi-Machine Claude Code

When running Claude Code on a dev server but needing to read files from another machine
(e.g. a Mac with local files, or a production server), SSHFS lets you mount the remote
filesystem locally. Claude Code can then use Read/Edit/Write tools transparently.

## Use Cases

- Dev server reads Mac home directory files without SSH round-trips per file
- Claude Code on server can access media files, databases, config from another machine
- Unified filesystem view across multiple machines

## Prerequisites

```bash
# Install SSHFS
apt install sshfs fuse

# Allow non-root users to mount (optional)
echo "user_allow_other" >> /etc/fuse.conf
```

## SSH Config (required)

Add the remote machine to `~/.ssh/config` with a stable alias:

```ssh-config
Host remote-mac
    HostName 192.168.1.100    # or the actual hostname/IP
    User yourusername
    Port 22
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 15
    ServerAliveCountMax 3
```

Generate and copy your key if not done:
```bash
ssh-keygen -t ed25519 -C "devserver"
ssh-copy-id remote-mac
```

## Manual Mount

```bash
# Create mount point
mkdir -p /mnt/remote-home

# Mount
sshfs -o StrictHostKeyChecking=no,reconnect,ServerAliveInterval=15,allow_other \
  remote-mac:/Users/username /mnt/remote-home

# Verify
ls /mnt/remote-home

# Unmount
fusermount -u /mnt/remote-home
```

## Automatic Mount (systemd)

1. Copy the service file:
```bash
cp sshfs-mount.service /etc/systemd/system/
```

2. Edit the placeholders:
```bash
# In the service file, replace:
#   <SSH_ALIAS>          -> your SSH config host alias (e.g. remote-mac)
#   <REMOTE_PATH>        -> path on remote machine (e.g. /Users/username)
#   <LOCAL_MOUNT_POINT>  -> local path to mount at (e.g. /mnt/remote-home)
```

3. Create the mount point and enable:
```bash
mkdir -p /mnt/remote-home
systemctl daemon-reload
systemctl enable --now sshfs-mount
```

## Mount Health Check

SSHFS connections go stale silently. The mount-check scripts detect and remount:

```bash
cp check-mounts.sh /usr/local/bin/check-remote-mounts
chmod +x /usr/local/bin/check-remote-mounts

# Install the timer for automatic recovery every 30 seconds
cp ../systemd/mount-check.service /etc/systemd/system/
cp ../systemd/mount-check.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now mount-check.timer
```

## Troubleshooting

**"Transport endpoint is not connected"**: Mount is stale. Run:
```bash
fusermount -u /mnt/remote-home
systemctl restart sshfs-mount
```

**Slow file operations**: Increase the kernel cache:
```
-o kernel_cache,cache_timeout=60,attr_timeout=60
```

**Permission errors**: Check `allow_other` in `/etc/fuse.conf` and the service runs as root.

**Reconnect not working**: SSHFS `reconnect` option handles network interruptions but not
full SSH session drops. The mount-check timer handles those.
