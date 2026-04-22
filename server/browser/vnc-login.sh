#!/bin/bash
# vnc-login.sh — expose the authenticated-chrome Xvfb display over VNC so you
# can log in to Google / GitHub / LinkedIn once, from your laptop.
#
# Usage (on server):   bash vnc-login.sh start
#                      bash vnc-login.sh stop
#
# Then, on your Mac (in another terminal):
#   ssh -L 5900:localhost:5900 ax41
#   open vnc://localhost:5900
#
# Password is stored in /root/.vnc/passwd — set with `x11vnc -storepasswd`.

set -u
DISPLAY_NUM=${DISPLAY_NUM:-98}
PORT=${PORT:-5900}
PASSFILE="/root/.vnc/passwd"

case "${1:-start}" in
  start)
    command -v x11vnc >/dev/null || { echo "install: apt-get install -y x11vnc"; exit 1; }
    if [[ ! -f "$PASSFILE" ]]; then
      echo "⚠ No VNC password set."
      echo "  Run once:  x11vnc -storepasswd"
      exit 1
    fi
    pkill -f "x11vnc.*:$DISPLAY_NUM" 2>/dev/null || true
    sleep 1
    x11vnc -display ":$DISPLAY_NUM" \
           -rfbauth "$PASSFILE" \
           -rfbport "$PORT" \
           -localhost \
           -forever \
           -shared \
           -bg \
           -o /var/log/vnc-login.log
    echo "✓ VNC listening on localhost:$PORT (attached to display :$DISPLAY_NUM)"
    echo "  From Mac:  ssh -L $PORT:localhost:$PORT ax41 &  open vnc://localhost:$PORT"
    ;;
  stop)
    pkill -f "x11vnc.*:$DISPLAY_NUM" && echo "✓ VNC stopped"
    ;;
  *)
    echo "usage: $0 [start|stop]" >&2; exit 2 ;;
esac
