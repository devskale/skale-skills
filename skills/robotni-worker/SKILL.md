---
disable-model-invocation: true
name: robotni-worker
description: "Fix and develop worker jobs across frontend and backend. Covers the full robotni worker stack — klark0 worker API, robotni_arq backend, and the ROBOTNI messaging protocol between them. Use when debugging job failures, adding new task types, changing progress display, modifying the worker API contract, or launching/polling/cancelling jobs on a Robotni API."
compatibility: "Requires robotni_arq running (FastAPI + ARQ worker + Redis). klark0 for frontend changes."
metadata:
  author: skale
---

# Robotni Worker Stack

Full-stack guide for developing and debugging worker jobs that span klark0 (frontend) and robotni_arq (backend).

## Architecture — the data flow

```
klark0 (Next.js)                          robotni_arq (FastAPI + ARQ)
─────────────────                         ──────────────────────────
POST /api/worker/jobs  ───enqueue───►     POST /api/worker/jobs
   {type, name, parameters}                  → Redis queue
                                             → ARQ worker picks up
                                             → Task runs, emits ROBOTNI messages to stdout
                                             → Stdout stored in Redis stream
GET /api/worker/jobs   ◄──poll/list───     GET /api/worker/jobs
GET /api/worker/jobs/{id}/stream            GET /api/worker/jobs/{id}/stream
   → Parse ROBOTNI messages
   → Display progress, status, results
DELETE /api/worker/jobs/{id} ◄──cancel────     DELETE /api/worker/jobs/{id}
   → Cancel queued/in-progress/deferred jobs
   → Worker aborts via asyncio.CancelledError
   → Cancelled jobs are filtered from list responses

Callback flow:
POST /api/worker/jobs/{id}/callback_generic
   {status, result, stdoutTail}
```

**Key insight**: klark0's worker API is a proxy. It forwards to robotni_arq and parses the ROBOTNI protocol from stdout. The actual job runs in Python.

## Code locations

### Frontend (klark0)

| Component | Path | What it does |
|-----------|------|-------------|
| Worker API routes | `app/api/worker/jobs/route.ts` | POST to enqueue, GET to list |
| Callback handler | `app/api/worker/jobs/callback_generic/route.ts` | Receives job completion callbacks |
| Worker settings | `app/api/worker/settings/route.ts` | Worker server URL config |
| Message parser | `lib/worker/robotni-messages.ts` | Parses `[ROBOTNI]` lines from stdout |
| Base URL resolver | `lib/worker/base-url.ts` | Resolves worker server URL from settings |
| Job matcher | `lib/worker/jobMatcher.ts` | Matches jobs to UI targets |
| Tool presets | `config/worker-tools.ts` | Available tool definitions |

### Backend (python-utils/packages/robotni/robotni_arq)

| Component | Path | What it does |
|-----------|------|-------------|
| FastAPI app | `robotni_arq/api.py` | REST API endpoints |
| ARQ worker | `robotni_arq/workers/worker.py` | Job execution loop |
| Task functions | `robotni_arq/tasks.py` | Auto-discovered task handlers (`task_*` functions) |
| Messaging helpers | `robotni_arq/messaging.py` | Re-exports from `robotni_messaging` package |
| Subprocess config | `subprocess_config.yaml` | CLI tool → task type mapping |
| Start/restart | `rob.sh` | `./rob.sh start\|stop\|restart\|status` |

### Protocol spec

Load when changing the ROBOTNI protocol or debugging message parsing:

- [robotni-messaging-spec.md](https://github.com/devskale/klark0/blob/dev/docs/dev/robotni-messaging-spec.md) — canonical wire format spec (kanonisch NUR hier; GitHub: devskale/klark0/blob/dev/docs/dev/)
- [packages/robotni_messaging/docs/frontend-guide.md](https://github.com/devskale/python-utils/blob/dev/packages/robotni_messaging/docs/frontend-guide.md) — frontend integration guide

## ROBOTNI messaging protocol — essentials

### Wire format

```
[ROBOTNI] <type> <json_payload>
```

Regex: `/^\[(ROBOTNI(?::V\d+)?)\]\s+([a-z0-9_]{1,32})\s+(.+)$/`

### Message types

| Type | Purpose | Required fields |
|------|---------|----------------|
| `status` | Phase changes, lifecycle | `phase`, `message` |
| `progress` | Progress bar | `current`, `total`, `percent` |
| `checkpoint` | Milestones | `step`, `message` |
| `result` | Final outcome | `status` (`"success"` or `"warning"`), `message`, `phase` |
| `warning` | Non-fatal issues | `message` |
| `error` | Fatal errors | `message` |

### Critical contract rules

1. **First message must be `status`** — signals task started
2. **`result` must include `status`** — frontend uses it for badge color (`"success"` green, `"warning"` orange)
3. **`result` must include `phase`** — frontend routes by phase
4. **`checkpoint` must include `step`** — frontend reads `step`, not `name`
5. **Always calculate `percent`** — don't rely on frontend computing it from `current`/`total`
6. **No messages after `result`** — extractors stop at result

### Phase routing

| Phase | Pipeline |
|-------|----------|
| `pdf2md` | PDF conversion |
| `strukt2meta` | OFS processing |
| `auditflow` | Criteria auditing |
| `fapflow` | FAP sub-flow |
| `matchaflow` | Document matching |

## Worker API — interact directly

For launching, polling, or canceling jobs on any Robotni API server.

### Resolve worker URL and auth

Server config lives in `repos.yml` under `servers:`. Each server may have:

```yaml
servers:
  rageval:
    url: https://rageval.ds-ifs.tuwien.ac.at
    base_path: /rob          # Robotni API prefix (varies per server)
    http_auth:
      user: skale
      password: $nrflW26     # HTTP Basic Auth (same credentials may be shared across servers)
  tu:
    ssh: tu
    http_auth:
      user: skale
      password: $nrflW26
    note: TU Vienna server, production worker
```

Read `repos.yml` at session start to resolve URLs. The full API base is `{url}{base_path}`.
Some servers share credentials (e.g. `tu` and `rageval` both use the same nginx auth).

### API endpoints

All endpoints use HTTP Basic Auth. Replace `$BASE` with `{url}{base_path}`.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `$BASE/api/worker/version` | Server version, uptime, installed tasks |
| GET | `$BASE/api/worker/list/` | Available task types and their default params |
| POST | `$BASE/api/worker/jobs` | Enqueue a job |
| GET | `$BASE/api/worker/jobs` | List all jobs |
| GET | `$BASE/api/worker/jobs/{id}` | Single job status |
| GET | `$BASE/api/worker/jobs/{id}/stream` | Full stdout (ROBOTNI messages) |
| DELETE | `$BASE/api/worker/jobs/{id}` | Cancel queued/in-progress/deferred job (non-blocking, ~ms) |
| GET | `$BASE/api/worker/queue/state` | Queue pause state + depth: `{queues:[{name,paused,depth}], paused_any}` |
| POST | `$BASE/api/worker/queue/{queue}/pause[?ttl=<sec>]` | Pause a queue (`{queue}` ∈ `arq:queue\|light\|all`); stops new pickups, in-progress drains |
| POST | `$BASE/api/worker/queue/{queue}/resume` | Resume a paused queue |

> **Enqueue-gate:** while a queue is paused, `POST /api/worker/jobs` for that
> queue returns **HTTP 409 `{success:false, error:"queue_paused", details:"…"}`**
> — it does NOT queue the job. (klark0 surfaces this as a tailored toast.)

### Workflow: launch → poll → read

```bash
# 1. Check server is alive
curl -s -u 'skale:$nrflW26' https://rageval.ds-ifs.tuwien.ac.at/rob/api/worker/version

# 2. List available task types
curl -s -u 'skale:$nrflW26' https://rageval.ds-ifs.tuwien.ac.at/rob/api/worker/list/

# 3. Launch a job (POST body: type, name, parameters)
curl -s -u 'skale:$nrflW26' -X POST https://rageval.ds-ifs.tuwien.ac.at/rob/api/worker/jobs \
  -H 'Content-Type: application/json' \
  -d '{"type":"task_ofs","name":"ofs tree","parameters":{"param":"tree -d"}}'
# → returns {"success":true,"data":{"id":"<job_id>","status":"queued",...}}

# 4. Poll until complete (check status field)
curl -s -u 'skale:$nrflW26' https://rageval.ds-ifs.tuwien.ac.at/rob/api/worker/jobs/<job_id>

# 5. Read full output stream
curl -s -u 'skale:$nrflW26' https://rageval.ds-ifs.tuwien.ac.at/rob/api/worker/jobs/<job_id>/stream | \
  python3 -c "import sys,json; print('\n'.join(json.load(sys.stdin)['stream']))"

# 6. Cancel a job
curl -s -u 'skale:$nrflW26' -X DELETE https://rageval.ds-ifs.tuwien.ac.at/rob/api/worker/jobs/<job_id>
```

> **Stream-Kappung:** `/stream` liefert nur die letzten **~200 Zeilen** (Ringbuffer) —
> Vollbäume kommen gekappt an. Kompakte Kommandos wählen (`tree -d` statt `tree`,
> `list-projects`, gezielte `list-bidders`), sonst ist der Output still unvollständig.
> Für Korpus-Inventur gibt es `./k.sh ofs-corpus inventory @<server>` (macht genau das).

### Poll loop pattern

For long-running jobs, poll in a loop until status leaves `queued`/`in_progress`:

```bash
JOB_ID="<id>"
while true; do
  STATUS=$(curl -s -u 'skale:$nrflW26' "$BASE/api/worker/jobs/$JOB_ID" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['status'])")
  echo "$STATUS"
  case "$STATUS" in complete|failed|cancelled) break ;; esac
  sleep 3
done
```

## Common tasks

### Build a task parameter (identifier + limits)

Two silent traps when enqueueing auditflow-style tasks (cost real jobs 2026-10-05/06):

- **Identifier = FULL project dir name**, never the projekt.json display name.
  OFS `get_path` fuzzy-resolves bare names — `Brandschutzschaum` matched the
  historical copy `Archiv/Brandschutzschaum` (no projekt.json → instant
  FileNotFoundError). Correct: `'PUT Brandschutzschaum@Hilti reeval'` — the
  frontend builds it via `getBidderContextIdentifier` (lib/fs/fileTreeUtils.ts).
- **`--limit` defaults to 10** (`flows/base.py: default_limit = 10`). A naked
  reeval with 14 criteria silently processed only 10 ("Auditliste: 14,
  criteria_total: 10"). Full runs need explicit `--limit 0` (= no cap).

```json
{"type":"task_auditflow","name":"…","parameters":{"param":"'PUT Brandschutzschaum@Hilti reeval' --limit 0"}}
```

### Debug a failing job

```bash
# Check robotni is running
ssh <server> 'cd code/python-utils/packages/robotni/robotni_arq && ./rob.sh status'

# List recent jobs
curl <suser:spass>@<worker_url>/api/worker/jobs | python3 -m json.tool

# Get specific job stdout (ROBOTNI messages)
curl -suser:spass>@<worker_url>/api/worker/jobs/<job_id>/stream

# Check Redis
ssh <server> 'redis-cli ping'
```

### Add a new task type (backend)

1. Create `async def task_my_thing(ctx, params)` in `robotni_arq/tasks.py`
2. Emit ROBOTNI messages:
   ```python
   from robotni_arq.messaging import robotni_status, robotni_progress, robotni_result
   robotni_status(phase="my_thing", message="Starting...")
   robotni_progress(current=1, total=10, percent=10, message="Processing...")
   robotni_result(status="success", message="Done", phase="my_thing")
   ```
   Note: `robotni_arq.messaging` re-exports from the shared `robotni_messaging` package.
3. Verify discovery: `curl <worker_url>/api/worker/list/`
4. Restart: `./rob.sh restart`
5. **Validate:** enqueue a test job from the frontend or `curl -X POST`, confirm ROBOTNI messages appear in `/stream` and job completes.

### Add a tool preset (frontend)

Edit `config/worker-tools.ts` — add entry with `id`, `name`, `description`, `type` (must match backend task function name).

### Test ROBOTNI output

```bash
# Validate pipeline output against all rules
cd klark0
npx tsx tests/validate-robotni-messaging.ts --run

# Pipe specific tool output through validator
uv run pdf2md fake --nail --bad | npx tsx tests/validate-robotni-messaging.ts --stdin
```

## Status mapping — frontend ↔ backend

| Backend (ARQ) | Frontend display | Progress |
|---------------|------------------|----------|
| `queued` | `pending` | 0 |
| `in_progress` | `running` | from ROBOTNI `progress` |
| `deferred` | `running` | from ROBOTNI `progress` |
| `complete` | `completed` | 100 |
| `failed` | `failed` | 100 |

## Gotchas

- klark0 proxies to robotni_arq — the worker URL is in team settings (DB), not hardcoded
- `stdoutTail` in job listing is only 3 lines — use `/stream` endpoint for full output
- Progress in the API defaults to 0 for running jobs — real progress comes from parsing ROBOTNI stdout
- Messages must be single-line JSON — no newlines in payload
- `message` fields should be German (user-facing), `phase`/`step`/`code` in English
- `robotni_arq/messaging.py` is a re-export shim — actual implementation lives in the `robotni_messaging` package
- **base_path varies per server** — e.g. `/rob` on rageval, `/` on others. Always read `repos.yml` to resolve. A 404 on `/api/worker/version` means the base_path is wrong.
- **Auth is required** — all endpoints return 401 without HTTP Basic Auth. Credentials come from `repos.yml` `servers.<name>.http_auth`.
- **Job IDs are `job_<epochms>_<hex>`** — e.g. `job_1783117961472_11fae` (NOT 15-hex, NOT UUIDs). Treat as opaque strings.
- **`ts` is emitted on every ROBOTNI message** — epoch-ms integer (see spec §3.0). Use for real per-step durations.
- **Status mapping is centralized in klark0** — `lib/worker/job-status.ts` (`mapStatusToUi`, `isActiveStatus`, …). Don't re-derive per component.
- **Cancel is non-blocking + fast** — `DELETE` flags + returns immediately (~ms, was up to 5s); the job vanishes from the next list poll.
- **Queue pause is real server-side control** — pauses stop *new* pickups; in-progress jobs finish naturally; new enqueues are 409-gated while paused.
