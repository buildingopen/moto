# Residential IP proxy

Why: many services (Google sign-in, LinkedIn, Zomato, Instagram) flag or block
data-center IPs. Routing agent traffic through a residential IP makes you look
like a normal user.

## How moto does it

`server/docker/compose.yaml` includes an optional `proxy` service (3proxy)
under the `proxy` profile. It:

- reads `PROXY_URL` from `.env`
- exposes a local forward proxy on `:8118` (HTTP) and `:1080` (SOCKS5)
- forwards all requests through your residential endpoint

Other containers (`runtime-api`, `dev-sandbox`, optionally
`authenticated-chrome`) set `HTTP_PROXY=http://moto-proxy:8118` so every
outbound request is rewritten.

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
