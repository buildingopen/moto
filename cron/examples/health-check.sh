#!/bin/bash
# health-check.sh - Generic service health check
#
# Checks connectivity and liveness for each configured service.
# Logs pass/fail with timestamp. Optionally sends an alert on failure.
#
# Configuration via environment variables (or .env file):
#   HEALTH_CHECK_ENDPOINTS   Space-separated list of URLs to check (HTTP 2xx expected)
#   HEALTH_CHECK_HOSTS       Space-separated list of hostnames to ping
#   HEALTH_CHECK_PORTS       Space-separated "host:port" pairs to TCP-check
#   HEALTH_CHECK_PROCESSES   Space-separated process name patterns to check with pgrep
#   HEALTH_CHECK_DISK_PATH   Path to check disk usage against HEALTH_CHECK_DISK_MAX_PCT
#   HEALTH_CHECK_DISK_MAX_PCT  Alert if disk usage exceeds this percent (default: 90)
#   ALERT_WEBHOOK            URL to POST failure notifications to (optional)
#   LOG_FILE                 Log file path (default: /var/log/health-check.log)

set -euo pipefail

LOG_FILE="${LOG_FILE:-/var/log/health-check.log}"
DISK_MAX_PCT="${HEALTH_CHECK_DISK_MAX_PCT:-90}"

PASS=0
FAIL=0
FAILURES=""

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

pass() {
  local name="$1"
  log "PASS  $name"
  PASS=$((PASS + 1))
}

fail() {
  local name="$1"
  local detail="${2:-}"
  log "FAIL  $name${detail:+ ($detail)}"
  FAIL=$((FAIL + 1))
  FAILURES="${FAILURES}${FAILURES:+, }${name}"
}

# --- HTTP endpoint checks ---
if [ -n "${HEALTH_CHECK_ENDPOINTS:-}" ]; then
  for url in $HEALTH_CHECK_ENDPOINTS; do
    code=$(curl -o /dev/null -s -w "%{http_code}" --max-time 10 "$url" || echo "000")
    if [[ "$code" =~ ^2 ]]; then
      pass "HTTP $url ($code)"
    else
      fail "HTTP $url" "status $code"
    fi
  done
fi

# --- Ping checks ---
if [ -n "${HEALTH_CHECK_HOSTS:-}" ]; then
  for host in $HEALTH_CHECK_HOSTS; do
    if ping -c 1 -W 5 "$host" &>/dev/null; then
      pass "PING $host"
    else
      fail "PING $host" "no response"
    fi
  done
fi

# --- TCP port checks ---
if [ -n "${HEALTH_CHECK_PORTS:-}" ]; then
  for hostport in $HEALTH_CHECK_PORTS; do
    host="${hostport%%:*}"
    port="${hostport##*:}"
    if timeout 5 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
      pass "TCP $hostport"
    else
      fail "TCP $hostport" "connection refused"
    fi
  done
fi

# --- Process checks ---
if [ -n "${HEALTH_CHECK_PROCESSES:-}" ]; then
  for pattern in $HEALTH_CHECK_PROCESSES; do
    if pgrep -f "$pattern" &>/dev/null; then
      pass "PROC $pattern"
    else
      fail "PROC $pattern" "not running"
    fi
  done
fi

# --- Disk usage check ---
if [ -n "${HEALTH_CHECK_DISK_PATH:-}" ]; then
  pct=$(df "$HEALTH_CHECK_DISK_PATH" | awk 'NR==2 {gsub(/%/,""); print $5}')
  if [ -n "$pct" ] && [ "$pct" -ge "$DISK_MAX_PCT" ]; then
    fail "DISK $HEALTH_CHECK_DISK_PATH" "${pct}% used (max: ${DISK_MAX_PCT}%)"
  else
    pass "DISK $HEALTH_CHECK_DISK_PATH (${pct:-?}%)"
  fi
fi

# --- Summary ---
log "SUMMARY  pass=$PASS fail=$FAIL"

# --- Alert on failure ---
if [ "$FAIL" -gt 0 ] && [ -n "${ALERT_WEBHOOK:-}" ]; then
  payload="{\"text\": \"Health check failed: $FAILURES (pass=$PASS, fail=$FAIL)\"}"
  curl -s -o /dev/null -X POST -H "Content-Type: application/json" \
    -d "$payload" "$ALERT_WEBHOOK" || true
fi

exit "$FAIL"
