# Release Notes

Log of notable changes to skale-skills. Newest first.

## Unreleased

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
