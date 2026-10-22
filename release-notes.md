## Unreleased

### youtube — Registry-Metadata: uptime %, api-Flag, Region (health sichtbar machen)
- **`youtube hosts` zeigt jetzt Registry-Daten** (beide Views, cached + `--probe`):
  30-Tage-Uptime-%, `api:yes/NO/?`-Flag und Region aus der offiziellen
  Registry (api.invidious.io) — direkt neben dem eigenen Live-Probe.
- **Kill-Kriterium vorab sichtbar:** eine Instance kann 99,6% "up" sein,
  während der Betreiber die API abgeschaltet hat (403 auf `/api/v1/*`).
  Live gemessen 2026-10-21: 4/5 Registry-Instanzen `api: false` —
  ein 403-Roulette, das der Flag vorab verrät.
- **Probe-Order nutzt die Daten** (`discover_instances`): api-enabled,
  high-uptime Hosts zuerst — spart Fehlprobes auf API-gesperrte Instanzen.
- Cache: `.instance-registry.json`, 6h TTL, stale-Fallback bei
  Registry-Ausfall. Unit-Tests (6 neue, gemockte Registry), Suite 54/54 grün,
  Live-Smoke ok.

### fetch-url 2.9.0 — defuddle: lokale Haupt-Inhalts-Extraktion (neues Tool)
- **Neues Tool `defuddle`** ([kepano/defuddle](https://github.com/kepano/defuddle),
  Obsidian Web Clipper Engine): curl_cffi-Fetch (Chrome-TLS-Impersonation) →
  `npx defuddle parse --json`. Lokal, kostenlos, unbegrenzt — keine Dritt-API.
- **Live-benchmarkt (2026-10)** gegen w3m/lynx/jina: gewinnt auf GitHub
  (README-only, 13 KB statt 20 KB Nav-Chrome), MDN (3,9 statt 7,2 KB) und
  Python-Docs; verliert auf List-Seiten (HN) und JS-Shells. Site-Hints
  umgestellt: github.com / docs.python.org / developer.mozilla.org →
  defuddle-first; Wikipedia → defuddle als jina-Fallback.
- **Shell-Gate:** JS-Shells (Medium ~48 Wörter Nav-Reste) werden über defuddles
  `wordCount` erkannt (<100 = Shell → Failure → Fallthrough), sodass defuddle
  nie jina/markdown auf JS-Seiten verdrängt.
- `curl_cffi>=0.7` als Dependency (TLS/JA4-Gate-Prophylaxe, apisniffer-SOTA-
  Check), pinned `defuddle@0.19.5` (pre-1.0). `--tool defuddle` im CLI.
  Hintergrund + Benchmark: `references/inspirations.md`.

### visualize — pele-Gallery als lebendes Beispiel (`examples/`)
- Die Sechs-Typen-Gallery (Flowchart+Subgraph, Sequenz, Git-Graph, Gantt, Pie,
  Mindmap — alles echte Session-Daten) liegt jetzt als gefülltes Beispiel unter
  `examples/pele-gallery.html`: in SKILL.md verlinkt, in der Test-Suite durch
  lint/validate/jscheck gegrünt.
- Lehre gebakt: pele-Gantt-Task-Namen dürfen kein `:` enthalten ("too many
  fields") — als Gotcha ins pele-Modul in modules.md dokumentiert.

### visualize — pele als Diagramm-Renderer (neues Template `pele.html`)
- **pele** ([pele.run](https://pele.run/), MIT, Obsidian) rendert Mermaid-Syntax als
  themeable SVG: zero deps, 6× kleiner, ~0,1 ms statt 6–82 ms. Neues CDN-Template
  `templates/pele.html` — gleiche Anatomie wie `mermaid.html`, aber die pele-Farben
  sind CSS-Variablen (`--pele-*`), die in `:root` auf die House-Tokens gemappt sind:
  Diagramme folgen dem Skin ohne Re-Render.
- `references/modules.md`: neues Modul `pele` mit Wann-pele/wann-mermaid-Regel
  (House-Feeling, mobile `responsive`/`maxWidth`, viele kleine Diagramme → pele;
  ZenUML/HTML-Labels → mermaid). `templates/README.md` + `scaffolds.md` registriert,
  Test-Suite lintet/validiert/jscheckt das neue Template.
- Smoke (rodney, file://): Flowchart + Sequenzdiagramm 2/2 in 20 ms gerendert,
  theming greift, `supports("gantt")=true`. Integration in `inspirations.md` →
  adoption vollzogen (Steal-Item „Renderer swap candidate" umgesetzt).
- **README-Refresh — super images:** alle Flow-Bilder durch visualize-Seiten ersetzt
  (HTML = Source of Truth, PNG derived via rodney-Screenshot auf Seitennhöhe):
  `web-search-flow` / `fetch-url-flow` / `surf-flow` (paper flavor, pele-Diagramme) ersetzen
  die alten figure-PNGs bzw. die D2-SVG; visualize-Sektion bekommt zwei Selbst-Demos —
  `visualize-flavors` („One system, four moods": alle 4 Skin-Flavors im selben Bild,
  Token-Sets 1:1 aus skin.html) und `visualize-showcase` (alle Muster auf einer Seite:
  pele-Diagramm, Karten-Grid, ehrlicher Barchart mit echten pele-vs-mermaid-Daten,
  Prozess-Timeline). Alle Seiten durch `visualize gate` (validate/slop/chartcheck/jscheck)
  gegrünt, PNGs vision-verifiziert; `docs/skill-diagrams.md` dokumentiert die neue
  Pipeline (Legacy figure/D2 bleibt verlinkt). docs-Integrity: PASS 46 FAIL 0.

### imagegen 1.1.1 — P3-Express: Parser-Guard (nur #1); #3 zurückgezogen
- `-n two` / `--seed=abc`: NaN floss still in die Loop und endete als irreführendes
  „no images returned". Der Parser verwirft nicht-numerische Werte jetzt und
  meldet sie (`invalid`), der Handler zeigt eine Warnung; der n-Clamp in
  `generateAndSave` ist zusätzlich NaN-sicher (hand-editierte Settings-Datei).
  `parseImagegenArgs` exportiert, in Test [8] gepinnt.
- **#3 (State-Race) zurückgezogen** — Review-Fehler: `learnCost`/
  `rememberLastGood` sind synchron, im single-threaded JS ist load-modify-write
  damit atomar; in-process geht nichts verloren. Cross-session gilt weiter
  last-writer-wins (unverändert, akzeptabel). Lehre: vor „Race!" die
  Event-Loop-Semantik prüfen — sync Code rast nicht.
- #2 (dynamische Modell-IDs in der Beschreibung) bewusst verworfen — die
  Fallback-Kette fängt ID-Rotte ab, dynamische Descriptions wären Komplexität
  für Kosmetik. #4 (402-Präzision) auf Nutzer-Entscheid entfallen (402 ist
  sichtbar genug).

### imagegen 1.1.0 — Stabilitäts-Paket: Fetch-Caps, Auth-Klasse, Offline-Integrationstest
- **Fetch-Timeouts**: jeder ausgehende Fetch gedeckelt (Generierung 180 s,
  Katalog 15 s, per handgerolltem AbortSignal-Kombinator — `AbortSignal.any`
  fehlt in der TS-Lib-Stufe). Ein hängender Proxy hängt nie mehr den Tool-Call.
- **Auth-Fehler-Klasse** (`isAuthRejected`, exportiert): 401/403 + revoked-Token-Detail
  überspringt die Katalog-Sonde (jeder Kandidat fiele identisch), feuert sofort
  den pollinations-Notfallpfad, und der Rotation-Hinweis überlebt auch einen
  fehlgeschlagenen Notfallversuch (`sawAuthRejection`-Flag — der Emergency-Fehler
  überschreibt sonst lastError). Genau die 2026-10-17-Incident-Klasse.
- **Gateway-Key-Memo** pro Session: credgoo (bis 8 s) läuft nicht mehr pro
  Generierung — Restart re-resolviert.
- **Offline-Integrationstest [8]**: Mock-Relay (python, dynamischer Port) treibt
  das kompilierte `generateAndSave` hermetisch (HOME-Sandbox, fake auth.json,
  credgoo nicht erreichbar): 401→Emergency+Hinweis (oder echter Emergency-Erfolg
  mit Netz — beides pinnt den neuen Pfad; der alte Code scheitert an beidem),
  Valid-Token→Datei+Prompt-Metadaten, plus Classifier-Pins mit den echten
  Incident-Strings. Zwei Prozesse, weil der Key-Memo den Key-Swap prozesslokal
  unsichtbar macht. Suite: 24 PASS / 0 WARN.
- `generateAndSave`, `parseCost`, `isModelUnavailable` für Tests exportiert.

### imagegen 1.0.2 — ein Gateway-Token: credgoo-Service `unii` (Nutzer-Präferenz)
- Statt zweier Provider-Services (pollinations, tu — beide gelöscht) liest die
  Auflösung jetzt EINEN Token aus EINEM Service: `<PROVIDER>_API_KEY` (scoped
  Override) → `UNIINFER_API_KEY` → `credgoo unii` → `auth.json unii.key`.
  Ein Gateway, ein Token, ein Rotationspunkt — keine Schattierung mehr durch
  veraltete Provider-Einträge (die 2026-10-17- Ursache).
- Suite live grün über den Einzel-Service (22 PASS / 0 WARN).

### imagegen 1.0.1 — Tokens + Katalog-ID repariert (live wieder grün)
- Beide credgoo-Bild-Tokens (pollinations, tu) waren am Proxy revoked — der
  gültige Gateway-Token lag in `~/.pi/agent/auth.json` (`unii.key`) und wurde
  von den toten credgoo-Einträgen geschattet. Beide Services jetzt mit dem
  gültigen Token bestückt (Auflöse-Kette der Extension unverändert:
  env → credgoo → auth.json).
- uniinfer hat die pollinations-Modell-IDs namespaced (2026-10-17):
  `dreamshaper` → `lykon/dreamshaper-8-lcm` (tu unverändert). Tool-Beschreibung
  + Tests auf die neue ID; Suite damit erstmals wieder komplett live grün
  (23 PASS / 0 WARN, beide Provider generieren echt).

### xmodel 0.5.15 — toDisplayPng photon-only, sips-Fallback raus (pi#10292 gefixt)
- Anlass: pi 1.0.1 hat den Original-Bug upstream gefixt
  ([pi#10292](https://github.com/earendil-works/pi/issues/10292) — Kitty `f=100`
  warf non-PNG still weg; pi-tui konvertiert seitdem zur Render-Zeit über einen
  photon-Transcoder). Unser `toDisplayPng` bleibt trotzdem: pi's Transcoder
  konvertiert NUR (kein Resize, verifiziert an pi 1.3.0, `image-convert.js`) —
  unsere 1200px-Kappe hält den APC-Payload ~5× klein.
- sips-Fallback (macOS-only) entfernt: in Test-Kontexten maskierte er still
  einen nicht auflösbaren photon (WARN-grün statt FAIL). Fehlerfall jetzt
  ehrlich: Input unverändert → pi's Render-Zeit-Transcoder als Safety-Net.
- `PI_PHOTON_ENTRY` in `loadPhoton()`: expliziter photon-Einstiegspfad für
  Tests/Embeddings (argv[1] ist dort nicht pi).
- Test [3] neu gebaut: tsc-kompiliert (raw node kann die .ts-Sourcen nicht
  laden — extensionless Imports), committete Fixtures (png/jpg/gif/webp),
  photon-Gate via `normalizationProbe` (exit 77 = ehrlicher WARN). Lief zuvor
  nie wirklich: Fixtures wurden zur Laufzeit per sips generiert (schlug fehl),
  und der raw-node-Aufruf war seit dem photon-Import (0.5.13) kaputt — beides
  still hinter einem WARN.

### pdf2mark 1.7.0 — result cache + job attach: big PDFs unblocked
- Reading a 100-page PDF took ~5-6 min **every time** (server-side pdfplumber
  ~0.5-3.6s/page + upload + polling) — and agents re-read the same file on
  every follow-up. Two client-side unblocks, no server changes:
  - **result cache** (`~/.cache/pdf2mark/`, keyed by content hash + method
    + tier): the second read is instant (measured: 6m07s → 0.23s, identical
    output, `converter=cache/…`). `--force` bypasses, `PDF2MD_CACHE` overrides.
  - **job registry** (`jobs.json`): async job ids are persisted — a re-run
    while a job is running (or within the ~2h server-side TTL) re-attaches
    to it instead of re-uploading and re-converting.
- Offline mock-API tests pin all three paths (cache hit / --force / attach);
  pre-existing network tests now pass `--force` so a cached fixture can't
  defeat them.

### xmodel 0.5.14 — read_image is the canonical understand path
- Evidence (2026-10-16, two sessions): schema-strict providers never emit the
  out-of-schema `understand` param on `read` — the model *intends* it, tool-call
  generation drops it (glm/tu: 4/4 dropped; the tldraws agent burned three reads
  before falling back). Advertising the param first made agents try the path
  that cannot work.
- Protocol note, handover note, read_image description and guidelines now lead
  with `read_image` (declared with path/focus/thinking params — every provider
  can call it; it displays the image AND returns the analysis).
- The `understand` interception stays (works where providers do emit extra
  params) but is no longer advertised to the model. Matrix test pins the new
  handover text.

### HARD RULE: failures are loud, never silenced (8 launchers + audit suite)
- New repo rule (AGENTS.md / CODING_RULES.md): launchers may not discard
  stderr of critical operations (`git pull`, `uv sync`) via `2>/dev/null`,
  `&>/dev/null` or `|| true`. A failed auto-update warns on stderr and does
  **not** write `.last-update`, so the next run retries instead of hiding the
  breakage for the whole 7-day window. Manual `--update` fails with exit 1.
- Enforced by new `tests/loud-failures/test.sh` (32 checks; also scans
  `except: pass` swallows in skill python scripts — benign ones carry an
  explicit `# loud-ok` marker with a reason). Wired into the `--full` gate.
- Applied to the shared launcher template in: fetch-url 2.8.4, pdf2mark 1.6.1,
  improve-ux, visualize 1.13.4, issues 1.5.1, youtube 2.2.1, vtd 1.3.1,
  surf 1.6.1 (web-search 2.5.1 landed earlier in this change set).
- One genuine hidden error surfaced by the audit and fixed:
  `fetch-url` silently fell back to default settings on a corrupt
  `settings.json` — now warns on stderr first.

### web-search 2.5.0 — degraded SearXNG instances are retried, not reported as misses
- A SearXNG answer of `200 + results:[]` with **all engines suspended**
  (CAPTCHA / access denied / 429 — lubu 2026-10-16 after its update) is now
  treated as a degraded instance: the search falls through to the next
  instance (private → public list) instead of stopping there. If every
  instance is degraded, the first payload is served so the suspension stays
  visible.
- `web-search` output names the suspended engines when an instance is
  degraded (`⚠ Instance degraded … engines suspended — …`) — no more
  "No results found" for what is really an upstream outage. A healthy empty
  result set is still a plain miss (no fallback, no note).
- tests: mocked urlopen unit checks pin the fall-through, the all-degraded
  path, the healthy-miss short-circuit, and the output hint.

## 1.6.14 — 2026-10-15

### pdf2mark 1.6.0 — output goes to a file, not stdout
- `pdf2mark document.pdf` writes `md/document.pdf.md` next to the PDF (dir
  created) instead of dumping markdown to stdout. `--out FILE` still overrides,
  new `--stdout` restores the pipe case.
- tests: `default_out_path` unit check, live default-output integration check,
  `--stdout` check; fixture build got a `ps2pdf` fallback (`cupsfilter` is
  broken on this box); token probe falls back to the skill's venv credgoo.

### rodney 1.1.0 (skill) — minimum version enforced in scripts
- New `skills/rodney/MIN_VERSION` (`0.12.1`) is the single source of truth, read
  by `install.sh`, `install.bat` and `tests/rodney/test.sh`. Older binaries fail
  install and suite instead of silently passing with the `about:blank` panic bug
  (devskale/rodney 78b8dd4).
- Fixed `find -perm +111` → `-perm -u+x` (GNU findutils 4.10 rejects `+111`).

### Housekeeping
- dropped the `skills/pdf2md/` rename leftover (untracked `uv.lock`)
- linked `.work` in this checkout (`issues init skale-skills`) — its absence made
  the docs gate flag a dead link in `skills/youtube/SKILL.md`

## Unreleased

### visualize 1.13.3 — description: no gate mechanics
- The always-loaded description dropped its "Hard style bans (enforced by
  the share gate): …" clause (365 → 242 chars): mechanics in the description
  drift — the "no pills" ban it claimed for months was never enforced. The
  body (§ Hard style bans) stays the single source of truth.
- skill-metadata now WARNs on enforcement language ("enforced by", "hard
  ban", "exit N") in any description — the drift-shape can't silently return.

### visualize 1.13.2 — live agent path as a check (and what it caught)
- **`LIVE_OK=1` runs prompts.md P1 verbatim through `pi --print --skill`:** a
  real agent session builds the page; the suite asserts file + `visualize gate`
  exit 0 + card-grid + real skill names. The product path (agent + prompt →
  passing page) is now executable proof, opt-in like rodney/surf live (tokens,
  ~1–2 min). Offline: honest WARN.
- **First catch: chartcheck false-positived on a quoted command.** Same run,
  same prompt — one page passed, another put `issues board/new/todo/…` in a
  card's command chip and failed its own gate: the process-note regex matched
  the literal lowercase "todo". Fix follows the file-source precedent — shouted
  markers (TODO/FIXME/XXX) case-sensitive, whispered phrases (confirm,
  inferred, …) insensitive. Regression fixture in the suite; verified against
  the caught page.
- **Second catch: the live stdout-contract test was broken at birth** — `$()`
  strips the trailing newline, so `printf '%s' | wc -l` was always 0 for a
  lone URL. Nobody had run `LIVE_OK=1` since it landed; one `%s\n` fixes it.

### check.sh: four gates from the visualize retro (2026-10-15)
- **Bash status-leak pattern:** `[ … ] && exit 1` returns 1 on success too —
  visualize's `validate` shipped that for a year, masked by a trailing command
  (found while decoupling jscheck). Gate greps every tracked bash file; the one
  live site rewritten to `if`.
- **Test-suite temp hygiene:** fixed `/tmp` assert writes die at the gate — two
  parallel suites clobber each other. figure/heartbeat/skill-filter normalized
  to `mktemp -d` (visualize/improve-ux/pdf2mark already were).
- **Vacuous-ok lint:** a bare `ok` outside a `then`/`else` branch is a pass
  nothing asserted (two lived inside visualize's 190-count).
- **Version truth, centrally:** `tests/skill-metadata` asserts SKILL.md ↔
  pyproject for every skill with a pyproject — caught youtube 2.2.0 vs 2.1.0 in
  the wild (fixed).
- Command coverage: a central launcher-parsing mirror was built, found `issues
  mine/todo` never exercised (+2 suite checks), then **trimmed** to explicit
  per-suite command lists (issues/improve-ux/visualize) — three launcher
  dialects were 80% of the complexity for 0% of the findings.
- Retro rules landed in CODING_RULES: exit-code propagation, temp hygiene,
  vacuous ok, explicit command lists.

### visualize 1.13.1 — the JS gate had two definitions of "script block"
- **`jscheck` silently skipped every attributed tag.** The syntax pass matched
  `<script[[:space:]]*>` while the TDZ pass matched `<script[^>]*>` — so
  `<script type="module">`, the tag in our own `templates/mermaid.html`, was never
  syntax-checked. Two more holes came from the line-based parse: code on the same
  line as `<script>`, and a `</script>` in the final line without a trailing
  newline. A page with a real syntax error passed `validate` *and* `gate`, printed
  "all gates pass", and got a URL (found 2026-10-15 on
  `<script type="module">const a = ;</script>`).
- Extraction moved to `scripts/jscheck.py`: one definition of a script block for
  both passes, regex-based instead of line-based. Also fixes two false positives —
  HTML comments are stripped (a commented-out script never ran, but was flagged)
  and non-JS types (`application/ld+json`, `text/template`) plus `src=` blocks are
  skipped. `type="module"` is checked as ESM (`.mjs`), everything else classic.
  A block that fails to reach disk is now an error, not an unchecked pass.
  Launcher: 586 → 530 lines (one `exec` instead of ~45 lines of bash parsing).
- tests: 8 new jscheck checks — attributed `<script type="module">`, same-line,
  no-trailing-newline, JSON-LD/`src=` skip, commented-out script, error in the
  second block, missing file, `--help` listing — plus `jscheck` on every template.
  Two vacuous `ok` assertions replaced with real ones (`max = 120` is a denominator,
  not an axis floor; `--help` lists every command).
- **Docs told the same two lies the code did.** The always-loaded `description`
  claimed a "no pills" hard ban the gate has never enforced (pills are info), and
  README claimed "no API or no token → `exit 3`" when the client degrades to the
  offline hard-ban subset (`exit 1` on a hit). Description, README, `output.md`,
  `html-patterns.md`, `report.md`, `templates/README.md` and the launcher's own
  header comment now state what the gate actually does.
- Added the missing `pyproject.toml` (CODING_RULES: required for Python), version
  aligned with SKILL.md and asserted in the suite.
- **gate composition:** jscheck ist jetzt ein eigener, korrekt gelabelter gate-Zweig —
  vorher lief es als stiller Anhang in validate, und ein JS-Fehler hieß „gate validate:
  FAIL" (der Agent suchte ein Dependency-Problem). Nebenfund beim Entkoppeln:
  `[ $? -ne 0 ] && exit 1` in validate lieferte auf dem Erfolgspfad Status 1, jahrelang
  vom jscheck-Anhang auf 0 maskiert — jetzt ein explizites `if`. usage/SKILL.md/README/
  Flow-Diagramm nennen alle vier Gates.
- **TDZ-Heuristik scope-bewusst** (Brace-Tiefe statt Textposition): eine Nutzung in
  Funktionskörper/Callback vor der Deklaration läuft später und wird nicht mehr falsch
  markiert (präistentes Falsch-Positiv auf gültigen Seiten; klammungslose
  Arrow-Callbacks bleiben dokumentierte Grenze).
- **Test-Isolation:** alle drei Suiten (visualize, improve-ux, pdf2mark) schreiben ihre
  Assert-Ausgabe nach `$(mktemp -d)` statt auf einen festen `/tmp`-Pfad — zwei parallele
  Läufe (zwei Agent-Sessions) haben sich sonst gegenseitig die Assert-Datei
  überschrieben. AGENTS.md-Testzahlen aufgefrischt (visualize ~216, issues 88,
  pdf2mark ~52).

### pdf2md → pdf2mark (rename)
- Skill dir `skills/pdf2md-lite/` → `skills/pdf2mark/`, command `pdf2md` → `pdf2mark`
  (launcher `~/.local/bin/pdf2mark`, script `scripts/pdf2mark.py`, venv cache
  `~/.cache/skales-skills/pdf2mark`). Old launcher/venv removed on install.
  Tests moved to `tests/pdf2mark/` (52/0/1). Historical entries keep the old name.
### issues 1.5.0 — every repo can kanban: legacy migration + throway-virtual mode
- `issues init` / `doctor --fix` migrate a legacy `handoffs` root found next to
  `works`: renamed when works is missing/empty, merged (unique entries moved,
  duplicate dropped) otherwise. Sync-lag leftovers clean themselves on the
  next init (found 2026-10-14: the rename resurrected `handoffs` from a lagging peer).
- throway-virtual mode: `issues pull` (force-fetch snapshot, overwrites),
  `issues push` (refresh snapshot + enable auto-push). After a successful
  bootstrap pull, every mutation (new/start/review/done/cancel/set/triage/
  archive/purge) auto-pushes a fresh snapshot — skipped on machines whose
  works root is a real share (.stfolder above it or network mount).
- suite now counts ALL tests: the summary sat mid-file, everything after the
  bootstrap section ran uncounted (69 shown, 88 real) — summary moved to EOF.

# Release Notes

Log of notable changes to skale-skills. Newest first.

## Unreleased


### issues 1.3.0 — Container-Link heißt `.work` (konfigurierbar, kein Hardcode)
- Repo-seitiger Container-Link: `.handoff` → **`.work`** — benennt den Container
  nach seiner Klasse statt nach einem Mechanismus (`.git`-Prinzip: drin heißen
  die Teile konkret — `issues/`, `docs/`).
- **Kein Hardcode:** `ISSUES_LINK_NAME` (default `.work`) +
  `ISSUES_LEGACY_LINK_NAMES` (default `.handoff`), dokumentiert in `--help`
  §CONFIG. Env-only mit Begründung: eine Projekt-Config-Override wäre zirkulär
  (der Link resolvT die Config).
- Walk-up findet primären + Legacy-Namen; `issues init` migriert alte Links
  (`.handoff` → `.work`, mv erhält das Ziel); doctor meldet Legacy-Links als ok
  mit Migrations-Hinweis.
- Root (`~/code/handoffs`), Identity (`~/.handoff-me`), LaunchAgent, fstab,
  sync-handoffs: unberührt — der Rename ist reichweitenarm auf den Repo-Link
  beschränkt.
- 4 neue Tests: Legacy-Resolve, Legacy-Migration, `ISSUES_LINK_NAME`-Steuerung
  für init + walk-up (67/67).

- **web_apis pdf-API gehärtet + pdf2md 1.5.1 — Backend-Abort, Client-Cancel,
  nie abgeholte Ergebnisse** (SOTA-Recherche 2026-10-13: Job-Queue-Playbook
  + FastAPI-Disconnect-Patterns; umgesetzt wurde, was zur 1-GB-File-Queue
  passt — Idempotency-Keys bewusst geskippt, kein Client retried Submits):
  - **Orphan-Sweep** (= Visibility-Timeout-Reclaim): queued/running-Jobs, die
    älter als der Prozess sind, sind per Definition verwaist (Threads sterben
    mit dem Boot) → beim ersten Read `failed`, statt 20 min „running“.
  - **Worker-Crash = First-Class-Event** (DLQ-Regel): Catch-all in beiden
    Workern flippt JETZT mit Exception-Name — nie still → Deadline.
    Nebenbei eine echte alte Race enthüllt & gefixt: `_purge_jobs` unlinkte
    frische `.tmp`-Writes → `os.replace` flog → Worker starb still. Jetzt:
    nur >60s-alte `.tmp` reappen + `_save_job`-Retry.
  - **`DELETE /pdf/jobs/{id}`** (Client-Abort): queued/running → `cancelled`
    (Worker verwerfen an Checkpoints), done/failed → sofortige Purge
    (= manuelle TTL-Kontrolle für Ergebnisse, die niemand abholt).
  - **Queue-Cap zählt nur aktive Jobs**: nie abgeholte done-Ergebnisse
    blockieren (2h TTL lang!) keine neuen Submits mehr.
  - **LlamaParse-Retry-Policy**: 1 Retry mit Backoff bei Retryable
    (502/504/Netzwerk), Permanent (429 Quota / 503 Key) failt fast.
  - Client 1.5.1: `cancelled` ist terminal (SSE + Poll) mit klarem Hinweis
    statt 20-min-Totpollen.
  - Tests: 8 neue Hardening-Tests (Sweep, Crash, Cancel-Discard, Purge,
    Active-Cap, Retry/Permanent) — 33/33 pdf-Suite, 52/0/1 Skill-Suite.
- **pdf2md 1.5.0 + web_apis: SSE für Job-Warten — das Warteerlebnis (Folge der
  Webhook-Diskussion: Client kann keine Callbacks empfangen, aber ein Stream
  schlägt das 3s-Poll-Raster).**
  - **Server** `GET /pdf/jobs/{id}/events`: ein Event pro Statuswechsel
    (queued→running→done/failed), jedes mit vollem Snapshot **inkl.
    expires_in (TTL)** — Ergebnis-Haltbarkeit immer sichtbar. Terminaler Job
    → sofortiges Event + Stream-Ende. `: ping` alle 15s hält Proxys offen;
    Stream-Cap = Job-TTL. Poll- und SSE-Pfad teilen `_job_snapshot()` (nie
    driftende Semantik). nginx: `proxy_http_version 1.1` + `Connection ""`
    für /api/ (SSE/chunked), Live-Config in ~/configs versioniert gespiegelt.
  - **Client** (1.5.0): SSE-first mit **automatischem Polling-Fallback** —
    älterer Server, Proxy-Ausfall, malformed Event: alles fällt still auf
    das bewährte Polling zurück; SSE ist Accelerator, nie Contract.
    Kill-Switch: `PDF2MD_NO_SSE=1`.
  - **Queue-Hygiene**: `out_q.close()+join_thread()` nach jedem pdfplumber-
    Child — offene mp.Queues ließen den Test-Prozess am Exit hängen
    (resource_tracker stallte auf Feeder-Threads/Pipe-FDs).
  - Tests: 5 SSE-Endpoint-Tests (Transitionen+TTL, Terminal-sofort, 404,
    Auth), 12 Client-Unit-Tests (_sse_wait: jede Failure-Mode → None →
    Fallback). Suite 52/0/1, web_apis 25/25.
- **pdf2md 1.4.5 — große PDFs funktionieren wieder (Server-Fix-Kombination, Issue web_apis 2026-10-13).**
  Drei Server-Ursachen behoben (mp.Queue-Deadlock, RLIMIT-Bremse, Sync-Watchdog
  zu knapp auf amd — Details: web_apis/docs/issues). Skill-Seite:
  1. **504-Meldung pro Methode:** pdfplumber-504 sagt jetzt ehrlich „server
     watchdog (60s)“ statt des falschen llamaparse-Job-Hinweises.
  2. **Async-Poll-Budget:** bei 202-Antworten pollt der Client jetzt mindestens
     600s statt des Sync-Defaults (149 Seiten ≈ 2 min auf amd).
  Große Text-PDFs (>30 Seiten) laufen automatisch als Server-Job — Client
  braucht keinen neuen Flag, das Polling existierte schon. Live validiert:
  149-Seiten-Thesis 1m48s / 347k chars (vorher: deterministischer 504).
- **xmodel: tsc-Fix für pi-SDK-Union (`BeforeAgentStartEvent`).**
  Der SDK-Typ ist jetzt `user | custom` — `images` existiert nur noch auf der
  user-Variante. Zugriff ohne Narrowing → `TS2339: Property 'images' does not
  exist` (blockierte Gate & Pre-Push für ALLE, auch unberührte Commits).
  Fix: `event.messageType === "user" && (event.images?.length ?? 0) > 0` vor
  dem auto-vision-Switch. Verhalten unverändert — custom triggerTurn-Nachrichten
  tragen per Definition keine Bilder.
- **web-search 2.4.0 — Duck→SearXNG Client-Fallback + beschreibende Fehlermeldungen (Issue 2026-10-13, StreamReset).**
  Der Skill brach ab, wenn die Duck API selbst unerreichbar war — kein zweiter
  Versuch, Error-Message ohne Urheber. Jetzt:
  1. **Fallback:** eine Duck-Fehler-Row (nicht: leere Liste) triggert genau
     einen SearXNG-Versuch — private Instanz zuerst, öffentliche zuletzt
     („public = last resort, never default“). Beide-Backend-Tod → exit 1 mit
     BEIDEN Fehlern, jede origin-labeliert.
  2. **Ursprungs-Labels:** jede Fehlermeldung nennt ihren Absender —
     `Duck API error 502 (…)`, `Duck API request failed (host): …`,
     `Duck news API …`, `SearXNG error: all N instances failed — last error: …`.
     Kein „tu error“-Rätselraten mehr, welcher Backend gekippt ist.
  3. Refactor: `_duck_only_flags()`, `_run_searxng_search()`,
     `_searxng_fallback()` extrahiert; der SearXNG-Pfad nutzt sie primär UND
     als Fallback (keine credgoo/auth-Duplizierung mehr, `import base64`
     statt `__import__`).
  **Tests:** 17 neue Unit-Checks (Fallback-Matrix: success/both-failed/
  passthrough, genau ein Versuch, Origin-Labels im Source) + Integrationstest
  `[7d]` mit deterministisch toter Duck-URL (Port 1). Suite: 63 pass, ein
  erwarteter Version-Drift bis zum package-clone-Update.
- **rodney 0.11.3 — Orphan-GC mit TTL + Session-Cap (Nutzer: „keine Zombies, TTL, parallel max").**
  Zwei Lücken im Orphan-Sweep, beide live verifiziert:
  1. **Kein TTL.** Der Sweep killte nur Browser, deren PID in KEINER live
     `state.json` stand. Ein **hängender** Chrome (antwortet nie auf den Debug-Port,
     exited nie) hatte aber eine gültige state.json → sein PID war geschützt,
     für immer. 100–500 MB RAM + Profile, bis es jemand von Hand merkt.
     Jetzt: **Alters-Pass** — älter als `RODNEY_ORPHAN_TTL_HOURS` (Default 24h) →
     killen + State entfernen, auch wenn der PID lebt. Anker: neues
     `State.StartedAt`. `StartedAt <= 0` (alter State) wird **nie** nach Alter
     gesweept, und ein Zeitstempel aus der Zukunft (Clock-Skew) gilt nicht als
     abgelaufen. Entscheidung in der reinen `ttlExpired()`.
  2. **Kein Cap.** `--session <name> start` war unbegrenzt — jede Session ein
     voller Chromium. Jetzt `RODNEY_MAX_SESSIONS` (Default 6): darüber verweigert
     `start` und **nennt die zu stoppenden Sessions**. `0` deaktiviert beides.
  **Tests:** 8 Unit-Tests für `ttlExpired` (disabled / unknown-age / fresh /
  Grenzwert / Clock-Skew / Kurz-TTL / Round-Trip / Legacy-State) + E2E in
  sandbox-HOME mit echten schlafenden PIDs: fresh-live überlebt (inkl. Prozess),
  old-live wird gekillt+gesweept, die lebende Global-Session bleibt intakt.
  Volle Suite grün (317s), Skill-Doku + Registry nachgezogen.

- **rodney: Suite-Crash unter `set -e` gefixt (known issue seit 2026-10-01); registry.md drift behoben.**
  Der in `check.sh` dokumentierte Known-Issle war real: **jeder** fehlschlagende
  rodney-Befehl in den Live-Sektionen killte die GANZE Suite mit exit 2 und
  **null Ergebnissen** — ein hängender Chrome, ein frozen Snapshot, und man sah
  nur „exit 2", keine Ahnung welcher Check rot war. Jetzt sind die 15 Live-
  Kommandos failure-tolerant (`|| true` / `|| echo ""`): ein fehlschlagender
  Befehl kostet einen **benannten** FAIL statt Stille. Zusätzlich guard für den
  `wc -c < file`-Redirect (wirft, wenn die Datei fehlt — vor `|| echo` greift).
  **Zweiter Fund aus demselben Lauf:** `references/registry.md` war 18 Zeilen
  stale gegen das Binary — `page <pattern>`, `pages [pattern]` und das erweiterte
  `open --reuse` waren undokumentiert. Regeneriert (`gen-registry.sh --write`),
  66 PASS.

- **Extension-Evaluation: drei Befunde, zwei gefixt, einer entkräftet.**
  Evaluation aller fünf Extensions (heartbeat, image-slim, statusline, imagegen,
  xmodel) — alle Suites grün, Gesamturteil: reif. Befunde:
  1. **statusline log beim `(auto)`-Marker.** Er wurde UNBEDINGT an den Context-%
     angehängt, obwohl der built-in Footer ihn bei deaktivierter Auto-Compaction
     ausblendet — der Code-Kommentar sagte „ExtensionContext expose that flag
     nicht, können wir nicht replizieren". Stimmt für `ctx.sessionManager`
     (read-only `Pick` mit 15 Methoden), aber nicht für die Lösung: pi's eigene
     Quelle der Wahrheit liegt auf Disk (`compaction.enabled` in den User- +
     Project-Settings, Default `true`). Die Extension liest jetzt dieselbe Datei,
     cached 60 s. Kein Gelogen mehr im Footer. Doc + 6 neue Checks.
  2. **imagegen hatte keine `VERSION`.** Einzige Extension ohne — bei 1210 Zeilen
     und aktiv genutztem Tool genau die Lücke, die ein Bug-Report zuerst braucht.
     Jetzt `VERSION = "1.0.0"`, sichtbar im Help-Panel und in der Erfolgs-Notify.
     5 neue Checks (inkl. Parity-Assert über alle Extensions).
  3. **`heartbeat-parse`/`xmodel-config` ohne try/catch** — ENKRÄFTET: beide Libs
     werfen nie („null if invalid"), es gibt nichts zu fangen. Korrektes Design.

- **pdf2md 1.4.4 — Size-Guard vor dem Read; `--share` lädt das Markdown im Async-Job nicht mehr.**
  Zum Review-Befund (2026-10-11): (1) `convert()` machte `open().read()` VOR der
  10MB-Prüfung — eine 2-GB-Datei wurde vollständig in den RAM gepuffert, nur um
  dann abgelehnt zu werden. Jetzt `os.path.getsize()` (reines stat) plus ein
  Re-Check nach dem Read (Datei könnte gewachsen sein) und ein eigener Fehler für
  leere Dateien. (2) `wait_job()` lud bei `markdown_url` das Markdown **immer**
  herunter — auch mit `--share`, wo nur die URL gewünscht ist. Bei einem 500-Seiten-
  Scan waren das Megabyte umsonst übertragen. Jetzt returned `--share` ein Sentinel
  (`SHARE_SKIPPED_DOWNLOAD`), das main()'s Auto-Fallback nicht als „leeres Ergebnis →
  Scan?" missversteht — ohne das Sentinel feuerte der llamaparse-Fallback und
  verdoppelte die Arbeit (im Test als DOWNLOADS=2 sichtbar).
  **Tests:** Size-Guard-Checks (11MB-Datei, leere Datei) + ein gemockter Async-Job
  (202 → done mit markdown_url), der beweist, dass `--share` die URL druckt und
  **nicht** fetched (Zähler im Mock). 48 PASS.

- **xmodel 0.5.13 — Vertikal-Tiling mit NEED-MORE-Progression für ultra-lange Seiten.**
  Auslöser (Nutzer 2026-10-11: „manche Webseiten sind ultralang"): ein Fullpage-
  Capture 1440×12000 wurde aspect-preserving in das 2MP-Budget gequetscht →
  188×1568, ein Streifen, in dem das VLM **keine einzige Textzeile** lesen konnte
  (verifizert). **Lösung:** ab Aspect > 3:1 schneidet `planTiles()` die Seite in
  überlappende Vertikal-Segmente (1568px hoch, 15% Overlap, EXIF-korrigiert,
  letztes Segment erreicht den Boden). **Progression nach Nutzer-Regel** („wenn
  1es tile schon info enthält nicht weiter, nur weiter wenn agent sagt"): der
  ERSTE Call trägt genau EIN Segment; das VLM muss mit „NEED MORE" + dem Fehlenden
  antworten, um den nächsten Batch (4 Segmente) zu ziehen. Segment-Frage → 1 Call,
  Global-Frage („was ist ganz unten?") → alle Segmente. „NO IMAGE" zählt als
  NEED-MORE-Signal (sonst stoppte die Progression an einem blanken Tile — live
  beobachtet). Bei Seitenende mit offenem NEED MORE wird `truncated` ehrlich
  berichtet, damit der Agent nicht selbst slicet.
  **Drei Live-E2E-Bugs, die nur der Live-Lauf fand:** (1) Tiling wurde auf der
  bereits normalisierten Temp-Datei entschieden — der Strip hat nichts mehr zu
  tiling; jetzt Entscheidung auf den ORIGINAL-Bytes. (2) „NO IMAGE" wurde als
  Antwort gewertet. (3) Das VLM halluzinierte aus Segment 1 eine Antwort auf eine
  Global-Frage — Prompt gehärtet („Extrapolation ist schlimmer als NEED MORE").
  **Tests:** 33 Checks inkl. Segment-Geometrie, Overlap, Boden-Abdeckung, Gate,
  alle drei Progressions-Ausgänge, NO-IMAGE-Pfad. Multi-Image-in-einem-Call
  vorab gegen den DGX-VLM verifiziert.

- **xmodel 0.5.13 — portable Bild-Normalisierung vor der VLM-Delegation (photon-WASM).**
  Hintergrund (Nutzer-Frage „brauchen Bilder bei komischen Größen eine Normierung?"):
  jeder Provider resized serverseitig stillschweigend (Claude 1568px/~1.15MP, GPT-4o
  2048-Box→Tiles, Qwen3-VL max_pixels≈576 Tokens, Gemini Token-Budget — recherchiert
  2026-10-11). Wer größer schickt, zahlt nur Base64-Payload + Latenz: der 434-KB-
  Fullpage-Screenshot aus dem Timeout-Vorfall erzeugte einen 3.4-MB-Child-Output-Strom.
  **Fix:** neue Lib `extensions/lib/image-normalize.ts` — decode via
  `@silvia-odwyer/photon-node` (WASM, bereits in pi gebündelt, **läuft auf mac/Linux/
  Windows**, kein `sips`/ImageMagick), EXIF-Orientierung wird honoriert, danach
  aspect-preserving **Downscale only** auf 1568px Long-Edge + 2MP-Pixel-Cap, Re-Encode
  als JPEG q80. **Warum JPEG:** datenbasiert entschieden — q80 war auf dem echten
  DGX-VLM *lesbarer* als PNG-1568 (Job-Namen überlebten, bei PNG fielen sie) bei 40%
  der Bytes; PNG bleibt per `XMODEL_VISION_JPEG=0` opt-in für pixelgenaue Aufgaben.
  Fail-soft: jedes Problem → `null`, Caller behält das Original. Overrides:
  `XMODEL_VISION_NORMALIZE=0`, `XMODEL_VISION_MAX_EDGE`, `XMODEL_VISION_MAX_PIXELS`.
  Nebenbei portabel gemacht: `toDisplayPng` transcoded non-PNG vorher via `sips`
  (macOS-only) — jetzt photon-first, sips nur noch als Fallback.
  **Tests:** `tests/image-normalize/` (20 Checks, echte Fixtures, inkl. EXIF-6-
  Rotation, Degraded-Mode) + xmodel-Suite grün.

  **Zwei Nachzüge aus dem Live-E2E (beide von der Forensik entlarvt, nicht von Tests):**
  1. **`analyzeImageFile` (read_image-Pfad) übergab das Roh-File** — die 0.5.13-
     Normierung sass nur in `writeImageTmp` (Delegate-Pfad). Jetzt normiert auch
     der explizite read_image-Pfad (Temp-Kopie, Original unberührt, Cleanup im
     `finally`).
  2. **`process.argv[1]` ist ein bin-SYMLINK** (`/opt/homebrew/bin/pi` →
     `../lib/node_modules/.../cli.js`). `createRequire` läuft node_modules vom
     gegebenen Pfad aufwärts — ein Symlink unter `bin/` findet **nichts**, photon
     lud nicht, die Normierung war ein stummer No-Op. Fix: `argv[1]` versuchen,
     dann `realpathSync(argv[1])`. Test fährt jetzt gezielt über das Bin-Symlink.
  **E2E-Wirkung** (Fullpage-Screenshot 1430×2275, DGX-VLM): 434 KB → 173 KB,
  Child-Output-Strom 3.4 MB → 722 KB (−79%), Latenz 10.6s → 2.3s.

- **xmodel 0.5.12 — Vision-Timeouts: retry statt Aufgeben + lokaler DGX-VLM.**
  Vorfall 2026-10-09 (Session 01a12257): `zai/glm-5.3-flash` als `_vision.vlm` lief bei
  ~9% aller Bild-Analysen in einen 90s-Hard-Timeout OHNE ein Token (transienter
  API-Hang — dasselbe Bild lief beim manuellen Retry in 51–73s durch). Der Code
  brach die Retry-Schleife bei Timeout just ab (`break`), obwohl genau dieser Fall
  vom Retry profitiert. **Fix:** Timeout auf Attempt 1 → ein sofortiger Retry;
  erst ein Timeout beim LETZTEN Versuch meldet `TIMED OUT` (beide Pfade:
  delegate-Vision + read_image). Neu: `XMODEL_VLM_TIMEOUT_MS`-Env-Override für
  den 90s-Default. **Zusätzlich** `_vision.vlm` auf `dgxp/nvidia/Qwen3.6-35B-A3B-NVFP4`
  (lokale DGX, LAN) umgestellt — Smoke: 4–10s statt 50–90s, korrektere Analyse als
  der tu-Kandidat. Vertrag gepinnt in Matrix-Sektion (g) via stateful Fake-pi
  (`timeout_once` / `always_timeout`).
- **Vorfall-Postmortem: trailing comma in package.json brach jeden pi-Start.**
  Mein deprecated-Move (3723cb2) entfernte die `!skills/deprecated/**`-Zeile, liess
  aber das Komma des Vorgaengers stehen → invalid JSON → `JSON.parse`-Absturz im
  pi-ResourceLoader ("Unexpected token ]"). Behoben (d293bf2), der Live-Clone
  direkt repariert, pi laeuft wieder. **Gate-Nachzug:** `check.sh` parst jetzt
  jede ge-trackte .json strikt — JSON-Fehler koennen den Gate nie wieder passieren.

- **blockdiagram.html template + README flagship entry für visualize.**
  Das Selbstporträt-Blockdiagramm (blueprint flavor, hand-crafted SVG mit Pfeilen,
  Gate-Fan-out + Edit-Loop) ist jetzt Template: `templates/blockdiagram.html` mit
  Platzhaltern und Filling-Rules im Kommentar (Vokabular behalten, Inhalt tauschen).
  README: visualize ist jetzt Flagship (fünf Skills production-hardened) mit
  Skin/Gates/Pin-Ledger-Steckbrief, Quick-Start-Schritt 4, Highlight-Zeile,
  image-slim in der Extension-Tabelle, Badges (13 Skills · 5 Extensions).

- **Retro 2026-10 (2. Runde): drei Funde, alle gebaut.**
  1. **YAML-Parse-Check im Skill-Metadata-Gate** (mechanisch): ungültiges
     SKILL.md-Frontmatter bricht den GESAMTEN Skill-Load in pi (visualize-Bruch
     riss scheinbar youtube+vtd mit ab). Das Gate parst jetzt jedes Frontmatter
     mit PyYAML (Fallback: unquoted-colon-Scan) — der exakte visualize-Fehler
     wird gefangen, verifiziert mit einem Bad-Skill-Fixture.
  2. **AGENTS.md (global): „Baseline rauchen vor dem Bau"** — bei Feature-Wünschen
     erst das IST-Verhalten mit einem Aufruf verifizieren (vtd-Runde: Feature
     gebaut, das schon existierte; vollständiger Revert).
  3. **AGENTS.md (global): interaktive TUI-Kommandos nie via bash** — `pi config`
     kippt ANSI-Müll in die Tool-Ausgabe; Config-Datei direkt lesen.

- **Retro 2026-10: fünf Funde aus der Session, alle gebaut.**
  1. **Pin-Ledger ohne Integrationstest gelandet** (Regelverstoß — nachgeholt):
     `VISUALIZE_SHARES_FILE` überschreibt das Ledger (Tests sandboxen es statt das
     echte `~/.config/visualize/shares.tsv` zu verschmutzen), `_pin_set`/`_pin_get`
     sind direkt aufrufbar, 4 neue Tests (Roundtrip, Replace, Koexistenz, stdout-Vertrag).
  2. **Share-stdout ist Vertrag:** GENAU EINE Zeile — die URL; slop-Report,
     Pin-Hinweise und Fehler gehen nach stderr (auch im slop_client `--human`).
     `share f 2>/dev/null` ist der stabile Agent-Parse.
  3. **Kommandoliste dedupliziert:** Header-Kommentar verweist auf `usage()` —
     eine Quelle statt zwei zu pflegender Kopien.
  4. **CODING_RULES:** Mode-Variablen am Anfang des Command-Zweigs initialisieren
     (zwei `unbound variable`-Funde im visualize-Launcher, beide vermeidbar).
  5. **architecture-log.md:** Architektur-Reviews hinterlassen eine dauerhafte
     Spur (Kandidaten, Entscheidungen, Verworfenes) — der throway-HTML-Report
     verfällt, die Begründungen nicht mehr.

- **visualize 1.13.0: `visualize gate` — eine Interface über alle Gates.**
  Kandidat 4 des architecture reviews. Vorher: validate/jscheck, lint/slop und
  chartcheck waren verstreute Einzelbefehle — vergaß der Agent einen, lief er nie.
  Jetzt: `visualize gate <file>` fächert alle Gates parallel auf (jeder Check liest
  nur die Datei; Laufzeit ≈ langsamstes Gate ≈ die 300ms slop-API, nicht die Summe),
  druckt je Gate OK/FAIL + Befund, exit 1 wenn eines fällt. `share` behält seinen
  URL-first-Slop-Check als letztes Netz. Das Skill-Diagramm (GATES-Gruppe) ist damit
  wörtlich wahr. 185/0.

- **visualize 1.12.x: pin ledger — der Edit-Loop ist derselbe Befehl.**
  Kandidat 3 des architecture reviews („drei Modi, drei Upload-Pfade“) umgesetzt:
  jeder Share pinnt `realpath → URL` in `~/.config/visualize/shares.tsv`. Re-share
  derselben Datei/Ordner = PUT in place („updated in place“, gleiche URL) — kein
  `--update`-Flag zu merken. `--fresh` erzwingt neue URL, stale pins heilen
  (Warnung + frischer Upload). `--update` (slug) und `--dir` pinnen mit; `--dir`
  wiederverwendet das bestehende Verzeichnis statt jedes Mal neu anzulegen.
  Grundlage: throway single uploads sind PUT-editable (verifiziert).

- **visualize v1.11.0: house skin v3 mit vier Flavors — Style by construction.**
  Warum: der Generator hat weiter free-hand CSS geschrieben und dabei regelmäßig
  Card-Edge-Accents produziert (der Linter fing sie, aber der Loop generate→flag→fix
  war das Antipattern). Jetzt: `templates/skin.html` ist der verpflichtende Startpunkt —
  Tokens, Typo-Skala, Card/Legend/KV/Table-Muster, vier Stimmungen per
  `data-skin="paper|swiss|terminal|blueprint"` (Editorial / Poster-Grid / Infra-Dark /
  technische Zeichnung). Jeder Flavor ist vor-gevetet: hardslop-Set ist jetzt NUR
  Card-Edge-Accents (`edge_stripe`, engine-seitig), Pills sind info („pills sind ok"),
  Violet-Fills inkl. gedämpft (#5a4a8a-Familie, sat ≥ 0.25) bleiben hard. SKILL.md
  trägt die Hard-Bans jetzt im Generierungspfad (§ Hard style bans) statt 270 Zeilen
  tief in promptlib; die Regel ist side-agnostisch (border-top zählt genauso wie
  border-left — der auditflow-Fall). Die Kategorie-Farbe behält ihren Sinn: Fixing
  heißt Hue auf Content verschieben (Dot/Label/Wert), nicht die Unterscheidung löschen;
  `terminal`/`blueprint` geben Infra/Architektur-Farben ein Zuhause.
  Live-Vergleich aller vier: https://skale.dev/throway/d/skin-flavors

- **visualize v1.10.0: slop-Gate auf jedem Share — throw → lint → update.**
  Jede geteilte HTML wird direkt nach dem Upload gegen die slop-API gescannt
  (`amd.skale.dev/api/slop/lint`, 11 fuzzy AI-slop-Detektoren — accent stripes
  auf allen 4 Kanten, var()-Auflösung, pills, purple, glass, glow, slop fonts,
  stat banners). Die URL kommt zuerst (Share blockiert nie am Linter); harte
  Findings (confidence ≥ 0.7) drucken Fix-Hints und setzen exit 1 — der
  Fix-Zyklus ist: lokal editieren → `visualize share --update` (PUT in place,
  gleiche URL). Reviews (0.3–0.7, z.B. nummerierte Steps, die echter Prozess
  sein können) gehen als „you decide" an den Agenten. `share --dir` linted max
  3 HTML-Dateien. Token: `SLOP_TOKEN` env → `credgoo FETCH_URL_BEARER`; ohne
  Token/API wird der Check mit Note übersprungen (Share stirbt nie am Linter).
  Gründungsfall: die auditflow-Seite, deren `border-top:4px var(--cat-a)`-
  Streifen der alte border-left-only-Check unsichtbar ließ.

- **surf v1.6.0: `open`/`find-tab` attachen über ALLE laufenden Chromium-Instanzen.**
  Man arbeitet mit mehreren Chromes gleichzeitig (Stable + Beta) — eine Page,
  die schon irgendwo offen ist, wurde trotzdem neu geöffnet, weil `open` nur
  den Tabs der EINEN gewählten App suchte. Jetzt: Reuse-Suche (Tier 1 exact,
  Tier 2 Pfad-Präfix) läuft über jede laufende Instanz der Chromium-Familie
  (Chrome, Beta, Chromium, Brave, Edge, Arc, Opera, Vivaldi — `$APP` zuerst).
  Ein Hit in einer anderen Instanz attached dort: der Pin speichert die App
  (Format v2 `App|W T url`), Start fördert sie zu `$APP` (nur wenn sie läuft —
  nie wird ein Browser gelauft gestartet), Folgebefehle fahren die Instanz.
  `find-tab` durchsucht ebenfalls alle Instanzen (`[App]`-Präfix auf fremden
  Rows, `--activate` schaltet mit). `SURF_APPS="Brave Browser:Vivaldi"`
  überschreibt die Kandidatenliste; `SURF_APP` bleibt der Single-App-Override.
  Legacy-Pins (3 Felder) laufen weiter. Suite: 66 Checks (live cross-instance
  skippt ehrlich, wenn keine zweite Instanz läuft). SKILL.md-Version war
  draufgedriftet (1.4.7 vs. Code 1.5.0) — beide jetzt 1.6.0.

- **issues: doctor prüft jetzt, ob der Auto-Commit-LaunchAgent wirklich LÄUFT.**
  Fund (Retro 2026-10-05): der LaunchAgent `com.skale.handoffs` war entladen —
  letzter Commit 2026-10-03, während `issues doctor` grün zeigte („versioning:
  local git + auto-commit"). Der Check testete die plist-Existenz, nicht den
  Load-Zustand. Jetzt: `launchctl list` wird geprüft (macOS); nicht geladen →
  WARN mit Fix-Zeile. Suite unverändert (63) — der Check ist Umgebung, nicht
  Sandbox.

- **rodney: self-decompose — leaked rod-family browsers are now rodney's own
  responsibility.** Fund: 5 verwaiste Chromium-Prozesse (seit Sa), 139
  rod-Temp-Profile unter `$TMPDIR/rod/user-data` = 2.0 GB. Ursache:
  `main_test.go` nutzte `launcher.New()` ohne `UserDataDir` — go-rod streut
  pro Run ein Random-Dir; bei abgebrochenen Test-Läufen bleibt der Chromium
  (Leakless false) + das Profil für immer liegen. Fix zweigeteilt:
  (1) Fork `main_test.go`: dediziertes `rodney-test-*`-Dir + `chrome.pid` +
  `defer os.RemoveAll` — normale Läufe räumen selbst ab, abgebrochene sind
  auffindbar. (2) `rodney-cleanup.sh` erkennt jetzt die ganze rod-Familie
  (rod-managed Binary `~/.cache/rod/browser`, nicht nur `.rodney`-Dirs), killt
  Orphans (nie PIDs aus lebenden `state.json`s) und fegt stale rod-Temp-Dirs
  (ungenutzt + älter 1h). Suite: 66 Checks. Aufgeräumt: 15 Prozesse, 135 Dirs,
  ~1.9 GB frei.
- **visualize: colored left-edge accent on cards is now a banned AI-tell.**
  „That damn left-edge coloured line on a panel" (Kosta, „Spot the Slop") —
  `border-left:≥2px solid <hue>` auf Karten/Panels. Ursache war unsere eigene
  Anleitung: promptlib.md empfahl „2px left borders" als strukturelle Farbe.
  Jetzt: Hue gehört auf den Inhalt (Label/Dot/Value), nie auf die Kartenkante;
  Ausnahme bleiben neutrale Konnektoren (Timeline-Spine, Tree-Guides, `--line`).
  `visualize lint` prüft das als Tell #5 (Hex + var(--ok/--warn/--bad/--cat-*/
  --accent) erkannt, `var(--line|--muted|--soft|--ink)` + <2px passieren).
  before-after.html Template bereinigt (.tr-div-Streifen → div-note-Text in
  Hue). Suite: 176 Checks.
- **issues: `doctor` — pocock-style Setup-Check (explore → report → fix).**
  `issues doctor` prüft die ganze Maschinen-Setup: synced root, Transport
  (Syncthing / `throway_dir` in der Projekt-Config), Versionierung, Identity
  (`~/.handoff-me`), `.handoff`-Link, Board-Kolumnen. `--fix` wendet die
  sicheren Fixes an (root anlegen, Identity pinnen, fehlende Kolumnen
  erstellen). Neue Maschine: `install.sh` → `issues doctor --fix` → fertig.
- **issues: „purge ist final" war gelogen — Doku an die Realität angepasst.**
  `~/code/handoffs/` hat seit 2026-10-03 ein lokales Git + stündlichen
  Auto-Commit (LaunchAgent `com.skale.handoffs`, Recovery nach Issue-Datei-
  Verlust). SKILL.md, `--help` und die Root-README behaupteten trotzdem
  „no git, purge is final". Jetzt ehrlich: History ist ein per-Maschine-
  Recovery-Netz, nicht synchronisiert — `purge` löscht live überall,
  wiederherstellbar nur wo lokale History existiert. Suite: 63 Checks.
- **visualize: share reads the throway contract instead of discarding it.**
  `share` (single file, `--update`, `--dir`) hat `GET /api` nur angepingt
  und die Antwort verworfen (throway issue #1). Jetzt wird
  `max_file_bytes` geparst und VOR dem Upload geprüft — aus einem blinden
  413-Upload wird ein lokaler, früher, benannter Fehler mit der echten
  Grenze („over the store's max_file_bytes (5242880)"). Contract
  unreachable → warnen und weiterfahren wie bisher (best effort).
- **rodney: self-fetching reference + multi-session helpers.**
  - `scripts/gen-registry.sh` rendert `references/registry.md` direkt aus
    `rodney help --json` — die Referenz holt sich der Skill progressiv aus der
    CLI statt statisch zu driften. Suite [13] prüft Byte-Frische.
  - `scripts/rodney-sessions.sh`: list/`--stop-all`/`--clean [--age]`/`--json`
    für named sessions; `rodney-cleanup.sh` sieht jetzt auch
    `~/.rodney-sessions/*/state.json` (fand sofort einen echten Orphan).
  - Validiert gegen rodney 0.11.0 (83 Commands); 2 Binary-Bugs als
    devskale/rodney#1/#2 gefiled, Stop-Race als #3.
- **visualize: Diagramm-Vokabular aus mattpococks improve-codebase-architecture
  übernommen.** Cross-section / Mass-diagram / Collapse als before/after-Inhalte
  (structures.md), „if the diagram needs a paragraph, redraw the diagram", Wins-Bullets
  ≤6 Wörter, Empfehlungsstärke als Dot+Text in Severity-Hue (report.md), Mix-Media-Regel
  für Mermaid vs. hand-built (html-patterns.md). Ideen ja — Code nein (Tailwind-CDN und
  deren Scaffold widersprechen unserer Inline-Regel).
- **watchlist.jsonl — Watchlist jetzt JSONL (war WATCHLIST.md).** Eine
  Quelle der Wahrheit, eine Zeile pro Eintrag, maschinenlesbar: Pflichtfelder
  `status` (watch/review/adopted/rejected), `type` (skill/ext), `name`,
  `source`, `why`, `added`; optional `verdict`, `install`. Adden per Chat
  (`watchlist add <org/repo> — <why>`) oder `echo '...' >> watchlist.jsonl`.
  Der Gate prüft die Datei jetzt mit (scripts/check.sh): valides JSON pro
  Zeile, Pflichtfelder, Status/Type-Enums, keine doppelten Quellen.
  Negativtest verifiziert (kaputte Zeile → FAIL). Grund für JSONL: trivial
  appendbar, von der geplanten skale.dev/skills-Seite beim Build direkt
  einlesbar, und die eventuelle Write-API-Queue wäre ebenfalls JSONL.
- **WATCHLIST.md — persönliche Watchlist für Skills & Extensions.** Eine
  Datei im Repo-Root (nicht im pi-Package-Manifest, bleibt privat): append-only
  Liste mit Status-Lebenszyklus 👀 watch → 🔍 in review → ✅ adopted / ❌
  rejected, Einzeilen-Format `skill:/ext:` mit Quelle, Warum und Datum. Adden
  per Chat (`watchlist add <org/repo> — <why>`, Agent kennt die Konvention via
  AGENTS.md) oder einfach selbst eine Zeile dranhängen. Review-Phase: Session
  fetcht Repo + SKILL.md, schreibt 2-3-Zeilen-Verdict, flippt den Status —
  ✅-Einträge mit Install-Cmd sind automatisch die Empfehl-Liste. Bewusst kein
  Script (der Agent ist der Add-Befehl; Script bei Bedarf nachrüstbar, Format
  bleibt gleich). Seeds: mattpocock 🔍, emilkowlski 👀, pi-web-access 👀.
- **docs/browser-use/terminal-browsing.md — eigene Intelligence-Sektion über
  Terminal-Browsing.** Warum Terminal-Browser für Menschen (SSH/low-RAM),
  Agenten (Dump = layout-bewusster Text-Extraktor) und TUI-Workflows (pi,
  herdr) zählen; die Agenten-Leiter fetch-url → w3m/cha → rodney/surf
  (mittlere Sprosse am unterbenutztesten); w3m-vs-chawan-Urteil (chawans
  QuickJS = JS im Terminal, w3m = das robuste Default); heute re-verifizierte
  Bruchstellen (GitHub-Gzip reproduziert, **reddit.com neu blockiert** —
  Feb-Eval sagte noch "works", orf.at/Wikipedia/HN/lite-DDG weiter ok);
  Text-Web-Endpunkte (lite.duckduckgo, old.reddit, hn.algolia-API); unsere
  Empfehlungs-Policy. Verlinkt aus README-Nav und browser-tools-comparison.
- **docs/browser-use/: Toten-Audit.** Verifikation via GitHub API / npm / PyPI
  (2026-10-04), tote und walking-dead Tools markiert und in einen Graveyard-Appendix
  in browser-tools-comparison.md (0.1.6) verschoben:
  - **Kaputter Puppeteer-MCP-Abschnitt gefixt**: `@anthropic-ai/puppeteer-mcp`
    existierte nie auf npm (GitHub-Link 404) — der alte Install-Block war
    ungültig. Realität: Reference-Server deprecated (2025-05), Xandon-Server tot
    (2025-06). Empfehlung jetzt: Playwright MCP für den MCP-Pfad.
  - **chrome-mcp → livemcp**: Repo von DeepakSilaych/chrome-mcp nach
    Magi-Labs/livemcp umbenannt (GitHub-Redirect). Tabellen + Links aktualisiert.
  - **Walking dead markiert**: mcp-chrome (hangwin, 9 Monate still), Real
    Browser MCP (0 Stars), agentauth-py (Quelle tot seit 2025-03) — 🧟 in
    Tabellen, Sections zu One-Linern mit Appendix-Link verdichtet.
  - **Decision Flow bereinigt**: Extension-Empfehlung jetzt Nanobrowser /
    Playwright MCP Bridge statt der toten; Cookie-Extraktion → sweet-cookie.
  - **Appendix "Dead & Walking Dead"**: Operator (2025-08), Instant Checkout,
    ChatGPT Atlas (2026-08-09, nach 292 Tagen), MultiOn tot; Renames
    (Cloudflare Browser Rendering → Browser Run); Alive-Spot-Check
    (OpenChrome, CloakBrowser 31.9k★, agent-browser 43.5k★ u.a.).
- **docs/browser-use/ Accuracy-Pass.** Live-Verifikation gegen surf 1.5.0,
  rodney 0.11.0, den verbundenen chrome-devtools-MCP und Chrome 154:
  - **chrome-dev.md**: fast alle Beispiel-Tool-Namen waren falsch (chrome_navigate
    → chrome_navigate_page, chrome_screenshot → chrome_take_screenshot,
    chrome_evaluate → chrome_evaluate_script, chrome_get_console_logs →
    chrome_list_console_messages, chrome_get_dom_snapshot → chrome_take_snapshot,
    …) — jetzt live-verifiziert (30 Tools). Kategorien-Tabelle auf echten
    Bestand umgeschrieben.
  - **surf.md**: war auf 1.0.0-Stand — Version/datum auf 1.5.0, Kommandoinventar
    ergänzt (find-tab, table, cookie, localstorage, form, download, shot-full,
    bookmarks, batch, doctor), "~11 KB script" → ~90 KB Multi-File-Realität,
    State-Datei ist jetzt per-Session (target-<name>).
  - **vcl-agent-browser.md**: rodney-Install war `uv tool install rodney`
    (upstream-PyPI, nicht unser Fork) → go build/devskale-Release; rodney hatte
    "Network interception: no" — real: mock/block; "CSS only" → CSS+XPath;
    Chrome "v149" → 154.
  - **browser-tools-comparison.md**: 35→63 Tests, 11.5→17 MB Binary, XPath-Schwäche
    entfiel (0.11.0 nimmt `//`-Selektoren + xpath-of).
  - **which-browser-tool.md**: chrome-devtools-mcp hatte "Network intercept ✅" —
    real read-only (list/get requests, kein mock/block).
  - **README.md**: surf.md war nicht in der Navigation. guides/rodney-setup.md:
    "verify 0.6.x" → 0.11.0.
- **vtd 1.3.1: Cookie-Bug — Default war nicht off.** `cookieArgs()` behandelte ein
  fehlendes `--cookies`-Flag wie `--cookies` (undefined fiel in den Config-Zweig):
  Mit vorhandener Config (`vtd cookies set …`) zog **jeder** vtd-Aufruf still die
  Browser-Cookies (1842 Cookies pro Aufruf beobachtet). Fix: `undefined` → keine
  Cookies; Config gilt nur noch bei explizitem Flag. Suite [12] pinnt jetzt die
  Semantik per echtem CLI-Aufruf (isoliertes HOME + VTD_DEBUG, Bogus-URL): kein
  Flag → keine Auflösung; `--cookies` → Config; `false` → aus; inline → inline.
  64/64. Live-Check: WAP-Captions sind nicht age-gated (Fast Path transkribiert
  ohne Cookies — das Gate trifft das Video-Playback, nicht die Untertitel).
- **youtube ↔ vtd: Cross-Links geschlossen.** youtube-SKILL.md verlinkt vtd jetzt
  richtig (relativer Link statt Fließtext) und nennt den Loop-Closer
  `vtd transcript --list <name>` (Batch-Transkription der Picks); curation.md
  endet nicht mehr beim Einzel-URL-Handoff, sondern beim Batch. Gegenseite war
  schon sauber verlinkt.
- **youtube 2.2.0: Leanness-Pass.** SKILL.md 101 → 97 Zeilen (Limit <100, wieder
  eingehalten); cmd_hosts kompaktiert (1136 → 1121 Zeilen search.py trotz neuem
  Subcommand); Age-restricted-Gotcha gestrafft.
- **youtube 2.2.0: `hosts`-Subcommand.** `youtube hosts` zeigt Cache + Health-History
  (offline), `youtube hosts --probe` prüft aktiv jeden bekannten Host parallel
  (alive/dead + Latenz) und schreibt Überlebende zurück in Cache. Aktueller Stand:
  3/9 alive (catgirl 637ms, f5.si 955ms, materialio 2390ms) — der statische
  Cold-Start-Pool ist fast komplett tot. Suite [14]: 54/54 (vorher 50).
- **youtube 2.2.0: Top-up über Instanzen + Fail-Loud.** Ein Host-Pool, der die
  Deep-Filter nicht erfüllt, wurde still unterschickt (nur mit --verbose sichtbar).
  Jetzt: Ergebnisse mergen über die bekannten gesunden Instanzen (Dedup per videoId),
  bis die Filter `--num` erfüllen; Short-Count druckt eine Note mit den Stellhebeln.
  Top-up nutzt nur den bekannten Cache (Cold-Start-Pool voller Toter = Timeout-Falle).
  `YOUTUBE_HOSTS`-Env-Override für deterministische Tests (lokaler Fixture-Server,
  keine Cache-Schreibseite). Suite [13]: 50/50 (vorher 44).
- **visualize: references/scaffolds.md — Blueprint je Template** (nach mattpococks
  HTML-REPORT.md-Vorbild): Anatomie + Füllregeln für alle 10 Templates (cards,
  repo-tree, system-map, report, mermaid, tailwind-report, timeline, before-after,
  cheatsheet, barchart), verlinkt aus SKILL.md und templates/README.md.
- **visualize 1.x: Tailwind-Track (CDN, opt-in).** `templates/tailwind-report.html`
  übernimmt mattpococks Tailwind-Scaffold: Utilities als Syntax, House-Tokens als
  Vokabular (inline `tailwind.config` mappt ink/paper/severity → `text-ink`,
  `bg-paper`, `text-ok`), kritisches CSS gegen den White-Flash, House-Regeln gelten
  weiter (Dot+Text statt Pills). `visualize lint` erkennt jetzt auch Tailwind-Pill-
  Klassen (`rounded-full` + getönte bg-Utility). Netzwerk zur View-Zeit ist der
  akzeptierte Contract (wie mermaid.html); Inline-Basis bleibt Default-Track.
- **pi-priority policy beim Agent-Linking.** `scripts/link-agents.sh` verwaltet
  jetzt `!skills/<name>/**`-Exclusions in pi's User-Settings: pi lädt gelinkte
  Skills weiter aus der Package-Kopie (gefiltert, `pi install`-versioniert),
  andere Agenten lesen die `~/.agents/skills`-Links unverändert — keine
  Skill-Kollisionen mehr, der pi-Package-Filter wird nicht umgangen.

- **surf 1.5.0 — parallel sessions, smarter new/close.**
  - `surf --session <name>`: der Target-Pin liegt pro Session in
    `~/.config/surf/target-<name>` — parallele surf-Agenten überschreiben sich
    nicht mehr gegenseitig den Pin (gleiches Modell wie `rodney --session`).
  - `new` pinnt den frisch geöffneten Tab als Target — `here`/`text`/`eval`
    lesen den Pin, nicht den Front-Tab; vorher arbeitete man nach `new`
    unbeabsichtigt auf dem alten Ziel.
  - `close [wN.tN]` schließt einen konkreten Tab per Ref (vorher wurden
    Argumente still ignoriert und immer der Pin geschlossen); ein Pin auf den
    Tab wird mit gelöscht.
  - Tests: [9] läuft gegen eine lokale `file://`-Fixture (example.com hat sein
    Markup im Wild geändert und brach die Content-Asserts) und räumt jeden
    geöffneten Tab wieder ab; [12] echter Pin-Isolationstest. Suite 52/52.
- **rodney 0.6.1 (devskale fork) — parallel sessions & page reuse.**
  - `rodney --session <name>`: State unter `~/.rodney-sessions/<name>/` — jede
    Session besitzt eigene `active_page` und eigenen Chrome; `stop` killt nur
    den eigenen Browser.
  - `open <url> --reuse`: wechselt zu einer bestehenden Page mit der URL statt
    die aktive Page wegzunavigieren (Trailing-Slash normalisiert) — parallele
    Sessions konvergieren auf EINER Page statt sie N-mal zu öffnen.
  - `page t:<targetID>`: Pinning per stabiler Target-ID, drift-sicher wenn
    parallele Sessions die Indizes verschieben; `pages` listet `t:`-IDs.
  - Test-Suite gegen lokale Fixture umgestellt (49/49).
- **issues**: `cancel <slug>` without a reason exited 1 — the trailing
  `[ $# -gt 0 ] && {…}` returned the test's false as the function's exit code;
  a successful cancel looked like a failure to callers. Fixed + regression-tested
  (suite now 56 checks).
- **issues (new skill)** — moved from kontext.one to this package. The issues kanban serves
  9 projects (292 issues); the CLI lived in one of its users. Now: `skills/issues/` with
  launcher conventions (`--update`/`--selfcheck`, 7-day auto-update), `install.sh`/`install.bat`,
  and a 52-check test suite (`tests/issues/test.sh`, sandboxed `ISSUES_DIR`) covering today's
  regressions: `ls` flags without a value (was: `unbound variable` crash), bad slugs (`|`/tab/space/
  `/` were accepted and broke pipe-separated rows), and `done <slug>` (was: silently listed archive
  instead of setting DONE). kontext.one's `k.sh setup-issues` now sources the CLI from this package.
- peep SKILL.md: fixed YAML frontmatter parse error (unquoted `CLI: ` colon-space in description).
- **pre-push hook — depth ladder, fast by default.** `git push` läuft jetzt nur lint +
  typecheck (~2s statt der vollen Regression). Tiefer nur on request: `CHECK=1 git push`
  (fast gate + skill-metadata + docs), `RELEASE=1 git push` (volle Regression). Der alte
  Default (alle Suites bei jedem Push) machte jeden Push langsam und anfällig für
  Netzwerk-Flakes. `PUSH_SKIP_TESTS=1` bleibt der WIP-Escape-Hatch.

- **visualize `share --update` — stabile URL, Edit in place.** Teilt eine Seite unter einem
  stabilen Namen (`/d/<slug>`) via throways eigenem `&share=` (create-or-get) + PUT-Edit
  (ersetzt in place, Edit-History wächst) statt eines frischen Hash-Uploads. Der Server
  empfiehlt genau dieses Muster ("PUT edits, do NOT re-upload copies"). Für Iteration an
  derselben Seite bleibt der Link stabil.

- **visualize SKILL.md — rewrite auf Übersicht + Index (95 → 46 Zeilen).** Lange Prosa
  (Modes, Patterns, Templates, Validate-Flags, Share-Flags) ist in die references/
  gewandert; die SKILL.md ist jetzt Landkarte + Index (progressive disclosure). Dazu:
  Kreativitäts-Freigabe als Design-Prinzip ("templates are a floor, not a cage") +
  Routing-Tabelle in promptlib §6.5 (Swimlane / Mermaid-Decision-Tree / Before-After-Trace /
  Trust-Boundary / Loop / System-Map wann immer das Subjekt eine Beziehung ist).

- **xmodel Design-Goal dokumentiert: "show images inline, keep them out of the context".**
  Load-bearing Prinzip für alle Image-Extensions (xmodel, image-slim, imagegen): der User
  will Bilder inline SEHEN, aber sie sollen den Modell-Context nicht verstopfen (~580KB
  base64 pro Foto). Display-only ist der Default; Verstehen ist opt-in und delegiert an
  einen VLM-Sub-Call; `blockImages` ist das Sicherheitsnetz. Dazu: die zwei KONVERTIERUNGEN
  präzisiert — pi's `processImage` normalisiert nur das MIME-Label (JPEG/WebP bleiben),
  unser `toDisplayPng` konvertiert die Pixel zu PNG + 1200px erst beim Display/APC.

- **peep — YAML-Fix.** `description` im Frontmatter enthielt `CLI: ` (Colon+Space) und
  brach so das YAML-Parsing ("Nested mappings are not allowed") — die Skill lud nicht.
  Fix: description gequotet.

- **xmodel 0.5.11 — Display-Entries speichern das Original, nicht das transkodierte PNG.**
  Für 20+ angezeigte Bilder war jede Entry ~2,6 MB (full-res PNG aus dem Transcode), obwohl die
  Quelle als JPEG/WebP nur ~300 KB hatte. `writeViewEntry` legt jetzt die **Original-Bytes**
  ab (Mime via `guessMime`); `toDisplayPng` transkodiert **und resized** (sips `-Z 1200`) erst
  beim Rendern — einmal pro Bild (der Image-Component cached seine Lines). Session-Dateien für
  Bildlastige Runs: ~8× kleiner; Modell-Context unchanged (Text-Platzhalter only, seit 0.5.10).
  PNG-Quellen bleiben byte-identisch (kein Re-Encode, getestet).

- **image-slim 1.0.0 — neues Extension: Compaction bekommt keine Bild-Payloads mehr.** pi 1.0s
  Compaction ruft das rohe `convertToLlm()` (ohne den `blockImages`-Filter) — jeder gespeicherte
  Base64-Bild-Block landete voll im Summarize-Prompt (636 KB → Provider-Timeout). Die Extension
  hookt `session_before_compact` und ersetzt Bild-Blocks **auf Kopien** durch einen kurzen
  Text-Platzhalter (636 KB → 0.4 KB). Chat/TUI bleibt unberührt — Bilder bleiben inline sichtbar.
  Dazu: Alt-Sessions gesäubert (~247 MB Base64 entfernt, Backup in `/tmp/pi-session-backup`).

- **xmodel 0.5.10 — Display-Entries speichern Pixel nur noch einmal.** `writeViewEntry` schrieb
  die Base64-Payload doppelt in die Session (content[] **und** details.images); der Renderer liest
  ausschließlich details — content[] trägt jetzt nur Text-Platzhalter. Halbiert die Entry-Größe
  für alle neuen Sessions.

- **xmodel 0.5.9 — VLM delegation actually sees images under `blockImages`.** Two layers:
  (1) The delegation child inherits the user's `images.blockImages: true` and strips the
  attachment before the model sees it — glm answered literally `NO IMAGE` (forensic:
  `textLen: 8`). A project-scope override in a throwaway cwd does **not** reach pi 1.0's
  `-p` runtime, so `runChildPi` now isolates the child completely via `PI_CODING_AGENT_DIR`:
  its own `settings.json` (blockImages off) plus copies of `models.json`/`auth.json` — the
  user's real config is untouched, the temp dir is removed on finish. Verified: zai/glm
  now returns real visual detail (lemon tree, rattan chairs — not guessable from the
  filename). (2) The VLM-failure texts now explicitly forbid describing the image: with
  the blinded child, agents narrated confident fake descriptions invented from the
  filename ("Capri coast, Faraglioni") and users cannot tell that from real vision.
  Note: a preset/config `vlm` pointing at a free endpoint (kilo@nvidia…:free) still drops
  image attachments provider-side — configure a vision model on a real endpoint.

- **xmodel 0.5.8 — pi 1.0: display entries render live again (and land at turn end).** pi 1.0's
  `SessionManager._appendEntry` only persists — it emits nothing, so our direct
  `appendCustomMessageEntry` call wrote entries to the session file while the live TUI never
  heard about them: the read handover noted "displayed inline" (truthfully, per its own return
  value), the model behaved, and the terminal showed nothing — zero Kitty APCs in the write
  log. `writeEntry` now goes through the official `pi.sendMessage(..., { triggerTurn: false })`
  when available (defers while streaming, then appends **and** emits `message_start/end`, which
  is what makes the chat render the entry), falling back to the direct append on pi ≤0.99.
  `triggerTurn: false` matters twice: the streaming default would `steer()` the display entry
  into the LLM conversation, and the deferral places images **after** the agent's text at turn
  end — in the live viewport, where Kitty graphics can actually show, instead of scrolled away
  above it. Contract unchanged: `read` → images inline, VLM only when asked.

- **xmodel 0.5.7 — composes with pi's `images.blockImages`.** pi can strip image blocks from
  LLM messages (`~/.pi/agent/settings.json` → `images.blockImages: true`; replaced by
  "Image reading is disabled." at conversion time, checked dynamically). Our routing assumed
  "vision-capable ⇒ pixels arrive" — under blockImages a vision-capable model got the
  placeholder instead, silently breaking native understanding. New `modelSeesPixels(ctx)`
  (capability AND not blocked, read fresh per call) now gates every pixel-routing decision:
  the `understand:true` native pass-through, non-`read` tool results, `read_image`'s inline
  return, `/readimg`'s no-handoff shortcut, saved-screenshot synthesis, and both
  `switch`-mode triggers (a model switch is pointless when pixels cannot arrive). With
  blockImages on, understanding routes through the VLM automatically — the display entry is
  unaffected (custom display entries never go to the model).

- **xmodel 0.5.6 — images actually render inline again.** Two independent changes, plus a
  correction of this entry's own first draft (kept honest below). (1) pi-tui's Kitty encoder
  hardcodes the format key `f=100` (PNG) and ignores `mimeType`, so `.webp`/`.jpg`/`.gif`/`.bmp`
  were sent labelled as PNG and the terminal dropped them without a word — only real `.png` files
  ever worked. Non-PNG is now transcoded via `sips`; PNG stays byte-identical. This alone explains
  the original symptom: the `🖼 view-only` header rendered while the pixels never did.
  (2) `read` display semantics changed by contract: `understand:true` on a **vision-capable** main
  model used to `return;` before the display entry was written — the user got only the model's
  text description, which is exactly what read as "the VLM processed it instead of showing it"
  (the system-prompt note steers agents toward `understand:true`, so this was the common path).
  And with `_vision.mode = view`, `read` routed to throway/browser instead of the terminal.
  `read` now **always** writes the local inline display, for every model and every mode;
  understanding stays explicit and orthogonal (`understand` / `read_image`).
  *Correction:* an earlier draft of this entry claimed plain `read` also skipped the display on
  vision-capable models. False — plain `read` always reached the handover; only the
  `understand:true` path early-returned. Verified against the pre-change code before rewriting.
  `imagegen.ts` carried the same un-normalised render and was fixed too. Reported upstream as
  [earendil-works/pi#10292](https://github.com/earendil-works/pi/issues/10292) — the local fix is a
  workaround for that bug.

- **visualize: `validate` no longer rejects pages that *document* an import.** Regression found by
  running the new tier-0 routing end-to-end (see below): the single-file check scanned the whole
  file for `import … from '…'`, so a page explaining a refactor — `<code>import … from './transport'</code>`
  — was flagged as a local dependency. A gate that fails valid output is worse than no gate: it
  teaches agents to ignore it. The JS-import check now reads only real `<script>` content
  (`validate` on the produced page: exit 1 → exit 0). Covered by two new regression checks —
  prose passes, a real local `<script>` import still fails — because the existing template suite
  could not catch this (no template shows an import in prose).

- **visualize 1.8.0 — inline forms merged from humanlayer's `show-me`.** `visualize` is no longer
  HTML-only: a pseudocode block, call tree, component tree, annotated file tree, or a
  **matched-shape diff** placed next to the sentence it supports is now a first-class output
  (`references/code-forms.md`). The routing gains **tier 0 — answer inline, build no file**
  (`references/routing.md`), ahead of the existing inline-diagram and `d2`/`figure` tiers, and
  `structures.md` cross-links it so structure selection never runs before the inline check.
  Adapted from [humanlayer/skills](https://github.com/humanlayer/skills) `show-me` (MIT): the
  Claude-only `Bash(open …)` HTML fallback was dropped — building the page stays `visualize`'s
  job — and the four diff shapes (component / file-layout / call-tree / control-flow) were kept
  verbatim because the shape-matched diff is the strongest idea in the original.
  Tests: 167 pass / 0 fail (+13). New checks cover the code-forms sections, the diff shapes, the
  absence of the `Bash(open …)` fallback, and the wiring into `routing.md`/`SKILL.md`/`structures.md`;
  `prompts.md` gains P14–P19, six tier-0 prompts that must produce **zero** HTML.
  SKILL.md kept under the repo's 100-line convention (98).
  **Verified live** (`pi --print --skill ./skills/visualize`): P15 call tree and the file-layout
  diff both answered inline with no HTML; the escalation prompt ("Mach mir daraus eine Seite fürs
  README") built a page as designed. Two failure modes surfaced while testing and are fixed below
  or documented: a prompt that embeds the answer invites explanation instead of the form, and an
  invented path (`src/transport.ts` that exists in no repo here) makes the agent refuse or pad.

## 1.4.6 — 2026-09-08

- **vtd:** the yt-dlp venv now lives outside the repo (`~/.cache/skale-skills/video-transcript-downloader`) — pi package updates run `git clean -fdx` and would wipe an in-repo `.venv`. Launcher exports `VTD_ENV_DIR`; `--update` uses `--ff-only` and refreshes yt-dlp.
- **viewimg + visualize:** launchers gained `--update`/`--selfcheck`, `.last-update` stamp, and 7-day auto-update (parity with fetch-url/web-search).
- **surf:** user-provided strings (URLs, keystrokes) are now escaped in AppleScript contexts via a new `as_str()` helper — same discipline as `js_str()` on the JS side.
- **youtube:** launcher updates with `--ff-only`, auto-update also fires on a missing stamp, `parse_list_entries` correctly annotated as a generator.
- **tests:** network-dependent blocks count as honest WARN/skip instead of PASS (fetch-url, web-search, youtube, vtd, imagegen); youtube's cache checks no longer hard-fail when discovery is down; viewimg generates its image fixture on the fly (committed `generated/*.jpg` went stale).
- **lint.sh:** finds the installed pi package portably (`PI_PACKAGE` override → Homebrew → `npm root -g`); `@types/node` comes from the lint toolchain — the gate now works off-macOS.
- **index-skills.py:** extensions no longer index as `/**`; git-package entries render readable labels. SKILL-INDEX.md regenerated.
- **figure:** package.json aligned with the skill (v1.2.0, name `figure`).
- **docs:** AGENTS.md lists all 12 skills + 13 test suites, phantom `api/` section removed, browser deep-dive condensed to a link; README badge/table, RECOMMENDED-SKILLS extensions, release-notes backfill (1.4.4/1.4.5); stale Chrome-version claims fixed (auto-connect needs 144+, per official docs).
- **hygiene:** untracked `uv.lock` (fetch-url, web-search) and ignored-but-tracked `testbed/`, `.vscode/`; removed orphaned `test_rodney.sh`, stale `docs/*.d2` drafts; manual test script moved out of shipped `extensions/`; d2 SKILL.md no longer contradicts its bundled wrapper scripts.

## 1.4.5 — 2026-09-06

- **surf:** open reuses tabs by default (exact match + same-origin prefix tier); `--new` forces a fresh tab.

## 1.4.4 — 2026-09-04

- **imagegen:** linters for generated HTML/images + pollinations-free dynamic fallback.
- **extensions:** cleared all pre-existing typecheck errors; lint gate green.
- **xmodel:** vision uses a vision-capable main model directly, loud timeouts, ESC abort, parametrizable vision thinking.
- **improve-ux:** SOTA baseline, numeric a11y/motion guidance, rating loop; refreshed reference catalog.
- **CONVENTION.md:** coding guidelines distilled from the Codex repo learnings.

## 2026-08-12

### visualize
- **Added:** `references/promptlib.md` — a prompt library of design moves that make a visualization *lovely* (colour-coded grouping, editorial typography, card grids, provenance footer). SKILL.md points to it when building.
- **Added:** annotated **repo tree** recipe (promptlib §8 + structures.md) — indented rows with name + one-line desc + colour-coded kind tag, deep dirs summarised. Live-tested on skale-skills and piui.
- **Added:** **system map** recipe (promptlib §9 + structures.md) — multi-panel map for multi-repo / multi-service orchestrators (repo topology, pipeline, fleet, top-level tree). Live-tested on kontext.one.
- **Test:** suite now checks promptlib.md exists (16 checks).

## 2026-08-12

### d2 / figure
- **Changed:** `d2` and `figure` are now **manual-only** — `disable-model-invocation: true` hides them from the model's auto-invocation. They're invoked explicitly via `/skill:d2` / `/skill:figure`.

### visualize
- **Changed:** added a related-skills note clarifying the split — `d2`/`figure` are manual diagram generators (single SVGs); `visualize` is the auto-invocable page layer that can embed their output.

## 2026-08-12

### visualize (new)
- **Added:** `visualize` skill — render any set of things as ONE self-contained HTML document and share a URL. Agent understands what you want to visualize, picks a structure (cards, grid, before-after, timeline, list, flow, hierarchy, comparison), builds a single portable HTML file, then opens it locally and uploads it to the throway store for a short-lived URL.
- **Launcher:** `visualize open <file>` / `visualize share <file>` / `visualize validate <file>`; `install.sh`/`install.bat` → `~/.local/bin/visualize`.
- **References:** `structures.md` (structure catalogue) + `html-patterns.md` (inline-CSS scaffold, SVG arrows, optional Mermaid).
- **Test suite:** `tests/visualize/test.sh` — 15 checks incl. live throway upload.

### extensions (imagegen)
- **Changed:** model discovery now probes the per-provider `/image/models/<provider>` endpoint (fallback: filtered `/models` catalog) — no hardcoded model names.
- **Added:** `isModelUnavailable` detection — a 400 model-unavailable (renamed/removed) is now a probe signal that falls through to an available model instead of failing hard; only genuine failures (auth/network/timeout) surface as-is.

### deprecated
- **Deprecated:** the `skiller` CLI moved to `deprecated/skiller/` (kept for reference). Its multi-agent-install niche is served by `openskills` / `npx @anthropic-ai/skills add` / `skills.sh`. Docs, README, and architecture diagrams updated to drop it.

## 2026-08-11

### rodney
- **Renamed:** the `jodney` skill back to **`rodney`** (matches `devskale/rodney`, working branch `skale`). Renamed skill dir `skills/jodney/` → `skills/rodney/`, `tests/jodney/` → `tests/rodney/`, `guides/jodney-setup.md` → `guides/rodney-setup.md`, and `test_jodney.sh` → `test_rodney.sh`.
- **Fixed:** env vars to match the `skale` branch — `RODNEY_CHROME_BIN`/`RODNEY_TIMEOUT` → `ROD_CHROME_BIN`/`ROD_TIMEOUT` (go-rod standard); kept `RODNEY_HOME`.
- **Removed:** the `--update` self-update command from docs — the `skale` branch no longer has it; install/refresh now `git clone -b skale` + `go build`.
- **Docs:** updated AGENTS.md, README, SKILL-INDEX, browser-tools comparison, surf/peep cross-refs, diagrams, and setup guides to the `rodney` name.

## 2026-08-09

### extensions
- **Added:** shared `extensions/lib/image-utils.ts` unifying `isVisionCapable`, `guessMime`, and `isValidImage` across xmodel + imagegen (each previously carried a copy).
- **Moved:** shared helper modules (`session-state.ts`, `xmodel-config.ts`, `xmodel-vision-utils.ts`, `image-utils.ts`) into `extensions/lib/` — a subdir pi doesn't auto-discover as extensions, so the `package.json` extension glob is clean again (no `!` exclusions). Extensions import via `./lib/<name>`.
- **Removed:** a Middle Man re-export (`isValidImage` now imported directly) and dead `extractFinalAssistantText`.

## 2026-08-09

### xmodel
- **Added:** extracted the pure config store into `extensions/xmodel-config.ts` and the stateless vision helpers into `extensions/xmodel-vision-utils.ts`. xmodel.ts dropped from 1719 → 1468 lines. The stateful vision pipeline (delegate/human/view) stays in xmodel.ts.

### surf
- **Changed:** split `help.sh` (920-line data monolith) into `help-overview.sh` (the categorized index) + `help-command.sh` (per-command detail + dispatcher). Verified byte-identical output for all 45 commands.
- **Documented:** `surf.sh` now declares THE SEAM — `run_js` (engine.sh) + `get_target` (target.sh) are the two load-bearing interfaces every command routes through; `$APP`/`$TARGET_FILE` are read-only shared config.

### package
- **Fixed:** helper modules (`session-state.ts`, `xmodel-config.ts`, `xmodel-vision-utils.ts`) are now excluded from the extension glob so pi doesn't try to load them as extensions.

## 2026-08-09

### fetch-url / web-search
- **Changed:** dropped the copy-pasted global-first `sys.path` credgoo bootstrap and the `credgoo_get` wrapper. Both now import `get_api_key` directly (declared dependency, resolved to credgoo 0.1.14). Missing keys log at DEBUG — silent by default, opt-in loud via a DEBUG handler. Removed the `contextlib.redirect_stdout` cargo-cult from docs.

### extensions (xmodel / heartbeat)
- **Added:** shared `extensions/session-state.ts` with `reconstructLastCustomEntry` + `isStaleCtxError`.
- **Changed:** xmodel + heartbeat now import these from the shared module instead of duplicating them; each keeps its own session handler wiring. statusline untouched (different read shape).

## 2026-08-09

### viewimg
- **Changed:** `viewimg` accepts **multiple files**; `--open` opens **all** images in **one** Preview window (tabs) via `open -a Preview` — Preview reuses its window across calls, so repeated `viewimg --open` never stacks up multiple windows.

### xmodel
- **Changed:** `read_image` is **opt-in** — the model must not autonomously call it right after a plain `read`/`viewimg` (those are display-only and fast). Only an explicit "understand/analyze" request fires the VLM.

### viewimg (new skill)
- **Added:** `viewimg` — show an image in the terminal **view-only** (never VLM). Renders as ANSI block art via `chafa`, or opens natively with `open` on macOS (`--open`). Understanding stays opt-in (`read_image` / `/readimg`).

## 2026-08-09

### figure / imagegen / d2
- **Changed:** generated/derived output now lands in the **XDG-standard** `$XDG_CACHE_HOME/generated/` (default `~/.cache/generated/`) — regenerable cache belongs in the cache dir per the XDG Base Directory Specification (web-grounded). No more hardcoded `~/generated/images` / `~/Pictures/generated` / `~/.generated`.
- **figure:** output dir resolves `$XDG_CACHE_HOME/generated` (override `FIGURE_OUT_DIR`); docs updated.
- **imagegen:** `outputDir()` resolves `$XDG_CACHE_HOME/generated` (override `IMAGEGEN_OUTPUT_DIR`); `uploads/` web-serving unchanged.
- **d2:** documented `~/.cache/generated/` as the default for rendered diagrams.

## 2026-08-09

### xmodel v0.4.0
- **Changed:** `read` (and `view`/`generate_image`) are now **display-only** — they show the image but **never trigger the VLM**. Understanding is opt-in.
- **Added:** `read_image` tool + `/readimg` command — explicit "understand" path that runs the VLM on an image and returns the text analysis. `/readimg` with no args shows help; `/readimg settings` opens the vision hub to pick the image model (`_vision.vlm`).
- **Added:** `analyzeImageFile` helper (VLM sub-call via child-pi `@file`), shared by `read_image` and `/readimg`.

### imagegen
- **Changed:** default model → `pollinations@dreamshaper` (cheapest); model discovery via the OpenAI-compatible `/models` catalog (any provider/modelid), generic key resolution, keyless providers supported.
- **Added:** self-healing default — remembers last-good model per provider, falls back through cheaper models on 402, learns costs from 402 responses (no hardcoded models/costs).

## 2026-06-22

### web-search
- **Fixed:** launcher had a hardcoded macOS path (`/Users/johannwaldherr/...`), broken on Linux. Replaced with portable symlink resolution.
- **Added:** `--update`, `--selfcheck`, 7-day auto-update, and a credgoo health check to the launcher.
- **Changed:** `install.sh` now symlinks `~/.local/bin/web-search` to the tracked `search` launcher (matching `fetch-url`'s pattern) instead of generating a script.

### statusline
- **Docs:** improved header doc-comment — documents the three intentional changes vs. the built-in footer (machineName prepend, Z.ai usage append, stats reorder for progressive skip) and the `(auto)` compaction caveat.

### repo / docs
- **Added:** `docs/installation.md` → "Loose-file conflicts" section — pi auto-loads `~/.pi/agent/skills/` symlinks and hand-copied `~/.pi/agent/extensions/*.ts`, which collide with the git package by **identity** (not content).
- **Added:** `docs/development.md` — the dev loop for skills & extensions: edit in the working tree → push upstream → `pi update --extension` → **then** remove dev overrides. Documents the critical catch (removing an override before the fix lands = silent regression).
- **Updated:** `AGENTS.md` Docs table links both new docs.

### context
- A dev-machine cleanup prompted these docs: stale `~/.pi/agent/skills/{fetch-url,web-search}` symlinks and a loose `~/.pi/agent/extensions/statusline.ts` were causing pi's `[Skill conflicts]` startup warning. Removed them so the git package is the sole source. (See `docs/installation.md`.)
