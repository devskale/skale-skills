---
disable-model-invocation: true
name: sts
description: "Drive klark0's worker, filesystem, and settings from an external client (script, E2E harness, agent, debug tool) via the Steuerschnittstelle (STS) API-key path — no browser login required. Use when launching/polling/cancelling worker jobs, creating projects/bidders/files, reading or writing team settings, or introspecting the callable API surface from outside the browser. Triggers on mentions of STS, Steuerschnittstelle, external API access, x-sts-key, API key for klark0, E2E harness, or driving the worker from a script/agent."
compatibility: "Requires klark0 dev server running and a key minted by a team owner (NEXT_PUBLIC_STS_ENABLED=true). For E2E: the harness in python-utils/packages/agentos/agentos/e2e/."
metadata:
  author: skale
---

# STS — Steuerschnittstelle (external API access to klark0)

STS lets an external client drive the same `/api/**` routes the browser uses,
**without a login/session**, via a team-scoped owner-generated API key in the
`x-sts-key` header. It is the Backend-for-Frontend (BFF) API-key path for
external/debug access.

## Default keyfile + bash helpers

Keys are gitignored and read by `scripts/sts.sh` in this precedence:
`-t <team>` (from `sts.keys`) → `$STS_KEY` → `$STS_KEYFILE` → `sts.temp.key`.

- **`sts.keys`** (preferred, multi-team) — one `<teamId>=<key>` per line; inline
  `# comments` are stripped. Select per call with `-t <teamId>`.
- **`sts.temp.key`** (single-team default) — copy `sts.temp.key.example` to
  `sts.temp.key` and paste one key.

```bash
# sts.keys (gitignored) — preferred for multiple teams:
#   10=STS-10-a1b2c3d4e5f67890   # pi grill
#   11=STS-11-9439               # local mac (legacy 4-digit still validates)
./scripts/sts.sh -t 10 discover                   # select team per call
```

Prefer the bundled helpers over hand-rolled curl. They auto-read the key,
auto-normalize paths (relative + NFD), and cover the common operations:

```bash
cd klark0
./scripts/sts.sh discover                         # list callable endpoints
./scripts/sts.sh ls <path>                         # directory listing
./scripts/sts.sh cat|read <path>                   # text / raw bytes
./scripts/sts.sh find <needle> [root]              # recursive NAME search
./scripts/sts.sh grep <needle> [root] [glob]       # recursive CONTENT search in JSON
./scripts/sts.sh inventory                         # project triage table (client/lots/docs/flags)
./scripts/sts.sh bidders <project>                 # list B/ bidders
./scripts/sts.sh projekt <project> [summary|meta|bdoks|kriterien|raw]
./scripts/sts.sh audit <project> <bidder> [summary|meta|kriterien|bdoks|raw]
# filesystem mutations (write scope):
./scripts/sts.sh mkdir <path> | upload <path> <file> | del <path>...
./scripts/sts.sh cp <src> <dest>                   # copy file or dir tree (recursive)
./scripts/sts.sh mv|rename <src> <dest>            # move/rename (cross-dir)
./scripts/sts.sh archive <path>...                 # move into Archiv/ root
# worker (write scope):
./scripts/sts.sh jobs | job <id> | enqueue <type> [name] '<params-json>'
#   e.g. enqueue task_index "reindex" '{"param":"index update --recursive /dir"}' (flat)
#   param ist SHELL-Syntax (shlex): Pfade mit Leerzeichen MÜSSEN gequoted sein —
#   '{"param":"index update --recursive \"/klark0/PUT Brandschutzschaum KI-Reval\""}'
#   (unquoted splittet der Worker den Pfad → argparse-Fehler im Job-Result).
./scripts/sts.sh cancel <id>                        # delete/cancel a job
./scripts/sts.sh -t <team> post /api/worker/queue/arq:queue/pause   # pause queue
./scripts/sts.sh help                              # full command list
```

See `klark0/scripts/README.md` ("STS Helpers") for the full reference and the
path-normalization gotcha (leading-slash WebDAV paths are treated as absolute
→ the helpers strip the leading slash and NFD-normalize umlauts automatically).

### FS ops jenseits der App-Routen (Admin-Pfad, WebDAV/dufs direkt)

Die App bietet bewusst KEINE Route, um ganze JSON-Dateien (z. B. `audit.json`)
 roh zu überschreiben. Für Admin-Ops (Freeze-Aufbau, Naked-Writes, Cleanup in
 `Archiv/`) geht man direkt auf dufs — Creds aus dem Team-Setting:

```bash
# 1) Creds in EINER bash-invocation holen + verbrauchen (Datei danach löschen):
#    POSTGRES_URL aus klark0/.env.local → app_settings (team_id, 'fileSystem')
#    → { host, username, password } → /tmp/dufs-creds.json
# 2) curl -u user:pw … dufs-URL (MKCOL/COPY/MOVE/DELETE/PUT)
# 3) rm /tmp/dufs-creds.json
```

Regeln: Creds nie printen/persistieren, alles in EINER Invocation (kein
Secret-Übergreifen zwischen Calls), und App-Guards gelten hier NICHT — der
Referenz-Freeze (`Archiv/REFERENZ …`) ist auch auf diesem Weg schreibgeschützt
zu lassen. Beispiele (Walk+MKCOL+COPY, Naked-PUT): `scripts/reeval-reset.mjs`
(klark0) und Issue `referenz-sets-golden-freeze-evaluation`.

## TL;DR for an external client

```bash
BASE=http://localhost:3000
KEY=$(cat klark0/sts.temp.key)       # default: read from gitignored keyfile

# 1. ALWAYS discover first — don't hardcode routes (they drift):
curl -s -H "x-sts-key: $KEY" $BASE/api/sts/services | jq '.summary, (.services[] | select(.callable))'

# 2. Call any endpoint that reported callable:true:
curl -s -H "x-sts-key: $KEY" $BASE/api/worker/version
curl -s -H "x-sts-key: $KEY" $BASE/api/worker/jobs | jq '.data[].status'
```

## How to get a key

1. Log in to klark0 as a **team owner** (gate is `user.teamRole === "owner"`,
   i.e. `team_members.role`, not the vestigial `users.role`).
2. User dropdown menu → **STS** (between *Sicherheit* and *Dokumentation*).
   Only visible when `NEXT_PUBLIC_STS_ENABLED=true`.
3. Choose scope → **Nur-Lese-Key** (default, `read`) or **Vollzugriff-Key**
   (`write`) → copy the `STS-<teamId>-<code>` key shown **once**.
4. Pass on every request: `x-sts-key: STS-10-6779`.

## Auth model — dual path, additive

Every STS-enabled route is wrapped with `withStsAccess` (`klark0/lib/auth/sts-access.ts`):

- **`x-sts-key` header present** → parse `STS-<teamId>-<code>` → validate against
  the team's stored `StsSession` (5s in-memory cache, invalidated on enable/disable).
  On success: `request.teamId`/`userId` set from key, `request.stsAuth = true`.
  On failure → `401 { error: "Invalid or inactive STS key." }`.
- **No header** → delegates to `withTeamContext` (existing browser session).
  Browser flows are a **no-op vs. today** — STS is purely additive.

Key format `STS-<teamId>-<16 hex>` (e.g. `STS-10-a1b2c3d4e5f67890`, 64-bit crypto-secure via node:crypto). Legacy `STS-<teamId>-<4 digits>` keys still validate until re-minted. The `teamId` is in
the key so lookup is single-team and the caller always sees only its own team's
data (existing proxy filters — job list by `originalRequesterTeamId`, FS sandbox
basePath — apply unchanged).

## Scope: `read` vs `write`

- `read` (default) → GET only. Non-GET → `403 { error: "STS key is read-only." }`.
- `write` → all methods.

`read` is enough for monitoring, assertions, test-setup verification.
`write` is required to mutate (mkdir/upload/enqueue/settings save/cancel).

## Discovery — `GET /api/sts/services` (start here)

Self-describing: returns every STS-enabled endpoint with `callable` flags
tailored to **your key's scope**. Always call this first — it's auto-discovered
from the guards themselves (the `__stsWrapped` marker on `withStsAccess`), so it
can never lie about whether a route is protected.

**Prod-Limitierung (Befund 2026-10-13, klark0 fix d720c789):** die Discovery ist
ein Source-Walk (fs-Glob über `app/api/*.ts`) — from-artifact/standalone-Builds
(klark.one, kontext.one) haben keinen walkbaren Source im cwd. STS funktioniert
dort unbeeinträchtigt, aber `/api/sts/services` liefert dann `sourceAvailable:
false` + `discoveryNote` (vor dem Fix: still 0 Endpoints — Agenten-Falle).
Auf Prod-Instanzen: nicht auf Discovery verlassen, dokumentierte Routen nutzen.

```bash
curl -s -H "x-sts-key: $KEY" $BASE/api/sts/services | jq '{
  caller: .caller,
  summary: .summary,            # {totalEndpoints, callableCount}
  callable: [.services[] | select(.callable) | "\(.method) \(.path)"],
  write_visible: [.services[] | select(.callable|not) | "\(.method) \(.path)"]
}'
```

Security-critical fields (`path`, `method`, `requiredScope`, `stsProtected`)
come ONLY from file location + export name + the `withStsAccess` call, never
from comments. Descriptions/gating come from `/** */` docstrings above handlers:

```ts
/**
 * Enqueue a worker task. Routed to heavy/light queue by task weight.
 * Returns 503 if the worker is unreachable.
 *
 * @sts gating=worker-liveness,team-scoped
 * @sts requestShape={type:string,name:string,parameters:object}
 * @sts teamScoped=true
 */
```

## Quick contract reference (route quirks — read before guessing)

Route contracts are NOT uniform. Verified live 2026-06-29:

| Route | Path param | Body / form |
|---|---|---|
| `GET /api/fs` | `?path=` query | — |
| `POST /api/fs/mkdir` | `?path=` query | — |
| `POST /api/fs/upload` | `?path=` query | form field **`files`** (not `file`); must pass `isAllowedDocFile` (`.txt` rejected, `.md`/docs ok) |
| `POST /api/fs/rename` | `?path=from&destination=to` query | — (cross-dir move = mv) |
| `POST /api/fs/copy` | `?path=from&destination=to` query | — (recursive: file or dir tree; WebDAV walks because dufs lacks depth-infinity COPY) |
| `POST /api/fs/archive` | `?path=` query (repeatable) | — (moves into top-level `Archiv/`, mirrors tree) |
| `POST /api/fs/delete` | `?path=` query (repeatable) | — (NOT DELETE — it's a POST route) |
| `GET /api/settings` | `?key=` query — keys: `fileSystem`/`aiServices`/`kiEinstellungen`/`documentParser` (NOT `fs`/`ai`/`ki`) | — |
| `POST /api/settings` | `?key=` query | settings object as JSON body |
| `POST /api/worker/jobs` | — | `{type, name, parameters}` JSON body |
| `POST /api/fs/audit/version` | — | `{path: <bieterDir>, action: "freeze"\|"tag"\|"untag"\|"fork"\|"describe"\|"activate", label?, beschreibung?}` JSON body — Bieter-Versionierung (ADR-0009): freeze stempelt v1+Label, tag sichert (frozen_am), fork kopiert+löst alte ab; **describe nur nach freeze** (409 „erst freeze, dann benennen" auf Unversioniertem) |
| `POST /api/fs/audit/update-kriterien` | — | `{path: <audit.json-Pfad>, changes: [{id, action: "set_status", status: "audit.nein"}]}` JSON body — Write-Guard (403 frozen/superseded) feuert NUR mit valider Shape; falsche Shape = 400 Zodrum davor |
| `DELETE /api/worker/jobs/{jobId}` | path | — |

**Query-vs-Body-Falle** (Vorfall 2026-10-09): routes listed with `?path=` query read ONLY the
query string — a JSON body `{"path": …}` is silently ignored and the route answers a
misleading `400 „Fehlende Parameter"` (not „wrong shape"). Send mutations with query params
exactly as the table says; JSON body only where the Notes column says so. Multi-target
routes take `?path=` repeated (or comma-separated).

**KIQ-Quelle** (2026-10-13): `GET /api/fs/audit/stats?path=<bieterDir>` **berechnet** den KIQ
live (`stats.kriterien.kiq`/`kiqBewertet`/`total`) — `audit.json` persistiert KEINEN Score;
`meta.kriterienErgebnis` existiert nicht (kanonischer Client: klark0 `scripts/sts-kiq.mjs`).

**Archiv-Block**: Verschieben nach `Archiv/` nur via `/api/fs/archive` — `rename` dorthin
blockt mit 403. **Archiv ist eine Einbahnstraße (2026-10-13, Transport-Merge):** aus `Archiv/`
blockt die API `rename` UND `copy` (403 „Archivierte Elemente…“), Writes landen still nicht.
Zurückholen nur per **read+recreate** (Lesen geht): Dateien walken, per `/api/fs/upload`
neu hochladen, `.ofs.index.json` auslassen (Monitor heilt). Upload-Whitelist: Doku-Endungen
+ exakt `audit.json`/`projekt.json` + `*.md` — andere `.json` (Sidecars, `faps.json`…)
werden rejected; Schmuggelweg: als `<name>.md` hochladen, dann `/api/fs/rename` auf den
echten Namen (Rename prüft keine Endung). `._*`-AppleDouble-Dateien = Mac-Junk, nicht kopieren.

## What an agent can do via STS

| Capability | Endpoint(s) | Scope |
|---|---|---|
| **Introspect** | `GET /api/sts/services` | read |
| **Worker liveness** | `GET /api/worker/version` | read |
| **List/available tasks** | `GET /api/worker/list` | read |
| **List jobs** (auto team-filtered) | `GET /api/worker/jobs` | read |
| **Job status / result** | `GET /api/worker/jobs/{jobId}` | read |
| **ROBOTNI stream** | `GET /api/worker/jobs/{jobId}/stream` | read |
| **Read settings** (secrets masked `***`) | `GET /api/settings`, `/settings/worker`, `/worker/settings` | read |
| **Read filesystem** | `GET /api/fs`, `/fs/read`, `/fs/metadata` | read |
| **Enqueue task** | `POST /api/worker/jobs` | write |
| **Cancel job** | `DELETE /api/worker/jobs/{jobId}` | write |
| **Create project/bidder/folder** | `POST /api/fs/mkdir` | write |
| **Rename / move** | `POST /api/fs/rename` | write |
| **Copy** (file or recursive dir tree) | `POST /api/fs/copy` | write |
| **Archive** (move into `Archiv/`) | `POST /api/fs/archive` | write |
| **Upload file** | `POST /api/fs/upload` | write |
| **Delete** | `POST /api/fs/delete` | write |
| **Pause/resume queue** | `POST /api/worker/queue/{queue}/pause\|resume` | write |
| **Queue state** | `GET /api/worker/queue/state` | read |
| **Reindex OFS** | `POST /api/fs/index` | write |
| **Settings save** | `POST /api/settings`, `/settings/worker`, `/worker/settings` | write |

## Invariants (always hold)

1. **Owner-only activation** (`isTeamOwner`, reads `team_members.role`).
2. **One active key per team** — re-activating overwrites; deactivate = instant lockout.
3. **STS never bypasses business guards.** Sandbox path resolution
   (`lib/fs/server-filesystem.ts`), read-only path guards (`getReadOnlyPathReason`
   for archive/`_` folders), file-type allowlists, and RBAC all stay active.
   Verified live: `_`-prefixed path writes rejected; `.txt` uploads blocked.
4. **Secret masking on read.** The 3 settings routes are wrapped in the
   `withStsAccessSettings` preset, which masks secret fields (`"***"`) on the
   way out — the consequence lives behind the STS seam, not in the handlers.
   Masked set (`SECRET_KEYS`, `lib/auth/secret-masking.ts`): `workerAuthPassword`,
   `bearer`/`bearerGemini`/`bearerOpenai`/`bearerUniinfer`, `geminiApiKey`,
   `openaiApiKey`, `encryptionKey`, WebDAV `username`/`password`. Verified live.
5. **Team scoping is automatic.** `teamId` parsed from key → existing proxy
   filters apply → no cross-team data leak.

## Explicitly NOT STS-enabled

- `/api/sts` itself (management stays session-only — a key must not extend itself).
- `/api/auth/**`, user/team management.
- `/api/fs/stats` (session-only; polls WebDAV).
- Callbacks (`/api/worker/jobs/callback_generic` — posted *by* the worker).

## Code map (klark0)

| Piece | Path |
|---|---|
| DB layer | `lib/db/sts.ts` (`StsSession`, `generateStsKey`, `parseStsKey`, `validateStsKey`, `enableSts`/`disableSts`) |
| Guard wrapper | `lib/auth/sts-access.ts` (`withStsAccess`, `withStsAccessSettings` preset) |
| Auth decision | `lib/auth/sts-decision.ts` (`decideStsAuth` — pure, no DB/Next) |
| Secret masking | `lib/auth/secret-masking.ts` (`SECRET_KEYS`, `maskSecrets`, `maskJsonResponse`) |
| Auth type | `lib/auth/team-context.ts` (`RequestWithTeam.stsAuth?`) |
| Discovery | `lib/sts/discover.ts` (`discoverStsServices`, `__stsWrapped` marker) |
| Management API | `app/api/sts/route.ts` (session-only) |
| Discovery API | `app/api/sts/services/route.ts` (STS-auth) |
| **Bash helpers** | `klark0/scripts/sts.sh` + `_sts-find.sh` + `_sts-grep.sh` (auto-read `sts.temp.key`) |
| UI | `components/StsModal.tsx`, gated in `app/(dashboard)/dashboard/layout.tsx` |

## E2E harness (consumes STS)

The deterministic Python E2E harness at
`python-utils/packages/agentos/agentos/e2e/` drives the full klark0→worker loop
via STS. Run flows against `--fake` (zero LLM, real ROBOTNI + files) for fast,
deterministic tests:

```bash
export STS_KEY="STS-10-XXXX"   # Vollzugriff for write scenarios
cd python-utils/packages/agentos
uv run python -m agentos.e2e auditflow-fake              # through the klark0 proxy
uv run python -m agentos.e2e auditflow-fake --client robotni   # direct to worker
```

## Fast auditflow repro (`--sim`, no LLM)

For verifying an auditflow-dependent feature (durable checkpoints, the activity
timeline, the criterion view) or reproducing an issue **without LLM cost or
endpoint flakiness**, enqueue a **simulated** auditflow via STS — it runs the
real `auditFlow.py` in simulation mode: fake LLM responses, **no `audit.json`
writes**, but it still emits the full ROBOTNI protocol (status/checkpoint/
result, `criterion_id`-tagged, with stage). Completes in seconds.

```bash
# Vollzugriff key; --sim = no LLM, no audit.json write, full ROBOTNI emit
./scripts/sts.sh -t 10 enqueue task_auditflow "sim repro" \
  '{"param":"test@test --id E_BERUFL_001 --sim --force"}'
# poll to complete (seconds), then inspect:
./scripts/sts.sh -t 10 job <jobId>                       # → data.robotniSummary.checkpoints
./scripts/sts.sh -t 10 get "/api/worker/jobs/<jobId>/stream"  # → live ROBOTNI lines
```

**Convenience wrappers** (readable + grep/CI-friendly, vs the raw enqueue above):
- `./scripts/sts.sh -t 10 sim` (alias `eval-completed`) — enqueue a `--sim`
  auditflow, poll to completion, print the completed-view derivation (Kriterium
  groups + verdict summary) from `robotniSummary.checkpoints`.
- `./scripts/sts.sh -t 10 tags` (alias `validate-tags`) — enqueue a `--sim` run
  and **validate the criterion-tagging contract**: every per-criterion step
  status (`stepNeedsContext`/`stepRetrieve`/`stepAssess`) carries
  `data.criterion_id`, and Route/Start/`auditflow_complete` stay global.
  PASS/FAIL per message + exit code (0 = pass) — the repeatable check for
  backend `auditflow-tag-step-statuses-with-criterion-id` and the ADR-0004
  frontend grouping that depends on it.

Gotchas:
- **`--sim` skips `audit.json` writes** (`_write_allowed(sim,dry) = not sim
  and not dry` in agentos) — so it tests the ROBOTNI/stream/durable-checkpoint
  path, not the static evidence side (use a real run, or the e2e `auditflow-
  fake` harness with file fixtures, for that).
- **Durable checkpoints land in `data.robotniSummary.checkpoints`**, **not**
  `result.checkpoints` (empty by design) — checking the wrong field is a common
  false-"not-live". See ADR-0004 "Verifying it (live)".
- Reach for this when the model endpoint is misbehaving (e.g. `[tu] network
  error on qwen-3.6-35b` hangs a real run for minutes).

## Pending hardening (Phase 2 — ticketed, not blocking)

See `.work/issues/backlog/sts-phase2-hardening.md`:
- TTL / auto-expiry (default 24h) — rotation best practice.
- Audit logging (`logs/sts-audit.jsonl`, identity+method+path+status only).
- Rate limiting (`STS_MAX_REQ_PER_MIN`, discovery exempt).

## Canonical references

- Design + rationale: `docs/archive/sts.spec.md`
- Best-practice validation: `docs/archive/soa-research.md`
- E2E strategy: `docs/archive/e2e.assessment.md`
- Live verification status: `klark0/AGENTS.md` "STS" → "Verification status"
