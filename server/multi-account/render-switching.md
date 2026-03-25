# Render Multi-Account Switching

## Setup

Store Render API keys in a file not tracked in git:

```bash
# ~/.render-keys (chmod 600, not tracked in git)
export RENDER_KEY_PROJECT_A="rnd_xxxxxxxxxxxxxxxxxxxx"
export RENDER_KEY_PROJECT_B="rnd_xxxxxxxxxxxxxxxxxxxx"
```

```bash
chmod 600 ~/.render-keys
```

## Shell Functions

Add to `~/.bashrc`:

```bash
# Load keys
source ~/.render-keys 2>/dev/null

# Switching functions
render-project-a() { export RENDER_API_KEY="$RENDER_KEY_PROJECT_A"; echo "Switched to Render: project-a"; }
render-project-b() { export RENDER_API_KEY="$RENDER_KEY_PROJECT_B"; echo "Switched to Render: project-b"; }

# Check which key is active
render-which() {
    if [ -z "$RENDER_API_KEY" ]; then
        echo "No RENDER_API_KEY set"
        return
    fi
    # Get current user info from Render API
    curl -s -H "Authorization: Bearer $RENDER_API_KEY" \
        https://api.render.com/v1/owners?limit=1 | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['owner']['name'] if d else 'unknown')" 2>/dev/null
}
```

## Getting API Keys

1. Go to https://dashboard.render.com/u/settings
2. Under "API Keys", create a new key for each project/team
3. Name them clearly (e.g. "devserver-project-a")

## Common Operations

```bash
# Deploy a service
curl -X POST \
    -H "Authorization: Bearer $RENDER_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"serviceId": "<SERVICE_ID>"}' \
    https://api.render.com/v1/deploys

# List services
curl -s \
    -H "Authorization: Bearer $RENDER_API_KEY" \
    https://api.render.com/v1/services | \
    python3 -c "import sys,json; [print(s['service']['name']) for s in json.load(sys.stdin)]"
```

## Notes

- Render API keys are per-owner (personal or team), not per-service
- Each team/workspace needs its own key
- The `render` CLI (if using it) reads `RENDER_API_KEY` from the environment
