# Residential IP proxy

Why: many services (Google sign-in, LinkedIn, Zomato, Instagram) flag or block
data-center IPs. Routing agent traffic through a residential IP makes you look
like a normal user.

## How moto does it

`server/docker/compose.yaml` includes an optional `proxy` service (tinyproxy,
built locally from `server/docker/proxy/`) under the `proxy` profile. It:

- reads `PROXY_URL` from `.env`
- exposes an HTTP forward proxy on `127.0.0.1:8118` (loopback only)
- forwards all requests through your residential endpoint via tinyproxy's
  `upstream http|https|socks5 …` directive, generated at container start
  by `server/docker/proxy/entrypoint.sh`

Other containers (`runtime-api`, `dev-sandbox`, optionally
`authenticated-chrome`) set `HTTP_PROXY=http://moto-proxy:8118` so every
outbound request is rewritten. Chrome uses its own `--proxy-server=$PROXY_URL`
flag and bypasses this sidecar — see the Chrome-specific note below.

**No SOCKS5 listener in v0.1.** Tinyproxy only offers HTTP/HTTPS on the
inbound side (it does accept a SOCKS5 *upstream*). Most agent clients speak
HTTP proxy anyway; run a separate `gost` / `microsocks` container if you
genuinely need a local SOCKS5 listener.

## Enable

```bash
# .env:
PROXY_URL=http://USER:PASS@gate.smartproxy.com:7000
PROXY_APPLIES_TO=authenticated-chrome,runtime-api
```

Then:

```bash
ssh ax41 'cd /opt/moto/server/docker && docker compose --profile proxy up -d'
```

Verify:

```bash
ssh ax41 'curl -x http://127.0.0.1:8118 https://ifconfig.me'
# → prints a residential IP, not the server IP
```

## Providers at a glance

| Provider    | Strength                           | Format                                                               |
|-------------|------------------------------------|----------------------------------------------------------------------|
| Bright Data | Largest pool, strict KYC           | `http://brd-customer-hl_XXX-zone-residential:PASS@brd.superproxy.io:22225` |
| Smartproxy  | Good value, easy signup            | `http://spXXXXX:PASS@gate.smartproxy.com:7000`                       |
| Oxylabs     | Solid scraping-focused             | `http://customer-USER-cc-us:PASS@pr.oxylabs.io:7777`                 |
| IPRoyal     | Cheap, good for experiments        | `http://USER:PASS@geo.iproyal.com:12321`                             |
| SOAX        | Flexible country/ASN targeting     | `http://package-XXX-country-us:PASS@proxy.soax.com:9000`             |

## Chrome-specific note

Chrome's `--proxy-server=` flag is set by `chrome-launcher.sh` when both
`PROXY_URL` is non-empty and `authenticated-chrome` is in
`PROXY_APPLIES_TO`. After enabling/disabling, `systemctl restart
authenticated-chrome` for it to take effect.

## Disabling

Set `PROXY_URL=` (empty) in `.env` and:

```bash
ssh ax41 'cd /opt/moto/server/docker && docker compose stop proxy && systemctl restart authenticated-chrome'
```

Traffic will return to using the server's native IP.

---

## Related: Cloudflare tunnel

The `cloudflared` service in `compose.yaml` is under the `tunnel` profile and
is **not** started by default. To use it:

```bash
# 1. set CLOUDFLARE_TUNNEL_TOKEN in .env (non-empty!)
# 2. activate the profile:
cd /opt/moto/server/docker
docker compose --profile tunnel up -d cloudflared
```

If `CLOUDFLARE_TUNNEL_TOKEN` is empty when the profile is activated, the
container crash-loops — leave the profile off unless you've set the token.
