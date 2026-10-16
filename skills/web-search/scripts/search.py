#!/usr/bin/env python3
"""
Web Search - Unified search with public and private backends.
Defaults to public SearXNG instances (no credentials needed).
Supports private Duck API and SearXNG with credentials for better results.
"""

import argparse
import base64
import io
import json
import os
import sys
import urllib.parse
import urllib.request
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

# credgoo is a declared dependency (uv sync installs it into this skill's venv).
# The missing-key message is surfaced through `logging` at DEBUG — silent by
# default, opt-in loud. Configure a DEBUG handler to see "no key" diagnostics.
try:
    from credgoo import get_api_key
except ImportError:
    # Graceful fallback so importing this module never hard-fails when credgoo
    # isn't installed in the running interpreter (e.g. bare `python3` logic tests).
    # The launcher runs under the skill venv, where credgoo exists.
    def get_api_key(service, **kwargs):  # type: ignore
        return None


# =============================================================================
# Configuration
# =============================================================================

# Duck API base URL is config-based (env → credgoo), NOT baked into code.
# Point it at your own Duck-API host; if unset the duck backend is disabled
# and search falls back to SearXNG. credgoo key: DUCK_API_URL. The news
# endpoint is optional and defaults to the search URL when not set.

# Public SearXNG instances (no auth required)
PUBLIC_SEARXNG_INSTANCES = [
    "https://searx.be",
    "https://search.bus-hit.me",
    "https://search.rowie.at",
    "https://searx.fmac.xyz",
]

# Private instance (if configured)
PRIVATE_SEARXNG_URL = os.environ.get("SEARXNG_URL", "")

# Ad-click redirect URLs (bing/yahoo engine byproducts since the 2026-09
# ddgs/yahoo primary). Never organic results — strip them client-side.
_AD_URL_MARKERS = (
    "bing.com/aclick",
    "bing.com/aclk",
    "doubleclick.net",
    "google.com/aclk",
)


def filter_ads(results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Drop ad-click redirect rows (bing.com/aclick, doubleclick, ...)."""
    return [
        r for r in results
        if not any(marker in (r.get("href") or r.get("url") or "").lower()
                   for marker in _AD_URL_MARKERS)
    ]


# =============================================================================
# Credentials (Optional)
# =============================================================================

def _key_with_refresh(service: str) -> Optional[str]:
    """credgoo lookup: local cache first, refetch from source on miss/error.

    credgoo's own cache is the freshness authority — it carries a 7-day TTL
    (CREDGOO_CACHE_TTL_SECONDS), so a key added or rotated in the backend is
    picked up automatically. A cache miss therefore means "stale or absent",
    and one refetch is the correct response. No refresh gate lives here on
    purpose: a per-skill gate would need to track the backend's TTL, go stale
    of its own, and starve the second lookup of a multi-key skill.
    """
    try:
        if key := get_api_key(service):
            return key
    except Exception:
        pass  # network hiccup / backend down → try the source once
    try:
        return get_api_key(service, no_cache=True) or None
    except Exception:
        return None  # genuinely unavailable → caller falls back (SearXNG)


def get_bearer_token() -> Optional[str]:
    """Get bearer token from env or credgoo. No silent fallbacks."""
    if token := os.environ.get("WEB_SEARCH_BEARER"):
        return token

    return _key_with_refresh("WEB_SEARCH_BEARER")


def _resolve_url(env_key: str, credgoo_key: str) -> str:
    """Resolve a config URL from env var, then credgoo. Empty if unset."""
    if url := os.environ.get(env_key):
        return url
    return (_key_with_refresh(credgoo_key) or "").strip()


def get_duck_api_url() -> str:
    """Duck API base URL: env DUCK_API_URL → credgoo DUCK_API_URL → ''.

    This is the BASE (e.g. https://host/api/duck); the search and news
    endpoints are derived by appending /search and /news.
    """
    return _resolve_url("DUCK_API_URL", "DUCK_API_URL").rstrip("/")


def get_duck_search_url() -> str:
    """Duck search endpoint: {base}/search."""
    base = get_duck_api_url()
    return f"{base}/search" if base else ""


def get_duck_news_url() -> str:
    """Duck news endpoint: {base}/news (optional; empty when base unset)."""
    base = get_duck_api_url()
    return f"{base}/news" if base else ""


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
    if cred := get_api_key("searx"):
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

    # Duck API only if a token AND a configured endpoint URL exist.
    if get_bearer_token() and get_duck_api_url():
        # News is served natively by the Duck API (/duck/news, dedicated
        # news index with dates). Images/videos stay on SearXNG — the Duck
        # API has no equivalent.
        if args.categories:
            if args.categories.strip() == "news":
                return "duck"
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
    backend: Optional[str] = None,
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
    if backend:
        # ddgs engine override: comma list (yahoo,brave) or "auto"
        params["backend"] = backend

    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {bearer}"
    }

    try:
        resp = requests.get(
            get_duck_search_url(), params=params, headers=headers, timeout=(5, 45),
        )
        if resp.status_code == 404:
            # Server raises 404 for a genuinely empty result set —
            # that's "no results", not an error.
            return []
        if resp.status_code == 502:
            # All upstream backends failed or the box-wide ddgs queue is
            # saturated — retrying immediately just deepens the queue.
            return [{"error": "Duck API error 502 (all upstream backends "
                              "failed or the ddgs queue is saturated). "
                              "Retry in a few seconds."}]
        resp.raise_for_status()
        return filter_ads(resp.json().get("results", []))
    except requests.RequestException as e:
        safe_msg = str(e).split("Authorization")[0].rstrip(": ,")
        host = urllib.parse.urlparse(get_duck_search_url()).netloc
        return [{"error": f"Duck API request failed ({host}): {safe_msg}"}]
    except Exception as e:
        return [{"error": f"Duck API unexpected error "
                         f"({type(e).__name__}): {e}"}]


def search_duck_news(
    topic: str,
    max_results: int = 10,
    timelimit: Optional[str] = None,
    region: str = "wt-wt",
    safesearch: str = "off",
    page: Optional[int] = None,
    backend: Optional[str] = None,
    bearer: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """Search news via the Duck API /duck/news endpoint (requires token).

    Rows carry title/url/body/date/source. Server-side timelimit defaults
    to "m" (past month) when unset.
    """
    if not requests:
        raise RuntimeError("requests library required. Run: uv pip install requests")

    if not bearer:
        raise ValueError("Bearer token required. Set WEB_SEARCH_BEARER env var.")

    params: Dict[str, Any] = {
        "topic": topic,
        "max_results": max_results,
        "region": region,
        "safesearch": safesearch,
    }
    if timelimit:
        params["timelimit"] = timelimit
    if page:
        params["page"] = page
    if backend:
        params["backend"] = backend

    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {bearer}",
    }

    try:
        resp = requests.get(
            get_duck_news_url(), params=params, headers=headers, timeout=(5, 45),
        )
        if resp.status_code == 404:
            return []
        if resp.status_code == 502:
            return [{"error": "Duck news API error 502 (all upstream backends "
                              "failed or the ddgs queue is saturated). "
                              "Retry in a few seconds."}]
        resp.raise_for_status()
        return filter_ads(resp.json().get("results", []))
    except requests.RequestException as e:
        safe_msg = str(e).split("Authorization")[0].rstrip(": ,")
        host = urllib.parse.urlparse(get_duck_news_url()).netloc
        return [{"error": f"Duck news API request failed ({host}): "
                         f"{safe_msg}"}]
    except Exception as e:
        return [{"error": f"Duck news API unexpected error "
                         f"({type(e).__name__}): {e}"}]


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
    degraded: Optional[Dict[str, Any]] = None
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
                    data["results"] = filter_ads(data["results"])[:max_results]
                    data["_instance"] = instance
                    if not data["results"] and data.get("unresponsive_engines"):
                        # Degraded instance, not a genuine miss: every queried
                        # engine is suspended (CAPTCHA / access denied / 429).
                        # Try the next instance; keep this payload as last
                        # resort so the suspension stays visible (format_results).
                        if degraded is None:
                            degraded = data
                        dead = ", ".join(e for e, _ in data["unresponsive_engines"])
                        last_error = f"{instance}: engines suspended ({dead})"
                        continue
                return data
        except Exception as exc:
            last_error = f"{instance}: {exc}"
            continue

    if degraded is not None:
        return degraded
    detail = f" — last error: {last_error}" if last_error else ""
    return {"error": f"SearXNG error: all {len(instances_to_try)} instances "
                     f"failed{detail}"}


# =============================================================================
# SearXNG invocation + Duck fallback
# =============================================================================

def _duck_only_flags(args: argparse.Namespace) -> List[str]:
    """Flags only the Duck API supports (SearXNG ignores them)."""
    return [f for f, v in (
        ("--site", args.site), ("--filetype", args.filetype),
        ("--inurl", args.inurl), ("--exclude", args.exclude),
        ("--exact", args.exact),
    ) if v]


def _run_searxng_search(args: argparse.Namespace) -> Dict[str, Any]:
    """One SearXNG pass: private instance (if configured) first, then the
    public instance list. Serves as the primary SearXNG path and as the
    fallback when the Duck API errors (issue 2026-10-13: public SearXNG is
    the LAST resort, never the default)."""
    creds = get_searxng_credentials()
    instance_url = creds["url"] if creds else None
    auth = None
    if creds and creds.get("user") and creds.get("pass"):
        auth = base64.b64encode(
            f"{creds['user']}:{creds['pass']}".encode()
        ).decode()
    return search_searxng(
        query=args.query,
        max_results=args.max,
        categories=args.categories,
        engines=args.engines,
        time_range=args.time_range or (args.timelimit[0] if args.timelimit else None),
        language=args.language,
        instance_url=instance_url,
        auth=auth,
    )


def _searxng_fallback(
    args: argparse.Namespace, results: List[Dict[str, Any]],
) -> tuple:
    """Fall back from a failed Duck API call to SearXNG (one attempt).

    A Duck error row is a backend OUTAGE, not "no results" — retry the query
    via SearXNG instead of giving up. Every error names its origin (Duck API
    vs SearXNG) so the failure trail stays readable.

    Returns (results, fell_back). results is None when both backends failed
    (both errors already printed to stderr, origin-labeled).
    """
    if not (results and isinstance(results[0], dict) and "error" in results[0]):
        return results, False

    duck_error = results[0]["error"]
    print(f"Warning: {duck_error}", file=sys.stderr)

    is_news = bool(args.categories and args.categories.strip() == "news")
    if not is_news:
        unsupported = _duck_only_flags(args)
        if unsupported:
            print(f"Warning: {', '.join(unsupported)} cannot carry over to "
                  f"SearXNG (Duck-only filters).", file=sys.stderr)
    print("Warning: falling back to SearXNG (private instance first, then "
          "public instances)...", file=sys.stderr)

    sx = _run_searxng_search(args)
    if isinstance(sx, dict) and "error" in sx:
        print(f"Error: Duck API failed first: {duck_error}", file=sys.stderr)
        print(f"Error: SearXNG fallback failed too: {sx['error']}", file=sys.stderr)
        return None, True
    return sx, True


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
        if isinstance(results, dict) and results.get("unresponsive_engines"):
            dead = ", ".join(e for e, _ in results["unresponsive_engines"])
            where = results.get("_instance", "the instance")
            return (f"No results found for '{query}'.\n\n"
                    f"⚠ Instance degraded ({where}): all queried engines "
                    f"suspended — {dead}. Not a query miss; engines usually "
                    f"recover after their suspension window.")
        return f"No results found for '{query}'."

    lines = [f"# Results for '{query}'\n"]

    if verbose and isinstance(results, dict) and "_instance" in results:
        lines.append(f"_Instance: {results['_instance']}_\n")

    for i, r in enumerate(items[:limit], 1):
        title = r.get("title", "No title")
        url = r.get("href") or r.get("url", "")
        snippet = r.get("body") or r.get("content", "") or ""
        source = r.get("engine") or r.get("source") or ""
        date = (r.get("date") or "").strip()

        lines.append(f"{i}. [**{title}**]({url})")
        if date:
            # News rows (Duck /duck/news) carry an ISO date — keep the date part
            lines.append(f"   _{date[:10]}_")
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
  - Duck API: Set WEB_SEARCH_BEARER (token) + DUCK_API_URL (endpoint,
              env or credgoo) for advanced filters; news reuses DUCK_API_URL
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
    parser.add_argument("--backend", help="Duck API ddgs engine override: comma "
                        "list (yahoo,brave) or 'auto' (Duck backend only)")

    args = parser.parse_args()

    # Reject empty/whitespace queries up front — avoids a pointless 404 round-trip
    # to the Duck API (and empty SearXNG requests) with a clear local error.
    if not args.query or not args.query.strip():
        print("Error: query must not be empty", file=sys.stderr)
        sys.exit(1)

    # Select backend
    backend = select_backend(args)

    # Duck backend needs a configured endpoint URL (env/credgoo DUCK_API_URL).
    if backend == "duck" and not get_duck_api_url():
        print("Error: DUCK_API_URL not configured. Set the env var or add a "
              "credgoo key (DUCK_API_URL), or use --searxng for public search.",
              file=sys.stderr)
        sys.exit(1)

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

        # /duck/news has a dedicated endpoint (news index with dates);
        # text-search operators (site/filetype/inurl/exclude/exact) don't
        # apply there.
        if args.categories and args.categories.strip() == "news":
            news_flags = _duck_only_flags(args)
            if news_flags:
                print(f"Warning: {', '.join(news_flags)} ignored "
                      f"(not supported for news).", file=sys.stderr)
            results = search_duck_news(
                topic=args.query,
                max_results=args.max,
                timelimit=duck_timelimit,
                region=args.region,
                page=args.page if args.page > 1 else None,
                backend=args.backend,
                bearer=bearer,
            )
        else:
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
                backend=args.backend,
                bearer=bearer,
            )

        # Backend outage (error row) → one SearXNG attempt before giving up.
        results, fell_back = _searxng_fallback(args, results)
        if results is None:
            sys.exit(1)
        if fell_back:
            backend = "searxng"
            if args.verbose:
                print("# Backend: searxng (fallback)", file=sys.stderr)
    else:
        duck_only = _duck_only_flags(args)
        if duck_only:
            print(f"Warning: {', '.join(duck_only)} ignored (Duck API only). Use --api to force Duck backend.", file=sys.stderr)

        results = _run_searxng_search(args)

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
