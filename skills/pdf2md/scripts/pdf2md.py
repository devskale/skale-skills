# pdf2md.py - Convert PDFs to Markdown via the skale pdf API.
# pdfplumber (local, text-layer) by default; llamaparse (cloud OCR) for scans.
import argparse
import os
import sys
import threading
import time
from contextlib import contextmanager

import requests

API_URL = os.environ.get("PDF2MD_URL", "https://amd.skale.dev/api/pdf/to_md")
API_BASE = API_URL.rsplit("/pdf/", 1)[0]
MAX_BYTES = 10 * 1024 * 1024
AUTO_FALLBACK_CHARS = 20  # less than this from pdfplumber -> scan, go llamaparse
DEFAULT_TIMEOUTS = {"pdfplumber": 180, "llamaparse": 600}  # OCR scales with pages


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


def wait_job(queued: dict, bearer: str, verbose: bool, timeout: int):
    """Poll an async conversion job (202 answer) until done/failed.

    The API forces async beyond ~40 pages; llamaparse processes at ~2s/page.
    `timeout` is the total poll budget — results stay retrievable ~2h, so a
    timeout exits with the manual poll command. If the result was transferred
    to throway, download it so the caller still gets markdown.
    """
    job_id = queued["job_id"]
    poll_url = f"{API_BASE}/pdf/jobs/{job_id}"
    headers = {"Authorization": f"Bearer {bearer}"}
    deadline = time.monotonic() + timeout
    with heartbeat(f"polling job {job_id[:8]}…", verbose,
                   hint="results are kept ~2h"):
        while True:
            r = requests.get(poll_url, headers=headers, timeout=30)
            if r.status_code == 401:
                sys.exit("error: 401 authentication failed while polling. Check the token: credgoo FETCH_URL_BEARER")
            if r.status_code >= 400:
                sys.exit(f"error: job status HTTP {r.status_code}")
            body = r.json()
            status = body.get("status")
            if status == "done":
                break
            if status in ("failed", "error"):
                sys.exit(f"error: job failed: {body.get('error', 'unknown')}")
            if time.monotonic() > deadline:
                sys.exit(f"error: job {job_id} not done after {timeout}s — poll manually "
                         f"(result kept ~2h):\n"
                         f"  curl -s -H 'Authorization: Bearer <token>' {poll_url}")
            time.sleep(3)
    if body.get("markdown_url"):
        if verbose:
            print(f"pdf2md: shared via {body['markdown_url']} (4h TTL)", file=sys.stderr)
        try:
            body["markdown"] = requests.get(body["markdown_url"], timeout=60).text
        except requests.exceptions.RequestException as e:
            sys.exit(f"error: could not download shared result: {e}\n"
                     f"  fetch {body['markdown_url']} manually before the 4h TTL expires")
    return body.get("markdown", ""), body


@contextmanager
def heartbeat(label: str, enabled: bool, interval: int = 30, hint: str = ""):
    """While blocked, print a stderr heartbeat every `interval` s — only when enabled.

    Prints the label immediately so a long wait is acknowledged from 0 s;
    `hint` sets the expectation once (e.g. 'large scans take minutes').
    """
    stop = threading.Event()
    thread = None

    def tick():
        start = time.monotonic()
        print(f"pdf2md: {label}" + (f" ({hint})" if hint else ""),
              file=sys.stderr, flush=True)
        while not stop.wait(interval):
            print(f"pdf2md: {label}… {int(time.monotonic() - start)}s elapsed",
                  file=sys.stderr, flush=True)

    try:
        if enabled:
            thread = threading.Thread(target=tick, daemon=True)
            thread.start()
        yield
    finally:
        stop.set()
        if thread is not None:
            thread.join(timeout=0.5)  # no garbled last line on exit


def convert(path: str, method: str, tier: str, language: str, bearer: str,
            timeout: int, verbose: bool = False, no_wait: bool = False,
            share: bool = False):
    with open(path, "rb") as fh:
        data = fh.read()
    if len(data) > MAX_BYTES:
        sys.exit(f"error: {path} is larger than 10MB (API limit)")
    params = {"method": method}
    if method == "llamaparse":
        params["tier"] = tier
        params["language"] = language
        if no_wait:
            params["wait"] = "false"  # async job: dodges the server-side sync timeout
    if share:
        params["transfer"] = "throway"  # result as 4h link instead of inline text
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
        sys.exit("error: 429 rate limit, llamaparse quota exhausted, or job queue full — retry later")
    if resp.status_code == 502:
        sys.exit("error: 502 llamaparse failure"
                 + (" or throway transfer failed — retry without --share" if share else " — retry"))
    if resp.status_code == 503:
        if share:
            sys.exit("error: 503 throway transfer disabled server-side (or llamaparse key missing)")
        sys.exit("error: 503 llamaparse key not configured server-side")
    if resp.status_code == 504:
        sys.exit("error: 504 job deadline exceeded server-side (default 20 min) — retry with --no-wait")
    if resp.status_code == 202:
        # long document -> async job (forced beyond ~40 pages); poll until done
        return wait_job(resp.json(), bearer, verbose, timeout)
    if resp.status_code >= 400:
        raise ApiError(resp.status_code, detail)
    result = resp.json()
    return result.get("markdown", ""), result


def convert_or_exit(args, method: str, bearer: str, timeout: int):
    """convert() with a -v heartbeat and clean network-error exits."""
    try:
        with heartbeat(f"waiting for {method}", args.verbose,
                       hint="large scans take minutes"):
            return convert(args.pdf, method, args.tier, args.language, bearer,
                           timeout, verbose=args.verbose, no_wait=args.no_wait,
                           share=args.share)
    except requests.exceptions.Timeout:
        sys.exit(f"error: conversion took >{timeout}s — large documents can take "
                 f"minutes; retry with a higher --timeout")
    except requests.exceptions.RequestException as e:
        sys.exit(f"error: request failed: {e}")


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
    parser.add_argument("--timeout", type=int, default=None,
                        help="request timeout in seconds (default: 180, 600 for llamaparse)")
    parser.add_argument("--no-wait", action="store_true",
                        help="llamaparse only: submit as async job and poll — use this "
                        "when sync conversion dies with 504 (typical for big scans)")
    parser.add_argument("--share", action="store_true",
                        help="share the result via skale.dev/throway (4h TTL): prints "
                        "the URL instead of the full text")
    parser.add_argument("--verbose", "-v", action="store_true", help="stats to stderr")
    args = parser.parse_args()

    args.pdf = os.path.expanduser(args.pdf)
    if not os.path.isfile(args.pdf):
        sys.exit(f"error: file not found: {args.pdf}")

    bearer = resolve_bearer()
    method = args.method
    if method == "auto":
        method = "pdfplumber"
        if args.verbose:
            print("pdf2md: auto -> pdfplumber", file=sys.stderr)
    timeout = args.timeout or DEFAULT_TIMEOUTS[method]

    try:
        markdown, result = convert_or_exit(args, method, bearer, timeout)
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
        timeout = args.timeout or DEFAULT_TIMEOUTS[method]
        try:
            markdown, result = convert_or_exit(args, method, bearer, timeout)
        except ApiError as e:
            sys.exit(f"error: {e}")

    if args.share and result.get("markdown_url"):
        print(result["markdown_url"])
        return

    if args.out:
        args.out = os.path.expanduser(args.out)
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(markdown)
        print(f"✓ {os.path.abspath(args.out)}  (pages={result.get('pages')}, chars={result.get('chars')}, "
              f"converter={result.get('converter', result.get('status'))})", file=sys.stderr)
    else:
        sys.stdout.write(markdown)
        if args.verbose:
            print(f"\n--- pages={result.get('pages')} chars={result.get('chars')} "
                  f"converter={result.get('converter', result.get('status'))}", file=sys.stderr)


if __name__ == "__main__":
    main()
