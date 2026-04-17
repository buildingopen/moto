# moto — residential proxy sidecar

Routes agent traffic through your chosen residential IP provider.

## How it works

1. You set `PROXY_URL` in `.env` — any `http://`, `https://`, or `socks5://` URL.
2. `docker compose --profile proxy up -d proxy` starts a 3proxy container.
3. The container exposes:
   - **HTTP forward proxy** on `127.0.0.1:8118`
   - **SOCKS5** on `127.0.0.1:1080`
4. Agent containers set `HTTP_PROXY=http://moto-proxy:8118` — all their outbound requests are rewritten through your residential endpoint.

## Provider snippets

| Provider   | `PROXY_URL` example |
|------------|---------------------|
| Bright Data| `http://brd-customer-hl_XXXX-zone-residential:PASS@brd.superproxy.io:22225` |
| Smartproxy | `http://spXXXXX:PASS@gate.smartproxy.com:7000` |
| Oxylabs    | `http://customer-USER-cc-us:PASS@pr.oxylabs.io:7777` |
| IPRoyal    | `http://USER:PASS@geo.iproyal.com:12321` |
| SOAX       | `http://package-XXXX-country-us:PASS@proxy.soax.com:9000` |

## Zero-proxy mode

If `PROXY_URL` is empty, don't start this container — `docker compose up` without
`--profile proxy` skips it, and agents will use the server's native IP.

## Verify

```bash
# From the server:
curl -x http://127.0.0.1:8118 https://ifconfig.me
# ↑ should print a residential IP, not your server IP
```
