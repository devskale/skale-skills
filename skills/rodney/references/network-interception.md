# Network Interception Guide (`mock` / `block`)

> **Self-discover with `rodney mock --help` / `rodney block --help`.** This guide is a
> curated snapshot and the installed binary is the source of truth.

Rodney can intercept the browser's network traffic to **mock** API responses or **block**
requests entirely. This turns rodney from a read-only browser driver into a test tool that
controls what the page sees — ideal for error-state testing, offline simulation, and
deterministic scraping.

## Index

- [How it works](#how-it-works)
- [The persistent-process model](#the-persistent-process-model)
- [Command: `mock`](#command-mock)
- [Command: `block`](#command-block)
- [URL patterns](#url-patterns)
- [Use cases](#use-cases)
  - [1. Test error states in CI](#1-test-error-states-in-ci)
  - [2. Stub third-party APIs](#2-stub-third-party-apis)
  - [3. Simulate offline / resilience](#3-simulate-offline--resilience)
  - [4. Deterministic data for scraping](#4-deterministic-data-for-scraping)
  - [5. Block noisy resources](#5-block-noisy-resources)
- [Gotchas](#gotchas)
- [Related](#related)

---

## How it works

Both commands use rod's request-hijacking (the Chrome DevTools `Fetch` domain). When a
request matches a URL pattern, rodney intercepts it **before it reaches the real server**
and either:

- **`mock`** — answers it with a canned response (body, status, content-type) you supply,
- **`block`** — fails it client-side, so the server is never contacted.

Interception applies to **all resource types** (navigation, XHR/fetch, images, scripts),
so API calls, page loads, and sub-resources are all covered.

## The persistent-process model

Because a request must be answered while the interception router is alive, **`mock` and
`block` are persistent foreground processes** — not one-shot commands like the rest of
rodney.

```
Shell A:  rodney mock "*api.example.com/users*" '{...}' --type application/json
          # ^ blocks here, router stays alive, prints "Ctrl+C to stop"

Shell B:  rodney open https://example.com      # drive the browser normally
          rodney assert '...'                   # assert on the mocked behaviour

Shell A:  Ctrl+C                                # stop interception
```

**Key rules:**
- Run `mock`/`block` in their **own shell/background process**.
- The browser must already be running (`rodney start` first).
- Drive the browser from **other** rodney commands while interception is active.
- Stop with **Ctrl+C** (SIGINT) or SIGTERM.
- The command exits 0 naturally on signal — clean for scripting.

---

## Command: `mock`

Serve a canned response for matching requests.

```
rodney mock <pattern> <response> [--status N] [--type MIME] [--method M]
```

| Flag | Default | Purpose |
|------|---------|---------|
| `--status N` | `200` | HTTP status code to return |
| `--type MIME` | `text/plain` | `Content-Type` header |
| `--method M` | *(all)* | Only intercept this HTTP method (e.g. `POST`) |
| `-file=<path>` | — | Read the response body from a file instead of `<response>` |

### Examples

```bash
# Mock a JSON API with a fixed payload
rodney mock "*api.example.com/users*" '{"id":1,"name":"Mock"}' --type application/json

# Force a 503 to test error handling
rodney mock "*api.example.com/login*" '{"error":"offline"}' --status 503 --method POST

# Serve a file as the body
rodney mock "*example.com/config*" -file=config.json --type application/json
```

---

## Command: `block`

Fail matching requests client-side, so the server is never reached.

```
rodney block <pattern> [--method M]
```

| Flag | Default | Purpose |
|------|---------|---------|
| `--method M` | *(all)* | Only block this HTTP method (e.g. `POST`) |

### Examples

```bash
# Block all images
rodney block "*.jpg" "*.png" "*.gif"

# Block a whole domain
rodney block "*analytics.example.com*"

# Block only POST requests to an API
rodney block "*api.example.com*" --method POST
```

---

## URL patterns

`pattern` is a glob-style URL pattern (the Chrome DevTools `URLPattern` format):

- `*` — matches zero or more characters
- `?` — matches exactly one character
- `\*` — literal asterisk (escape)

Examples:

| Pattern | Matches |
|---------|---------|
| `*api.example.com/users*` | any request to that host/path |
| `*.jpg` | any `.jpg` request |
| `*example.com*` | everything under example.com |
| `https://api.example.com/v1/*` | a specific scheme/host/path prefix |

---

## Use cases

### 1. Test error states in CI

Make the app hit a 500/503/timeout and assert the UI reacts:

```bash
rodney start
rodney mock "*api.example.com*" '{"error":"service_unavailable"}' --status 503 &
rodney open https://myapp.com
rodney assert 'document.querySelector(".error-banner") !== null'
rodney stop
```

### 2. Stub third-party APIs

Deterministic responses for payment/maps/weather — no network, no flakiness:

```bash
rodney mock "*api.stripe.com*" '{"id":"pi_mock","status":"succeeded"}' --type application/json &
rodney open https://myapp.com/checkout
rodney assert 'document.querySelector("#payment-status").textContent' "Paid"
```

### 3. Simulate offline / resilience

```bash
rodney block "*.jpg" "*.png" "*.gif" &
rodney block "*analytics.example.com*" &
rodney open https://example.com
# layout still works without images/trackers?
```

### 4. Deterministic data for scraping

Pin API-driven numbers so screenshots/reports are reproducible:

```bash
rodney mock "*api.example.com/dashboard*" "$(cat fixture.json)" --type application/json &
rodney open https://example.com/dashboard
rodney screenshot dashboard.png   # always the same data
```

### 5. Block noisy resources

Speed up loads and drop trackers:

```bash
rodney block "*google-analytics.com*" "*doubleclick.net*" &
rodney open https://example.com
```

---

## Gotchas

- **`mock`/`block` are persistent** — they don't return until interrupted. Always run them
  in a separate shell or background, never inline in a script that expects them to exit.
- **Browser must be running first** — `rodney start` before `mock`/`block`.
- **Interception is per-page-router and lives for the process lifetime** — when the process
  exits (Ctrl+C), interception stops and requests flow to the real server again.
- **A `--method` filter with `mock`** passes non-matching requests straight through to the
  real server (it does not mock them).
- **Patterns match the full URL**, so include `*` on both sides unless you want an exact
  prefix/suffix match.
- **`mock`/`block` do not modify the request** — for rewriting URLs or request headers you'd
  need a different tool; rodney's interception is response-side only.

---

## Related

- [commands.md](commands.md) — full command reference
- [examples.md](examples.md) — ready-to-run workflow scripts
- rod request-hijacking docs: <https://github.com/go-rod/rod>
