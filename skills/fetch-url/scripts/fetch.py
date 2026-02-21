#!/usr/bin/env python3
"""
Fetch URL content using text-based browsers (w3m or lynx) or via API.
Supports markdown.new and Jina.ai Reader for clean markdown output.
Auto-selects best tool for platform with automatic fallback.
Extracts readable text from web pages without rendering.
"""

import os
import sys
import argparse
import subprocess
import platform as platform_module
import json
from pathlib import Path
from typing import Dict, List, Optional, Any

requests = None
try:
    import requests
except ImportError:
    pass  # Will show error when API mode is actually used

# Configuration
SCRIPT_DIR = Path(__file__).parent
SKILL_DIR = SCRIPT_DIR.parent  # Config files are in skill root, not scripts/
W3M_CONFIG = SKILL_DIR / "w3m_config"
LYNX_CONFIG = SKILL_DIR / "lynx_config"
SETTINGS_FILE = SKILL_DIR / "settings.json"
DEFAULT_API_URL = "https://amd1.mooo.com/api/fetch_url"
MARKDOWN_NEW_URL = "https://markdown.new"
JINA_READER_URL = "https://r.jina.ai"


def load_settings() -> Dict[str, Any]:
    """Load settings from settings.json."""
    if SETTINGS_FILE.exists():
        try:
            return json.loads(SETTINGS_FILE.read_text())
        except json.JSONDecodeError:
            pass
    return get_default_settings()


def get_default_settings() -> Dict[str, Any]:
    """Return default settings if settings.json not found."""
    return {
        "tools": {
            "w3m": {"platforms": ["Darwin", "Linux"], "requires_install": True},
            "lynx": {"platforms": ["Darwin", "Linux"], "requires_install": True},
            "markdown": {"platforms": ["Darwin", "Linux", "Windows"], "requires_install": False},
            "jina": {"platforms": ["Darwin", "Linux", "Windows"], "requires_install": False},
        },
        "defaults": {
            "Darwin": ["w3m", "jina", "markdown", "lynx"],
            "Linux": ["w3m", "jina", "markdown", "lynx"],
            "Windows": ["jina", "markdown"]
        },
        "fallback_order": ["jina", "markdown", "w3m", "lynx"],
        "timeout": 30
    }


def get_platform() -> str:
    """Get current platform name."""
    system = platform_module.system()
    if system == "Darwin":
        return "Darwin"
    elif system == "Linux":
        return "Linux"
    elif system == "Windows":
        return "Windows"
    return system


def get_available_tools(settings: Dict[str, Any]) -> List[str]:
    """Get list of tools available for current platform."""
    current_platform = get_platform()
    available = []
    for tool_name, tool_config in settings.get("tools", {}).items():
        if current_platform in tool_config.get("platforms", []):
            available.append(tool_name)
    return available


def get_default_tool(settings: Dict[str, Any]) -> str:
    """Get default tool for current platform."""
    current_platform = get_platform()
    defaults = settings.get("defaults", {})
    platform_defaults = defaults.get(current_platform, ["jina", "markdown"])
    available = get_available_tools(settings)

    # Return first available default
    for tool in platform_defaults:
        if tool in available:
            return tool
    return "jina"  # Fallback to jina (works everywhere)


def check_tool_available(tool: str, settings: Dict[str, Any]) -> bool:
    """Check if a tool is available on current platform."""
    current_platform = get_platform()
    tool_config = settings.get("tools", {}).get(tool, {})
    return current_platform in tool_config.get("platforms", [])


def get_bearer_token() -> Optional[str]:
    """Get bearer token from environment variable or .env file."""
    token = os.environ.get("FETCH_URL_BEARER") or os.environ.get("WEB_SEARCH_BEARER")
    if token:
        return token

    # Look for .env in skill root directory
    env_file = SKILL_DIR / ".env"
    if env_file.exists():
        for line in env_file.read_text().strip().split('\n'):
            if line.startswith('FETCH_URL_BEARER=') or line.startswith('WEB_SEARCH_BEARER='):
                return line.split('=', 1)[1].strip()

    return None


def get_w3m_path() -> str:
    """Determine the correct path for w3m based on the OS."""
    if platform_module.system() == 'Linux':
        return '/usr/bin/w3m'
    return 'w3m'


def get_lynx_path() -> str:
    """Determine the correct path for lynx based on the OS."""
    if platform_module.system() == 'Linux':
        return '/usr/bin/lynx'
    return 'lynx'


def fetch_with_markdown_new(url: str, method: str = 'auto', retain_images: bool = False, timeout: int = 30) -> str:
    """Fetch a webpage using markdown.new API."""
    if requests is None:
        raise RuntimeError("'requests' library required. Install with: pip install requests")

    url = url.strip()
    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url

    try:
        params = []
        if method != 'auto':
            params.append(f"method={method}")
        if retain_images:
            params.append("retain_images=true")

        query_string = "?" + "&".join(params) if params else ""
        api_url = f"{MARKDOWN_NEW_URL}/{url}{query_string}"

        response = requests.get(api_url, timeout=timeout)
        response.raise_for_status()
        return response.text

    except requests.exceptions.Timeout:
        raise RuntimeError(f"markdown.new request timed out for URL: {url}")
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"markdown.new failed: {e}")


def fetch_with_jina(url: str, timeout: int = 30) -> str:
    """Fetch a webpage using Jina.ai Reader API."""
    if requests is None:
        raise RuntimeError("'requests' library required. Install with: pip install requests")

    url = url.strip()
    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url

    try:
        api_url = f"{JINA_READER_URL}/{url}"
        response = requests.get(api_url, timeout=timeout)
        response.raise_for_status()
        return response.text

    except requests.exceptions.Timeout:
        raise RuntimeError(f"Jina.ai request timed out for URL: {url}")
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"Jina.ai failed: {e}")


def fetch_with_w3m(url: str, links: bool = False, timeout: int = 30) -> str:
    """Fetch a webpage using w3m."""
    w3m_path = get_w3m_path()

    try:
        cmd = [
            w3m_path,
            '-config', str(W3M_CONFIG),
            '-o', f'display_link_number={1 if links else 0}',
            '-dump',
            url
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=timeout)
        return result.stdout

    except subprocess.TimeoutExpired:
        raise RuntimeError(f"w3m timed out for URL: {url}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"w3m failed: {e.stderr}")
    except FileNotFoundError:
        raise RuntimeError("w3m not found. Install with 'brew install w3m' (macOS) or 'sudo apt-get install w3m' (Linux)")


def fetch_with_lynx(url: str, timeout: int = 30) -> str:
    """Fetch a webpage using Lynx."""
    lynx_path = get_lynx_path()

    try:
        cmd = [
            lynx_path,
            url,
            '-dump',
            '-cfg=', str(LYNX_CONFIG),
            '--display_charset=utf-8',
            '-accept_all_cookies',
            '-nomore'
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=timeout)
        return result.stdout

    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Lynx timed out for URL: {url}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Lynx failed: {e.stderr}")
    except FileNotFoundError:
        raise RuntimeError("Lynx not found. Install with 'brew install lynx' (macOS) or 'sudo apt-get install lynx' (Linux)")


def fetch_via_api(url: str, tool: str = 'w3m', bearer: str = None, api_url: str = None, timeout: int = 30) -> str:
    """Fetch a webpage via the API endpoint."""
    if requests is None:
        raise RuntimeError("'requests' library required. Install with: pip install requests")

    if not bearer:
        bearer = get_bearer_token()
    if not bearer:
        raise ValueError("Bearer token required for API mode. Set FETCH_URL_BEARER or WEB_SEARCH_BEARER env var.")

    api_url = api_url or DEFAULT_API_URL

    url = url.strip()
    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url

    params = {'url': url, 'tool': tool}
    headers = {'accept': 'application/json', 'Authorization': f'Bearer {bearer}'}

    try:
        response = requests.get(api_url, params=params, headers=headers, timeout=timeout)
        response.raise_for_status()
        data = response.json()
        return data.get('content', '')
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"API request failed: {e}")
    except (ValueError, KeyError) as e:
        raise RuntimeError(f"Failed to parse API response: {e}")


def fetch_with_tool(tool: str, url: str, links: bool = False, bearer: str = None,
                    api_url: str = None, md_method: str = 'auto',
                    md_retain_images: bool = False, timeout: int = 30,
                    settings: Dict[str, Any] = None) -> str:
    """Fetch URL using a specific tool."""
    if tool == 'w3m':
        return fetch_with_w3m(url, links, timeout)
    elif tool == 'lynx':
        return fetch_with_lynx(url, timeout)
    elif tool == 'markdown':
        return fetch_with_markdown_new(url, md_method, md_retain_images, timeout)
    elif tool == 'jina':
        return fetch_with_jina(url, timeout)
    elif tool == 'api':
        # Get API URL from settings if not provided
        if not api_url and settings:
            api_url = settings.get("tools", {}).get("api", {}).get("api_url", DEFAULT_API_URL)
        if not bearer:
            bearer = get_bearer_token()
        return fetch_via_api(url, 'w3m', bearer, api_url or DEFAULT_API_URL, timeout)
    else:
        raise ValueError(f"Unknown tool: {tool}")


def fetch_with_fallback(url: str, preferred_tool: str, settings: Dict[str, Any],
                        links: bool = False, bearer: str = None, api_url: str = None,
                        md_method: str = 'auto', md_retain_images: bool = False,
                        verbose: bool = False) -> str:
    """Fetch URL with automatic fallback to other tools on failure."""
    timeout = settings.get("timeout", 30)
    fallback_order = settings.get("fallback_order", ["jina", "api", "markdown", "w3m", "lynx"])
    available = get_available_tools(settings)
    
    # Check if API tool can be used (requires auth)
    api_requires_auth = settings.get("tools", {}).get("api", {}).get("requires_auth", True)
    has_auth = bool(bearer or get_bearer_token())

    # Build tool order: preferred first, then fallbacks
    tool_order = []
    if preferred_tool in available:
        tool_order.append(preferred_tool)
    for tool in fallback_order:
        if tool in available and tool not in tool_order:
            # Skip api tool if no auth available
            if tool == 'api' and api_requires_auth and not has_auth:
                continue
            tool_order.append(tool)

    errors = []
    for tool in tool_order:
        try:
            if verbose and tool != preferred_tool:
                print(f"Trying {tool}...", file=sys.stderr)
            result = fetch_with_tool(tool, url, links, bearer, api_url, md_method, md_retain_images, timeout, settings)
            if result and result.strip():
                return result
            errors.append(f"{tool}: empty response")
        except Exception as e:
            errors.append(f"{tool}: {e}")

    raise RuntimeError(f"All tools failed:\n  " + "\n  ".join(errors))


def fetch_url(url: str, tool: str = 'auto', links: bool = False, use_api: bool = False,
              bearer: str = None, api_url: str = None, md_method: str = 'auto',
              md_retain_images: bool = False, verbose: bool = False) -> str:
    """Fetch a webpage using the specified tool or auto-select best available."""
    settings = load_settings()

    # Handle URL protocol
    url = url.strip()
    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url

    # API mode doesn't use fallback
    if use_api:
        timeout = settings.get("timeout", 30)
        return fetch_via_api(url, 'w3m', bearer, api_url, timeout)

    # Auto-select tool if needed
    if tool == 'auto':
        tool = get_default_tool(settings)
        if verbose:
            print(f"Auto-selected tool: {tool}", file=sys.stderr)

    # Check tool availability
    if not check_tool_available(tool, settings):
        available = get_available_tools(settings)
        raise ValueError(f"Tool '{tool}' not available on {get_platform()}. Available: {', '.join(available)}")

    return fetch_with_fallback(url, tool, settings, links, bearer, api_url, md_method, md_retain_images, verbose)


def clean_output(text: str, remove_empty_lines: bool = True) -> str:
    """Clean the output text."""
    if remove_empty_lines:
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
    if sys.platform == 'win32':
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')

    parser = argparse.ArgumentParser(
        description='Fetch and extract text content from web URLs with automatic tool selection and fallback',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Auto-select best tool (default)
  %(prog)s "https://example.com"

  # Use specific tool
  %(prog)s "https://example.com" --tool jina
  %(prog)s "https://example.com" --tool markdown
  %(prog)s "https://example.com" --tool w3m
  %(prog)s "https://example.com" --tool api --bearer TOKEN

  # JS-heavy sites
  %(prog)s "https://spa-site.com" --tool markdown --md-method browser

  # Show fallback attempts
  %(prog)s "https://example.com" --verbose

  # Fetch with link numbers (w3m only)
  %(prog)s "https://docs.python.org" --tool w3m --links

Tools:
  auto      - Auto-select best tool for platform (default)
  jina      - Jina.ai Reader (free unlimited, works everywhere)
  api       - Custom API endpoint (requires bearer token)
  markdown  - markdown.new API (clean markdown, 50/day limit)
  w3m       - Local text browser (best formatting, macOS/Linux only)
  lynx      - Local text browser (fast, macOS/Linux only)
        """
    )

    parser.add_argument('url', help='URL to fetch')
    parser.add_argument('--tool', choices=['auto', 'w3m', 'lynx', 'markdown', 'jina', 'api'], default='auto',
                        help='Tool to use (default: auto)')
    parser.add_argument('--links', action='store_true', help='Display link numbers (w3m only)')
    parser.add_argument('--clean', action='store_true', help='Remove consecutive empty lines')
    parser.add_argument('--verbose', action='store_true', help='Show fallback attempts')
    parser.add_argument('--api', action='store_true', help='Use custom API (requires --bearer)')
    parser.add_argument('--api-url', help='Custom API endpoint URL')
    parser.add_argument('--bearer', help='Bearer token for API mode')
    parser.add_argument('--md-method', choices=['auto', 'ai', 'browser'], default='auto',
                        help='markdown.new method: auto, ai, or browser (for JS sites)')
    parser.add_argument('--md-images', action='store_true', help='Retain images in markdown output')

    args = parser.parse_args()

    try:
        content = fetch_url(
            args.url,
            args.tool,
            args.links,
            use_api=args.api,
            bearer=args.bearer,
            api_url=args.api_url,
            md_method=args.md_method,
            md_retain_images=args.md_images,
            verbose=args.verbose
        )
        if args.clean:
            content = clean_output(content)
        print(content)
    except (ValueError, RuntimeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
