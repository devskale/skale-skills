#!/usr/bin/env python3
"""
DuckDuckGo Web Search via API
Performs text searches with rich filters and pagination support.
"""

# Standard library imports
import os
import sys
import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Optional

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
DEFAULT_API_URL = "https://amd1.mooo.com/api/duck/search"

def get_bearer_token() -> Optional[str]:
    """Get bearer token from environment variable, credgoo, or .env file.

    Priority order:
    1. Environment variable (WEB_SEARCH_BEARER)
    2. credgoo (if available)
    3. .env file

    Returns:
        The bearer token string if found, None otherwise.
    """
    # Check environment variable first
    token = os.environ.get("WEB_SEARCH_BEARER")
    if token:
        return token

    # Try credgoo if available
    if credgoo is not None:
        try:
            token = credgoo.get_api_key("web-search")
            if token:
                return token
        except Exception:
            # Silently fail if credgoo is not configured
            pass

    # Try to read from .env file in skill directory (parent of scripts/)
    env_file: Path = Path(__file__).parent.parent / ".env"
    if env_file.exists():
        for line in env_file.read_text().strip().split('\n'):
            if line.startswith('WEB_SEARCH_BEARER='):
                return line.split('=', 1)[1].strip()

    return None

def build_query(args: argparse.Namespace) -> str:
    """Build the search query with DuckDuckGo operators.

    Args:
        args: Parsed command-line arguments containing query and filters.

    Returns:
        The constructed query string with operators.
    """
    query: str = args.query

    # Add operators if specified via flags
    if args.site:
        query = f"site:{args.site} {query}"
    if args.filetype:
        query = f"filetype:{args.filetype} {query}"
    if args.inurl:
        query = f"inurl:{args.inurl} {query}"

    # Handle exclusions
    if args.exclude:
        for term in args.exclude.split(','):
            term = term.strip()
            if term:
                query = f"{query} -{term}"

    # Handle exact phrase matching
    if args.exact:
        query = f'"{query}"'

    return query.strip()

def search(
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
    """Perform a DuckDuckGo search via the API.

    Args:
        query: Search query string.
        max_results: Maximum number of results to return.
        region: Region code (e.g., wt-wt, us-en, de-de).
        safesearch: Safe search level (off, moderate, strict).
        exact: Whether to use exact phrase matching.
        page: Page number for pagination.
        timelimit: Time range filter (d, w, m, y).
        backend: Search backend (auto, all, bing, brave, duckduckgo, google, mojeek, yandex, yahoo, wikipedia).
        proxy: Proxy URL (e.g., socks5h://127.0.0.1:9150).
        verify: Verify SSL certificates.
        bearer: Bearer token for authentication.
        api_url: Custom API endpoint URL.
        timeout: Request timeout in seconds.

    Returns:
        List of search result dictionaries.

    Raises:
        ValueError: If bearer token is not provided.
    """
    if not bearer:
        raise ValueError("Bearer token is required. Set WEB_SEARCH_BEARER environment variable or create a .env file.")

    params: Dict[str, Any] = {'query': query}

    # Add optional parameters
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

    # Use custom API URL if provided, otherwise use default
    url: str = api_url or DEFAULT_API_URL
    request_timeout: int = timeout or 30

    try:
        response = requests.get(url, params=params, headers=headers, timeout=request_timeout)
        response.raise_for_status()
        data = response.json()
        return data.get('results', [])
    except requests.exceptions.RequestException as e:
        print(f"Error performing search: {e}", file=sys.stderr)
        if hasattr(e, 'response') and e.response is not None:
            print(f"Response: {e.response.text}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error parsing response: {e}", file=sys.stderr)
        sys.exit(1)

def format_results(results: List[Dict[str, Any]]) -> str:
    """Format search results as markdown.

    Args:
        results: List of search result dictionaries.

    Returns:
        Formatted markdown string of results.
    """
    if not results:
        return "No results found."

    output: List[str] = []
    for result in results:
        title: str = result.get('title', 'No title')
        url: str = result.get('url', '')
        body: str = result.get('body', '')

        # Format as markdown link with description
        if body:
            output.append(f"- [**{title}**]({url})\n  {body}\n")
        else:
            output.append(f"- [**{title}**]({url})\n")

    return '\n'.join(output)

def main():
    parser = argparse.ArgumentParser(
        description='Search the web using DuckDuckGo via API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "rust programming"
  %(prog)s "async await" --site developer.mozilla.org
  %(prog)s "research papers" --filetype pdf --max 25
  %(prog)s "exact phrase" --exact
  %(prog)s "python tutorial" --exclude youtube,video
  %(prog)s "latest news" --timelimit d --max 20
  %(prog)s "ai developments" --backend google --region us-en
  %(prog)s "search results" --proxy socks5h://127.0.0.1:9150
        """
    )

    parser.add_argument('query', help='Search query')
    parser.add_argument('--max', type=int, default=10,
                        help='Maximum number of results (default: 10)')
    parser.add_argument('--region', default='wt-wt',
                        help='Region code (default: wt-wt, e.g., us-en, de-de)')
    parser.add_argument('--safesearch', choices=['off', 'moderate', 'strict'],
                        default='moderate',
                        help='Safe search level (default: moderate)')
    parser.add_argument('--exact', action='store_true',
                        help='Use exact phrase matching (quote the query)')
    parser.add_argument('--page', type=int, default=1,
                        help='Page number for pagination (default: 1)')
    parser.add_argument('--site',
                        help='Filter to specific domain (e.g., github.com)')
    parser.add_argument('--filetype',
                        help='Filter by file extension (e.g., pdf, txt)')
    parser.add_argument('--inurl',
                        help='Filter by URL fragment')
    parser.add_argument('--exclude',
                        help='Comma-separated list of terms/domains to exclude')
    parser.add_argument('--timelimit', choices=['d', 'w', 'm', 'y'],
                        help='Time range filter: d (day), w (week), m (month), y (year)')
    parser.add_argument('--backend',
                        choices=['auto', 'all', 'bing', 'brave', 'duckduckgo', 'google', 'mojeek', 'yandex', 'yahoo', 'wikipedia'],
                        help='Search backend provider')
    parser.add_argument('--proxy',
                        help='Proxy URL (e.g., socks5h://127.0.0.1:9150)')
    parser.add_argument('--verify', type=lambda x: x.lower() in ('true', '1', 'yes', 'on'), default=True,
                        help='Verify SSL certificates (default: True)')
    parser.add_argument('--bearer',
                        help='Bearer token (overrides WEB_SEARCH_BEARER env var)')
    parser.add_argument('--api-url',
                        help='Custom API endpoint URL')
    parser.add_argument('--timeout', type=int, default=30,
                        help='Request timeout in seconds (default: 30)')

    args = parser.parse_args()

    # Get bearer token
    bearer = args.bearer or get_bearer_token()

    # Build query with operators
    query = build_query(args)

    # Perform search
    results = search(
        query=query,
        max_results=args.max,
        region=args.region,
        safesearch=args.safesearch,
        exact=args.exact,
        page=args.page,
        timelimit=args.timelimit,
        backend=args.backend,
        proxy=args.proxy,
        verify=args.verify,
        bearer=bearer,
        api_url=args.api_url,
        timeout=args.timeout
    )

    # Output results
    print(format_results(results))

if __name__ == '__main__':
    main()
