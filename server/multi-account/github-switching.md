# GitHub Multi-Account Switching

## Setup

The `gh` CLI supports multiple authenticated accounts since v2.40.

```bash
# Authenticate each account (run once per account)
gh auth login --hostname github.com
# Follow prompts, choose SSH or HTTPS, paste token when asked

# List all authenticated accounts
gh auth status
```

## Switching Aliases

Add to `~/.bashrc` or `~/.bash_aliases`:

```bash
# GitHub account switching
# Replace <USERNAME> with your actual GitHub usernames
alias gh-personal="gh auth switch --user <PERSONAL_USERNAME>"
alias gh-work="gh auth switch --user <WORK_USERNAME>"
alias gh-client-a="gh auth switch --user <CLIENT_A_USERNAME>"

# Show currently active account
alias gh-which="gh auth status 2>&1 | grep Active -A1 | head -2"
```

## Usage

```bash
# Switch to personal account
gh-personal

# Verify
gh-which

# Now all gh commands use personal account
gh repo list
gh pr create ...
```

## Per-Project Default (via git config)

If you always want a specific GitHub account for a given repo:

```bash
# Inside the repo directory
git config --local credential.username <USERNAME>
```

Or set the remote URL to use the correct SSH key:
```bash
git remote set-url origin git@github-work:<org>/<repo>.git
```

With `~/.ssh/config`:
```ssh-config
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_work
```

## Creating Repos

Always create as private first, audit for secrets, then make public if needed:

```bash
gh repo create my-project --private --clone
# Review, then if needed:
# gh repo edit my-project --visibility public
```

## Common Operations

```bash
# List all repos for current account
gh repo list

# View PRs
gh pr list

# Create a PR
gh pr create --title "Fix thing" --body "Description"

# Check CI status
gh pr checks
```
