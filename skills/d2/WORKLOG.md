# D2 Skill — Worklog & Resume Context

> Read this first when resuming work on the `d2` skill. Everything needed to
> get back to speed fast: state, methodology, proven facts, earned gotchas,
> real artifacts, and the next steps.

---

## Status

- **Version:** v1.1.0 (recipes + diagram-types + delivery-polish guides; 35-test suite)
- **Hygiene pass (2026-07-13):** corrected the stale dagre/ASCII gotcha — the ASCII/text export ignores `--layout` *and* `vars.d2-config.layout-engine` (verified byte-identical), so ASCII works with any engine but doesn't reflect the delivered SVG's layout; dagre's real weakness is Sugiyama-DAG layout quality (cycles, fan-in, crossings). Added `tests/d2/test.sh` (23 checks). Trimmed SKILL.md to 88 lines.
- **Location:** `skale-skills/skills/d2/`
- **Activation:** 🟢 global — symlinked to `~/.pi/agent/skills/d2`
- **Type:** Knowledge skill (no scripts, no `pyproject.toml`, no `install.sh`)
- **Indexed:** yes — `SKILL-INDEX.md` lists it as global

### Files

| File | Lines | Role |
|------|-------|------|
| `SKILL.md` | ~95 | Frontmatter (routing) + render loop + core syntax + gotchas + workflow + status block. Keep under 100. |
| `references/syntax.md` | ~194 | Level-3 catalog: connections, shapes, containers, styles, special objects (sequence/sql/class), composition, layouts/themes. Loaded on demand. |
| `WORKLOG.md` | this file | Resume context. Not referenced by SKILL.md (won't load into agent context). Human/dev-facing. |

### Structure sanity

This is a pure-knowledge skill — same shape as sibling skills in the repo
(`command-creator`, `agents-md-init`, `todo`, `readme-write`): `SKILL.md` +
optional `references/`. Do **not** add `scripts/`, `pyproject.toml`,
`install.sh`, or a launcher — `d2` is a single `brew install d2` binary.
Those conventions in `CONVENTION.md` apply only to skills that bundle a CLI
(fetch-url, web-search, rodney).

---

## How This Skill Was Built (the methodology)

The whole skill was built by **dogfooding on real diagrams**, not from
memory or docs alone. The process — and it worked extremely well — is the
best-practices Section 14 "Start with a real task" approach:

1. Build a real diagram for a real codebase (`~/code/kontext.one`).
2. Every time something went wrong, or behaved non-obviously, capture it as a **gotcha**.
3. Each gotcha is **failure-backed** — we hit it, then verified the cause by testing, then wrote it down.
4. Gotchas are the highest-value part of the skill (best-practices Section 6).

**The verify loop** (this is the core of the skill — keep it sacred):

```bash
d2 validate diagram.d2      # 1. syntax check
d2 diagram.d2 diagram.txt   # 2. ASCII render — READ THIS to self-verify structure
d2 diagram.d2 diagram.svg   # 3. only then ship the SVG
```

The non-obvious key insight: **as an agent, I cannot view SVG/PNG images**
(current model doesn't accept image input). The ASCII export (`*.txt`) is my
*only* way to see a diagram. This makes ELK layout mandatory (ASCII needs
ELK/TALA, not dagre) and vertical layout preferable (horizontal terminal-wraps).

---

## Proven Facts About D2 (verified on this machine, jMacAir)

Verified by running `d2 0.7.1` directly, not from docs.

- **Binary:** `d2` at `/opt/homebrew/bin/d2`, v0.7.1 via `brew install d2`.
- **Layout engines installed (bundled, free):** `dagre` (default), `elk`. `tala` is paid — not installed.
- **SVG export:** zero dependencies, self-contained by default (`--bundle=true`).
- **PNG/PDF/PPTX/GIF:** use Playwright. **First run on a fresh machine downloads Chromium 129 + FFMPEG (~141 MiB)** to `~/Library/Caches/ms-playwright/`. Already cached on this machine now.
- **ASCII export (`*.txt`):** ELK/TALA only. With dagre it silently falls back and renders nothing useful. v0.7.1 calls it beta. Default charset = extended (Unicode box-drawing); `--ascii-mode standard` for plain ASCII.
- **Output formats:** svg, png, pdf, pptx, gif, txt. **No native HTML** — embed SVG.
- **Composition** (`layers`/`scenarios`/`steps`): `d2 x.d2 outdir` produces one SVG per board under `outdir/`. Animate into one SVG: `--animate-interval <ms>` (SVG only).
- **CLI subcommands:** `d2 layout [name]`, `d2 themes`, `d2 fmt x.d2` (in-place format; `--check` to lint), `d2 validate x.d2`, `d2 play x.d2` (open in playground).
- **Useful flags:** `--no-xml-tag` (embed SVG in HTML), `--salt <name>` (unique IDs for multi-SVG pages), `-l/--layout`, `-t/--theme`, `-s/--sketch`, `--scale`, `--pad`, `--target=<board>`.
- **Theme IDs:** 0 Neutral Default, 1 Neutral Grey, 3 Flagship, 5 Mixed Berry Blue, 6 Grape Soda, 8 Colorblind Clear, 200/201 Dark, 300 Terminal, 301 Terminal Grayscale, 302 Origami, 303 C4. Full list: `d2 themes`.

---

## The Gotchas — How Each Was Earned

Every gotcha in `SKILL.md` came from a real mistake or surprise. This table is
the audit trail; the SKILL.md gotchas are the distilled form.

| Gotcha | Discovery |
|--------|-----------|
| ELK mandatory for agent workflows (ASCII self-verify fails on dagre) | I can't view images → ASCII is my only eyes → confirmed ASCII needs ELK by testing |
| Default layout dagre is mediocre past a few nodes | Architecture diagram used ELK and looked great on first render |
| SVG default = no deps; PNG/PDF = 141 MiB download | First PNG render stalled downloading Playwright+FFmpeg |
| No HTML export → embed SVG (`--no-xml-tag`, `--salt`) | Read the exports doc page |
| `d2 validate` + `d2 fmt` verify loop exists | Ran both on the real diagrams |
| `vars.d2-config` for reproducible per-file config | Saw in tour intro, used it in every diagram |
| Vertical = agent-verifiable; `direction: right` is not (ASCII terminal-wraps) | First horizontal data-flow render was unreadable noise; vertical was instantly clear |
| Chain labels label EVERY edge, not the last (`a -> b -> c: label`) | Spotted `PARSE` on both edges in the readable vertical ASCII |
| Receive-only nodes pushed to layout end (LLM cloud) | Saw cloud displaced from callers in architecture diagram |
| Don't reference uninstalled icons | `icon: great-icon:apple` hard-failed the compile in a test probe |
| Cross-cutting shared-resource edges tangle layout | Auditflow had 6 LLM-calling steps → dropped cloud to a note, layout stayed clean |
| Small retry nodes render fine; large write-back cycles do not | Data-flow write-back tangled; auditflow retry loop (`assess → retry → assess`) laid out clean |

---

## Real Artifacts — kontext.one diagrams

All built by reading real code, all in `~/code/kontext.one/docs/diagrams/`.
Each produced `.d2` (source) + `.svg` (ship) + `.txt` (ASCII self-verify).

### 1. `architecture.d2` — system overview
- **Source read:** `README.md`, `docs/architecture.md`, `repos.yml`.
- **Shows:** User → klark0 (frontend) → worker machine (robotni + ARQ/Redis → task workers) → data (PostgreSQL + Dufs/WebDAV) + llm (uniinfer → 30+ providers).
- **Taught the skill:** the render loop works; SVG is the sane default; containers + dot notation.
- **Status:** looked "great" to the user on first render.

### 2. `data-flow.d2` — upload → audit pipeline
- **Source read:** `docs/architecture.md` data-flow section.
- **Shows (vertical):** USER → PDF → pdf2md → MARKDOWN → strukt2meta →(CLASSIFY→LLM)→ metadata → ofs → projekt.json → auditflow →(EVALUATE→LLM)→ pre.ki verdict → human reviewer → FINAL verdict.
- **Taught the skill:** vertical is agent-verifiable, horizontal is NOT; chain labels spread to all edges; write-back cycles tangle (fixed by using a distinct `final verdict` node instead of writing back to `projekt`).
- **Status:** clean, verified.

### 3. `auditflow.d2` — the NORMAL auditflow (not FAP)
- **Source read:** `python-utils/packages/agentos/auditFlow.py` (the real entrypoint, 2756 lines — NOT the empty `agentos/auditFlow.py`), `agentos/pas_resolver.py`, `agentos/flows/base.py`.
- **Key correction:** the user explicitly wanted the **normal auditflow**, not the FAP engine. First attempt built the FAP config-driven engine (`agentos/fap_flows/engine/`) — that was wrong. Rebuilt from `auditFlow.py`.
- **What the code revealed vs the doc:** doc said "flat 3-step (entscheideKontext → findeDoks → prüfeKriterium)" but reality is richer:
  - **Batch setup (once):** healthcheck → PRECHECKS (BIEGE, SUBUNTERNEHMER, FIRMENSTRUKTUR, LAND, PREIS → `audit.json` meta)
  - **Per criterion:** Route-Check (`stepRoute`) → [FAP branch | standard] → PAS routing (log-only) → Step 0 `stepNeedsContext` (`kontext_noetig` gates Step 1) → Step 1 `stepRetrieve` → deterministic enrichment (date-validity → signature meta → fact-extraction for truncated docs) → Step 2 `stepAssess` (retry ×2 on context-window err) → persist (atomic write → `audit.json`).
- **Taught the skill:** cross-cutting shared-resource edges tangle (dropped the 6-step LLM cloud to a comment); small retry nodes render fine.
- **Note:** there is ALSO a FAP engine diagram worth finishing one day (`fap_flows/engine/`: Gather → Audit (parallel arms) → Synthesis → Writeback). The FAP engine code is well understood already (see git history / earlier in this session) — `run_fap_flow` in `engine/runner.py`, phases `["gather","audit","synthesis","writeback"]`.

---

## What's Left / Next Steps

Prioritized. Each item, when done, should be validated by dogfooding.

### Hardening
- [ ] **`tests/d2/test.sh`** — per CONVENTION. Test: command available (`command -v d2`), version, `--help` has key flags, live smoke (render the bundled example to svg + txt), file structure check. Live tests must be network-resilient (warn, not fail).
- [ ] **Bump version** to 0.1.0 once tests pass and the open content gaps below are closed. (Only SKILL.md frontmatter carries version — no pyproject.toml to keep in sync for a knowledge skill.)
- [ ] Remove the "work in progress" status block in SKILL.md when stable.

### Content gaps in `references/syntax.md`
- [ ] **Sequence diagrams** — a worked example (we validated the syntax renders, just not a full guide). Use case: API call flows, robotni task protocol (`[ROBOTNI] <type> <json>`).
- [ ] **ER / SQL tables** — validated `sql_table` renders. A real ER diagram of the kontext DB (via Drizzle schema in `klark0/lib/db/`) would be a great dogfooding target.
- [ ] **Composition recipes** — `layers` (current vs proposed), `scenarios` (happy vs error), `steps` (progression). The data-flow could be re-done as `steps` to teach this.
- [ ] **A `.d2` snippet library** in `references/` — reusable shapes for common architecture primitives (DB, queue, external service, user, gateway). Currently each diagram reinvents these.

### More drill-downs (dogfooding candidates)
- [ ] **OFS directory layout** — a file tree (`Project/A/`, `Project/B/Bidder/`, `projekt.json`, `audit.json`). **Caveat: D2 isn't built for file-trees** — likely a skip or a hand-drawn adjunct. If attempted, document whether D2 can do it.
- [ ] **Audit status lifecycle** — `sync → pre.ki.ja/nein/teilweise → audit.ja/nein/teilweise`. Small, good fit.
- [ ] **klark0 internals** — API routes (`/api/worker/*`, `/api/fs/*`), Drizzle, JWT auth, proxy layer. A `layer` in composition, or a detailed box.
- [ ] **FAP engine** — code is already understood (see above); just needs the diagram rebuilt and verified.
- [ ] **Worker task pipeline** — ARQ/Redis queue mechanics, `rob.sh`, the `[ROBOTNI]` progress protocol, subprocess `uv run` spawning.

---

## How To Resume

1. **Re-read this file** (you're here). Skim the Gotchas table and Real Artifacts.
2. **Check the skill is still active:** `ls -la ~/.pi/agent/skills/d2` (should be a symlink). `d2 --version` (should be 0.7.1).
3. **Pick a task** from "What's Left" — dogfooding targets are highest-value (they generate new gotchas).
4. **Follow the verify loop for any diagram work:** `d2 validate` → `d2 x.d2 x.txt` (read ASCII) → `d2 x.d2 x.svg` → ship `.d2` + `.svg`.
5. **Every surprise or mistake → new gotcha** in SKILL.md, with a one-line "how discovered" note here in the Gotchas table.
6. **Keep SKILL.md under 100 lines.** Overflow detail goes to `references/syntax.md`.

### Quick command reference (proven)

```bash
# verify
d2 validate diagram.d2
d2 fmt --check diagram.d2        # lint without writing

# render
d2 diagram.d2                    # → diagram.svg
d2 diagram.d2 diagram.txt        # ASCII self-verify (needs ELK)
d2 diagram.d2 diagram.svg --no-xml-tag --salt one   # for HTML embedding

# introspect
d2 --version                     # 0.7.1
d2 layout                        # available engines
d2 themes                        # theme IDs
d2 --help                        # full flag list
```
