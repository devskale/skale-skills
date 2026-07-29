# ReAct diagram — source passages

Why `react-agent.fig.mjs` is drawn the way it is. Every design choice below is anchored to an
exact sentence from the ReAct paper.

**Source:** Shunyu Yao et al. (2023), *ReAct: Synergizing Reasoning and Acting in Language
Models*, arXiv:2210.03629. Passages transcribed from the ar5iv HTML rendering — verify at
<https://ar5iv.labs.arxiv.org/abs/2210.03629>.

---

## The passages, and what each fixed in the figure

**1. Reasoning and acting are interleaved by one model.**
> "we explore the use of LLMs to generate both reasoning traces and task-specific actions in
> an interleaved manner" (Abstract)

> "ReAct prompts LLMs to generate both verbal reasoning traces and actions pertaining to a
> task in an interleaved manner" (Introduction)

→ One agent alternates a `Thought` node and an `Action` node, rather than two separate agents.

**2. A thought changes nothing; only an action touches the environment.**
> "An action a^t∈ℒ in the language space, which we will refer to as a thought or a reasoning
> trace, does not affect the external environment, thus leading to no observation feedback"
> (Section 2)

→ `Thought: enough evidence?` is a pure reasoning/decision node (no observation comes from
it); the `Observation` only ever arrives after an `Action`.

**3. The trajectory is a loop of thought → action → observation.**
> "we alternate the generation of thoughts and actions so that the task-solving trajectory
> consists of multiple thought-action-observation steps" (Section 2)

→ The figure's cycle: `Thought → Action → Retrieval tool → Observation → Thought`, with the
observation looping back **unconditionally**.

**4. Actions gather information from an external source.**
> "actions allow it to interface with and gather additional information from external sources
> such as knowledge bases or environments" (Abstract)

> action space: "search[entity], lookup[string], finish[answer]" (Section 3.1)

→ The `Action` calls the green `Retrieval tool`; the returned text becomes the `Observation`.

**5. The agent stops by choosing a "finish" action.**
> "finish[answer], which would finish the current task with answer" (Section 3.1)

→ The decision lives at the reasoning step: `Thought: enough evidence?` → **YES** takes the
`finish` branch to `Answer`, **NO** issues another `Action`. This is why the branch labels
leave the *Thought* node (the earlier draft wrongly put them on the observation loop-back).

---

## Relation to IBM's ReAct

IBM's "ReAct agent" is the **same paradigm** — IBM credits Yao et al. (2023) and describes the
thought → action → observation loop identically. The differences are implementation/scope, not
architecture, and the figure sits above them:

- **Action space.** The paper fixes a Wikipedia API (`search`/`lookup`/`finish`) for its
  benchmarks; IBM generalises to **arbitrary user-defined tools/APIs**. The figure's generic
  `Retrieval tool` (one tool, specialised to tender retrieval) matches IBM's generalised
  framing rather than the paper's literal action set.
- **How the tool is called.** The paper parses free-text `Action:` strings (prompt-based
  ReAct); IBM presents that *and* framework-built agents (LangGraph, BeeAI), and contrasts it
  with **native function-calling** (structured JSON tool calls). This is an implementation
  fork the figure is deliberately agnostic to — the boxes and arrows are identical either way.
- **Stopping.** The paper stops via a `finish[answer]` action; IBM adds practical guards
  (a max-iterations cap, a confidence/condition threshold). The figure shows the core `finish`
  decision only, not the guard.
- **Scope.** The paper is a prompting method (+ some fine-tuning); IBM frames ReAct as a
  production agent pattern and layers on memory, multi-agent orchestration and frameworks —
  all outside this single-agent architecture view.

**Source:** IBM, *What is a ReAct Agent?* — <https://www.ibm.com/think/topics/react-agent>
(accessed 2026-07-03).
