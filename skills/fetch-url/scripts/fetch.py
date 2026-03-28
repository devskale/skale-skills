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
import re
import contextlib
import io
from pathlib import Path
from typing import Dict, List, Optional, Any

# Optional dependencies with graceful fallback
requests = None
try:
    import requests
except ImportError:
    pass  # Will show error when API mode is actually used

# Credgoo for credential management
try:
    from credgoo import get_api_key
except ImportError:
    get_api_key = None  # type: ignore

# Configuration
SCRIPT_DIR = Path(__file__).parent
SKILL_DIR = SCRIPT_DIR.parent  # Config files are in skill root, not scripts/
W3M_CONFIG = SKILL_DIR / "w3m_config"
LYNX_CONFIG = SKILL_DIR / "lynx_config"
SETTINGS_FILE = SKILL_DIR / "settings.json"
DEFAULT_API_URL = "https://amd1.mooo.com/api/fetch_url"
MARKDOWN_NEW_URL = "https://markdown.new"
JINA_READER_URL = "https://r.jina.ai"

# Error patterns that indicate blocked/failed responses
ERROR_PATTERNS = [
    r"been blocked by network security",
    r"blocked by network security",
    r"error 403",
    r"error 429",
    r"access denied",
    r"just a moment",
    r"checking your browser",
    r"captcha",
    r"cloudflare",
    r"please enable javascript",
    r"security verification",
    r"ray id:",
    r"you don't have permission",
    r"forbidden",
    r"rate limited",
]

# Site-specific tool preferences (domains that need specific tools)
SITE_TOOL_HINTS = {
    # Sites where w3m excels
    "reddit.com": ["w3m", "lynx", "markdown"],
    "www.reddit.com": ["w3m", "lynx", "markdown"],
    "news.ycombinator.com": ["w3m", "jina"],
    # Sites that block jina, use markdown fallback
    "stackoverflow.com": ["markdown"],
    "stackexchange.com": ["markdown"],
    "superuser.com": ["markdown"],
    "askubuntu.com": ["markdown"],
    "serverfault.com": ["markdown"],
    # Sites that work well with jina
    "docs.python.org": ["jina"],
    "developer.mozilla.org": ["jina"],
    "github.com": ["jina", "markdown"],
    "medium.com": ["jina"],
    "wikipedia.org": ["jina"],
    # Sites behind aggressive Cloudflare/JS challenges
    "firmenabc.at": ["chrome"],
    "www.firmenabc.at": ["chrome"],
}


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
            "Darwin": ["jina", "markdown", "w3m", "lynx"],
            "Linux": ["jina", "markdown", "w3m", "lynx"],
            "Windows": ["jina", "markdown"]
        },
        "fallback_order": ["jina", "markdown", "chawan", "w3m", "lynx"],
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


def check_tool_available(tool: str, settings: Dict[str, Any]) -> bool:
    """Check if a tool is available on current platform."""
    current_platform = get_platform()
    tool_config = settings.get("tools", {}).get(tool, {})
    return current_platform in tool_config.get("platforms", [])


def get_bearer_token() -> Optional[str]:
    """Get bearer token from credgoo, environment variable, or .env file."""
    # Environment variable (highest priority)
    if token := os.environ.get("FETCH_URL_BEARER"):
        return token
    
    # Credgoo (suppress output)
    if get_api_key:
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                if token := get_api_key("FETCH_URL_BEARER"):
                    return token
        except Exception:
            pass
    
    # Local .env file
    env_file = SKILL_DIR / ".env"
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            if line.startswith("FETCH_URL_BEARER="):
                return line.split("=", 1)[1].strip()
    
    return None


def extract_domain(url: str) -> str:
    """Extract domain from URL."""
    url = url.strip()
    if not url.startswith('http://') and not url.startswith('https://'):
        url = 'https://' + url
    
    # Extract domain
    match = re.match(r'https?://([^/]+)', url)
    if match:
        return match.group(1).lower()
    return ""


def get_site_tool_hint(url: str) -> Optional[List[str]]:
    """Get preferred tools for a specific site based on domain."""
    domain = extract_domain(url)
    
    # Direct match
    if domain in SITE_TOOL_HINTS:
        return SITE_TOOL_HINTS[domain]
    
    # Partial match (e.g., subdomain)
    for site_domain, tools in SITE_TOOL_HINTS.items():
        if domain.endswith(site_domain) or site_domain.endswith(domain):
            return tools
    
    return None


def is_valid_content(content: str) -> bool:
    """Check if content is valid (not an error page)."""
    if not content or not content.strip():
        return False
    
    content_lower = content.lower()
    for pattern in ERROR_PATTERNS:
        if re.search(pattern, content_lower, re.IGNORECASE):
            return False
    
    return True


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


def _html_to_text(html: str) -> str:
    """Convert raw HTML to readable text, stripping noise like cookie banners."""
    import html as html_mod

    # Try to extract TYPO3SEARCH content markers first (Austrian business sites)
    typo3 = re.search(r'TYPO3SEARCH_begin-->(.*?)<!--TYPO3SEARCH_end', html, flags=re.DOTALL)
    if typo3:
        html = typo3.group(1)
    else:
        # No TYPO3 markers — strip nav/header/footer for cleaner output
        for tag in ['header', 'nav', 'footer']:
            html = re.sub(rf'<{tag}[^>]*>.*?</{tag}>', '', html, flags=re.DOTALL | re.IGNORECASE)

    # Remove HTML comments
    html = re.sub(r'<!--.*?-->', '', html, flags=re.DOTALL)

    # Remove cookie consent, banner, GDPR overlays (aggressive multi-line removal)
    for kw in ['cookie', 'consent', 'cookiebot', 'gdpr', 'popup', 'overlay',
                'iab', 'cc-window', 'onetrust', 'cmp']:
        html = re.sub(rf'<[^>]*{kw}[^>]*>.*?(?:</div>|</section>|</aside>)', '', html,
                       flags=re.DOTALL | re.IGNORECASE)

    # Remove script, style, svg, noscript tags
    for tag in ['script', 'style', 'svg', 'noscript']:
        html = re.sub(rf'<{tag}[^>]*>.*?</{tag}>', '', html, flags=re.DOTALL | re.IGNORECASE)

    # Convert block-level tags to newlines, inline tags to spaces
    html = re.sub(r'<br\s*/?>', '\n', html, flags=re.IGNORECASE)
    html = re.sub(r'</?(p|div|h[1-6]|li|tr|section|article|header|footer|main|table|td|th|dd|dt|dl|blockquote|pre|ul|ol)[^>]*>', '\n', html, flags=re.IGNORECASE)
    html = re.sub(r'<[^>]+>', ' ', html)

    # Decode HTML entities
    html = html_mod.unescape(html)

    # Clean up whitespace
    lines = [line.strip() for line in html.split('\n')]
    lines = [l for l in lines if l and len(l) > 1]
    text = '\n'.join(lines)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()


def _find_chrome() -> Optional[str]:
    """Find Chrome/Chromium executable on the system."""
    candidates = [
        # macOS
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
        # Linux
        "/usr/bin/google-chrome",
        "/usr/bin/google-chrome-stable",
        "/usr/bin/chromium-browser",
        "/usr/bin/chromium",
        # Windows
        os.path.expandvars(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
        os.path.expandvars(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
    ]
    for candidate in candidates:
        if os.path.isfile(candidate):
            return candidate
    # Try PATH
    for name in ['google-chrome', 'google-chrome-stable', 'chromium-browser', 'chromium', 'chrome']:
        try:
            result = subprocess.run(['which', name], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                return result.stdout.strip()
        except Exception:
            pass
    return None


def fetch_with_chrome(url: str, timeout: int = 45) -> str:
    """Fetch a webpage using headless Chrome. Handles Cloudflare JS challenges."""
    chrome_path = _find_chrome()
    if not chrome_path:
        raise RuntimeError("Chrome/Chromium not found. Install Google Chrome or Chromium.")

    try:
        cmd = [
            chrome_path,
            '--headless=new',
            '--disable-gpu',
            '--no-sandbox',
            '--disable-dev-shm-usage',
            '--run-all-compositor-stages-before-draw',
            f'--virtual-time-budget={timeout * 250}',  # Allow JS to execute
            '--dump-dom',
            url
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=timeout)
        html = result.stdout
        if not html or not html.strip():
            raise RuntimeError("Chrome returned empty content")
        return _html_to_text(html)

    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Chrome timed out for URL: {url}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Chrome failed: {e.stderr}")


def fetch_with_chawan(url: str, timeout: int = 30) -> str:
    """Fetch a webpage using Chawan browser."""""
    try:
        cmd = ['cha', '-d', url]

        # Run with stderr suppressed (JS errors are common but don't affect output)
        result = subprocess.run(cmd, capture_output=True, text=True, check=True, timeout=timeout)
        return result.stdout

    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Chawan timed out for URL: {url}")
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Chawan failed: {e.stderr}")
    except FileNotFoundError:
        raise RuntimeError("Chawan not found. Install with 'brew install chawan' (macOS) or see https://github.com/devskale/chawan")


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
    elif tool == 'chrome':
        return fetch_with_chrome(url, timeout)
    elif tool == 'chawan':
        return fetch_with_chawan(url, timeout)
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
    """Fetch URL with automatic fallback to other tools on failure or invalid content."""
    timeout = settings.get("timeout", 30)
    fallback_order = settings.get("fallback_order", ["jina", "markdown", "chawan", "w3m", "lynx"])
    available = get_available_tools(settings)
    
    # Check if API tool can be used (requires auth)
    api_requires_auth = settings.get("tools", {}).get("api", {}).get("requires_auth", True)
    has_auth = bool(bearer or get_bearer_token())

    # Check for site-specific tool hints
    site_hints = get_site_tool_hint(url)
    
    # Build tool order: preferred first, then site hints, then fallbacks
    tool_order = []
    if preferred_tool in available:
        tool_order.append(preferred_tool)
    
    # Add site-specific tools next if available
    if site_hints:
        for tool in site_hints:
            if tool in available and tool not in tool_order:
                tool_order.append(tool)
    
    # Then add remaining fallback tools
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
            
            # Check if content is valid (not an error page)
            if result and result.strip():
                if is_valid_content(result):
                    return result
                else:
                    errors.append(f"{tool}: blocked/error response")
                    if verbose:
                        print(f"{tool}: detected blocked/error response, trying next...", file=sys.stderr)
            else:
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
        # Check for site-specific preference first
        site_hints = get_site_tool_hint(url)
        available = get_available_tools(settings)
        
        if site_hints:
            for hint_tool in site_hints:
                if hint_tool in available:
                    tool = hint_tool
                    if verbose:
                        print(f"Site-specific tool: {tool} for {extract_domain(url)}", file=sys.stderr)
                    break
        
        if tool == 'auto':
            tool = "jina"  # Default to jina (works everywhere)
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
        description='Fetch and extract text content from web URLs',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s "https://example.com"           # Just works (auto-select)
  %(prog)s "https://reddit.com/r/python"   # Auto-detects Reddit, uses markdown
  %(prog)s "https://stackoverflow.com/..." # Auto-detects, bypasses blocks
  %(prog)s "https://docs.python.org" --tool jina  # Force specific tool
        """
    )

    parser.add_argument('url', help='URL to fetch')
    parser.add_argument('--tool', choices=['auto', 'w3m', 'lynx', 'chawan', 'chrome', 'markdown', 'jina', 'api'], 
                        default='auto', help='Tool to use (default: auto)')
    parser.add_argument('--links', action='store_true', help='Display link numbers (w3m only)')
    parser.add_argument('--clean', '-c', action='store_true', default=True, 
                        help='Remove consecutive empty lines (default: True)')
    parser.add_argument('--no-clean', action='store_true', help='Keep all empty lines')
    parser.add_argument('--verbose', '-v', action='store_true', help='Show tool selection')
    parser.add_argument('--api', action='store_true', help='Use custom API')
    parser.add_argument('--bearer', help='Bearer token for API mode')
    parser.add_argument('--md-method', choices=['auto', 'ai', 'browser'], default='auto',
                        help='markdown.new method (for JS sites, use: browser)')
    parser.add_argument('--md-images', action='store_true', help='Keep images in markdown')

    args = parser.parse_args()
    
    # Handle clean flag
    do_clean = not args.no_clean

    try:
        content = fetch_url(
            args.url,
            args.tool,
            args.links,
            use_api=args.api,
            bearer=args.bearer,
            md_method=args.md_method,
            md_retain_images=args.md_images,
            verbose=args.verbose
        )
        if do_clean:
            content = clean_output(content)
        print(content)
    except (ValueError, RuntimeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
