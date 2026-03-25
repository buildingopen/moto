# Supabase Multi-Account Switching

## Setup

Store Supabase access tokens in a file not tracked in git:

```bash
# ~/.supabase-keys (chmod 600, not tracked in git)
export SUPABASE_KEY_PROJECT_A="sbp_xxxxxxxxxxxxxxxxxxxx"
export SUPABASE_KEY_PROJECT_B="sbp_xxxxxxxxxxxxxxxxxxxx"
```

```bash
chmod 600 ~/.supabase-keys
```

## Shell Functions

Add to `~/.bashrc`:

```bash
# Load keys
source ~/.supabase-keys 2>/dev/null

# Switching functions
sb-project-a() { export SUPABASE_ACCESS_TOKEN="$SUPABASE_KEY_PROJECT_A"; echo "Switched to Supabase: project-a"; }
sb-project-b() { export SUPABASE_ACCESS_TOKEN="$SUPABASE_KEY_PROJECT_B"; echo "Switched to Supabase: project-b"; }

# Check which org is active
sb-which() {
    if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
        echo "No SUPABASE_ACCESS_TOKEN set"
        return
    fi
    supabase orgs list 2>/dev/null | head -5
}
```

## Getting Access Tokens

1. Go to https://supabase.com/dashboard/account/tokens
2. Create a new access token for each project context
3. Name them clearly (e.g. "devserver-project-a")
4. Tokens expire - set a calendar reminder to rotate them

## Common CLI Operations

```bash
# After switching to the right account:

# List projects in current org
supabase projects list

# Link a local project
supabase link --project-ref <PROJECT_REF>

# Run migrations
supabase db push

# Pull remote schema
supabase db pull

# Check migration status
supabase migration list
```

## Database Direct Access

For direct psql/pgbouncer access, store connection strings separately:

```bash
# ~/.supabase-connections (chmod 600)
export DB_URL_PROJECT_A="postgresql://postgres.<ref>:<password>@<host>:5432/postgres"
export DB_URL_PROJECT_B="postgresql://postgres.<ref>:<password>@<host>:5432/postgres"
```

```bash
# Quick query helper
db-project-a() { psql "$DB_URL_PROJECT_A" "$@"; }
db-project-b() { psql "$DB_URL_PROJECT_B" "$@"; }
```

## Notes

- `SUPABASE_ACCESS_TOKEN` is what the `supabase` CLI uses for authentication
- The access token is for the Supabase dashboard API (orgs, projects, deploys)
- For actual database connections, use the database connection string directly
- Use the pooler (port 6543) for serverless/edge, direct connection (5432) for migrations
- Pooler hostname format: `aws-0-<region>.pooler.supabase.com` (check your project dashboard)
