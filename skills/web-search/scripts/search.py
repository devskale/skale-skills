#!/usr/bin/env python3
"""
Web Search - Unified search with public and private backends.
Defaults to public SearXNG instances (no credentials needed).
Supports private Duck API and SearXNG with credentials for better results.
"""

import argparse
import glob
import io
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

# Fix Windows console encoding: reconfigure stdout to UTF-8 so that
# Unicode characters from search results (✓, →, ☎, etc.) don't
# crash on cp1252 terminals.
if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        # Fallback: wrap in a TextIOWrapper that won't crash on unencodable chars
        try:
            sys.stdout = io.TextIOWrapper(
                sys.stdout.buffer, encoding='utf-8', errors='replace'
            )
        except Exception:
            pass

# Optional dependencies with graceful fallback
try:
    import requests
except ImportError:
    requests = None  # type: ignore

# Prefer a globally-installed credgoo (`uv tool install credgoo`) over the copy
# bundled in this skill's venv. We do it by inserting the global tool's
# site-packages at the front of sys.path before importing, so `import credgoo`
# resolves global-first. No subprocess, no re-resolution. If no global install
# exists, the bundled copy (kept so `--update` stays self-contained) is used.
_global_credgoo_sp = glob.glob(
    os.path.join(
        os.environ.get("UV_TOOL_DIR", str(Path.home() / ".local/share/uv/tools/credgoo")),
        "lib", "*", "site-packages",
    )
)
if _global_credgoo_sp and _global_credgoo_sp[0] not in sys.path:
    sys.path.insert(0, _global_credgoo_sp[0])

try:
    from credgoo import get_api_key
except ImportError:
    get_api_key = None  # type: ignore


def credgoo_get(service: str) -> Optional[str]:
    """Fetch a key via credgoo. Failures are loud (stderr), never silently masked."""
    if get_api_key is None:
        print(
            "credgoo unavailable. Install globally: "
            "uv tool install \"credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo\"",
            file=sys.stderr,
        )
        return None
    try:
        key = get_api_key(service)
    except Exception as e:
        print(f"credgoo error for '{service}': {e}", file=sys.stderr)
        return None
    if not key:
        print(f"credgoo returned no key for '{service}'", file=sys.stderr)
    return key


# =============================================================================
# Configuration
# =============================================================================

DUCK_API_URL = os.environ.get("DUCK_API_URL", "https://amd1.mooo.com/api/duck/search")

# Public SearXNG instances (no auth required)
PUBLIC_SEARXNG_INSTANCES = [
    "https://searx.be",
    "https://search.bus-hit.me",
    "https://search.rowie.at",
    "https://searx.fmac.xyz",
]

# Private instance (if configured)
PRIVATE_SEARXNG_URL = os.environ.get("SEARXNG_URL", "")


# =============================================================================
# Credentials (Optional)
# =============================================================================

def get_bearer_token() -> Optional[str]:
    """Get bearer token from env or credgoo. No silent fallbacks."""
    if token := os.environ.get("WEB_SEARCH_BEARER"):
        return token

    return credgoo_get("WEB_SEARCH_BEARER")


def _parse_searxng_cred(cred: str) -> Optional[Dict[str, str]]:
    """Parse a SearXNG credential string (URL or URL@USER@PASS).

    Returns None if the URL part is empty.
    """
    if not cred:
        return None
    parts = cred.split("@")
    url = parts[0]
    if not url:
        return None
    return {
        "url": url,
        "user": parts[1] if len(parts) > 1 else "",
        "pass": parts[2] if len(parts) > 2 else "",
    }


def get_searxng_credentials() -> Optional[Dict[str, str]]:
    """Get SearXNG credentials if configured.

    Returns:
        Dict with url/user/pass keys, or None if nothing is configured.
    """
    # Environment variable: URL or URL@USER@PASS
    if PRIVATE_SEARXNG_URL:
        result = _parse_searxng_cred(PRIVATE_SEARXNG_URL)
        if result:
            return result

    # Credgoo (no silent fallback to searx.json — that masked failures)
    if cred := credgoo_get("searx"):
        result = _parse_searxng_cred(cred)
        if result:
            return result

    return None


# =============================================================================
# Backend Selection
# =============================================================================

def select_backend(args: argparse.Namespace) -> str:
    """Select backend based on args and available credentials."""
    # Explicit choice
    if args.api:
        return "duck"
    if args.searxng:
        return "searxng"

    # Duck API only if token available
    if get_bearer_token():
        # Images/news better on SearXNG
        if args.categories:
            return "searxng"
        return "duck"

    # Default to public SearXNG
    return "searxng"


# =============================================================================
# Duck API Search (requires token)
# =============================================================================

def search_duck(
    query: str,
    max_results: int = 10,
    site: Optional[str] = None,
    filetype: Optional[str] = None,
    inurl: Optional[str] = None,
    exclude: Optional[str] = None,
    exact: bool = False,
    timelimit: Optional[str] = None,
    region: str = "wt-wt",
    safesearch: str = "off",
    page: int = 1,
    bearer: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """Search using Duck API (requires token)."""
    if not requests:
        raise RuntimeError("requests library required. Run: uv pip install requests")

    if not bearer:
        raise ValueError("Bearer token required. Set WEB_SEARCH_BEARER env var.")

    params: Dict[str, Any] = {
        "query": query,
        "max_results": max_results,
        "region": region,
        "safesearch": safesearch,
        "exact": str(exact).lower(),
        "page": page,
    }

    if site:
        params["site"] = site
    if filetype:
        params["filetype"] = filetype
    if inurl:
        params["inurl"] = inurl
    if exclude:
        params["exclude"] = exclude
    if timelimit:
        params["timelimit"] = timelimit

    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {bearer}"
    }

    try:
        resp = requests.get(
            DUCK_API_URL, params=params, headers=headers, timeout=(5, 15),
        )
        resp.raise_for_status()
        return resp.json().get("results", [])
    except requests.RequestException as e:
        safe_msg = str(e).split("Authorization")[0].rstrip(": ,")
        return [{"error": f"Search failed: {safe_msg}"}]
    except Exception as e:
        return [{"error": f"Unexpected error: {e}"}]


# =============================================================================
# SearXNG Search (public or private)
# =============================================================================

def search_searxng(
    query: str,
    max_results: int = 10,
    categories: Optional[str] = None,
    engines: Optional[str] = None,
    time_range: Optional[str] = None,
    language: str = "en",
    instance_url: Optional[str] = None,
    auth: Optional[str] = None,
) -> Dict[str, Any]:
    """Search using SearXNG (public or private instance)."""
    params = {
        "q": query,
        "format": "json",
        "language": language,
        "safesearch": 0,
    }

    if categories:
        params["categories"] = categories
    if engines:
        params["engines"] = engines
    if time_range:
        params["time_range"] = time_range

    # Try private instance first, then public instances
    instances_to_try = []
    if instance_url:
        instances_to_try.append(instance_url)
    instances_to_try.extend(PUBLIC_SEARXNG_INSTANCES)

    # SSL context: allow self-signed certs for private instances,
    # strict verification for public instances
    import ssl

    last_error: Optional[str] = None
    for i, instance in enumerate(instances_to_try):
        url = f"{instance}/search?{urllib.parse.urlencode(params)}"
        try:
            req = urllib.request.Request(url)
            if auth:
                req.add_header("Authorization", f"Basic {auth}")

            # Private instance (index 0 if configured) may have self-signed cert
            ssl_ctx = None
            if i == 0 and instance_url and instance == instance_url:
                ssl_ctx = ssl.create_default_context()
                ssl_ctx.check_hostname = False
                ssl_ctx.verify_mode = ssl.CERT_NONE

            with urllib.request.urlopen(req, timeout=15, context=ssl_ctx) as resp:
                data = json.loads(resp.read().decode())
                if "results" in data:
                    data["results"] = data["results"][:max_results]
                    data["_instance"] = instance
                return data
        except Exception as exc:
            last_error = f"{instance}: {exc}"
            continue

    detail = f" ({last_error})" if last_error else ""
    return {"error": f"All SearXNG instances failed (tried {len(instances_to_try)}).{detail}"}


# =============================================================================
# Output Formatting
# =============================================================================

def format_results(results: Union[List, Dict], backend: str, query: str, limit: int = 10, verbose: bool = False) -> str:
    """Format search results as markdown."""
    if isinstance(results, dict) and "error" in results:
        return f"**Error:** {results['error']}"
    if isinstance(results, list) and results and "error" in results[0]:
        return f"**Error:** {results[0]['error']}"

    items = results if isinstance(results, list) else results.get("results", [])
    if not items:
        return f"No results found for '{query}'."

    lines = [f"# Results for '{query}'\n"]

    if verbose and isinstance(results, dict) and "_instance" in results:
        lines.append(f"_Instance: {results['_instance']}_\n")

    for i, r in enumerate(items[:limit], 1):
        title = r.get("title", "No title")
        url = r.get("href") or r.get("url", "")
        snippet = r.get("body") or r.get("content", "") or ""
        source = r.get("engine", "")

        lines.append(f"{i}. [**{title}**]({url})")
        if snippet:
            if len(snippet) > 200:
                snippet = snippet[:197] + "..."
            lines.append(f"   {snippet}")
        if source:
            lines.append(f"   _Source: {source}_")
        lines.append("")

    return "\n".join(lines)


# =============================================================================
# Main
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Web search - works out of the box with public instances",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "react hooks tutorial"
  %(prog)s "python async" --site github.com --max 20
  %(prog)s "cats" --categories images
  %(prog)s "AI news" --categories news --time-range day
  %(prog)s "error fix" --exact

Backends:
  - Public SearXNG: Default, no setup required
  - Duck API: Set WEB_SEARCH_BEARER for advanced filters
  - Private SearXNG: Set SEARXNG_URL or add to credgoo
        """
    )

    parser.add_argument("query", help="Search query")
    parser.add_argument("--max", type=int, default=10, help="Max results (default: 10)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show backend info")

    # Filters
    parser.add_argument("--site", help="Filter by domain")
    parser.add_argument("--filetype", help="Filter by file type (pdf, txt, etc.)")
    parser.add_argument("--inurl", help="Filter by URL fragment (Duck API only)")
    parser.add_argument("--exclude", help="Comma-separated terms to exclude")
    parser.add_argument("--exact", action="store_true", help="Exact phrase match")
    parser.add_argument("--timelimit", "--time-limit", choices=["d", "w", "m", "y"],
                        help="Time filter shorthand: d/w/m/y (Duck API only)")
    parser.add_argument("--region", default="wt-wt", help="Region (e.g., us-en, de-de)")
    parser.add_argument("--page", type=int, default=1, help="Results page")

    # SearXNG options
    parser.add_argument("--categories", help="Category (images, news, videos)")
    parser.add_argument("--engines", help="Comma-separated engines")
    parser.add_argument("--time-range", choices=["day", "week", "month", "year"],
                        help="Time range (day/week/month/year). Works on both backends.")
    parser.add_argument("--language", default="en", help="Search language (e.g., en, de, ja). SearXNG backend only.")

    # Backend selection
    parser.add_argument("--api", action="store_true", help="Force Duck API")
    parser.add_argument("--searxng", action="store_true", help="Force SearXNG")

    args = parser.parse_args()

    # Select backend
    backend = select_backend(args)

    if args.verbose:
        print(f"# Backend: {backend}", file=sys.stderr)

    # Execute search
    if backend == "duck":
        bearer = get_bearer_token()
        if not bearer:
            print("Error: WEB_SEARCH_BEARER not set. Use --searxng for public search.", file=sys.stderr)
            sys.exit(1)

        # Map --time-range (full word) to Duck API's single-letter timelimit
        duck_timelimit = args.timelimit
        if not duck_timelimit and args.time_range:
            duck_timelimit = args.time_range[0]  # day->d, week->w, month->m, year->y

        results = search_duck(
            query=args.query,
            max_results=args.max,
            site=args.site,
            filetype=args.filetype,
            inurl=args.inurl,
            exclude=args.exclude,
            exact=args.exact,
            timelimit=duck_timelimit,
            region=args.region,
            bearer=bearer,
        )
    else:
        creds = get_searxng_credentials()
        instance_url = creds["url"] if creds else None
        auth = None
        if creds and creds.get("user") and creds.get("pass"):
            auth = __import__("base64").b64encode(
                f"{creds['user']}:{creds['pass']}".encode()
            ).decode()

        # Warn about Duck-only flags used with SearXNG
        duck_only_flags = []
        if args.site:
            duck_only_flags.append("--site")
        if args.filetype:
            duck_only_flags.append("--filetype")
        if args.inurl:
            duck_only_flags.append("--inurl")
        if args.exclude:
            duck_only_flags.append("--exclude")
        if args.exact:
            duck_only_flags.append("--exact")
        if duck_only_flags:
            print(f"Warning: {', '.join(duck_only_flags)} ignored (Duck API only). Use --api to force Duck backend.", file=sys.stderr)

        results = search_searxng(
            query=args.query,
            max_results=args.max,
            categories=args.categories,
            engines=args.engines,
            time_range=args.time_range or (args.timelimit[0] if args.timelimit else None),
            language=args.language,
            instance_url=instance_url,
            auth=auth,
        )

    # Check for errors
    if isinstance(results, dict) and "error" in results:
        print(f"Error: {results['error']}", file=sys.stderr)
        sys.exit(1)
    if isinstance(results, list) and results and isinstance(results[0], dict) and "error" in results[0]:
        print(f"Error: {results[0]['error']}", file=sys.stderr)
        sys.exit(1)

    # Output
    if args.json:
        # Remove internal keys before JSON output
        if isinstance(results, dict) and "_instance" in results:
            del results["_instance"]
        print(json.dumps(results, indent=2))
    else:
        print(format_results(results, backend, args.query, args.max, args.verbose))


if __name__ == "__main__":
    main()
