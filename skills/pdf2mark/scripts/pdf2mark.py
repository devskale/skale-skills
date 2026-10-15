# pdf2md.py - Convert PDFs to Markdown via the skale pdf API.
# pdfplumber (local, text-layer) by default; llamaparse (cloud OCR) for scans.
import argparse
import json
import os
import sys
import threading
import time
from contextlib import contextmanager
from typing import Optional

import requests

API_URL = os.environ.get("PDF2MD_URL", "https://amd.skale.dev/api/pdf/to_md")
API_BASE = API_URL.rsplit("/pdf/", 1)[0]
MAX_BYTES = 10 * 1024 * 1024
AUTO_FALLBACK_CHARS = 20  # less than this from pdfplumber -> scan, go llamaparse
# Marker for "the markdown exists but was deliberately not downloaded" (--share).
# main() must not read this as an empty conversion result.
SHARE_SKIPPED_DOWNLOAD = "\x00SHARE_SKIPPED\x00"
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


def _poll_wait(job_id: str, poll_url: str, headers: dict, deadline: float,
               verbose: bool) -> dict:
    """Klassisches 3s-Polling bis terminal/Deadline (der bewährte Pfad).

    Exits selbst bei 401/HTTP-Fehler/Deadline (mit poll-manual-Hinweis) —
    wie historisch wait_job.
    """
    while True:
        r = requests.get(poll_url, headers=headers, timeout=30)
        if r.status_code == 401:
            sys.exit("error: 401 authentication failed while polling. Check the token: credgoo FETCH_URL_BEARER")
        if r.status_code >= 400:
            sys.exit(f"error: job status HTTP {r.status_code}")
        body = r.json()
        status = body.get("status")
        if status == "done":
            return body
        if status in ("failed", "error"):
            sys.exit(f"error: job failed: {body.get('error', 'unknown')}")
        if status == "cancelled":
            sys.exit("error: job was cancelled (DELETE) — submit again if you "
                     "still want the conversion")
        if time.monotonic() > deadline:
            sys.exit(f"error: job {job_id} not done after poll budget — poll manually "
                     f"(result kept ~2h):\n"
                     f"  curl -s -H 'Authorization: Bearer <token>' {poll_url}")
        time.sleep(3)


def _sse_wait(job_id: str, headers: dict, deadline: float,
              verbose: bool) -> Optional[dict]:
    """Auf den SSE-Stream warten (/pdf/jobs/{id}/events): ein Event pro
    Statuswechsel statt 3s-Poll-Raster — das Warteerlebnis.

    Liefert den finalen Snapshot (done/failed) oder None, wenn SSE nicht
    nutzbar ist (älterer Server → 404/405, Proxy frisst den Stream,
    PDF2MD_NO_SSE=1 gesetzt, Stream endet ohne Terminal-Event): der Caller
    fällt dann automatisch aufs Polling zurück — SSE ist ein Accelerator,
    kein Pflicht-Contract.
    """
    if os.environ.get("PDF2MD_NO_SSE"):
        return None
    events_url = f"{API_BASE}/pdf/jobs/{job_id}/events"
    try:
        with requests.get(events_url, headers=headers, stream=True,
                          timeout=(5, 30)) as resp:
            if resp.status_code != 200:
                return None
            if verbose:
                print(f"pdf2md: streaming events for {job_id[:8]}…",
                      file=sys.stderr)
            event_name = None
            data_line = None
            for line in resp.iter_lines(decode_unicode=True):
                if time.monotonic() > deadline:
                    return None
                if line == "":  # Event-Grenze
                    if event_name == "status" and data_line:
                        data = json.loads(data_line)
                        if data.get("status") in ("failed", "cancelled"):
                            return data  # Fehler-/Cancel-Snapshot, Caller exittet
                        if data.get("status") == "done":
                            return data
                    event_name, data_line = None, None
                elif line.startswith("event: "):
                    event_name = line[len("event: "):]
                elif line.startswith("data: "):
                    data_line = line[len("data: "):]
                # `: ping` Heartbeat-Kommentare: halten den Stream offen,
                # brauchen keine Verarbeitung
    except (requests.RequestException, json.JSONDecodeError):
        return None
    return None  # Stream endete ohne Terminal-Event → Poll-Fallback


def wait_job(queued: dict, bearer: str, verbose: bool, timeout: int, share: bool = False):
    """Warten auf einen async-Job: SSE-first (Statuswechsel-Push, TTL in
    jedem Event), Polling als Fallback — der CLI kann keine Callbacks
    empfangen, aber ein offener Stream ist billiger und schneller als ein
    3s-Poll-Raster.

    The API forces async beyond ~40 pages; llamaparse processes at ~2s/page.
    `timeout` is the total wait budget — results stay retrievable ~2h.
    """
    job_id = queued["job_id"]
    poll_url = f"{API_BASE}/pdf/jobs/{job_id}"
    headers = {"Authorization": f"Bearer {bearer}"}
    deadline = time.monotonic() + timeout
    with heartbeat(f"polling job {job_id[:8]}…", verbose,
                   hint="results are kept ~2h"):
        body = _sse_wait(job_id, headers, deadline, verbose)
        if body is None:
            body = _poll_wait(job_id, poll_url, headers, deadline, verbose)
        if body.get("status") == "cancelled":
            sys.exit("error: job was cancelled (DELETE) — submit again if you "
                     "still want the conversion")
        if body.get("status") in ("failed", "error"):
            sys.exit(f"error: job failed: {body.get('error', 'unknown')}")
    if body.get("markdown_url"):
        if verbose:
            print(f"pdf2md: shared via {body['markdown_url']} (4h TTL)", file=sys.stderr)
        if share:
            # --share only wants the URL: downloading the markdown here would
            # transfer the whole document for nothing (megabytes on big scans).
            # The sentinel keeps main()'s auto-fallback (which treats an empty
            # markdown as "scan detected") from firing on a deliberate skip.
            return SHARE_SKIPPED_DOWNLOAD, body
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
    # Size check BEFORE reading: a 2GB file would be buffered in RAM just to be
    # rejected afterwards. os.path.getsize is a stat call, no read.
    try:
        size = os.path.getsize(path)
    except OSError as e:
        sys.exit(f"error: cannot read {path}: {e}")
    if size > MAX_BYTES:
        sys.exit(f"error: {path} is larger than 10MB (API limit)")
    if size == 0:
        sys.exit(f"error: {path} is empty")
    with open(path, "rb") as fh:
        data = fh.read()
    if len(data) > MAX_BYTES:
        # the file grew between stat and read (or a sparse/odd file) — re-check
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
        if method == "pdfplumber":
            sys.exit("error: 504 local conversion exceeded the server-side "
                     "watchdog (60s) — pathological PDF; try --method llamaparse "
                     "(cloud OCR) or split the file")
        sys.exit("error: 504 job deadline exceeded server-side (default 20 min) — retry with --no-wait")
    if resp.status_code == 202:
        # long document -> async job (forced beyond ~40 pages); poll until
        # done. Async conversions outlive the sync timeout by design (local:
        # ~0.5-0.8s/page on the server box) — the poll budget is therefore at
        # least 600s, however small the request timeout was.
        return wait_job(resp.json(), bearer, verbose,
                        max(timeout, 600), share=share)
    if resp.status_code >= 400:
        raise ApiError(resp.status_code, detail)
    result = resp.json()
    return result.get("markdown", ""), result


def default_out_path(pdf_path: str) -> str:
    """Default output location: md/<name>.pdf.md next to the PDF.

    abd.pdf -> ./md/abd.pdf.md — one PDF, one markdown twin, a predictable
    place. The .pdf.md suffix keeps the pair adjacent in listings and makes
    the origin obvious.
    """
    pdf_dir = os.path.dirname(os.path.abspath(pdf_path))
    return os.path.join(pdf_dir, "md", os.path.basename(pdf_path) + ".md")


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
    parser.add_argument("--out", metavar="FILE",
                        help="write markdown to FILE (default: md/<name>.pdf.md "
                             "next to the PDF)")
    parser.add_argument("--stdout", action="store_true",
                        help="write markdown to stdout instead of a file")
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

    if (method == "pdfplumber" and args.method == "auto"
            and markdown != SHARE_SKIPPED_DOWNLOAD
            and len(markdown.strip()) < AUTO_FALLBACK_CHARS):
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
    if markdown == SHARE_SKIPPED_DOWNLOAD:
        # --share on a job whose result we did not download: the URL was already
        # printed above when markdown_url was set; nothing left to write.
        return

    if args.out:
        args.out = os.path.expanduser(args.out)
    elif not args.stdout:
        args.out = default_out_path(args.pdf)
    if args.out:
        out_dir = os.path.dirname(os.path.abspath(args.out))
        os.makedirs(out_dir, exist_ok=True)
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
