#!/usr/bin/env python3
"""Search YouTube videos via Invidious API with automatic instance fallback."""

import sys
import json
import urllib.request
import urllib.parse
import urllib.error
import os
import time
import argparse
from typing import List, Optional, Dict, Any


# Default fallback instances (checked in order)
DEFAULT_INSTANCES = [
    "invidious.materialio.us",
    "yt.chocolatemoo53.com",
    "yt.tarka.dev",
]

# Cache file for discovered instances
CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".instance-cache.json")

# How long to trust cached instances (4 hours)
CACHE_TTL = 4 * 60 * 60


def format_duration(seconds: Any) -> str:
    """Format seconds into MM:SS or H:MM:SS.

    Args:
        seconds: Duration in seconds (int, float, or string).

    Returns:
        Formatted duration string.
    """
    try:
        seconds = int(seconds)
    except (ValueError, TypeError):
        return "Unknown"

    if seconds < 3600:
        m, s = divmod(seconds, 60)
        return f"{m}:{s:02d}"
    else:
        h, remainder = divmod(seconds, 3600)
        m, s = divmod(remainder, 60)
        return f"{h}:{m}:{s:02d}"


def load_cached_instances() -> List[str]:
    """Load instances from cache if fresh enough.

    Returns:
        List of instance hostnames, or empty list if cache is stale/missing.
    """
    try:
        if not os.path.exists(CACHE_FILE):
            return []
        with open(CACHE_FILE, "r") as f:
            cache = json.load(f)
        if time.time() - cache.get("ts", 0) < CACHE_TTL:
            return cache.get("instances", [])
    except (json.JSONDecodeError, OSError, KeyError):
        pass
    return []


def save_cached_instances(instances: List[str]) -> None:
    """Save working instances to cache.

    Args:
        instances: List of instance hostnames.
    """
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump({"ts": time.time(), "instances": instances}, f)
    except OSError:
        pass


def discover_instances() -> List[str]:
    """Fetch and test instances from api.invidious.io.

    Returns:
        List of HTTPS instance hostnames that respond to search API.
    """
    url = "https://api.invidious.io/instances.json"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "youtube-skill/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, json.JSONDecodeError, OSError):
        return []

    working: List[str] = []
    for name, info in data:
        inst = info if isinstance(info, dict) else (info[0] if isinstance(info, list) else {})
        uri = inst.get("uri", "")
        if not uri.startswith("https://"):
            continue
        host = uri.replace("https://", "").rstrip("/")
        # Quick test: does /api/v1/search return JSON with video entries?
        try:
            test_url = f"https://{host}/api/v1/search?q=test&type=video"
            req = urllib.request.Request(test_url, headers={"User-Agent": "youtube-skill/1.0"})
            with urllib.request.urlopen(req, timeout=6) as resp:
                body = resp.read().decode()
                result = json.loads(body)
                if isinstance(result, list) and len(result) > 0:
                    working.append(host)
        except Exception:
            continue

    return working


def get_instances() -> List[str]:
    """Get ordered list of instances: cache → discover → hardcoded fallback.

    Returns:
        Ordered list of instance hostnames.
    """
    # 1. Try cache
    cached = load_cached_instances()
    if cached:
        return cached

    # 2. Try discovery (can be slow, but we cache the result)
    discovered = discover_instances()
    if discovered:
        save_cached_instances(discovered)
        return discovered

    # 3. Hardcoded fallback
    return DEFAULT_INSTANCES


def search_instance(host: str, query: str, num: int, api_sort: str) -> Optional[List[Dict[str, Any]]]:
    """Search a single Invidious instance.

    Args:
        host: Instance hostname.
        query: Search query string.
        num: Max number of results.
        api_sort: Sort parameter for the API.

    Returns:
        List of video dicts, or None on failure.
    """
    params = {"q": query, "type": "video", "sort_by": api_sort}
    url = f"https://{host}/api/v1/search?{urllib.parse.urlencode(params)}"

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "youtube-skill/1.0"})
        with urllib.request.urlopen(req, timeout=15) as response:
            data = json.loads(response.read().decode())

        if not data:
            return None

        # Validate it's actual video results (skip garbage entries)
        if isinstance(data, list) and len(data) > 0:
            valid = [v for v in data if v.get("title") or v.get("videoId")]
            if valid:
                return valid[:num]
    except Exception:
        pass
    return None


def search_youtube(query: str, num: int = 5, sort_by: str = "relevance", verbose: bool = False) -> None:
    """Search YouTube via Invidious API with automatic fallback.

    Tries instances in order until one returns results.

    Args:
        query: Search query string.
        num: Maximum number of results to return.
        sort_by: Sort order (relevance, date, views, rating).
        verbose: Print instance used to stderr.
    """
    sort_map = {
        "relevance": "relevance",
        "date": "upload_date",
        "views": "view_count",
        "rating": "rating",
        "ranking": "rating",
    }
    api_sort = sort_map.get(sort_by, "relevance")

    instances = get_instances()
    last_error = ""

    for host in instances:
        if verbose:
            print(f"Trying {host}...", file=sys.stderr)

        result = search_instance(host, query, num, api_sort)
        if result is None:
            last_error = f"No results from {host}"
            continue

        for video in result:
            title = video.get("title", "Untitled")
            video_id = video.get("videoId", "")
            author = video.get("author", "Unknown Author")
            view_count = video.get("viewCountText", "N/A views")
            published = video.get("publishedText", "Unknown date")
            length_seconds = video.get("lengthSeconds", 0)

            duration = format_duration(length_seconds)
            link = f"https://{host}/watch?v={video_id}"

            print(
                f"- [**{title}**]({link}) by {author}"
                f" - {view_count} - {published} - Duration: {duration}"
            )
        return

    print(f"Error: all instances failed. {last_error}", file=sys.stderr)
    print("No results found.")
    sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Search YouTube videos via Invidious API")
    parser.add_argument("query", nargs="?", default="", help="Search query")
    parser.add_argument(
        "--num", type=int, default=3, help="Number of results (default: 3)"
    )
    parser.add_argument(
        "--rank",
        choices=["relevance", "date", "views", "rating", "ranking"],
        default="relevance",
        help="Sort order (default: relevance)",
    )
    parser.add_argument(
        "--discover", action="store_true", help="Force re-discovery of instances"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Show which instance is used"
    )

    args = parser.parse_args()

    if args.discover:
        discovered = discover_instances()
        if discovered:
            save_cached_instances(discovered)
            print(f"Discovered {len(discovered)} working instances:")
            for inst in discovered:
                print(f"  {inst}")
        else:
            print("No working instances found.")
        sys.exit(0)

    search_youtube(args.query, num=args.num, sort_by=args.rank, verbose=args.verbose)
