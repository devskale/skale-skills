#!/usr/bin/env python3
"""
Unified Web Search - Automatic backend selection
Search the web with rich filters. Smart backend selection based on query.
"""

# Standard library imports
import os
import sys
import argparse
import json
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

# Third-party imports
requests = None
try:
    import requests
except ImportError:
    pass  # Will show error when API mode is actually used

credgoo = None
try:
    from credgoo import get_api_key
except ImportError:
    pass  # Optional dependency

# Default configuration
DEFAULT_DUCKDUCKGO_API_URL = "https://amd1.mooo.com/api/duck/search"


# ============================================================================
# Credential Management
# ============================================================================

def get_bearer_token() -> Optional[str]:
    """Get bearer token from environment variable, credgoo, or .env file."""
    token = os.environ.get("WEB_SEARCH_BEARER")
    if token:
        return token

    if credgoo is not None:
        try:
            token = credgoo.get_api_key("web-search")
            if token:
                return token
        except Exception:
            pass

    env_file: Path = Path(__file__).parent.parent / ".env"
    if env_file.exists():
        for line in env_file.read_text().strip().split('\n'):
            if line.startswith('WEB_SEARCH_BEARER='):
                return line.split('=', 1)[1].strip()

    return None


def get_searxng_credentials() -> Optional[Dict[str, str]]:
    """Get SearXNG credentials from credgoo or local file. Format: URL@USERNAME@PASSWORD"""
    # Try credgoo first
    if credgoo is not None:
        try:
            cred_string = get_api_key("searx")
            if cred_string:
                parts = cred_string.split("@")
                if len(parts) == 3:
                    return {"base_url": parts[0], "username": parts[1], "password": parts[2]}
        except Exception:
            pass

    # Try local file fallback
    config_dir = os.path.expanduser("~/.config/api_keys")
    config_file = Path(config_dir) / "searx.json"
    if config_file.exists():
        try:
            import json
            data = json.loads(config_file.read_text())
            return {
                "base_url": data.get("url", data.get("base_url", "")),
                "username": data.get("username", ""),
                "password": data.get("password", "")
            }
        except Exception:
            pass

    return None


def has_searxng_credentials() -> bool:
    """Check if SearXNG credentials are available."""
    return get_searxng_credentials() is not None


# ============================================================================
# Backend Selection
# ============================================================================

def select_backend(args: argparse.Namespace) -> str:
    """Automatically select the best backend based on query and options.
    
    Decision logic:
    - If --backend explicitly specified, use it
    - If SearXNG-specific options (categories, engines) used, use SearXNG
    - If SearXNG credentials available, use SearXNG (more private)
    - Default to DuckDuckGo
    """
    # Explicit backend choice
    if hasattr(args, 'backend') and args.backend and args.backend != 'auto':
        return args.backend
    
    # SearXNG-specific options
    if args.categories or args.engines or args.time_range:
        if has_searxng_credentials():
            return 'searxng'
        elif args.categories or args.engines:
            # User asked for searxng features but no credentials
            print("Warning: SearXNG options requested but no credentials. Using DuckDuckGo.", file=sys.stderr)
    
    # Auto-select: prefer SearXNG if available (privacy, more engines)
    if has_searxng_credentials():
        return 'searxng'
    
    return 'duckduckgo'


# ============================================================================
# DuckDuckGo Search
# ============================================================================

def build_ddg_query(args: argparse.Namespace) -> str:
    """Build the search query with DuckDuckGo operators."""
    query: str = args.query

    if args.site:
        query = f"site:{args.site} {query}"
    if args.filetype:
        query = f"filetype:{args.filetype} {query}"
    if args.inurl:
        query = f"inurl:{args.inurl} {query}"

    if args.exclude:
        for term in args.exclude.split(','):
            term = term.strip()
            if term:
                query = f"{query} -{term}"

    if args.exact:
        query = f'"{query}"'

    return query.strip()


def search_duckduckgo(
    query: str,
    max_results: Optional[int] = None,
    region: Optional[str] = None,
    safesearch: Optional[str] = None,
    exact: Optional[bool] = None,
    page: Optional[int] = None,
    timelimit: Optional[str] = None,
    backend: Optional[str] = None,
    proxy: Optional[str] = None,
    verify: Optional[bool] = None,
    bearer: Optional[str] = None,
    api_url: Optional[str] = None,
    timeout: Optional[int] = None
) -> List[Dict[str, Any]]:
    """Perform a DuckDuckGo search via the API."""
    if not bearer:
        raise ValueError("Bearer token required. Set WEB_SEARCH_BEARER env var or .env file.")

    params: Dict[str, Any] = {'query': query}

    if max_results is not None:
        params['max_results'] = max_results
    if region is not None:
        params['region'] = region
    if safesearch is not None:
        params['safesearch'] = safesearch
    if exact is not None:
        params['exact'] = str(exact).lower()
    if page is not None:
        params['page'] = page
    if timelimit is not None:
        params['timelimit'] = timelimit
    if backend is not None:
        params['backend'] = backend
    if proxy is not None:
        params['proxy'] = proxy
    if verify is not None:
        params['verify'] = str(verify).lower()

    headers: Dict[str, str] = {
        'accept': 'application/json',
        'Authorization': f'Bearer {bearer}'
    }

    url: str = api_url or DEFAULT_DUCKDUCKGO_API_URL
    request_timeout: int = timeout or 30

    try:
        response = requests.get(url, params=params, headers=headers, timeout=request_timeout)
        response.raise_for_status()
        data = response.json()
        return data.get('results', [])
    except requests.exceptions.RequestException as e:
        print(f"Error performing search: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing response: {e}", file=sys.stderr)
        sys.exit(1)


# ============================================================================
# SearXNG Search
# ============================================================================

def search_searxng(
    query: str,
    max_results: Optional[int] = None,
    engines: Optional[List[str]] = None,
    categories: Optional[List[str]] = None,
    language: str = "en",
    time_range: Optional[str] = None,
    safesearch: int = 0,
    format: str = "json",
    timeout: int = 30
) -> Dict[str, Any]:
    """Search using a SearXNG instance."""
    creds = get_searxng_credentials()
    if not creds:
        return {"error": "No SearXNG credentials. Configure 'searx' in credgoo (URL@USERNAME@PASSWORD)"}

    base_url = creds["base_url"]
    username = creds["username"]
    password = creds["password"]
    search_endpoint = f"{base_url}/search"

    params = {
        "q": query,
        "format": format,
        "language": language,
        "safesearch": safesearch,
    }

    if engines:
        params["engines"] = ",".join(engines)
    if categories:
        params["categories"] = ",".join(categories)
    if time_range:
        params["time_range"] = time_range

    url = f"{search_endpoint}?{urllib.parse.urlencode(params)}"

    try:
        req = urllib.request.Request(url)

        if username and password:
            auth_string = f"{username}:{password}"
            b64_auth = __import__("base64").b64encode(auth_string.encode()).decode()
            req.add_header("Authorization", f"Basic {b64_auth}")

        with urllib.request.urlopen(req, timeout=timeout) as response:
            data = response.read().decode("utf-8")
            results = json.loads(data)

            if max_results and "results" in results:
                results["results"] = results["results"][:max_results]

            return results
    except urllib.error.URLError as e:
        return {"error": f"SearXNG request failed: {e.reason}"}
    except json.JSONDecodeError as e:
        return {"error": f"Invalid JSON from SearXNG: {e}"}
    except Exception as e:
        return {"error": f"SearXNG error: {e}"}


# ============================================================================
# Unified Search
# ============================================================================

def search(
    query: str,
    backend: str = "auto",
    max_results: Optional[int] = None,
    region: Optional[str] = None,
    safesearch: Optional[str] = None,
    exact: Optional[bool] = None,
    page: Optional[int] = None,
    timelimit: Optional[str] = None,
    proxy: Optional[str] = None,
    verify: Optional[bool] = None,
    bearer: Optional[str] = None,
    api_url: Optional[str] = None,
    timeout: Optional[int] = None,
    engines: Optional[List[str]] = None,
    categories: Optional[List[str]] = None,
    language: str = "en",
    time_range: Optional[str] = None,
    args: Optional[argparse.Namespace] = None,
) -> Union[List[Dict[str, Any]], Dict[str, Any]]:
    """Perform a web search with automatic backend selection."""
    
    # Auto-select backend if needed
    if backend == "auto" and args is not None:
        backend = select_backend(args)
    
    if backend == "searxng":
        return search_searxng(
            query=query,
            max_results=max_results,
            engines=engines,
            categories=categories,
            language=language,
            time_range=time_range,
            safesearch=0 if safesearch == "off" else 1 if safesearch == "moderate" else 2,
            timeout=timeout or 30
        )
    else:
        return search_duckduckgo(
            query=query,
            max_results=max_results,
            region=region,
            safesearch=safesearch,
            exact=exact,
            page=page,
            timelimit=timelimit,
            backend=backend,
            proxy=proxy,
            verify=verify,
            bearer=bearer,
            api_url=api_url,
            timeout=timeout
        )


# ============================================================================
# Output Formatting
# ============================================================================

def format_ddg_results(results: List[Dict[str, Any]]) -> str:
    """Format DuckDuckGo results as markdown."""
    if not results:
        return "No results found."

    output: List[str] = []
    for result in results:
        title: str = result.get('title', 'No title')
        url: str = result.get('href', '') or result.get('url', '')
        body: str = result.get('body', '')

        if body:
            output.append(f"- [**{title}**]({url})\n  {body}\n")
        else:
            output.append(f"- [**{title}**]({url})\n")

    return '\n'.join(output)


def format_searxng_results(results: Dict[str, Any], query: str, limit: int = 5) -> str:
    """Format SearXNG results as markdown."""
    if "error" in results:
        return f"Error: {results['error']}"

    if "results" not in results or not results["results"]:
        return "No results found."

    output: List[str] = []
    output.append(f"# Search Results for '{query}'\n")

    count = 0
    for result in results["results"]:
        if count >= limit:
            break

        title = result.get("title", "No Title")
        url = result.get("url", "#")
        content = result.get("content", "")
        source = result.get("engine", "Unknown")

        if content is None:
            content = ""

        output.append(f"- [**{title}**]({url})\n  {content}\n  Source: {source}\n")
        count += 1

    return '\n'.join(output)


# ============================================================================
# Main
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Search the web with automatic backend selection',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "react hooks"
  %(prog)s "python tutorial" --site github.com
  %(prog)s "research papers" --filetype pdf
  %(prog)s "latest AI news" --timelimit d
  %(prog)s "python error" --exact
  %(prog)s "tutorial" --exclude youtube,video
  %(prog)s "cats" --categories images
  %(prog)s "news" --time-range day
        """
    )

    parser.add_argument('query', help='Search query')
    parser.add_argument('--max', type=int, default=10, help='Maximum results (default: 10)')
    parser.add_argument('--region', default='wt-wt', help='Region code (e.g., us-en, de-de)')
    parser.add_argument('--safesearch', choices=['off', 'moderate', 'strict'], default='moderate')
    parser.add_argument('--exact', action='store_true', help='Exact phrase matching')
    parser.add_argument('--page', type=int, default=1, help='Page number')
    parser.add_argument('--site', help='Filter by domain')
    parser.add_argument('--filetype', help='Filter by file extension (pdf, txt)')
    parser.add_argument('--inurl', help='Filter by URL fragment')
    parser.add_argument('--exclude', help='Comma-separated terms to exclude')
    parser.add_argument('--timelimit', choices=['d', 'w', 'm', 'y'], help='Time filter: d/w/m/y')
    parser.add_argument('--proxy', help='Proxy URL')
    parser.add_argument('--verify', type=lambda x: x.lower() in ('true', '1', 'yes', 'on'), default=True)
    parser.add_argument('--bearer', help='Bearer token override')
    parser.add_argument('--api-url', help='Custom API endpoint')
    parser.add_argument('--timeout', type=int, default=30, help='Request timeout')

    # Advanced options (auto-detect backend)
    parser.add_argument('--categories', help='Filter by category (images, news, videos)')
    parser.add_argument('--engines', help='Comma-separated engine names')
    parser.add_argument('--time-range', choices=['day', 'week', 'month', 'year'], help='Time range')
    parser.add_argument('--language', default='en', help='Language code')
    
    # Backend control (mostly hidden - auto is default)
    parser.add_argument('--backend', default='auto', 
                        choices=['auto', 'duckduckgo', 'searxng'],
                        help='Search backend (auto-detect by default)')

    parser.add_argument('--json', action='store_true', help='Output raw JSON')
    parser.add_argument('--verbose', action='store_true', help='Show which backend was chosen')

    args = parser.parse_args()

    # Auto-select backend
    backend = select_backend(args)
    
    if args.verbose:
        print(f"# Using backend: {backend}", file=sys.stderr)

    # Get credentials
    bearer = args.bearer or get_bearer_token()

    # Parse list arguments
    categories = args.categories.split(",") if args.categories else None
    engines = args.engines.split(",") if args.engines else None

    # Build query
    if backend == "duckduckgo":
        query = build_ddg_query(args)
    else:
        query = args.query

    # Perform search
    results = search(
        query=query,
        backend=backend,
        max_results=args.max,
        region=args.region,
        safesearch=args.safesearch,
        exact=args.exact,
        page=args.page,
        timelimit=args.timelimit,
        proxy=args.proxy,
        verify=args.verify,
        bearer=bearer,
        api_url=args.api_url,
        timeout=args.timeout,
        engines=engines,
        categories=categories,
        language=args.language,
        time_range=args.time_range,
        args=args
    )

    # Output
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        if backend == "searxng":
            print(format_searxng_results(results, args.query, args.max))
        else:
            print(format_ddg_results(results))


if __name__ == '__main__':
    main()
