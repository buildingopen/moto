#!/bin/bash
# cq - Claude Queue management
#
# A filesystem-based queue for sending prompts to Claude sessions.
# Works with claude-with-queue to dispatch tasks to busy Claude instances.
#
# Install:
#   cp cq.sh /usr/local/bin/cq
#   chmod +x /usr/local/bin/cq
#
# Usage:
#   cq add "do this thing"              Queue to any idle session
#   cq add -s my-session "do thing"     Queue to a specific session
#   cq ls                               List all sessions and queues
#   cq status                           Health overview
#   cq rm 001 [-s session]              Remove a queued item
#   cq clear [-s session]               Clear all queued items
#   cq done                             Show recently completed prompts
#   cq clean                            Remove stale session registrations

BASE_DIR="$HOME/.claude-queue"
SESSIONS_DIR="$BASE_DIR/sessions"
DONE_DIR="$BASE_DIR/done"
LOG="$BASE_DIR/queue.log"
mkdir -p "$SESSIONS_DIR" "$DONE_DIR"

session_display() {
    local f="$1"
    local name=$(grep "^name=" "$f" 2>/dev/null | cut -d= -f2)
    local cwd=$(grep "^cwd=" "$f" 2>/dev/null | cut -d= -f2)
    local base=$(basename "$cwd" 2>/dev/null)
    if [ -n "$name" ] && [ "$name" != "$(basename $HOME)" ] && [ "$name" != "unknown" ]; then
        echo "$name"
    elif [ -n "$base" ] && [ "$cwd" != "$HOME" ]; then
        echo "$base"
    else
        echo "$(basename "$f")"
    fi
}

session_alive() {
    local f="$1"
    local pid=$(grep "^pid=" "$f" | cut -d= -f2)
    [ -z "$pid" ] && return 1
    kill -0 "$pid" 2>/dev/null || return 1
    return 0
}

resolve_session() {
    local explicit="$1"
    if [ -n "$explicit" ]; then echo "$explicit"; return; fi
    local active=()
    for f in "$SESSIONS_DIR"/*; do
        [ -f "$f" ] || continue
        session_alive "$f" || continue
        active+=($(basename "$f"))
    done
    if [ ${#active[@]} -eq 1 ]; then echo "${active[0]}"
    elif [ ${#active[@]} -eq 0 ]; then echo ""
    else echo "AMBIGUOUS"; fi
}

list_sessions() {
    local found=0
    for f in "$SESSIONS_DIR"/*; do
        [ -f "$f" ] || continue
        session_alive "$f" || continue
        local key=$(basename "$f")
        local name=$(session_display "$f")
        local qdir="$BASE_DIR/pending/$key"
        local count=$(ls -1 "$qdir"/*.md 2>/dev/null | wc -l | tr -d " ")
        printf "  %-12s %-25s [%s pending]\n" "$key" "$name" "$count"
        found=1
    done
    local gcount=$(ls -1 "$BASE_DIR/pending"/*.md 2>/dev/null | wc -l | tr -d " ")
    [ "$gcount" != "0" ] && printf "  %-12s %-25s [%s pending]\n" "(global)" "any-idle" "$gcount"
    [ $found -eq 0 ] && [ "$gcount" = "0" ] && echo "  (no active sessions)"
    return 0
}

case "${1:-ls}" in
    add|a)
        shift
        session_key=""
        if [ "$1" = "--session" ] || [ "$1" = "-s" ]; then session_key="$2"; shift 2; fi
        [ -z "$1" ] && { echo "Usage: cq add [-s session] \"prompt\""; exit 1; }
        if [ -n "$session_key" ]; then
            QUEUE_DIR="$BASE_DIR/pending/$session_key"
        else
            QUEUE_DIR="$BASE_DIR/pending"
        fi
        mkdir -p "$QUEUE_DIR"
        last=$(ls -1 "$QUEUE_DIR" 2>/dev/null | grep -oE "^[0-9]+" | sort -n | tail -1)
        last=${last:-0}
        next=$(printf "%03d" $((last + 1)))
        slug=$(echo "$*" | tr "[:upper:]" "[:lower:]" | sed "s/[^a-z0-9]/-/g" | head -c 40 | sed "s/-$//;s/^-//;s/--*/-/g")
        file="$QUEUE_DIR/${next}-${slug}.md"
        printf "%s" "$*" > "$file"
        count=$(ls -1 "$QUEUE_DIR"/*.md 2>/dev/null | wc -l | tr -d " ")
        target="${session_key:-global}"
        echo "[$next] queued to $target ($count pending)"
        ;;

    ls|list)
        echo "Sessions:"
        list_sessions
        echo ""
        has_queued=0
        for f in "$SESSIONS_DIR"/*; do
            [ -f "$f" ] || continue
            session_alive "$f" || continue
            local_key=$(basename "$f")
            qdir="$BASE_DIR/pending/$local_key"
            files=$(ls -1 "$qdir"/*.md 2>/dev/null)
            if [ -n "$files" ]; then
                name=$(session_display "$f")
                echo "Queue for $name ($local_key):"
                echo "$files" | while read qf; do
                    echo "  $(basename "$qf" .md): $(head -c 80 "$qf")"
                done
                has_queued=1
            fi
        done
        gfiles=$(ls -1 "$BASE_DIR/pending"/*.md 2>/dev/null)
        if [ -n "$gfiles" ]; then
            echo "Global queue:"
            echo "$gfiles" | while read qf; do
                echo "  $(basename "$qf" .md): $(head -c 80 "$qf")"
            done
            has_queued=1
        fi
        [ $has_queued -eq 0 ] && echo "All queues empty."
        ;;

    sessions) list_sessions ;;

    status)
        echo "Claude Queue Status"
        echo "==================="
        echo ""
        alive=0; dead=0
        for f in "$SESSIONS_DIR"/*; do
            [ -f "$f" ] || continue
            if session_alive "$f"; then alive=$((alive+1)); else dead=$((dead+1)); fi
        done
        echo "Sessions: $alive active, $dead stale"
        [ $alive -gt 0 ] && list_sessions
        echo ""
        total=0
        for f in "$SESSIONS_DIR"/*; do
            [ -f "$f" ] || continue
            session_alive "$f" || continue
            k=$(basename "$f")
            c=$(ls -1 "$BASE_DIR/pending/$k"/*.md 2>/dev/null | wc -l | tr -d " ")
            total=$((total + c))
        done
        gc=$(ls -1 "$BASE_DIR/pending"/*.md 2>/dev/null | wc -l | tr -d " ")
        total=$((total + gc))
        echo "Pending prompts: $total"
        last_log=$(tail -1 "$LOG" 2>/dev/null)
        [ -n "$last_log" ] && echo "Last log: $last_log"
        [ $dead -gt 0 ] && echo "" && echo "Run cq clean to remove $dead stale sessions"
        ;;

    rm)
        shift
        [ -z "$1" ] && { echo "Usage: cq rm <number> [-s session]"; exit 1; }
        num="$1"; shift
        session_key=""
        if [ "$1" = "--session" ] || [ "$1" = "-s" ]; then session_key="$2"; fi
        resolved=$(resolve_session "$session_key")
        if [ -z "$resolved" ] || [ "$resolved" = "AMBIGUOUS" ]; then
            echo "Specify session with -s:"; list_sessions; exit 1
        fi
        QUEUE_DIR="$BASE_DIR/pending/$resolved"
        found=$(ls -1 "$QUEUE_DIR"/${num}-*.md 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            rm "$found"
            echo "Removed: $(basename "$found") from $resolved"
        else
            echo "Not found: $num in $resolved"
        fi
        ;;

    clear)
        shift
        session_key=""
        if [ "$1" = "-s" ]; then session_key="$2"; shift 2; fi
        if [ -n "$session_key" ]; then
            QUEUE_DIR="$BASE_DIR/pending/$session_key"
        else
            QUEUE_DIR="$BASE_DIR/pending"
        fi
        count=$(ls -1 "$QUEUE_DIR"/*.md 2>/dev/null | wc -l | tr -d " ")
        mv "$QUEUE_DIR"/*.md "$DONE_DIR/" 2>/dev/null
        echo "Cleared $count items"
        ;;

    done)
        ls -1t "$DONE_DIR"/*.md 2>/dev/null | head -10 | while read f; do
            echo "  $(basename "$f" .md)"
        done
        [ -z "$(ls -1t "$DONE_DIR"/*.md 2>/dev/null | head -1)" ] && echo "  (none)"
        ;;

    log) tail -20 "$LOG" 2>/dev/null || echo "No log yet" ;;

    clean)
        cleaned=0
        for f in "$SESSIONS_DIR"/*; do
            [ -f "$f" ] || continue
            if ! session_alive "$f"; then
                echo "Removing stale: $(basename "$f") ($(session_display "$f"))"
                rm "$f"
                cleaned=$((cleaned+1))
            fi
        done
        [ $cleaned -eq 0 ] && echo "No stale sessions" || echo "Cleaned $cleaned stale sessions"
        ;;

    *)
        echo "cq - Claude Queue"
        echo ""
        echo "  cq add [-s KEY] \"prompt\"  Queue a prompt"
        echo "  cq ls                     List sessions + queues"
        echo "  cq sessions               List active sessions"
        echo "  cq status                 Health check"
        echo "  cq rm NUM [-s KEY]        Remove item"
        echo "  cq clear [-s KEY]         Clear queue"
        echo "  cq done                   Show completed"
        echo "  cq log                    Show log"
        echo "  cq clean                  Remove stale sessions"
        ;;
esac
