#!/usr/bin/env python3
"""
Web Search - Unified search with automatic backend selection.
Supports DuckDuckGo API (with multiple engine backends) and SearXNG.
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

# Search engine backends available through the Duck API
DUCK_BACKENDS = ["auto", "all", "bing", "brave", "duckduckgo", "google", "mojeek", "yandex", "yahoo", "wikipedia"]


# =============================================================================
# Credentials
# =============================================================================

def get_bearer_token() -> Optional[str]:
    """Get bearer token from env, credgoo, or .env file."""
    # Environment variable
    if token := os.environ.get("WEB_SEARCH_BEARER"):
        return token
    
    # Credgoo (suppress output)
    if get_api_key:
        try:
            import io
            import contextlib
            with contextlib.redirect_stdout(io.StringIO()):
                if token := get_api_key("WEB_SEARCH_BEARER"):
                    return token
        except Exception:
            pass
    
    # Local .env file
    env_file = Path(__file__).parent.parent / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("WEB_SEARCH_BEARER="):
                return line.split("=", 1)[1].strip()
    
    return None


def get_searxng_credentials() -> Optional[Dict[str, str]]:
    """Get SearXNG credentials. Format: URL@USERNAME@PASSWORD"""
    if get_api_key:
        try:
            import io
            import contextlib
            with contextlib.redirect_stdout(io.StringIO()):
                cred = get_api_key("searx")
            if cred:
                parts = cred.split("@")
                if len(parts) == 3:
                    return {"url": parts[0], "user": parts[1], "pass": parts[2]}
        except Exception:
            pass
    
    # Local fallback file
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
# Backend Selection Strategy
# =============================================================================

def select_backend(args: argparse.Namespace) -> str:
    """
    Select the best backend based on query type and available credentials.
    
    Strategy:
    - Duck API: Best for general search, reliable results
    - SearXNG: Best for images/news/videos aggregation
    
    Selection logic:
    1. User explicitly chose --api (duck) or --searxng → honor it
    2. Image/video/news categories → SearXNG (better aggregation)
    3. Default → Duck API (more reliable)
    """
    # Explicit choice
    if args.api:
        return "duck"
    if args.searxng:
        return "searxng"
    
    # Category-based: images/news/videos better on SearXNG
    if args.categories and get_searxng_credentials():
        return "searxng"
    
    # Default to Duck API (more reliable)
    return "duck"


# =============================================================================
# Duck API Search
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
    """
    Search using the Duck API with advanced filters.
    All filter operators are handled by the API directly.
    """
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
    
    # Optional filters (API handles these directly)
    # Note: backend parameter not supported by API, kept for future compatibility
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
# SearXNG Search
# =============================================================================

def search_searxng(
    query: str,
    max_results: int = 10,
    categories: Optional[str] = None,
    engines: Optional[str] = None,
    time_range: Optional[str] = None,
    language: str = "en",
) -> Dict[str, Any]:
    """Search using SearXNG (privacy-focused metasearch)."""
    creds = get_searxng_credentials()
    if not creds:
        return {"error": "SearXNG credentials not configured. Add 'searx' to credgoo."}
    
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
    
    url = f"{creds['url']}/search?{urllib.parse.urlencode(params)}"
    
    try:
        req = urllib.request.Request(url)
        auth = __import__("base64").b64encode(f"{creds['user']}:{creds['pass']}".encode()).decode()
        req.add_header("Authorization", f"Basic {auth}")
        
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
            if "results" in data:
                data["results"] = data["results"][:max_results]
            return data
    except Exception as e:
        return {"error": f"SearXNG failed: {e}"}


# =============================================================================
# Output Formatting
# =============================================================================

def format_results(results: Union[List, Dict], backend: str, query: str, limit: int = 10) -> str:
    """Format search results as markdown."""
    # Handle errors
    if isinstance(results, dict) and "error" in results:
        return f"**Error:** {results['error']}"
    if isinstance(results, list) and results and "error" in results[0]:
        return f"**Error:** {results[0]['error']}"
    
    # Normalize results
    items = results if isinstance(results, list) else results.get("results", [])
    if not items:
        return f"No results found for '{query}'."
    
    lines = [f"# Results for '{query}'\n"]
    
    for i, r in enumerate(items[:limit], 1):
        title = r.get("title", "No title")
        url = r.get("href") or r.get("url", "")
        snippet = r.get("body") or r.get("content", "") or ""
        source = r.get("engine", "")
        
        lines.append(f"{i}. [**{title}**]({url})")
        if snippet:
            # Truncate long snippets
            if len(snippet) > 200:
                snippet = snippet[:197] + "..."
            lines.append(f"   {snippet}")
        if source and backend == "searxng":
            lines.append(f"   _Source: {source}_")
        lines.append("")
    
    return "\n".join(lines)


# =============================================================================
# Main Entry Point
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Web search with automatic backend selection",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "react hooks tutorial"
  %(prog)s "python async" --site github.com --max 20
  %(prog)s "machine learning" --backend google --timelimit w
  %(prog)s "error fix" --exact
  %(prog)s "cats" --categories images --searxng
  %(prog)s "news today" --backend brave --timelimit d

Backend Selection (automatic by default):
  - Duck API: General search, specific engines (google, bing, brave)
  - SearXNG: Images, news, videos (better aggregation)
        """
    )
    
    # Required
    parser.add_argument("query", help="Search query")
    
    # Result options
    parser.add_argument("--max", type=int, default=10, help="Max results (default: 10)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--verbose", "-v", action="store_true", help="Show backend used")
    
    # Duck API filters (passed directly to API)
    parser.add_argument("--site", help="Filter by domain (site:)")
    parser.add_argument("--filetype", help="Filter by file type (pdf, txt, etc.)")
    parser.add_argument("--inurl", help="Filter by URL fragment")
    parser.add_argument("--exclude", help="Comma-separated terms to exclude")
    parser.add_argument("--exact", action="store_true", help="Exact phrase match")
    parser.add_argument("--timelimit", choices=["d", "w", "m", "y"],
                        help="Time filter: day/week/month/year")
    parser.add_argument("--region", default="wt-wt", help="Region (e.g., us-en, de-de)")
    parser.add_argument("--safesearch", choices=["off", "moderate", "strict"], default="off")
    parser.add_argument("--page", type=int, default=1, help="Results page")
    
    # SearXNG options
    parser.add_argument("--categories", help="Category filter (images, news, videos)")
    parser.add_argument("--engines", help="Comma-separated engines for SearXNG")
    parser.add_argument("--time-range", dest="time_range",
                        choices=["day", "week", "month", "year"],
                        help="Time range (SearXNG)")
    
    # Backend selection
    parser.add_argument("--api", action="store_true", help="Force Duck API")
    parser.add_argument("--searxng", action="store_true", help="Force SearXNG")
    
    args = parser.parse_args()
    
    # Select backend
    backend = select_backend(args)
    
    if args.verbose:
        print(f"# Backend: {backend}", file=sys.stderr)
    
    # Get credentials for Duck API
    bearer = get_bearer_token()
    
    # Execute search
    if backend == "duck":
        if not bearer:
            print("Error: WEB_SEARCH_BEARER not set. Configure credentials first.", file=sys.stderr)
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
            safesearch=args.safesearch,
            page=args.page,
            bearer=bearer,
        )
    else:
        results = search_searxng(
            query=args.query,
            max_results=args.max,
            categories=args.categories,
            engines=args.engines,
            time_range=args.time_range,
        )
    
    # Output
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        print(format_results(results, backend, args.query, args.max))


if __name__ == "__main__":
    main()
