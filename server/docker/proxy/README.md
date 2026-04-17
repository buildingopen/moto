# moto — residential proxy sidecar

Routes agent traffic through your chosen residential IP provider via an HTTP forward proxy.

## How it works

1. You set `PROXY_URL` in `.env` — any `http://`, `https://`, or `socks5://` URL.
2. `docker compose --profile proxy up -d proxy` builds and starts a tinyproxy container.
3. `entrypoint.sh` parses `PROXY_URL` and substitutes a matching `upstream http|https|socks5 …` directive into tinyproxy's config at boot.
4. The container exposes an **HTTP forward proxy** on `127.0.0.1:8118` (loopback only, never on the internet).
5. Agent containers set `HTTP_PROXY=http://moto-proxy:8118` — every outbound request is rewritten through your residential endpoint. Chrome uses `--proxy-server=$PROXY_URL` directly (bypassing this sidecar).

## Verify

```bash
ssh ax41 'docker compose -f /opt/moto/server/docker/compose.yaml --profile proxy up -d'
ssh ax41 'curl -x http://127.0.0.1:8118 https://ifconfig.me'
# → prints a residential IP, not your server IP
```

## Provider snippets

| Provider   | `PROXY_URL` example |
|------------|---------------------|
| Bright Data| `http://brd-customer-hl_XXXX-zone-residential:PASS@brd.superproxy.io:22225` |
| Smartproxy | `http://spXXXXX:PASS@gate.smartproxy.com:7000` |
| Oxylabs    | `http://customer-USER-cc-us:PASS@pr.oxylabs.io:7777` |
| IPRoyal    | `http://USER:PASS@geo.iproyal.com:12321` |
| SOAX       | `http://package-XXXX-country-us:PASS@proxy.soax.com:9000` |

## Zero-proxy mode

If `PROXY_URL` is empty or you don't pass `--profile proxy` to `docker compose`, the container is simply never started and agents use the server's native IP.

## Why tinyproxy (not 3proxy or Squid)

- **3proxy** — our first attempt. Its `parent` directive was silently ignored across `0.9.4`, `0.9.5`, and `latest` (the child went direct even though the config parsed cleanly). Switched after burning meaningful debug time.
- **Squid** — would work, but the config is ~20× larger and 8MB binary vs 40KB for tinyproxy.
- **tinyproxy** — `upstream http USER:PASS@host:port` is one line, well-documented, and verified end-to-end by `server/test/proxy-smoke.sh`.

## No SOCKS5 listener in v0.1

Tinyproxy only offers HTTP/HTTPS proxy on the inbound side. It accepts a SOCKS5 **upstream** (outbound), so if your residential provider is SOCKS5 the chain still works — it just means moto clients need to speak HTTP proxy, not SOCKS5, to reach the sidecar. Chrome, curl, node `https-proxy-agent`, Python `requests`, and every agent CLI in moto do this natively.

If you genuinely need a local SOCKS5 listener, run `gost` or `microsocks` as a sibling container; it's out of scope for v0.1.
