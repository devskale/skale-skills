#!/usr/bin/env python3
"""YouTube search via Invidious — find fresh, long, deep content; curate it into lists.

v2 — list-centric:
  youtube "<query>" [filters]        → search, save ./lists/<slug>.md, print path + preview
  youtube "<query>" --stdout         → print only (legacy behaviour)
  youtube expand  --like <url> | --channel <id> | --more "<q>" [--list <name>]
  youtube exclude --channel <X> [--list <name>]
  youtube dedup   [--list <name>]
  youtube channel --fav|--block <name|id> | --list

Zero external dependencies (stdlib only). Backend: public Invidious API with
automatic instance fallback. A global channel store (~/.config/youtube-skill/
channels.md) auto-excludes blocked channels and boosts favourites on every query.
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
from typing import List, Optional, Dict, Any, Tuple

# ── Instance management ───────────────────────────────────────────────────────

DEFAULT_INSTANCES = [
    "invidious.materialio.us",
    "yt.chocolatemoo53.com",
    "yt.tarka.dev",
]

CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".instance-cache.json")
CACHE_TTL = 4 * 60 * 60
UA = "youtube-skill/2.0"

# ── Deep-mode tuning ──────────────────────────────────────────────────────────

RECENCY_HALFLIFE_DAYS = 180
DEFAULT_MIN_VIEWS = 1000
DEFAULT_MIN_DURATION_S = 20 * 60  # 20 min (longform)
DEFAULT_MAX_AGE = "18m"
DEFAULT_POOL = 30        # candidates fetched + filtered + ranked
DEFAULT_NUM = 8          # surfaced as Picks (rest → Candidates)
FAV_BOOST = 1.25         # score multiplier for favourite channels

# Ranking presets → (recency, views, duration, relevance) weights.
PRESETS: Dict[str, Tuple[float, float, float, float]] = {
    "deep": (0.35, 0.25, 0.15, 0.25),
    "trending": (0.45, 0.40, 0.05, 0.10),
    "fresh": (0.60, 0.15, 0.10, 0.15),
}

# ── Channel preference store (global) ────────────────────────────────────────

CHANNELS_FILE = os.path.expanduser("~/.config/youtube-skill/channels.md")
LISTS_DIR = os.path.join(os.getcwd(), "lists")


# ╔ Formatting helpers ════════════════════════════════════════════════════════

def format_duration(seconds: Any) -> str:
    try:
        seconds = int(seconds)
    except (ValueError, TypeError):
        return "?"
    if seconds < 3600:
        m, s = divmod(seconds, 60)
        return f"{m}:{s:02d}"
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{h}:{m}:{s:02d}"


def format_views(count: Any) -> str:
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


def slugify(text: str) -> str:
    text = (text or "").strip().lower()
    text = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return text[:60] or "search"


def parse_age_spec(spec: str) -> Optional[float]:
    """'3m','1y','2w','14d','all' → max age in seconds (None = no limit)."""
    spec = (spec or "").strip().lower()
    if spec in ("all", "any", "0", "off", ""):
        return None
    units = {"d": 86400, "w": 604800, "m": 2_592_000, "y": 31_536_000}
    m = re.match(r"^(\d+)\s*([dwmy])$", spec)
    if not m:
        raise ValueError(f"bad age spec: {spec!r} (use e.g. 3m, 1y, 2w, 14d, all)")
    return int(m.group(1)) * units[m.group(2)]


def _to_int(val: Any) -> int:
    try:
        return int(val)
    except (ValueError, TypeError):
        return 0


# ╔ Instance discovery (cached, self-healing) ══════════════════════════════════

def _get_json(url: str, timeout: int = 15) -> Any:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def load_cached_instances() -> List[str]:
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
    try:
        with open(CACHE_FILE, "w") as f:
            json.dump({"ts": time.time(), "instances": instances}, f)
    except OSError:
        pass


def discover_instances() -> List[str]:
    try:
        data = _get_json("https://api.invidious.io/instances.json", timeout=10)
    except Exception:
        return []
    working: List[str] = []
    for name, info in data:
        inst = info if isinstance(info, dict) else (info[0] if isinstance(info, list) else {})
        uri = inst.get("uri", "")
        if not uri.startswith("https://"):
            continue
        host = uri.replace("https://", "").rstrip("/")
        try:
            result = _get_json(f"https://{host}/api/v1/search?q=test&type=video", timeout=6)
            if isinstance(result, list) and result:
                working.append(host)
        except Exception:
            continue
    return working


def get_instances() -> List[str]:
    cached = load_cached_instances()
    if cached:
        return cached
    discovered = discover_instances()
    if discovered:
        save_cached_instances(discovered)
        return discovered
    return DEFAULT_INSTANCES


# ╔ Channel preference store ════════════════════════════════════════════════════

def load_channels() -> Dict[str, Dict[str, str]]:
    """Return {'fav': {ucid: name}, 'block': {ucid: name}}."""
    channels: Dict[str, Dict[str, str]] = {"fav": {}, "block": {}}
    section: Optional[str] = None
    if not os.path.exists(CHANNELS_FILE):
        return channels
    try:
        for raw in open(CHANNELS_FILE, encoding="utf-8"):
            line = raw.rstrip("\n")
            if line.startswith("# Favorite"):
                section = "fav"
            elif line.startswith("# Blocked"):
                section = "block"
            elif section and "|" in line:
                body = line.strip().lstrip("- ").strip()
                ucid, _, name = body.partition("|")
                ucid, name = ucid.strip(), name.strip()
                if ucid:
                    channels[section][ucid] = name
    except OSError:
        pass
    return channels


def save_channels(channels: Dict[str, Dict[str, str]]) -> None:
    os.makedirs(os.path.dirname(CHANNELS_FILE), exist_ok=True)
    out: List[str] = ["# Favorite channels"]
    for ucid, name in channels["fav"].items():
        out.append(f"{ucid} | {name}")
    out += ["", "# Blocked channels"]
    for ucid, name in channels["block"].items():
        out.append(f"{ucid} | {name}")
    try:
        with open(CHANNELS_FILE, "w", encoding="utf-8") as f:
            f.write("\n".join(out) + "\n")
    except OSError as e:
        print(f"Error: could not write {CHANNELS_FILE}: {e}", file=sys.stderr)


def resolve_channel(name_or_id: str) -> Optional[Tuple[str, str]]:
    """Resolve a channel name (or pass through a UCID) → (ucid, name)."""
    s = (name_or_id or "").strip()
    if re.match(r"^UC[A-Za-z0-9_-]{10,}$", s):
        return (s, s)
    for host in get_instances():
        try:
            data = _get_json(
                f"https://{host}/api/v1/search?q={urllib.parse.quote(s)}&type=channel", timeout=10
            )
            for ch in data if isinstance(data, list) else []:
                if ch.get("authorId"):
                    return (ch["authorId"], ch.get("author", s))
        except Exception:
            continue
    return None


# ╔ Invidious search primitives ═════════════════════════════════════════════════

def search_instance(
    host: str,
    query: str,
    num: int,
    api_sort: str = "relevance",
    duration: Optional[str] = None,
    features: Optional[str] = None,
    region: Optional[str] = None,
) -> Optional[List[Dict[str, Any]]]:
    params: Dict[str, str] = {"q": query, "type": "video", "sort_by": api_sort}
    if duration:
        params["duration"] = duration
    if features:
        params["features"] = features
    if region:
        params["region"] = region
    url = f"https://{host}/api/v1/search?{urllib.parse.urlencode(params)}"
    try:
        data = _get_json(url)
        if isinstance(data, list) and data:
            valid = [v for v in data if v.get("title") or v.get("videoId")]
            return valid[:num] if valid else None
    except Exception:
        return None
    return None


def search_channel(host: str, ucid: str, query: str, num: int) -> Optional[List[Dict[str, Any]]]:
    """Search within a channel (/channels/{ucid}/search). Empty query → latest videos."""
    if query:
        url = f"https://{host}/api/v1/channels/{ucid}/search?{urllib.parse.urlencode({'q': query, 'type': 'video'})}"
    else:
        url = f"https://{host}/api/v1/channels/{ucid}/videos"
    try:
        data = _get_json(url)
        vids = data if query else data.get("videos", []) if isinstance(data, dict) else data
        if isinstance(vids, list) and vids:
            return [v for v in vids if v.get("videoId")][:num]
    except Exception:
        return None
    return None


def get_related(host: str, video_id: str) -> Optional[List[Dict[str, Any]]]:
    """Recommended/related videos for a given video (/videos/{id})."""
    try:
        data = _get_json(f"https://{host}/api/v1/videos/{video_id}")
        rel = data.get("recommendedVideos") or data.get("relatedStreams") or []
        return [v for v in rel if v.get("videoId")]
    except Exception:
        return None


def video_id_from_url(s: str) -> str:
    m = re.search(r"(?:v=|youtu\.be/|/embed/)([A-Za-z0-9_-]{6,})", s)
    return m.group(1) if m else s.strip()


# ╔ Deep-mode scoring + filtering ══════════════════════════════════════════════

def passes_filters(
    v: Dict[str, Any],
    now: float,
    min_views: int,
    max_age_s: Optional[float],
    min_duration_s: int,
    max_duration_s: Optional[int],
    blocked: Dict[str, str],
    exclude_channels: List[str],
) -> bool:
    if _to_int(v.get("viewCount", 0)) < min_views:
        return False
    ls = _to_int(v.get("lengthSeconds", 0))
    if ls < min_duration_s:
        return False
    if max_duration_s is not None and ls > max_duration_s:
        return False
    if max_age_s is not None:
        pub = v.get("published")
        if isinstance(pub, (int, float)) and pub > 0 and (now - pub) > max_age_s:
            return False
    # Channel exclusions: blocked store (by UCID) + per-query --exclude-channel.
    author_id = v.get("authorId", "")
    if author_id and author_id in blocked:
        return False
    author = (v.get("author") or "").lower()
    if author_id and any(author_id.lower() == x.lower() for x in exclude_channels):
        return False
    if author and any(x.lower() in author for x in exclude_channels):
        return False
    return True


def score_video(
    v: Dict[str, Any],
    rank: int,
    total: int,
    now: float,
    weights: Tuple[float, float, float, float],
    favs: Dict[str, str],
) -> float:
    w_rec, w_views, w_dur, w_rel = weights
    pub = v.get("published")
    recency = 0.0
    if isinstance(pub, (int, float)) and pub > 0:
        age_days = max(0.0, (now - pub) / 86400.0)
        recency = 0.5 ** (age_days / RECENCY_HALFLIFE_DAYS)
    vc = _to_int(v.get("viewCount", 0))
    views = min(1.0, math.log10(max(1, vc)) / 6.0) if vc > 0 else 0.0
    ls = _to_int(v.get("lengthSeconds", 0))
    duration = min(1.0, ls / 3600.0) if ls > 0 else 0.0
    relevance = 1.0 - (rank / max(1, total))
    score = recency * w_rec + views * w_views + duration * w_dur + relevance * w_rel
    if v.get("authorId") and v["authorId"] in favs:
        score *= FAV_BOOST
    return score


# ╔ The list artifact (./lists/<slug>.md) ═══════════════════════════════════════

VIDEO_ID_RE = re.compile(r"(?:youtube\.com/watch\?v=|youtu\.be/|/embed/)([A-Za-z0-9_-]{6,})")
UCID_RE = re.compile(r"ucid:(UC[A-Za-z0-9_-]+)")


def entry_line(v: Dict[str, Any], now: float, score: Optional[float] = None) -> str:
    title = v.get("title", "Untitled")
    vid = v.get("videoId", "")
    author = v.get("author", "Unknown")
    ucid = v.get("authorId", "")
    score_str = f" ★{score:.2f}" if score is not None else ""
    ucid_str = f" ucid:{ucid}" if ucid else ""
    return (
        f"- [**{title}**](https://www.youtube.com/watch?v={vid}) — {author}"
        f" · {format_duration(v.get('lengthSeconds', 0))}"
        f" · {format_views(v.get('viewCount', 0))}"
        f" · {format_age(v.get('published', 0), now)}{score_str}{ucid_str}"
    )


def write_list(
    path: str,
    topic: str,
    picks: List[Tuple[float, Dict[str, Any]]],
    candidates: List[Tuple[float, Dict[str, Any]]],
    now: float,
    meta: str,
) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)

    def section(title_: str, items: List[Tuple[float, Dict[str, Any]]]) -> List[str]:
        lines = [f"## {title_}"] if items else []
        for score, v in items:
            lines.append(entry_line(v, now, score=score))
        return lines + ([""] if items else [])

    out: List[str] = [f"# {topic}", meta, ""]
    out += section("Picks", picks)
    out += section("Candidates", candidates)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out).rstrip() + "\n")


def parse_list_entries(text: str):
    """Yield (lineno, raw, video_id, ucid) for every entry that carries a video URL."""
    for i, raw in enumerate(text.splitlines()):
        m = VIDEO_ID_RE.search(raw)
        if not m:
            continue
        um = UCID_RE.search(raw)
        yield (i, raw, m.group(1), um.group(1) if um else "")


def entry_channel(raw: str) -> str:
    """Extract the channel name from an entry line: '... ) — Channel · dur · ...'."""
    m = re.search(r"\)\s*—\s*(.+?)\s*·", raw)
    return m.group(1).strip() if m else ""


def resolve_list_path(name: Optional[str]) -> Optional[str]:
    """Resolve a list by bare name (with/without .md) or path; default = newest in ./lists/."""
    if name:
        p = name if os.path.isabs(name) or os.sep in name else os.path.join(LISTS_DIR, name)
        if not p.endswith(".md"):
            p += ".md"
        return p if os.path.exists(p) else None
    if not os.path.isdir(LISTS_DIR):
        return None
    mds = [os.path.join(LISTS_DIR, f) for f in os.listdir(LISTS_DIR) if f.endswith(".md")]
    return max(mds, key=os.path.getmtime) if mds else None


# ╔ Stdout output (legacy / --stdout) ══════════════════════════════════════════

def print_results(results: List[Dict[str, Any]], now: float, show_score: bool = False,
                  scored: Optional[List[Tuple[float, Dict[str, Any]]]] = None) -> None:
    for i, video in enumerate(results):
        score_str = f" ★{scored[i][0]:.2f}" if show_score and scored else ""
        print(
            f"- [**{video.get('title', 'Untitled')}**](https://www.youtube.com/watch?v={video.get('videoId', '')})"
            f" — {video.get('author', 'Unknown')}{score_str}"
            f" — {format_views(video.get('viewCount', 0))}"
            f" — {format_age(video.get('published', 0), now)}"
            f" — {format_duration(video.get('lengthSeconds', 0))}"
        )


# ╔ Search + list building ══════════════════════════════════════════════════════

def do_search(args) -> int:
    now = time.time()
    raw_mode = args.rank is not None
    # Blocked channels always excluded; favourites skipped only with --no-favs.
    channels = load_channels()
    blocked = channels["block"]
    favs = {} if args.no_favs else channels["fav"]

    weights = PRESETS.get(args.preset, PRESETS["deep"])

    # Resolve --channel (name → UCID) once.
    channel_ucid: Optional[str] = None
    if args.channel:
        resolved = resolve_channel(args.channel)
        if not resolved:
            print(f"Error: could not resolve channel {args.channel!r}", file=sys.stderr)
            return 1
        channel_ucid = resolved[0]
        if args.verbose:
            print(f"Channel: {resolved[1]} ({resolved[0]})", file=sys.stderr)

    sort_map = {"relevance": "relevance", "date": "upload_date", "views": "view_count",
                "rating": "rating", "ranking": "rating"}
    api_sort = sort_map.get(args.rank, "relevance") if raw_mode else "relevance"

    if raw_mode:
        fetch_n = args.num
        duration = features = region = None
    else:
        fetch_n = args.pool
        duration = None if args.any_length else "2"
        features = "subtitles" if args.captions else None
        region = args.region
        max_age_s = parse_age_spec(args.fresh)
        min_duration_s = 0 if args.any_length else args.min_duration
        max_duration_s = args.max_duration
        if args.verbose:
            print(f"Mode: preset={args.preset} pool={fetch_n} top={args.num} "
                  f"captions={bool(features)} region={region or '-'} favs={len(favs)} "
                  f"blocked={len(blocked)}", file=sys.stderr)

    exclude_channels = [c.strip() for c in (args.exclude_channel or []) if c.strip()]

    for host in get_instances():
        if args.verbose:
            print(f"Trying {host}...", file=sys.stderr)
        if channel_ucid:
            result = search_channel(host, channel_ucid, args.query, fetch_n)
        else:
            result = search_instance(host, args.query, fetch_n, api_sort,
                                     duration=duration, features=features, region=region)
        if not result:
            continue

        if raw_mode:
            print_results(result, now)
            return 0

        filtered = [v for v in result if passes_filters(
            v, now, args.min_views, parse_age_spec(args.fresh),
            0 if args.any_length else args.min_duration, args.max_duration, blocked, exclude_channels)]
        if not filtered:
            continue

        scored = [(score_video(v, rank, len(filtered), now, weights, favs), v)
                  for rank, v in enumerate(filtered)]
        scored.sort(key=lambda sv: sv[0], reverse=True)
        picks = scored[: args.num]
        candidates = scored[args.num:]

        if args.verbose:
            print(f"Fetched {len(result)}, passed {len(filtered)}, "
                  f"picks {len(picks)}, candidates {len(candidates)}.", file=sys.stderr)

        if args.stdout:
            print_results([v for _, v in picks], now, show_score=args.verbose, scored=picks)
            return 0

        # Auto-save list.
        slug = slugify(args.save) if args.save else slugify(args.query)
        path = os.path.join(LISTS_DIR, f"{slug}.md")
        meta = (f"_Search: {time.strftime('%Y-%m-%d', time.localtime(now))} · "
                f"pool {len(result)} · preset {args.preset} · "
                f"`{args.query}`" + (f" · channel:{channel_ucid}" if channel_ucid else "") + "_")
        write_list(path, args.query or slug, picks, candidates, now, meta)
        print(path)
        # Preview: first ~6 lines so the agent/user sees what landed.
        with open(path, encoding="utf-8") as f:
            preview = [next(f, "") for _ in range(6)]
        sys.stderr.write("".join(preview).rstrip() + "\n")
        return 0

    print("Error: all instances failed or no results passed filters.", file=sys.stderr)
    return 1


# ╔ Subcommands ════════════════════════════════════════════════════════════════

def cmd_expand(rest: List[str]) -> int:
    p = argparse.ArgumentParser(prog="youtube expand", description="Append candidates to a list")
    p.add_argument("--like", help="video URL/ID — append more from its channel")
    p.add_argument("--channel", help="channel name/UCID — append that channel's videos")
    p.add_argument("--more", help="run another search and append its results")
    p.add_argument("--list", help="target list name (default: newest in ./lists/)")
    p.add_argument("--num", type=int, default=10)
    a = p.parse_args(rest)
    if not (a.like or a.channel or a.more):
        p.error("need one of --like / --channel / --more")

    path = resolve_list_path(a.list)
    if not path:
        print("Error: no target list. Run a search first, or pass --list <name>.", file=sys.stderr)
        return 1

    # Decide what to fetch. --like and --channel both resolve to a UCID and pull
    # more from that channel; --more is a fresh topic search. (Invidious's
    # /videos/{id} recommendedVideos is widely blocked, so --like resolves the
    # channel from the list entry's stored ucid: first, /videos/{id} as fallback.)
    ucid: Optional[str] = None
    if a.like:
        vid = video_id_from_url(a.like)
        raw_line = ""
        for _ln, raw, eid, eu in parse_list_entries(open(path, encoding="utf-8").read()):
            if eid == vid:
                ucid = eu
                raw_line = raw
                break
        # Fallback 1: resolve the channel NAME from the entry line (reliable —
        # uses channel search; works when Invidious omits authorId).
        if not ucid and raw_line:
            name = entry_channel(raw_line)
            if name:
                resolved = resolve_channel(name)
                if resolved:
                    ucid = resolved[0]
        # Fallback 2: the /videos/{id} endpoint (widely blocked on Invidious).
        if not ucid:
            for host in get_instances():
                try:
                    vd = _get_json(f"https://{host}/api/v1/videos/{vid}", timeout=8)
                    ucid = vd.get("authorId") or ""
                    if ucid:
                        break
                except Exception:
                    pass
        if not ucid:
            print("Error: couldn't resolve that video's channel (it's not in the list "
                  "and Invidious /videos is unavailable). Use --channel <name> or --more \"<topic>\".",
                  file=sys.stderr)
            return 1
    elif a.channel:
        resolved = resolve_channel(a.channel)
        if not resolved:
            print(f"Error: could not resolve channel {a.channel!r}", file=sys.stderr)
            return 1
        ucid = resolved[0]

    new: List[Dict[str, Any]] = []
    for host in get_instances():
        if ucid:
            new = search_channel(host, ucid, "", a.num) or []
        else:
            new = search_instance(host, a.more, a.num) or []
        if new:
            break
    if not new:
        print("Error: found nothing to add.", file=sys.stderr)
        return 1

    now = time.time()
    existing = {vid_ for _ln, _raw, vid_, _u in parse_list_entries(open(path, encoding="utf-8").read())}
    additions = [v for v in new if v.get("videoId") not in existing][: a.num]
    if not additions:
        print(f"Nothing new to add (all {len(new)} already in the list).")
        return 0
    with open(path, "a", encoding="utf-8") as f:
        f.write("\n## Expanded\n\n")
        for v in additions:
            f.write(entry_line(v, now) + "\n")
    print(f"Appended {len(additions)} new to {path}")
    return 0


def cmd_exclude(rest: List[str]) -> int:
    p = argparse.ArgumentParser(prog="youtube exclude", description="Bulk-remove entries from a list")
    p.add_argument("--channel", action="append", default=[], help="channel name or UCID (repeatable)")
    p.add_argument("--list", help="target list name (default: newest in ./lists/)")
    a = p.parse_args(rest)
    if not a.channel:
        p.error("need --channel (name or UCID)")
    path = resolve_list_path(a.list)
    if not path:
        print("Error: no target list.", file=sys.stderr)
        return 1
    terms = [c.lower() for c in a.channel]
    lines = open(path, encoding="utf-8").read().splitlines()
    kept, dropped = [], 0
    for raw in lines:
        m = VIDEO_ID_RE.search(raw)
        if not m:
            kept.append(raw)
            continue
        um = UCID_RE.search(raw)
        ucid = um.group(1).lower() if um else ""
        author = raw.lower()
        if (ucid and ucid in terms) or any(t in author for t in terms):
            dropped += 1
        else:
            kept.append(raw)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(kept).rstrip() + "\n")
    print(f"Removed {dropped} entr{'y' if dropped == 1 else 'ies'} from {path}")
    return 0


def cmd_dedup(rest: List[str]) -> int:
    p = argparse.ArgumentParser(prog="youtube dedup", description="Remove duplicate videos (by ID) from a list")
    p.add_argument("--list", help="target list name (default: newest in ./lists/)")
    a = p.parse_args(rest)
    path = resolve_list_path(a.list)
    if not path:
        print("Error: no target list.", file=sys.stderr)
        return 1
    lines = open(path, encoding="utf-8").read().splitlines()
    seen, kept, dropped = set(), [], 0
    for raw in lines:
        m = VIDEO_ID_RE.search(raw)
        if not m:
            kept.append(raw)
            continue
        if m.group(1) in seen:
            dropped += 1
        else:
            seen.add(m.group(1))
            kept.append(raw)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(kept).rstrip() + "\n")
    print(f"Removed {dropped} duplicate{'s' if dropped != 1 else ''} from {path}")
    return 0


def cmd_channel(rest: List[str]) -> int:
    p = argparse.ArgumentParser(prog="youtube channel", description="Manage favourite/blocked channels")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--fav", help="add a channel to favourites (name or UCID)")
    g.add_argument("--block", help="add a channel to the blocklist (name or UCID)")
    p.add_argument("--list", action="store_true", help="show current favourites/blocks")
    a = p.parse_args(rest)
    channels = load_channels()
    if a.list or not (a.fav or a.block):
        fav = channels["fav"]
        block = channels["block"]
        print(f"~/.config/youtube-skill/channels.md")
        print(f"Favourites ({len(fav)}):")
        for ucid, name in fav.items():
            print(f"  {ucid} | {name}")
        print(f"Blocked ({len(block)}):")
        for ucid, name in block.items():
            print(f"  {ucid} | {name}")
        return 0
    target = a.fav or a.block
    bucket = "fav" if a.fav else "block"
    resolved = resolve_channel(target)
    if not resolved:
        print(f"Error: could not resolve channel {target!r}", file=sys.stderr)
        return 1
    ucid, name = resolved
    channels[bucket][ucid] = name
    # If it's in the opposite bucket, remove it.
    opp = "block" if bucket == "fav" else "fav"
    channels[opp].pop(ucid, None)
    save_channels(channels)
    verb = "Favourited" if bucket == "fav" else "Blocked"
    print(f"{verb} {name} ({ucid})")
    return 0


# ╔ Main / dispatch ═════════════════════════════════════════════════════════════

SUBCOMMANDS = {
    "expand": cmd_expand,
    "exclude": cmd_exclude,
    "dedup": cmd_dedup,
    "channel": cmd_channel,
}


def main() -> int:
    raw = sys.argv[1:]
    if raw and raw[0] in SUBCOMMANDS:
        return SUBCOMMANDS[raw[0]](raw[1:])

    parser = argparse.ArgumentParser(
        description="YouTube via Invidious — find fresh/long/deep content; save a curated list",
    )
    parser.add_argument("query", nargs="?", default="", help="Search query")
    parser.add_argument("--num", type=int, default=DEFAULT_NUM, help=f"Picks to surface (default {DEFAULT_NUM})")
    parser.add_argument("--pool", type=int, default=DEFAULT_POOL, help=f"Candidates to fetch (default {DEFAULT_POOL})")
    parser.add_argument("--preset", choices=list(PRESETS), default="deep", help="Ranking preset (default deep)")
    parser.add_argument("--rank", choices=["relevance", "date", "views", "rating", "ranking"],
                        default=None, help="Raw single-dimension sort (disables deep mode)")
    # Filters — existing
    parser.add_argument("--min-views", type=int, default=DEFAULT_MIN_VIEWS)
    parser.add_argument("--fresh", default=DEFAULT_MAX_AGE, help="Max age: 3m/1y/2w/14d/all")
    parser.add_argument("--any-length", action="store_true", help="Include shorts")
    # Filters — new
    parser.add_argument("--captions", action="store_true", help="Only videos with subtitles")
    parser.add_argument("--channel", help="Search within a channel (name or UCID)")
    parser.add_argument("--exclude-channel", action="append", default=[], help="Drop a channel (repeatable)")
    parser.add_argument("--min-duration", type=int, default=DEFAULT_MIN_DURATION_S,
                        help="Min duration seconds (default 1200)")
    parser.add_argument("--max-duration", type=int, default=None, help="Max duration seconds")
    parser.add_argument("--region", help="Region code (e.g. US, DE)")
    parser.add_argument("--no-favs", action="store_true", help="Disable favourite-channel boost")
    # Output
    parser.add_argument("--stdout", action="store_true", help="Print to stdout (don't save a list)")
    parser.add_argument("--save", help="Name the list explicitly (overrides slug)")
    parser.add_argument("--discover", action="store_true", help="Re-discover Invidious instances")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(raw)

    if args.discover:
        discovered = discover_instances()
        if discovered:
            save_cached_instances(discovered)
            print(f"Discovered {len(discovered)} working instances:")
            for inst in discovered:
                print(f"  {inst}")
        else:
            print("No working instances found.")
        return 0

    if not args.query:
        parser.error("query is required (or use a subcommand: expand|exclude|dedup|channel)")

    return do_search(args)


if __name__ == "__main__":
    sys.exit(main())
