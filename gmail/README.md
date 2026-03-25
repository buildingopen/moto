# Multi-Account Gmail / IMAP Setup

Scripts and patterns for reading multiple Gmail (or IMAP) accounts without a GUI.

## Creating Google App Passwords

App Passwords are 16-character passwords that work even with 2FA enabled. They are **not** your account password.

1. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
2. Sign in to the target Google account
3. Under "Select app", choose "Mail" (or type a custom name)
4. Under "Select device", choose "Other" and name it (e.g. "server-imap")
5. Click "Generate"
6. Copy the 16-character password immediately (it is shown only once)
7. Use this password as `IMAP_PASS_*` in your `.env`

Repeat for each account.

## CRITICAL: Preserve read/unread status

**Always use `BODY.PEEK[]` instead of `RFC822` when fetching message bodies.**

```python
# CORRECT - does not mark as read
status, data = imap.fetch(num, '(BODY.PEEK[])')

# WRONG - marks message as read
status, data = imap.fetch(num, '(RFC822)')
```

If you accidentally mark a message as read:

```python
imap.store(num, '-FLAGS', '\\Seen')
```

## Configuring accounts

Copy `.env.example` to `.env` and fill in your accounts:

```bash
cp .env.example .env
```

Accounts are numbered sequentially:

```
IMAP_LABEL_1=personal
IMAP_USER_1=you@gmail.com
IMAP_PASS_1=abcd efgh ijkl mnop
IMAP_SERVER_1=imap.gmail.com

IMAP_LABEL_2=work
IMAP_USER_2=you@yourcompany.com
IMAP_PASS_2=xxxx xxxx xxxx xxxx
IMAP_SERVER_2=imap.gmail.com
```

The script reads as many `IMAP_LABEL_N` / `IMAP_USER_N` / `IMAP_PASS_N` / `IMAP_SERVER_N` groups as it finds.

## Running the checker

```bash
# List unread emails across all accounts
python3 email-check.py

# Filter to one account
python3 email-check.py --account personal

# Search by keyword in subject or body snippet
python3 email-check.py --search "invoice"

# Filter by sender
python3 email-check.py --from "billing@stripe.com"

# Combine filters
python3 email-check.py --account work --search "deploy"
```

## Security notes

- Store `.env` with restricted permissions: `chmod 600 .env`
- Never commit `.env` to version control (add to `.gitignore`)
- App passwords can be revoked individually at [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) without changing your main password
- For non-Gmail IMAP servers, set `IMAP_SERVER_N` to the correct IMAP hostname (e.g. `imap.mail.yahoo.com`)
- Gmail requires IMAP to be enabled: Gmail Settings -> See all settings -> Forwarding and POP/IMAP -> Enable IMAP

## Yahoo Mail

Yahoo also uses App Passwords. Generate one at [login.yahoo.com/security/app-passwords/new](https://login.yahoo.com/security/app-passwords/new) and set `IMAP_SERVER_N=imap.mail.yahoo.com`.
