#!/bin/sh
# moto — tinyproxy entrypoint.
#
# Parses $PROXY_URL into a tinyproxy `upstream` directive, substitutes it
# into the config template, and execs tinyproxy. Works with BusyBox sh
# (the tinyproxy base image is Alpine).
#
# Supported schemes: http / https / socks5
# If PROXY_URL is empty the upstream line is omitted → direct egress
# (useful for testing; in production leave the sidecar off instead).
set -eu

TEMPLATE=/etc/tinyproxy/moto.conf.tmpl
RENDERED=/tmp/tinyproxy.conf

upstream_line=""
if [ -n "${PROXY_URL:-}" ]; then
  url="$PROXY_URL"

  scheme="${url%%://*}"
  rest="${url#*://}"
  if [ "$scheme" = "$url" ] || [ "$rest" = "$url" ]; then
    echo "proxy entrypoint: PROXY_URL missing scheme (expected http://, https://, or socks5://)" >&2
    exit 1
  fi

  case "$scheme" in
    http|https|socks5) ;;
    socks5h) scheme="socks5" ;;
    *)
      echo "proxy entrypoint: unsupported scheme '$scheme' (use http/https/socks5)" >&2
      exit 1
      ;;
  esac

  # Split into userinfo / hostport
  case "$rest" in
    *@*)
      userinfo="${rest%%@*}"
      hostport="${rest##*@}"
      ;;
    *)
      userinfo=""
      hostport="$rest"
      ;;
  esac

  case "$hostport" in
    *:*) host="${hostport%%:*}"; port="${hostport##*:}" ;;
    *)   host="$hostport"; port="" ;;
  esac

  if [ -z "$host" ] || [ -z "$port" ]; then
    echo "proxy entrypoint: PROXY_URL must include host:port (got host='$host' port='$port')" >&2
    exit 1
  fi

  # tinyproxy syntax: `upstream <type> [USER:PASS@]host:port`
  if [ -n "$userinfo" ]; then
    upstream_line="upstream $scheme ${userinfo}@${host}:${port}"
    # Log with the password masked.
    user_masked="${userinfo%%:*}"
    echo "proxy: upstream $scheme://${host}:${port} (user: ${user_masked})"
  else
    upstream_line="upstream $scheme ${host}:${port}"
    echo "proxy: upstream $scheme://${host}:${port} (no auth)"
  fi
else
  echo "proxy: PROXY_URL empty — no upstream, direct egress"
fi

awk -v repl="$upstream_line" '
  {
    out = $0
    i = index(out, "__UPSTREAM__")
    if (i > 0) {
      out = substr(out, 1, i-1) repl substr(out, i + length("__UPSTREAM__"))
    }
    print out
  }
' "$TEMPLATE" > "$RENDERED"

BIN=""
for candidate in /usr/sbin/tinyproxy /usr/bin/tinyproxy /usr/local/bin/tinyproxy; do
  [ -x "$candidate" ] && BIN="$candidate" && break
done
[ -z "$BIN" ] && BIN="$(command -v tinyproxy 2>/dev/null || true)"
if [ -z "$BIN" ]; then
  echo "proxy entrypoint: tinyproxy binary not found in image" >&2
  exit 1
fi

# -d = don't daemonize (stay in foreground so Docker sees logs + signals)
# -c = path to config file
exec "$BIN" -d -c "$RENDERED"
