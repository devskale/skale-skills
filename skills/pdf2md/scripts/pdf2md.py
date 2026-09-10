# pdf2md.py - Convert PDFs to Markdown via the skale pdf API.
# pdfplumber (local, text-layer) by default; llamaparse (cloud OCR) for scans.
import argparse
import json
import os
import sys

import requests

API_URL = os.environ.get("PDF2MD_URL", "https://amd.skale.dev/api/pdf/to_md")
MAX_BYTES = 10 * 1024 * 1024
AUTO_FALLBACK_CHARS = 20  # less than this from pdfplumber -> scan, go llamaparse


def resolve_bearer() -> str:
    """Bearer token from env or credgoo. No silent fallbacks.

    Same credential the fetch-url 'api' tool uses: FETCH_URL_BEARER.
    credgoo is a declared dependency (uv sync installs it into this skill's
    venv). The try/except only keeps bare `python3` runs from hard-failing on
    the import; a missing token still exits with an error below.
    """
    for env_key in ("PDF2MD_BEARER", "FETCH_URL_BEARER"):
        value = os.environ.get(env_key, "").strip()
        if value:
            return value
    try:
        from credgoo import get_api_key

        key = get_api_key("FETCH_URL_BEARER")
        if isinstance(key, str) and key.strip():
            return key.strip()
    except Exception:
        pass
    sys.exit("error: no token. Set PDF2MD_BEARER/FETCH_URL_BEARER or run: credgoo FETCH_URL_BEARER")


class ApiError(Exception):
    def __init__(self, status, detail=""):
        self.status = status
        self.detail = detail
        super().__init__(f"HTTP {status} {detail}".strip())


def convert(path: str, method: str, tier: str, language: str, bearer: str, timeout: int):
    with open(path, "rb") as fh:
        data = fh.read()
    if len(data) > MAX_BYTES:
        sys.exit(f"error: {path} is larger than 10MB (API limit)")
    params = {"method": method}
    if method == "llamaparse":
        params["tier"] = tier
        params["language"] = language
    resp = requests.post(
        API_URL,
        headers={"Authorization": f"Bearer {bearer}"},
        files={"file": (os.path.basename(path), data, "application/pdf")},
        params=params,
        timeout=timeout,
    )
    detail = ""
    try:
        detail = resp.json().get("detail", "")
    except Exception:
        pass
    if resp.status_code == 401:
        sys.exit("error: 401 authentication failed. Check the token: credgoo FETCH_URL_BEARER")
    if resp.status_code == 413:
        sys.exit("error: 413 too large (API limit: 10MB / 500 pages)")
    if resp.status_code == 429:
        sys.exit("error: 429 rate limit or llamaparse quota exhausted")
    if resp.status_code == 503:
        sys.exit("error: 503 llamaparse key not configured server-side")
    if resp.status_code == 504:
        sys.exit("error: 504 conversion timed out server-side")
    if resp.status_code >= 400:
        raise ApiError(resp.status_code, detail)
    result = resp.json()
    return result.get("markdown", ""), result


def main():
    parser = argparse.ArgumentParser(
        prog="pdf2md",
        description="Convert a PDF to Markdown via the skale pdf API.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=("examples:\n"
                "  pdf2md document.pdf\n"
                "  pdf2md scan.pdf --method llamaparse\n"
                "  pdf2md doc.pdf --out doc.md\n"
                "  pdf2md scan.pdf --method llamaparse --tier agentic"),
    )
    parser.add_argument("pdf", help="path to the PDF file")
    parser.add_argument("--method", choices=["auto", "pdfplumber", "llamaparse"],
                        default="auto",
                        help="auto (default): pdfplumber, llamaparse fallback for scans")
    parser.add_argument("--tier", default="fast",
                        choices=["fast", "cost_effective", "agentic", "agentic_plus"],
                        help="llamaparse tier (default: fast)")
    parser.add_argument("--language", default="de", help="OCR language hint (default: de)")
    parser.add_argument("--out", metavar="FILE", help="write markdown to FILE instead of stdout")
    parser.add_argument("--timeout", type=int, default=180, help="request timeout in seconds")
    parser.add_argument("--verbose", "-v", action="store_true", help="stats to stderr")
    args = parser.parse_args()

    if not os.path.isfile(args.pdf):
        sys.exit(f"error: file not found: {args.pdf}")

    bearer = resolve_bearer()
    method = args.method
    if method == "auto":
        method = "pdfplumber"
        if args.verbose:
            print("pdf2md: auto -> pdfplumber", file=sys.stderr)

    try:
        markdown, result = convert(
            args.pdf, method, args.tier, args.language, bearer, args.timeout)
    except ApiError as e:
        # auto: a scan (422 no text) falls back to llamaparse below
        if not (args.method == "auto" and method == "pdfplumber" and e.status == 422):
            sys.exit(f"error: {e}")
        markdown, result = "", {"pages": None}

    if method == "pdfplumber" and args.method == "auto" and len(markdown.strip()) < AUTO_FALLBACK_CHARS:
        if args.verbose:
            print(f"pdf2md: pdfplumber got {len(markdown.strip())} chars -> scan? falling back to llamaparse",
                  file=sys.stderr)
        method = "llamaparse"
        markdown, result = convert(args.pdf, method, args.tier, args.language, bearer, args.timeout)

    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(markdown)
        print(f"✓ {args.out}  (pages={result.get('pages')}, chars={result.get('chars')}, "
              f"converter={result.get('converter')})", file=sys.stderr)
    else:
        sys.stdout.write(markdown)
        if args.verbose:
            print(f"\n--- pages={result.get('pages')} chars={result.get('chars')} "
                  f"converter={result.get('converter')}", file=sys.stderr)


if __name__ == "__main__":
    main()
