#!/usr/bin/env python3
import json
import os
import sys
import urllib.parse
import urllib.request
from typing import Dict, Any, List, Optional

SEARXNG_BASE_URL = "https://neusiedl.duckdns.org:8002"
SEARCH_ENDPOINT = f"{SEARXNG_BASE_URL}/search"


def load_config(config_path: str) -> Optional[Dict[str, str]]:
    """
    Load authentication credentials from config file.

    Config file should be JSON with format:
    {
      "username": "your_username",
      "password": "your_password"
    }
    """
    if not os.path.exists(config_path):
        return None

    try:
        with open(config_path, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return None


def search(
    query: str,
    config_path: Optional[str] = None,
    engines: Optional[List[str]] = None,
    categories: Optional[List[str]] = None,
    language: str = "en",
    time_range: Optional[str] = None,
    safesearch: int = 0,
    format: str = "json",
) -> Dict[str, Any]:
    """
    Search using the SearXNG instance.

    Args:
        query: The search query string
        config_path: Path to config.json with credentials (default: ./config.json)
        engines: List of search engines to use (e.g., ['google', 'bing'])
        categories: List of categories to search (e.g., ['general', 'images'])
        language: Language code (default: 'en')
        time_range: Time filter (e.g., 'day', 'week', 'month', 'year')
        safesearch: Safe search level (0-2)
        format: Response format (default: 'json', also supports 'html', 'csv')

    Returns:
        Dict with search results
    """
    if config_path is None:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        config_path = os.path.join(script_dir, "..", "config.json")

    if not os.path.exists(config_path):
        print(f"Error: Configuration file not found at {config_path}")
        print("Please run the setup script to configure credentials:")
        print(f"  {os.path.join(os.path.dirname(os.path.abspath(__file__)), 'setup.py')}")
        sys.exit(1)

    config = load_config(config_path)

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

    url = f"{SEARCH_ENDPOINT}?{urllib.parse.urlencode(params)}"

    try:
        req = urllib.request.Request(url)

        if config and "username" in config and "password" in config:
            auth_string = f"{config['username']}:{config['password']}"
            b64_auth = __import__("base64").b64encode(auth_string.encode()).decode()
            req.add_header("Authorization", f"Basic {b64_auth}")

        with urllib.request.urlopen(req, timeout=30) as response:
            data = response.read().decode("utf-8")
            return json.loads(data)
    except urllib.error.URLError as e:
        return {"error": f"Request failed: {e.reason}"}
    except json.JSONDecodeError as e:
        return {"error": f"Invalid JSON response: {e}"}


def main():
    if len(sys.argv) < 2:
        print("Usage: search.py <query> [--config <path>] [--engines <engines>] [--categories <categories>] [--language <lang>] [--time <range>]", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    args = sys.argv[2:]

    config_path = None
    engines = None
    categories = None
    language = "en"
    time_range = None

    i = 0
    while i < len(args):
        if args[i] == "--config" and i + 1 < len(args):
            config_path = args[i + 1]
            i += 2
        elif args[i] == "--engines" and i + 1 < len(args):
            engines = args[i + 1].split(",")
            i += 2
        elif args[i] == "--categories" and i + 1 < len(args):
            categories = args[i + 1].split(",")
            i += 2
        elif args[i] == "--language" and i + 1 < len(args):
            language = args[i + 1]
            i += 2
        elif args[i] == "--time" and i + 1 < len(args):
            time_range = args[i + 1]
            i += 2
        else:
            i += 1

    results = search(query, config_path=config_path, engines=engines, categories=categories, language=language, time_range=time_range)

    if "error" in results:
        print(f"Error: {results['error']}", file=sys.stderr)
        sys.exit(1)

    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
