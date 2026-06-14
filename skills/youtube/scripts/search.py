#!/usr/bin/env python3
"""Search YouTube via Invidious API with smart ranking for fresh, long, deep content.

Default behavior ("deep mode"): fetches a large candidate pool of longform videos,
filters by freshness + view floor + duration, then re-ranks with a combined score
(recency + views + duration + relevance). Designed for finding fresh podcasts,
lectures, and deep dives — not 3-minute explainers.

Use --rank for raw single-dimension sorting (legacy mode): relevance, date, views, rating.
"""

import sys
import json
import urllib.request
import urllib.parse
import urllib.error
import os
import re
import time
import math
import argparse
from typing import List, Optional, Dict, Any

# ── Instance management ───────────────────────────────────────────────────────

DEFAULT_INSTANCES = [
    "invidious.materialio.us",
    "yt.chocolatemoo53.com",
    "yt.tarka.dev",
]

CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".instance-cache.json")
CACHE_TTL = 4 * 60 * 60

# ── Deep-mode tuning ──────────────────────────────────────────────────────────

RECENCY_HALFLIFE_DAYS = 180  # recency decays by half every 6 months
FETCH_MULTIPLIER = 5  # fetch num * this many candidates, then filter + rerank
DEFAULT_MIN_VIEWS = 1000
DEFAULT_MIN_DURATION_S = 20 * 60  # 20 minutes (longform)
DEFAULT_MAX_AGE = "18m"  # generous "fresh" window


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
    h, remainder = divmod(seconds, 3600)
    m, s = divmod(remainder, 60)
    return f"{h}:{m}:{s:02d}"


def format_views(count: Any) -> str:
    """Format view count compactly (1.2M, 45K, 980)."""
    try:
        count = int(count)
    except (ValueError, TypeError):
        return "N/A"
    if count >= 1_000_000:
        return f"{count / 1_000_000:.1f}M views"
    if count >= 1_000:
        return f"{count / 1_000:.0f}K views"
    return f"{count} views"


def format_age(published: Any, now: float) -> str:
    """Human-readable age from a unix timestamp."""
    try:
        published = int(published)
        days = max(0, (now - published) / 86400)
    except (ValueError, TypeError):
        return "unknown age"
    if days < 1:
        return "today"
    if days < 30:
        return f"{int(days)}d ago"
    if days < 365:
        return f"{int(days / 30)}mo ago"
    return f"{days / 365:.1f}yr ago"


def parse_age_spec(spec: str) -> Optional[float]:
    """Parse '3m', '1y', '2w', '14d', 'all' → max age in seconds. None = no limit.

    Args:
        spec: Age specification string.

    Returns:
        Seconds, or None for no limit.

    Raises:
        ValueError: If the spec is unparseable.
    """
    spec = spec.strip().lower()
    if spec in ("all", "any", "0", "off", ""):
        return None
    units = {"d": 86400, "w": 604800, "m": 2_592_000, "y": 31_536_000}
    m = re.match(r"^(\d+)\s*([dwmy])$", spec)
    if not m:
        raise ValueError(f"bad age spec: {spec!r} (use e.g. 3m, 1y, 2w, 14d, all)")
    return int(m.group(1)) * units[m.group(2)]


# ── Instance discovery (cached, self-healing) ─────────────────────────────────

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
        req = urllib.request.Request(url, headers={"User-Agent": "youtube-skill/1.1"})
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
        try:
            test_url = f"https://{host}/api/v1/search?q=test&type=video"
            req = urllib.request.Request(test_url, headers={"User-Agent": "youtube-skill/1.1"})
            with urllib.request.urlopen(req, timeout=6) as resp:
                result = json.loads(resp.read().decode())
                if isinstance(result, list) and len(result) > 0:
                    working.append(host)
        except Exception:
            continue
    return working


def get_instances() -> List[str]:
    """Get ordered list of instances: cache → discover → hardcoded fallback."""
    cached = load_cached_instances()
    if cached:
        return cached
    discovered = discover_instances()
    if discovered:
        save_cached_instances(discovered)
        return discovered
    return DEFAULT_INSTANCES


# ── Search ────────────────────────────────────────────────────────────────────

def search_instance(
    host: str,
    query: str,
    num: int,
    api_sort: str,
    duration: Optional[str] = None,
) -> Optional[List[Dict[str, Any]]]:
    """Search a single Invidious instance.

    Args:
        host: Instance hostname.
        query: Search query string.
        num: Max number of results to return.
        api_sort: Invidious sort_by value.
        duration: '1' (short <4m), '2' (long >20m), '3' (medium 4-20m), or None (any).

    Returns:
        List of video dicts, or None on failure.
    """
    params: Dict[str, str] = {"q": query, "type": "video", "sort_by": api_sort}
    if duration:
        params["duration"] = duration
    url = f"https://{host}/api/v1/search?{urllib.parse.urlencode(params)}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "youtube-skill/1.1"})
        with urllib.request.urlopen(req, timeout=15) as response:
            data = json.loads(response.read().decode())
        if isinstance(data, list) and len(data) > 0:
            valid = [v for v in data if v.get("title") or v.get("videoId")]
            if valid:
                return valid[:num]
    except Exception:
        pass
    return None


# ── Deep-mode scoring and filtering ───────────────────────────────────────────

def _to_int(val: Any) -> int:
    """Defensive int coercion."""
    try:
        return int(val)
    except (ValueError, TypeError):
        return 0


def passes_filters(
    v: Dict[str, Any],
    now: float,
    min_views: int,
    max_age_s: Optional[float],
    min_duration_s: int,
) -> bool:
    """Hard filters: drop videos that don't meet floors."""
    if _to_int(v.get("viewCount", 0)) < min_views:
        return False
    if _to_int(v.get("lengthSeconds", 0)) < min_duration_s:
        return False
    if max_age_s is not None:
        pub = v.get("published")
        if isinstance(pub, (int, float)) and pub > 0:
            if (now - pub) > max_age_s:
                return False
    return True


def score_video(v: Dict[str, Any], rank: int, total: int, now: float) -> float:
    """Combined score 0.0–1.0: recency (0.35) + views (0.25) + duration (0.15) + relevance (0.25).

    Args:
        v: Video dict from Invidious API.
        rank: Original API rank position (0 = top).
        total: Total candidates in the pool.
        now: Current unix timestamp.

    Returns:
        Score in [0.0, 1.0]. Higher is better.
    """
    # Recency: exponential decay, half-life RECENCY_HALFLIFE_DAYS.
    pub = v.get("published")
    recency = 0.0
    if isinstance(pub, (int, float)) and pub > 0:
        age_days = max(0.0, (now - pub) / 86400.0)
        recency = 0.5 ** (age_days / RECENCY_HALFLIFE_DAYS)

    # Views: log-scale. 1K→0.50, 10K→0.67, 100K→0.83, 1M→1.0.
    vc = _to_int(v.get("viewCount", 0))
    views = min(1.0, math.log10(max(1, vc)) / 6.0) if vc > 0 else 0.0

    # Duration: 30min→0.5, 60min+→1.0. Rewards longform/podcasts.
    ls = _to_int(v.get("lengthSeconds", 0))
    duration = min(1.0, ls / 3600.0) if ls > 0 else 0.0

    # Relevance: API rank position. Top result = 1.0, last = 0.0.
    relevance = 1.0 - (rank / max(1, total))

    return recency * 0.35 + views * 0.25 + duration * 0.15 + relevance * 0.25


# ── Output ────────────────────────────────────────────────────────────────────

def print_results(
    results: List[Dict[str, Any]],
    host: str,
    now: float,
    show_score: bool = False,
    scored: Optional[List[tuple]] = None,
) -> None:
    """Print video results as markdown.

    Args:
        results: Ordered list of video dicts.
        host: Instance hostname (for watch links).
        now: Current timestamp (for age formatting).
        show_score: Show deep-mode score.
        scored: If provided, list of (score, video) tuples aligned with results.
    """
    for i, video in enumerate(results):
        title = video.get("title", "Untitled")
        video_id = video.get("videoId", "")
        author = video.get("author", "Unknown")
        views = format_views(video.get("viewCount", 0))
        published = video.get("published", 0)
        age = format_age(published, now)
        duration = format_duration(video.get("lengthSeconds", 0))
        link = f"https://{host}/watch?v={video_id}"
        score_str = f" `{scored[i][0]:.2f}`" if show_score and scored else ""
        print(
            f"- [**{title}**]({link}){score_str} — {author}"
            f" — {views} — {age} — {duration}"
        )


# ── Main ──────────────────────────────────────────────────────────────────────

def search_youtube(
    query: str,
    num: int = 5,
    rank_by: Optional[str] = None,
    deep: bool = True,
    min_views: int = DEFAULT_MIN_VIEWS,
    max_age_spec: str = DEFAULT_MAX_AGE,
    any_length: bool = False,
    verbose: bool = False,
) -> None:
    """Search YouTube with smart ranking or raw API sort.

    Args:
        query: Search query string.
        num: Number of results to return.
        rank_by: If set ('relevance'/'date'/'views'/'rating'), raw mode — no filtering/reranking.
        deep: If True and rank_by is None, use deep mode (filter + combined score).
        min_views: Minimum view count (deep mode only).
        max_age_spec: Max age spec like '6m', '1y', 'all' (deep mode only).
        any_length: If True, don't filter for longform (deep mode only).
        verbose: Print instance used to stderr.
    """
    now = time.time()
    raw_mode = rank_by is not None

    sort_map = {
        "relevance": "relevance",
        "date": "upload_date",
        "views": "view_count",
        "rating": "rating",
        "ranking": "rating",
    }

    if raw_mode:
        api_sort = sort_map.get(rank_by, "relevance")  # type: ignore[arg-type]
        fetch_n = num
        duration = None
        if verbose:
            mode = f"raw (--rank {rank_by})"
            print(f"Mode: {mode}", file=sys.stderr)
    else:
        api_sort = "relevance"
        fetch_n = num * FETCH_MULTIPLIER
        # Invidious duration codes: 1=short, 2=long(>20m), 3=medium.
        # Pass 2 at API level for longform, then enforce client-side too
        # (API filter is leaky — shorts slip through).
        duration = None if any_length else "2"
        max_age_s = parse_age_spec(max_age_spec)
        min_duration_s = 0 if any_length else DEFAULT_MIN_DURATION_S
        if verbose:
            extra = "any length" if any_length else f"longform >={DEFAULT_MIN_DURATION_S // 60}min"
            age_str = "all time" if max_age_s is None else f"<={max_age_spec}"
            print(
                f"Mode: deep (duration={duration or 'any'}, age={age_str}, "
                f"min_views>={min_views}, fetch={fetch_n}, return={num})",
                file=sys.stderr,
            )

    instances = get_instances()
    last_error = ""

    for host in instances:
        if verbose:
            print(f"Trying {host}...", file=sys.stderr)

        result = search_instance(host, query, fetch_n, api_sort, duration=duration)
        if result is None:
            last_error = f"No results from {host}"
            continue

        if raw_mode:
            print_results(result, host, now)
            return

        # Deep mode: filter, score, rerank.
        filtered = [
            v for v in result if passes_filters(v, now, min_views, max_age_s, min_duration_s)
        ]
        if not filtered:
            last_error = f"All {len(result)} candidates filtered out by {host}"
            continue

        scored = [
            (score_video(v, rank, len(filtered), now), v)
            for rank, v in enumerate(filtered)
        ]
        scored.sort(key=lambda sv: sv[0], reverse=True)
        top = scored[:num]

        if verbose:
            print(
                f"Fetched {len(result)}, passed filters {len(filtered)}, "
                f"returning top {len(top)}.",
                file=sys.stderr,
            )

        print_results([v for _, v in top], host, now, show_score=verbose, scored=top)
        return

    print(f"Error: all instances failed. {last_error}", file=sys.stderr)
    print("No results found.")
    sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Search YouTube via Invidious API — defaults to fresh, long, deep content",
    )
    parser.add_argument("query", nargs="?", default="", help="Search query")
    parser.add_argument("--num", type=int, default=5, help="Number of results (default: 5)")
    parser.add_argument(
        "--rank",
        choices=["relevance", "date", "views", "rating", "ranking"],
        default=None,
        help="Raw single-dimension sort (disables deep mode). "
        "Default: deep combined ranking.",
    )
    parser.add_argument(
        "--min-views",
        type=int,
        default=DEFAULT_MIN_VIEWS,
        help=f"Minimum view count, deep mode (default: {DEFAULT_MIN_VIEWS})",
    )
    parser.add_argument(
        "--fresh",
        type=str,
        default=DEFAULT_MAX_AGE,
        help=f"Max age: '3m', '1y', '2w', '14d', 'all' (default: {DEFAULT_MAX_AGE})",
    )
    parser.add_argument(
        "--any-length",
        action="store_true",
        help="Don't filter for longform (include shorts)",
    )
    parser.add_argument("--discover", action="store_true", help="Re-discover instances")
    parser.add_argument("-v", "--verbose", action="store_true", help="Show mode, instance, scores")

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

    if not args.query:
        parser.error("query is required")

    search_youtube(
        args.query,
        num=args.num,
        rank_by=args.rank,
        min_views=args.min_views,
        max_age_spec=args.fresh,
        any_length=args.any_length,
        verbose=args.verbose,
    )
