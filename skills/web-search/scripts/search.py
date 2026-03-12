#!/usr/bin/env python3
"""
Web Search - Unified search with public and private backends.
Defaults to public SearXNG instances (no credentials needed).
Supports private Duck API and SearXNG with credentials for better results.
"""

import argparse
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

# Optional dependencies with graceful fallback
try:
    import requests
except ImportError:
    requests = None  # type: ignore

try:
    from credgoo import get_api_key
except ImportError:
    get_api_key = None  # type: ignore


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
    """Get bearer token from env, credgoo, or .env file."""
    if token := os.environ.get("WEB_SEARCH_BEARER"):
        return token
    
    if get_api_key:
        try:
            import io
            import contextlib
            with contextlib.redirect_stdout(io.StringIO()):
                if token := get_api_key("WEB_SEARCH_BEARER"):
                    return token
        except Exception:
            pass
    
    env_file = Path(__file__).parent.parent / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("WEB_SEARCH_BEARER="):
                return line.split("=", 1)[1].strip()
    
    return None


def get_searxng_credentials() -> Optional[Dict[str, str]]:
    """Get SearXNG credentials if configured."""
    # Environment variable: URL or URL@USER@PASS
    if PRIVATE_SEARXNG_URL:
        if "@" in PRIVATE_SEARXNG_URL:
            parts = PRIVATE_SEARXNG_URL.split("@")
            if len(parts) == 3:
                return {"url": parts[0], "user": parts[1], "pass": parts[2]}
        else:
            return {"url": PRIVATE_SEARXNG_URL, "user": "", "pass": ""}
    
    # Credgoo
    if get_api_key:
        try:
            import io
            import contextlib
            with contextlib.redirect_stdout(io.StringIO()):
                cred = get_api_key("searx")
            if cred:
                parts = cred.split("@")
                if len(parts) >= 1:
                    return {
                        "url": parts[0],
                        "user": parts[1] if len(parts) > 1 else "",
                        "pass": parts[2] if len(parts) > 2 else ""
                    }
        except Exception:
            pass
    
    # Local config file
    config_file = Path.home() / ".config/api_keys/searx.json"
    if config_file.exists():
        try:
            data = json.loads(config_file.read_text())
            return {
                "url": data.get("url", ""),
                "user": data.get("username", ""),
                "pass": data.get("password", "")
            }
        except Exception:
            pass
    
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
        resp = requests.get(DUCK_API_URL, params=params, headers=headers, timeout=30)
        resp.raise_for_status()
        return resp.json().get("results", [])
    except requests.RequestException as e:
        return [{"error": f"Search failed: {e}"}]


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
    
    for instance in instances_to_try:
        url = f"{instance}/search?{urllib.parse.urlencode(params)}"
        try:
            req = urllib.request.Request(url)
            if auth:
                req.add_header("Authorization", f"Basic {auth}")
            
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode())
                if "results" in data:
                    data["results"] = data["results"][:max_results]
                    data["_instance"] = instance
                return data
        except Exception:
            continue
    
    return {"error": "All SearXNG instances failed"}


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
    parser.add_argument("--inurl", help="Filter by URL fragment")
    parser.add_argument("--exclude", help="Comma-separated terms to exclude")
    parser.add_argument("--exact", action="store_true", help="Exact phrase match")
    parser.add_argument("--timelimit", "--time-limit", choices=["d", "w", "m", "y"],
                        help="Time filter: day/week/month/year")
    parser.add_argument("--region", default="wt-wt", help="Region (e.g., us-en, de-de)")
    parser.add_argument("--page", type=int, default=1, help="Results page")
    
    # SearXNG options
    parser.add_argument("--categories", help="Category (images, news, videos)")
    parser.add_argument("--engines", help="Comma-separated engines")
    parser.add_argument("--time-range", choices=["day", "week", "month", "year"],
                        help="Time range (SearXNG)")
    
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
        
        results = search_duck(
            query=args.query,
            max_results=args.max,
            site=args.site,
            filetype=args.filetype,
            inurl=args.inurl,
            exclude=args.exclude,
            exact=args.exact,
            timelimit=args.timelimit,
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
        
        results = search_searxng(
            query=args.query,
            max_results=args.max,
            categories=args.categories,
            engines=args.engines,
            time_range=args.time_range or (args.timelimit[0] if args.timelimit else None),
            instance_url=instance_url,
            auth=auth,
        )
    
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
