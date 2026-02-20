#!/usr/bin/env python3
import json
import os
import sys
import urllib.parse
import urllib.request
import argparse
from typing import Dict, Any, List, Optional

# Configure UTF-8 encoding for stdout (especially important on Windows)
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

try:
    from credgoo import get_api_key
except ImportError:
    # Fallback for when running without the virtual environment active
    # This ensures the script can still provide a helpful error message
    get_api_key = None


def search(
    query: str,
    engines: Optional[List[str]] = None,
    categories: Optional[List[str]] = None,
    language: str = "en",
    time_range: Optional[str] = None,
    safesearch: int = 0,
    format: str = "json",
) -> Dict[str, Any]:
    """
    Search using the SearXNG instance with credentials from credgoo.
    """
    if get_api_key is None:
        return {"error": "credgoo library not found. Please install it: uv pip install -r https://skale.dev/credgoo"}

    try:
        # Get credentials from credgoo
        # Format: URL@USERNAME@PASSWORD
        cred_string = get_api_key("searx")
        if not cred_string:
             return {"error": "No credentials found for 'searx' in credgoo."}
             
        parts = cred_string.split("@")
        if len(parts) != 3:
            return {"error": f"Invalid credential format. Expected URL@USERNAME@PASSWORD, got {len(parts)} parts."}
            
        base_url, username, password = parts
        search_endpoint = f"{base_url}/search"
        
    except Exception as e:
        return {"error": f"Failed to retrieve credentials: {e}"}

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

        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read().decode("utf-8")
            return json.loads(data)
    except urllib.error.URLError as e:
        return {"error": f"Request failed: {e.reason}"}
    except json.JSONDecodeError as e:
        return {"error": f"Invalid JSON response: {e}"}


def print_markdown(results: Dict[str, Any], query: str, limit: int = 5):
    """Format and print results as Markdown."""
    if "results" not in results:
        if "error" in results:
            print(f"Error: {results['error']}")
        else:
            print("No results found.")
        return

    print(f"# Search Results for '{query}'\n")
    
    count = 0
    for result in results["results"]:
        if count >= limit:
            break
            
        title = result.get("title", "No Title")
        url = result.get("url", "#")
        content = result.get("content", "")
        source = result.get("engine", "Unknown Source")
        
        # Clean up content (sometimes it's None)
        if content is None:
            content = ""
            
        print(f"## [{title}]({url})")
        print(f"**Source:** {source}")
        if content:
            print(f"\n{content}")
        print("\n---\n")
        
        count += 1


def main():
    parser = argparse.ArgumentParser(description="Search SearXNG.")
    parser.add_argument("query", help="The search query string")
    parser.add_argument("--num", type=int, default=5, help="Number of results to return (default: 5)")
    parser.add_argument("--categories", help="Comma-separated list of categories (e.g., news,images)")
    parser.add_argument("--engines", help="Comma-separated list of engines (e.g., google,bing)")
    parser.add_argument("--time", help="Time range (day, week, month, year)")
    parser.add_argument("--language", default="en", help="Language code (default: en)")
    parser.add_argument("--json", action="store_true", help="Output raw JSON instead of Markdown")

    args = parser.parse_args()

    categories = args.categories.split(",") if args.categories else None
    engines = args.engines.split(",") if args.engines else None

    results = search(
        query=args.query,
        engines=engines,
        categories=categories,
        language=args.language,
        time_range=args.time
    )

    if args.json:
        if "error" in results:
            print(f"Error: {results['error']}", file=sys.stderr)
            sys.exit(1)
        print(json.dumps(results, indent=2))
    else:
        print_markdown(results, args.query, args.num)


if __name__ == "__main__":
    main()
