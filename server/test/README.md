# moto — container-based tests

Two isolated tests that run on the server **without touching the host**.

## Install test — `run-container-test.sh`

Runs `server/install.sh` end-to-end inside a throwaway `debian:12` container. Proves that a cold install actually works on a clean box.

```bash
cd moto
HOST=ax41 ./server/test/run-container-test.sh
```

Takes ~60–90s on first run (initial `debian:12` + Chrome pulls), ~30s on subsequent runs.

## Proxy smoke test — `proxy-smoke.sh`

Builds `server/docker/proxy/` (tinyproxy) and proves:

1. `PROXY_URL` parser handles `http://`, `https://`, `socks5://`, with and without auth (5 cases).
2. Empty `PROXY_URL` → listener comes up, direct egress fetches example.com.
3. Chained `PROXY_URL` pointing at a second tinyproxy → **the parent's own logs confirm the forwarded request**. This is strict proof that the upstream directive is actually engaged, not just that curl got a 200.

```bash
cd moto
HOST=ax41 ./server/test/proxy-smoke.sh
```

Takes ~15s. Latest run:

```
  ✓ parse [http://u:p@10.254.254.254:8080] → …
  ✓ parse [http://10.254.254.254:8080] → …
  ✓ parse [https://a:b@10.254.254.254:443] → …
  ✓ parse [socks5://u:p@10.254.254.254:1080] → …
  ✓ parse [<empty>] → 'PROXY_URL empty'
  ✓ direct egress: PROXY_URL empty → example.com fetched through sidecar
  ✓ chained upstream: parent saw the forwarded request
  ✓ ALL PROXY SMOKE CHECKS PASSED
```

## What it covers

The staged install uses two new install.sh flags so a test can run without systemd-in-docker or docker-in-docker:

- `SKIP_SYSTEMD_ENABLE=1` — installs unit files, skips `systemctl enable/start`
- `SKIP_DOCKER_COMPOSE=1` — skips `docker compose up`
- (`SKIP_OS_INSTALL=1` also exists for re-running on an already-installed container)

Verification phases:

| phase | checks                                                                           |
|-------|----------------------------------------------------------------------------------|
| 1     | Full `server/install.sh` run on vanilla debian:12 (apt, Chrome, Docker CE all succeed) |
| 2     | All 15+ scripts installed to the right paths with correct perms                  |
| 3     | All 11 systemd unit files dropped in `/etc/systemd/system/`                      |
| 4     | `systemd-analyze verify` passes on every `.service` / `.timer`                   |
| 5     | Every installed script passes `bash -n`                                          |
| 6     | `server/docker/compose.yaml` validates via `docker compose config`               |

## Latest run (v0.1.0)

```
━━━ summary ━━━
  pass: 50
  fail: 0
✓ moto container test PASSED
```

Tested on: Hetzner AX41 (Ubuntu 24.04 host, Debian 12 container), Docker 28.2.2, x86_64.

## What it does NOT cover

- **Live systemd** — `systemctl enable/start` is not exercised because the test container doesn't run PID 1 as systemd. Unit syntax is validated instead.
- **`docker compose up`** — nested Docker isn't meaningfully different from the host's Docker, and we don't want to test-start services that bind real ports. Compose config is validated.
- **Mac reverse tunnel / SSHFS mount** — requires an actual Mac online.
- **Chrome + Xvfb actually rendering** — requires a live X server, out of scope for a static install test.

For those, `moto doctor` (run from your Mac, after `moto up`) is the runtime health check.

## Running standalone (inside an already-started container)

```bash
docker run --rm -it \
  -v "$(pwd)":/opt/moto \
  -w /opt/moto \
  debian:12 \
  bash server/test/in-container.sh
```
