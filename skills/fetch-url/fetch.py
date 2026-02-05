#!/usr/bin/env python3
"""
Fetch URL content using text-based browsers (w3m or lynx) or via API.
Extracts readable text from web pages without rendering.
"""

import os
import sys
import argparse
import subprocess
import platform
from pathlib import Path

requests = None
try:
    import requests
except ImportError:
    pass  # Will show error when API mode is actually used

# Configuration
SCRIPT_DIR = Path(__file__).parent
W3M_CONFIG = SCRIPT_DIR / "w3m_config"
LYNX_CONFIG = SCRIPT_DIR / "lynx_config"
DEFAULT_API_URL = "https://amd1.mooo.com/api/fetch_url"


def get_bearer_token():
    """Get bearer token from environment variable or .env file."""
    # Check environment variable first
    token = os.environ.get("FETCH_URL_BEARER") or os.environ.get("WEB_SEARCH_BEARER")
    if token:
        return token

    # Try to read from .env file in skill directory
    env_file = Path(__file__).parent / ".env"
    if env_file.exists():
        for line in env_file.read_text().strip().split('\n'):
            if line.startswith('FETCH_URL_BEARER=') or line.startswith('WEB_SEARCH_BEARER='):
                return line.split('=', 1)[1].strip()

    return None


def get_w3m_path():
    """Determine the correct path for w3m based on the OS."""
    if platform.system() == 'Linux':
        return '/usr/bin/w3m'
    else:
        return 'w3m'


def get_lynx_path():
    """Determine the correct path for lynx based on the OS."""
    if platform.system() == 'Linux':
        return '/usr/bin/lynx'
    else:
        return 'lynx'


def fetch_with_w3m(url: str, links: bool = False) -> str:
    """Fetch a webpage using w3m with a custom config and return the text output.

    Args:
        url: The URL to fetch
        links: Whether to display link numbers (default: False)

    Returns:
        The text content of the webpage

    Raises:
        RuntimeError: If w3m fails or times out
    """
    w3m_path = get_w3m_path()

    try:
        cmd = [
            w3m_path,
            '-config', str(W3M_CONFIG),
            '-o', f'display_link_number={1 if links else 0}',
            '-dump',
            url
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            timeout=30  # 30 second timeout
        )

        return result.stdout

    except subprocess.TimeoutExpired:
        raise RuntimeError(f"w3m request timed out after 30 seconds for URL: {url}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Failed to fetch page with w3m: {e.stderr}")
    except FileNotFoundError:
        raise RuntimeError("w3m not found. Install it with 'brew install w3m' on macOS or 'sudo apt-get install w3m' on Linux")


def fetch_with_lynx(url: str) -> str:
    """Fetch a webpage using Lynx with a custom config and return the text output.

    Args:
        url: The URL to fetch

    Returns:
        The text content of the webpage

    Raises:
        RuntimeError: If lynx fails or times out
    """
    lynx_path = get_lynx_path()

    try:
        cmd = [
            lynx_path,
            url,
            '-dump',
            '-cfg=', str(LYNX_CONFIG),
            '--display_charset=utf-8',
            '-accept_all_cookies',
            '-nomore'  # Don't pause at page boundaries
        ]

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True,
            timeout=30  # 30 second timeout
        )

        return result.stdout

    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Lynx request timed out after 30 seconds for URL: {url}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Failed to fetch page with Lynx: {e.stderr}")
    except FileNotFoundError:
        raise RuntimeError("Lynx not found. Install it with 'brew install lynx' on macOS or 'sudo apt-get install lynx' on Linux")


def fetch_via_api(url: str, tool: str = 'w3m', bearer: str = None, api_url: str = None) -> str:
    """Fetch a webpage via the API endpoint.

    Args:
        url: The URL to fetch
        tool: The tool to use ('w3m' or 'lynx', default: 'w3m')
        bearer: Bearer token for authentication
        api_url: API endpoint URL

    Returns:
        The text content of the webpage

    Raises:
        RuntimeError: If the API request fails
    """
    if requests is None:
        raise RuntimeError("'requests' library is required for API mode. Install with: pip3 install requests")

    if not bearer:
        bearer = get_bearer_token()
    if not bearer:
        raise ValueError("Bearer token is required for API mode. Set FETCH_URL_BEARER or WEB_SEARCH_BEARER environment variable or create a .env file.")

    api_url = api_url or DEFAULT_API_URL

    # Ensure URL has protocol
    url = url.strip()
    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url

    params = {
        'url': url,
        'tool': tool
    }

    headers = {
        'accept': 'application/json',
        'Authorization': f'Bearer {bearer}'
    }

    try:
        response = requests.get(api_url, params=params, headers=headers, timeout=30)
        response.raise_for_status()
        data = response.json()
        return data.get('content', '')
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"API request failed: {e}")
    except (ValueError, KeyError) as e:
        raise RuntimeError(f"Failed to parse API response: {e}")


def fetch_url(url: str, tool: str = 'w3m', links: bool = False, use_api: bool = False,
              bearer: str = None, api_url: str = None) -> str:
    """Fetch a webpage using the specified text-based browser or via API.

    Args:
        url: The URL to fetch
        tool: The browser to use ('w3m' or 'lynx', default: 'w3m')
        links: Whether to display link numbers (only for w3m, default: False)
        use_api: Whether to use the API instead of local tools
        bearer: Bearer token for API mode
        api_url: API endpoint URL

    Returns:
        The text content of the webpage

    Raises:
        ValueError: If tool is not 'w3m' or 'lynx'
        RuntimeError: If the fetch operation fails
    """
    if use_api:
        return fetch_via_api(url, tool, bearer, api_url)

    url = url.strip()

    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url

    if tool == 'w3m':
        return fetch_with_w3m(url, links)
    elif tool == 'lynx':
        return fetch_with_lynx(url)
    else:
        raise ValueError(f"Invalid tool: {tool}. Use 'w3m' or 'lynx'.")


def clean_output(text: str, remove_empty_lines: bool = True) -> str:
    """Clean the output text.

    Args:
        text: The text to clean
        remove_empty_lines: Whether to remove consecutive empty lines

    Returns:
        The cleaned text
    """
    if remove_empty_lines:
        # Remove consecutive empty lines
        lines = text.split('\n')
        cleaned = []
        prev_empty = False
        for line in lines:
            is_empty = not line.strip()
            if is_empty and prev_empty:
                continue
            cleaned.append(line)
            prev_empty = is_empty
        text = '\n'.join(cleaned)

    return text.strip()


def main():
    parser = argparse.ArgumentParser(
        description='Fetch and extract text content from web URLs using text-based browsers or via API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Fetch using local w3m
  %(prog)s "https://example.com"

  # Fetch using local lynx
  %(prog)s "example.com" --tool lynx

  # Fetch via API
  %(prog)s "https://orf.at" --api

  # Fetch via API with custom bearer token
  %(prog)s "https://orf.at" --api --bearer YOUR_TOKEN

  # Fetch with link numbers (w3m only)
  %(prog)s "https://docs.python.org" --tool w3m --links

  # Pipe to grep
  %(prog)s "https://github.com" | grep -i python
        """
    )

    parser.add_argument('url', help='URL to fetch (http:// or https:// will be added if missing)')
    parser.add_argument('--tool', choices=['w3m', 'lynx'], default='w3m',
                        help='Text browser to use (default: w3m)')
    parser.add_argument('--links', action='store_true',
                        help='Display link numbers in output (w3m only)')
    parser.add_argument('--clean', action='store_true',
                        help='Remove consecutive empty lines from output')
    parser.add_argument('--api', action='store_true',
                        help='Use API instead of local tools')
    parser.add_argument('--api-url',
                        help='Custom API endpoint URL (default: https://amd1.mooo.com/api/fetch_url)')
    parser.add_argument('--bearer',
                        help='Bearer token for API authentication (overrides FETCH_URL_BEARER env var)')

    args = parser.parse_args()

    try:
        content = fetch_url(
            args.url,
            args.tool,
            args.links,
            use_api=args.api,
            bearer=args.bearer,
            api_url=args.api_url
        )
        if args.clean:
            content = clean_output(content)
        print(content)
    except (ValueError, RuntimeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
