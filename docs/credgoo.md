# credgoo — Credential Management for Skills

> credgoo is the **only approved way** to handle API keys and tokens in this repo. No `.env` files with real tokens. No hardcoded secrets.

**Source:** [github.com/devskale/python-openutils](https://github.com/devskale/python-openutils) (`packages/credgoo/`)

## What It Does

credgoo retrieves encrypted API keys from a Google Sheets backend, decrypts them locally, and caches them on disk. Skills import it as a Python library; developers call it from bash.

- Keys are **encrypted in transit** and **encrypted at rest** (XOR + base64 local cache)
- Cache lives in `~/.config/api_keys/` (mode 0600)
- Works offline from cache after first fetch
- One shared credential store for all skills

## Install

### For skills (as a dependency)

Add to `pyproject.toml`:

```toml
[project]
dependencies = [
    "credgoo",
]

[tool.uv.sources]
credgoo = { git = "https://github.com/devskale/python-openutils.git", subdirectory = "packages/credgoo" }
```

Then `uv sync` pulls it in.

### For CLI use

```bash
uv tool install "credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo"
```

## First-Time Setup

```bash
credgoo --setup
```

Prompts for:
1. **Google Apps Script URL** — the backend endpoint
2. **Bearer token** — auth for the backend
3. **Encryption key** — decrypts the stored keys

Validates with a live request before saving anything. Credentials go to `~/.config/api_keys/credgoo.txt`.

## CLI Usage

```bash
# Get a key (from cache or fetch)
credgoo WEB_SEARCH_BEARER

# Force re-fetch, bypass cache
credgoo --no-cache WEB_SEARCH_BEARER

# Update cached key (checks if remote changed)
credgoo --update WEB_SEARCH_BEARER

# Verbose output
credgoo -v searx
```

## Python Usage in Skills

### The standard pattern

Every skill that needs credentials follows this exact pattern:

```python
# 1. Import with graceful fallback
try:
    from credgoo import get_api_key
except ImportError:
    get_api_key = None  # type: ignore

# 2. Resolution function: env → credgoo → .env
def get_bearer_token() -> str | None:
    """Get token from env, credgoo, or .env file."""
    # Environment variable (highest priority)
    if token := os.environ.get("MY_SKILL_TOKEN"):
        return token

    # Credgoo (suppress stdout — it logs by default)
    if get_api_key:
        try:
            import contextlib, io
            with contextlib.redirect_stdout(io.StringIO()):
                if token := get_api_key("MY_SKILL_TOKEN"):
                    return token
        except Exception:
            pass

    # .env file (last resort)
    env_file = Path(__file__).parent.parent / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("MY_SKILL_TOKEN="):
                return line.split("=", 1)[1].strip()

    return None
```

### Why `contextlib.redirect_stdout`?

credgoo logs to `stdout` by default (`logger.info` without handlers goes to stdout). If you don't suppress it, key retrieval prints noise that breaks CLI output and JSON piping. Always wrap it.

### Fallback keys

Check related keys if your primary isn't set. Real example from fetch-url:

```python
def get_bearer_token() -> str | None:
    # Check both FETCH_URL_BEARER and WEB_SEARCH_BEARER
    for env_key in ("FETCH_URL_BEARER", "WEB_SEARCH_BEARER"):
        if token := os.environ.get(env_key):
            return token

    if get_api_key:
        for key in ("FETCH_URL_BEARER", "WEB_SEARCH_BEARER"):
            try:
                with contextlib.redirect_stdout(io.StringIO()):
                    if token := get_api_key(key):
                        return token
            except Exception:
                pass
    return None
```

The same token often works across multiple APIs. Always try the most specific key first, then broader ones.

## Adding Credentials to a New Skill

Step-by-step checklist:

### 1. Add the dependency

In `pyproject.toml`:

```toml
[project]
dependencies = [
    "credgoo",
    # ... other deps
]

[tool.uv.sources]
credgoo = { git = "https://github.com/devskale/python-openutils.git", subdirectory = "packages/credgoo" }
```

### 2. Add the import + resolution function

In your main script (copy the standard pattern from above). Adjust the env var name and credgoo service name.

### 3. Add the key to credgoo

```bash
# If the key already exists in the Google Sheet
credgoo MY_NEW_SERVICE_KEY

# If you need to add it for the first time
# Add it to the Google Sheet, then verify:
credgoo --no-cache MY_NEW_SERVICE_KEY
```

### 4. Document in SKILL.md

```markdown
## Credentials (optional)

For better results, configure an API key:

\`\`\`bash
credgoo MY_NEW_SERVICE_KEY
\`\`\`

Or set the `MY_NEW_SERVICE_KEY` environment variable.
```

### 5. Document in install.sh

Add to the post-install message:

```bash
echo ""
echo "Credentials (optional, for API features):"
echo "  credgoo MY_NEW_SERVICE_KEY"
```

### 6. Gitignore

Ensure `.gitignore` covers:

```
.env
```

Never commit real tokens. `.env.example` with placeholder values is fine.

## Resolution Order (All Skills)

```
1. Environment variable    MY_SKILL_TOKEN=xxx
2. credgoo                 get_api_key("MY_SKILL_TOKEN")
3. .env file               MY_SKILL_TOKEN=xxx (gitignored, last resort)
```

This order is consistent across all skills. Environment variables always win (useful for CI/CD, Docker, overrides).

## Current Services

| Service name | Used by | What |
|-------------|---------|------|
| `WEB_SEARCH_BEARER` | web-search | Duck API bearer token (advanced filters) |
| `FETCH_URL_BEARER` | fetch-url | Jina/markdown API bearer token |
| `searx` | web-search | Private SearXNG instance (`URL@username@password`) |

## CLI Reference

```
usage: credgoo [-h] [--setup] [--token TOKEN] [--key KEY] [--url URL]
               [--cache-dir CACHE_DIR] [--no-cache] [--update]
               [--save {all,token,key,url,none}] [--version] [-v]
               [service]

positional arguments:
  service               Service name to retrieve the API key for

options:
  --setup               Run interactive first-time setup
  --token TOKEN         Bearer token (overrides stored)
  --key KEY             Encryption key (overrides stored)
  --url URL             Google Apps Script URL (overrides stored)
  --cache-dir DIR       Cache directory (default: ~/.config/api_keys/)
  --no-cache            Bypass cache, force fetch from source
  --update              Check if remote key changed, update cache
  --save {all,token,key,url,none}
                        Which credentials to persist (default: all)
  --version             Show version
  -v, --verbose         Verbose output
```

## File Locations

| Path | What |
|------|------|
| `~/.config/api_keys/credgoo.txt` | Stored credentials (token, key, URL) — mode 0600 |
| `~/.config/api_keys/api_keys.json` | Cached decrypted keys (encrypted at rest) — mode 0600 |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `ImportError: No module named 'credgoo'` | Run `uv sync` in the skill directory |
| `Bearer token and encryption key are required` | Run `credgoo --setup` |
| Key returns `None` | Check service name matches exactly. Try `credgoo --no-cache SERVICE` |
| Stale cached key | `credgoo --update SERVICE` |
| Setup test failed | Check URL, token, and encryption key. Verify network access to the Apps Script URL |

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Your skill  │────►│   credgoo    │────►│ Google Sheet │
│  (Python)   │     │  (library)   │     │  (backend)   │
│             │◄────│              │◄────│              │
└─────────────┘     └──────┬───────┘     └─────────────┘
                           │
                    ┌──────▼───────┐
                    │  Local cache │
                    │  ~/.config/  │
                    │  api_keys/   │
                    └──────────────┘

Resolution: env var → cached key → fetch from Google → decrypt → cache → return
```
