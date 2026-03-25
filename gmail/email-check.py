#!/usr/bin/env python3
"""
email-check.py - Multi-account IMAP email checker

Reads accounts from .env (IMAP_LABEL_N, IMAP_USER_N, IMAP_PASS_N, IMAP_SERVER_N).
Lists unread emails with sender, subject, and date.
Uses BODY.PEEK[] to preserve read/unread status.

Usage:
    python3 email-check.py
    python3 email-check.py --account personal
    python3 email-check.py --search "invoice"
    python3 email-check.py --from "billing@stripe.com"
    python3 email-check.py --account work --search "deploy" --limit 20
"""

import argparse
import imaplib
import email
import os
import sys
from email.header import decode_header
from pathlib import Path
from datetime import datetime


# ---------------------------------------------------------------------------
# .env loader (minimal, no external dependency)
# ---------------------------------------------------------------------------

def load_dotenv(path: str = ".env") -> None:
    """Load key=value pairs from a .env file into os.environ."""
    env_path = Path(path)
    if not env_path.exists():
        return
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value


# ---------------------------------------------------------------------------
# Account discovery
# ---------------------------------------------------------------------------

def discover_accounts() -> list[dict]:
    """Read all IMAP_LABEL_N / IMAP_USER_N / IMAP_PASS_N / IMAP_SERVER_N groups."""
    accounts = []
    n = 1
    while True:
        label = os.environ.get(f"IMAP_LABEL_{n}")
        user = os.environ.get(f"IMAP_USER_{n}")
        password = os.environ.get(f"IMAP_PASS_{n}")
        server = os.environ.get(f"IMAP_SERVER_{n}", "imap.gmail.com")
        if not label or not user or not password:
            break
        accounts.append({"label": label, "user": user, "password": password, "server": server})
        n += 1
    return accounts


# ---------------------------------------------------------------------------
# Header decoding
# ---------------------------------------------------------------------------

def decode_str(value: str | None) -> str:
    """Decode an RFC 2047-encoded header value to a plain string."""
    if not value:
        return ""
    parts = decode_header(value)
    result = []
    for part, charset in parts:
        if isinstance(part, bytes):
            try:
                result.append(part.decode(charset or "utf-8", errors="replace"))
            except (LookupError, UnicodeDecodeError):
                result.append(part.decode("utf-8", errors="replace"))
        else:
            result.append(part)
    return "".join(result)


# ---------------------------------------------------------------------------
# IMAP helpers
# ---------------------------------------------------------------------------

def connect(account: dict) -> imaplib.IMAP4_SSL:
    """Open an IMAP SSL connection and log in."""
    imap = imaplib.IMAP4_SSL(account["server"], 993)
    imap.login(account["user"], account["password"])
    return imap


def search_unseen(imap: imaplib.IMAP4_SSL, keyword: str | None, sender: str | None) -> list[bytes]:
    """Return message UIDs matching the search criteria."""
    criteria_parts = ["UNSEEN"]
    if keyword:
        # IMAP SEARCH TEXT searches subject + body
        safe_kw = keyword.replace('"', '\\"')
        criteria_parts.append(f'TEXT "{safe_kw}"')
    if sender:
        safe_from = sender.replace('"', '\\"')
        criteria_parts.append(f'FROM "{safe_from}"')
    criteria = " ".join(criteria_parts)
    status, data = imap.search(None, criteria)
    if status != "OK" or not data[0]:
        return []
    return data[0].split()


def fetch_headers(imap: imaplib.IMAP4_SSL, uid: bytes) -> dict | None:
    """
    Fetch message headers using BODY.PEEK to avoid marking as read.
    Returns a dict with keys: uid, subject, from, date, snippet.
    """
    # BODY.PEEK[HEADER.FIELDS ...] fetches only specific headers without marking read
    status, data = imap.fetch(uid, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
    if status != "OK" or not data or not data[0]:
        return None

    raw_headers = data[0][1] if isinstance(data[0], tuple) else data[0]
    if not isinstance(raw_headers, bytes):
        return None

    msg = email.message_from_bytes(raw_headers)
    return {
        "uid": uid.decode(),
        "subject": decode_str(msg.get("Subject")) or "(no subject)",
        "from": decode_str(msg.get("From")) or "(unknown sender)",
        "date": decode_str(msg.get("Date")) or "",
    }


def fetch_body_snippet(imap: imaplib.IMAP4_SSL, uid: bytes, max_chars: int = 200) -> str:
    """
    Fetch plain-text body snippet using BODY.PEEK (preserves unread status).
    Returns up to max_chars characters of the first plain-text part.
    """
    status, data = imap.fetch(uid, "(BODY.PEEK[])")
    if status != "OK" or not data or not data[0]:
        return ""

    raw = data[0][1] if isinstance(data[0], tuple) else b""
    if not isinstance(raw, bytes):
        return ""

    msg = email.message_from_bytes(raw)

    def get_text(msg_part):
        if msg_part.is_multipart():
            for part in msg_part.walk():
                text = get_text(part)
                if text:
                    return text
        else:
            if msg_part.get_content_type() == "text/plain":
                try:
                    charset = msg_part.get_content_charset() or "utf-8"
                    payload = msg_part.get_payload(decode=True)
                    if payload:
                        return payload.decode(charset, errors="replace")
                except Exception:
                    pass
        return ""

    text = get_text(msg).strip()
    # Collapse whitespace
    text = " ".join(text.split())
    return text[:max_chars] + ("..." if len(text) > max_chars else "")


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

DIVIDER = "-" * 72


def print_account_header(label: str, user: str, count: int) -> None:
    print(f"\n{'=' * 72}")
    print(f"  Account: {label} ({user})")
    print(f"  Unread:  {count}")
    print(f"{'=' * 72}")


def print_message(info: dict, snippet: str = "") -> None:
    print(DIVIDER)
    print(f"  UID:     {info['uid']}")
    print(f"  From:    {info['from']}")
    print(f"  Subject: {info['subject']}")
    print(f"  Date:    {info['date']}")
    if snippet:
        print(f"  Snippet: {snippet}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Multi-account IMAP email checker (preserves read/unread status)"
    )
    p.add_argument(
        "--account", "-a",
        metavar="LABEL",
        help="Check only this account label (e.g. personal, work)",
    )
    p.add_argument(
        "--search", "-s",
        metavar="KEYWORD",
        help="Filter by keyword in subject or body",
    )
    p.add_argument(
        "--from", "-f",
        dest="sender",
        metavar="ADDRESS",
        help="Filter by sender email address",
    )
    p.add_argument(
        "--snippet",
        action="store_true",
        help="Fetch and show a body snippet (slower, but uses BODY.PEEK)",
    )
    p.add_argument(
        "--limit", "-l",
        type=int,
        default=50,
        metavar="N",
        help="Max messages per account (default: 50)",
    )
    p.add_argument(
        "--env",
        default=".env",
        metavar="FILE",
        help="Path to .env file (default: .env)",
    )
    return p.parse_args()


def check_account(account: dict, args: argparse.Namespace) -> int:
    """Connect, search, print results. Returns number of messages shown."""
    try:
        imap = connect(account)
    except imaplib.IMAP4.error as e:
        print(f"\n[{account['label']}] Connection failed: {e}", file=sys.stderr)
        return 0

    try:
        imap.select("INBOX", readonly=True)  # readonly=True: never changes flags
        uids = search_unseen(imap, keyword=args.search, sender=args.sender)

        # Most recent first (reverse the list from IMAP search, which is oldest-first)
        uids = list(reversed(uids))
        shown = uids[: args.limit]

        print_account_header(account["label"], account["user"], len(uids))

        if not shown:
            print("  (no matching messages)")
            return 0

        count = 0
        for uid in shown:
            info = fetch_headers(imap, uid)
            if not info:
                continue
            snippet = fetch_body_snippet(imap, uid) if args.snippet else ""
            print_message(info, snippet)
            count += 1

        if len(uids) > args.limit:
            print(DIVIDER)
            print(f"  ... and {len(uids) - args.limit} more (use --limit to show more)")

        return count

    finally:
        try:
            imap.logout()
        except Exception:
            pass


def main() -> None:
    args = parse_args()
    load_dotenv(args.env)

    accounts = discover_accounts()
    if not accounts:
        print(
            "No accounts found. Copy .env.example to .env and fill in IMAP_LABEL_1, "
            "IMAP_USER_1, IMAP_PASS_1, IMAP_SERVER_1.",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.account:
        accounts = [a for a in accounts if a["label"].lower() == args.account.lower()]
        if not accounts:
            print(f"No account with label '{args.account}' found.", file=sys.stderr)
            sys.exit(1)

    total = 0
    for account in accounts:
        total += check_account(account, args)

    print(f"\n{DIVIDER}")
    print(f"  Total unread shown: {total}")
    print()


if __name__ == "__main__":
    main()
