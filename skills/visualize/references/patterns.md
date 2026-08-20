# Semantic patterns — what the page *does*

A pattern describes **what the subject does**; a structure (structures.md) describes
**how the information is arranged**. Choose a pattern first when behaviour, state,
enforcement, or risk is load-bearing — then use its mapped structure as the layout
grammar. If no pattern fits, pick a structure directly.

> **Why this layer exists.** A card grid of "things" is easy. The hard cases are when the
> *relationship between the things* is the point — work queues up, a boundary is crossed,
> a loop feeds back, two policies diverge. Naming the pattern first stops you from
> reaching for a generic grid and hiding the mechanism. It also gives you a **complexity
> budget** (how many nodes before the page tangles) and a **static fallback** (our pages
> are static by definition — the still must carry the meaning).

## Choosing a pattern

| The reader must understand… | Pattern | Structure to use |
|---|---|---|
| Many arrivals competing for finite service capacity | **Fan-in queue / bottleneck** | `flow` |
| A lifecycle repeats the same questions across stages | **Stage framework with semantic slots** | `timeline` |
| A loose conversation becomes a durable structured record | **Unstructured input → structured artifact** | `before-after` |
| Why two similar things diverge, and where | **Paired trace / divergence** | `before-after` |
| Which routes cross a boundary and which are blocked | **Trust boundary** | `flow` / `system-map` |
| Which controls apply at each enforcement surface | **Governance / control catalog** | `table` |
| How a system feeds back on itself | **Loop / flywheel** | `flow` |
| Where claims come from, what is verified | **Provenance / evidence trail** | `hierarchy` |

Use **one primary pattern** per page. A second pattern may supply at most one supporting
panel; if both need full treatment, split into two pages.

---

## 1. Fan-in queue / bottleneck

**Selection triggers:** several producers converge on one reviewer, service, gate, or
constrained resource; the story depends on arrival rate, queue depth, wait, capacity, or
backpressure.

**Required primitives:** distinct sources; fanned ingress; an ordered queue with visible
slots and count; a capacity/service-rate label; one constrained service point; admitted
and deferred/rejected outcomes. Label units (`8/hour`, `3 slots`), not just "high".

**Complexity budget:** ≤5 sources, ≤5 queue slots, one bottleneck, two outcomes, ≤9
primary nodes. Aggregate excess sources as a named cohort.

**Anti-patterns:** an equal-width pipeline that hides contention; arrows merged before
they can be traced; capacity implied only by box size; decorative pile-up; red alone
meaning overloaded.

**Static fallback:** show the representative final queue, numeric count/capacity,
bottleneck label, and both outcome paths. A still must reveal *why* work waits.

**Structure:** `flow`. Use a `timeline` only when service stages, rather than sources,
dominate.

---

## 2. Stage framework with semantic slots

**Selection triggers:** a lifecycle or operating model repeats the same semantic questions
across stages (Question, Input, Governance, Output, …). Cross-stage comparability matters
more than message timing.

**Required primitives:** ordered stage headers; a consistent slot grid; explicit
empty/not-applicable slots; stage-to-stage handoff; stable slot labels; one primary output
per stage. Preserve slot order in every stage.

**Complexity budget:** 3–6 stages, 3–4 slot kinds, ≤20 populated cells, ≤2 lines per cell.
Split detail when a cell needs prose.

**Anti-patterns:** each stage invents a different internal layout; slot meaning encoded by
position with no labels; fake precision from dozens of cells; confusing stage order with
ownership lanes; shrinking text to keep one canvas.

**Static fallback:** render the full stage × slot matrix with handoffs and explicit `—` or
"Not applicable" entries. Do not depend on a staged reveal to teach the schema.

**Structure:** `timeline` (stages as the axis). Use `flow` only when message timing
between actors is also load-bearing.

---

## 3. Unstructured input → structured artifact

**Selection triggers:** dialogue, notes, prompts, or a rambling request are elicited,
normalised, and written into a durable brief, ticket, record, schema, or other structured
artifact.

**Required primitives:** source utterance(s); clarifying questions; extracted field/value
pairs; a named transformation; the durable artifact boundary; provenance links from
representative statements to fields; missing/unknown state.

**Complexity budget:** ≤4 exchanges, ≤6 artifact fields, one transformation, ≤3 provenance
links. Show representative content, not a transcript.

**Anti-patterns:** "AI magic" sparkle between two boxes; the artifact shown as another
chat bubble; fields appearing without sources; inventing certainty for missing facts.

**Static fallback:** show a short source excerpt beside the completed labelled artifact,
with at least one provenance mapping and any unknown fields visible.

**Structure:** `before-after` — source on the left, structured artifact on the right, the
transformation between them.

---

## 4. Paired trace / divergence

**Selection triggers:** two otherwise similar things reach different outcomes; the reader
needs rule-by-rule `PASS` / `FAIL` / `SKIPPED` / `NOT REACHED` state and the first
divergence.

**Required primitives:** the same ordered rules on both traces; explicit status *text*
plus symbol/shape; inputs that differ; final outcomes; a labelled first-divergence marker;
a distinction between `SKIPPED` (intentionally bypassed) and `NOT REACHED` (evaluation
stopped earlier).

**Complexity budget:** exactly 2 traces, 3–6 rules, one first divergence, ≤12 status
cells, one outcome per trace. Move rule prose to notes if labels exceed one line.

**Anti-patterns:** comparing two independently ordered flows; green/red dots without
words; treating skipped and not-reached as synonyms; highlighting every difference;
continuing a denied trace as if downstream rules ran.

**Static fallback:** show all states and both outcomes at once; use a persistent
bracket/line and label for the first divergence.

**Structure:** `before-after` with aligned rows.

---

## 5. Trust boundary

**Selection triggers:** a supported path creates a bounded route from intake to
deployment; trust boundaries, privileged moments, permitted versus forbidden ingress, and
approved versus blocked paths are the point.

**Required primitives:** labelled trust boundaries; actors and identities; permitted
ingress with a positive text label; forbidden ingress terminating *at* the boundary;
approved path; blocked bypass path; privileged gate; isolated runtime; audit destination.
Use different line styles and stop symbols in addition to colour.

**Complexity budget:** ≤3 trust zones, ≤8 components, ≤10 paths, ≤2 forbidden paths, one
privileged gate. Split control detail into a catalog figure.

**Anti-patterns:** a dashed box called "security" with no route semantics; a forbidden
arrow crossing into the protected zone; secrets or identity implied but unlabelled; every
component styled as trusted; a bypass path that visually rejoins the approved route.

**Static fallback:** render every boundary and both permitted/forbidden routes. Blocked
paths must visibly stop before entry or deployment.

**Structure:** `flow`; use `system-map` when the boundary spans a whole platform.

---

## 6. Governance / control catalog

**Selection triggers:** a control inventory must be understood by *where it is enforced*
(authoring, workspace, merge/CI, deploy/runtime, …). A single checklist would hide those
enforcement points.

**Required primitives:** enforcement-surface groups; named controls; enforcement actor
(`code`, `platform`, `human`); timing (`write`, `merge`, `deploy`, `run`); bypassability
or exception route; coverage/gap notation.

**Complexity budget:** 3–5 surfaces, 3–7 controls per surface, ≤24 controls total, ≤3
attributes per control. Summarise counts only when the item list exists elsewhere.

**Anti-patterns:** 35 tiny pills; grouping by vague themes instead of enforcement point;
mixing aspirations with enforced controls; icons without control names; claiming
defence-in-depth without showing surface coverage.

**Static fallback:** show the complete grouped catalog with surface headers and text
labels for actor and timing; preserve gaps and exceptions.

**Structure:** `table` (rows = controls, columns = surfaces/attributes).

---

## 7. Loop / flywheel

**Selection triggers:** the subject feeds back on itself — a flywheel, a self-improving
loop, a cycle whose output becomes input. The *cycle* is the point, not a linear path.

**Required primitives:** ordered stations around a hub; a shared memory/hub where state
persists; labelled write-backs (dashed); a clear direction of rotation; at least one
feedback edge that returns to an earlier station.

**Complexity budget:** 4–8 stations, one hub, ≤2 write-back edges, one direction. More
than two write-backs tangles the layout.

**Anti-patterns:** a straight pipeline drawn as a loop; write-backs that cross the whole
canvas; the hub drawn as just another station; direction ambiguous.

**Static fallback:** the arrows must make the cycle legible in a still — direction
markers, a labelled hub, dashed write-backs. Don't rely on motion.

**Structure:** `flow`. Keep it small; a long write-back to an early node tangles — prefer
a distinct downstream node over writing back upstream.

---

## 8. Provenance / evidence trail

**Selection triggers:** the reader must trust where claims come from — which source
supports which finding, what is verified versus asserted, what is missing.

**Required primitives:** claims/findings; source references; explicit verified /
unverified / missing state; provenance links from finding to source; a legend for the
evidence states.

**Complexity budget:** ≤12 findings, ≤1 source per finding (or a named cohort), ≤3
evidence states, one legend. Don't turn every finding into a mini-report.

**Anti-patterns:** a claim with no source; all findings "verified" with no method; colour
as the *only* evidence signal (add text); padding with sources that don't back the
finding.

**Static fallback:** every finding row shows its state as text plus a quiet marker; the
legend defines the states once.

**Structure:** `hierarchy` (finding → source) or `table` (finding × evidence columns).
Pair with the provenance footer (promptlib §5) for the page's own provenance.

---

## Rules

- **One pattern per page.** Pick the load-bearing behaviour; the rest is supporting detail.
- **Pattern before structure.** Name the pattern, then map to its structure. If no pattern
  fits, choose a structure directly.
- **Respect the complexity budget.** These are hard caps — exceeding them tangles the
  layout and hides the mechanism the pattern exists to reveal. Aggregate, summarise, or
  split.
- **Static is the contract.** Every pattern must tell its whole story in a still frame —
  our pages don't move. If meaning depends on hover, animation, or a staged reveal, it's
  not done.
- **Mechanism over outcome** (promptlib §6.5). These patterns exist to reveal *why*, not
  just *what*: show the queue, the boundary, the divergence, the loop — not a flat list of
  results.

## When a pattern outgrows the page → d2 / figure

A pattern maps to a `visualize` page by default, but when the real content **exceeds the
pattern's complexity budget**, the graph is usually better as a standalone deliverable
from `d2` or `figure` (manual-only — recommend, don't invoke).

- **→ `d2` (auto-laid-out technical graph):** the pattern is at heart a dense graph —
  **fan-in queue** with many producers, **trust boundary** with many routed paths,
  **paired trace** with many rule-by-rule states, **loop / flywheel** with a long
  write-back. d2's auto-layout handles the density; inline SVG tangles.
- **→ `figure` (hand-drawn editorial sketch):** the pattern's value is a polished,
  presentation-quality explainer — **stage framework**, **provenance / evidence trail**, a
  hand-drawn **unstructured → structured** transformation.
- **→ stay inline:** the pattern is simple (a few nodes) and one element among many in a
  quick shareable page.

See promptlib §10 for the full per-pattern routing table.
