# Browser login (one-time setup)

`authenticated-chrome.service` runs a persistent Chrome instance under
`Xvfb :98`. Its profile (`/root/.config/authenticated-chrome`) keeps cookies,
2FA tokens, passkeys, etc. Once logged in, your agents can drive it over CDP
without ever seeing credentials.

## 1. Start the VNC bridge on the server

```bash
ssh ax41
apt-get install -y x11vnc
x11vnc -storepasswd   # set a password, press enter
bash /root/authenticated-browser/vnc-login.sh start
```

The script binds VNC to `localhost:5900` only — **not** exposed to the internet.

## 2. Tunnel VNC to your Mac

```bash
# On the Mac:
ssh -L 5900:localhost:5900 ax41
# leave this open, then in another terminal:
open vnc://localhost:5900
```

You should see the Xvfb display with Chrome running.

## 3. Log in

Navigate to the sites you need (Google, GitHub, LinkedIn, etc.) and sign in.
Passkeys and 2FA tokens are stored in the profile directory, so you won't be
asked again on the next launch.

## 4. Snapshot the profile (optional)

```bash
ssh ax41 'bash /root/authenticated-browser/backup-profile.sh'
```

This creates `/root/authenticated-browser/profile-backups/chrome-profile-YYYYMMDD-HHMMSS.tgz`.
Keep a recent snapshot in case a site invalidates the profile.

## 5. Stop VNC

```bash
ssh ax41 'bash /root/authenticated-browser/vnc-login.sh stop'
```

## 6. Use it from agents

From any Docker container on the moto network, Chrome is reachable at:

```
ws://172.17.0.1:9222/devtools/browser
```

Puppeteer:

```js
import puppeteer from 'puppeteer-core';
const browser = await puppeteer.connect({
  browserURL: 'http://172.17.0.1:9222',
});
```

Playwright:

```js
const browser = await chromium.connectOverCDP('http://172.17.0.1:9222');
```

From the host (not a container), use `http://127.0.0.1:9222`.

## Troubleshooting

- **CDP unreachable**: `systemctl status authenticated-chrome chrome-bridge-keeper cdp-docker-proxy`
- **Chrome keeps dying**: `journalctl -u authenticated-chrome -n 50`
- **Session invalidated by Google**: restore from a profile-backup tarball; for repeated bouncing, log in from a residential IP (see [proxy.md](proxy.md)).
