# Multi-Account Management

When working across multiple projects (each with their own GitHub org, Render team,
Supabase org, etc.), you need a clean way to switch contexts without accidentally
running commands against the wrong account.

## Pattern

Store credentials in per-service key files loaded at shell startup. Define switching
functions that export the correct token. Add a `*-which` command to verify the active
account at a glance.

## Services Covered

- [GitHub](github-switching.md) - multiple `gh` CLI accounts
- [Render](render-switching.md) - multiple Render teams
- [Supabase](supabase-switching.md) - multiple Supabase orgs

## General Principle

```bash
# In ~/.bashrc or ~/.bash_aliases:

# Load all keys from a file NOT tracked in git
source ~/.service-keys 2>/dev/null

# Switching functions
project-a() { export SERVICE_TOKEN="$SERVICE_TOKEN_PROJECT_A"; echo "Switched to: project-a"; }
project-b() { export SERVICE_TOKEN="$SERVICE_TOKEN_PROJECT_B"; echo "Switched to: project-b"; }

# Verify current account
service-which() { <cli-command> auth status 2>&1 | grep -i active | head -2; }
```

The keys file (`~/.service-keys`) contains:
```bash
export SERVICE_TOKEN_PROJECT_A="token_here"
export SERVICE_TOKEN_PROJECT_B="token_here"
```

This file is sourced but never committed to git.

## Safety Rules

1. Never hardcode tokens in `.bashrc` or tracked files
2. Always provide a `*-which` command to verify context before destructive operations
3. Name projects consistently: use the same slug across all services
4. Add the keys files to `~/.gitignore_global`
