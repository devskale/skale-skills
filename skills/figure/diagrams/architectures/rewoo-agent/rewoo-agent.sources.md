# ReWOO diagram — source passages

Why `rewoo-agent.fig.mjs` is drawn the way it is. Every design choice below is anchored to
an exact sentence from the ReWOO paper.

**Source:** Binfeng Xu et al. (2023), *ReWOO: Decoupling Reasoning from Observations for
Efficient Augmented Language Models*, arXiv:2305.18323. Passages transcribed from the ar5iv
HTML rendering, **§2.1 (Formulation)** — verify at
<https://ar5iv.labs.arxiv.org/abs/2305.18323>.

---

## The passages, and what each fixed in the figure

**1. Three modules, one plan-then-execute pass.**
> "Planner leverages the foreseeable reasoning of LLMs to compose a solution blueprint."

> "Solver processes all plans and evidence to formulate a solution to the original task or
> problem, such as providing answers in QA tasks or returning the work status for action
> requests."

→ Planner and Solver are the LLM reasoning modules — drawn as the two brain (`agent`) nodes.

**2. The plan is a list of `(Plan, #E)` tuples.**
> "it contains consecutive tuples (Plan, #E) where Plan represents a descriptive message of
> the current step, and #E is a special token to store presumably correct evidence"

→ The `Plan` node is drawn as a document listing `#E1 = Tool[…]`, `#E2 = Tool[#E1]`.

**3. The Worker is a tool executor, not a reasoner.**
> "Worker enables ReWOO to interact with the environment through tool-calls. Once Planner
> provides a blueprint, designated Workers are invoked with instruction input, and populate
> #E with real evidence or observations."

→ This is the fix to the earlier draft. The Worker is **not** an LLM brain — it is drawn as
the blue tool-executor node that calls the Retrieval tool and fills the `#E` variables.

**4. Steps are interdependent and therefore ordered — not parallel.**
> "This paradigm enables ReWOO to tackle multi-step and complex tasks, particularly those
> where a subsequent step depends on the observations of prior steps, by referring to #E
> from previous steps in the instructions given to Workers."

→ Because `#E2` can reference `#E1`, the Worker is labelled "run #E1…#En **in order**", and
the earlier parallel-worker fan-out was removed.

**5. Reasoning is decoupled from observation — nothing loops back to the Planner.**
> "ReWOO separates the reasoning process of LLMs from external tools, avoiding the
> redundancy of interleaved prompts in observation-dependent reasoning."

→ The whole plan is committed before any tool runs, so there is **no** edge returning
observations to the Planner (contrast the ReAct figure, where the observation loops back).

**6. The Solver reads the plan *and* the evidence.**
> "Solver processes all plans and evidence to formulate a solution…"

→ The Solver node has two inputs: the resolved `Evidence` (`#E1…#En`) and a dashed `plan`
edge straight from the `Plan` node.

---

## Relation to IBM's ReWOO

IBM's ReWOO is the **same three-module paradigm** and credits Xu et al. (2023). It **agrees
with the paper — and this figure — on every load-bearing point**:

- **Worker is a non-thinking tool executor.** IBM: the Worker "executes the plan, calling
  external tools (without repeating costly LLM API calls for 'thinking,' as in ReAct)." This
  is exactly why the figure draws the Worker as a tool-executor node, not a brain.
- **Reasoning is decoupled; no feedback to the Planner.** IBM: "ReWOO breaks away from the
  think-act-observe pattern by decoupling reasoning from external observations." → one pass,
  nothing loops back to the Planner (both IBM's explainer and its build tutorial are strictly
  linear: Planner → Worker loop → Solver, no re-planning).
- **Sequential execution.** IBM's tutorial runs the steps one at a time (`for q in
  subquestions: … expert(q)`), matching the figure's "run #E1…#En **in order**".

Where IBM's **implementations simplify away from the paper** (and therefore from this figure):

- **No `#E` evidence-variable substitution.** The paper (and this figure) make later steps
  reference earlier evidence (`#E2 = Tool[#E1]`). IBM's Granite tutorial drops this — the
  Planner returns a plain list of independent subquestions and results are **not** substituted
  into downstream tool inputs. This figure deliberately follows the **paper**, keeping the
  interdependent `#E` steps (the mechanism that makes ReWOO more than parallel sub-QA).
- **Per-step LLM formatting in the Worker.** The tutorial's `expert(q)` uses an LLM to write
  each sub-answer from the search results — a light per-step LLM use the paper's "populate #E
  with real evidence" Worker does not require. The figure follows the paper's leaner Worker.
- **Tools & extras.** IBM's tutorial uses web search (Serper.dev) and adds chunked long-output
  generation; this figure uses a single tender `Retrieval tool`. Implementation details, not
  architecture.

Net: the figure is faithful to the **paper**, which is *more* detailed than IBM's simplified
tutorial; the only paper-vs-IBM divergence that touches the diagram is the `#E` interdependency,
which we keep on purpose. IBM's own explainer still describes ReWOO in the paper's terms.

**Sources:** IBM, *What is ReWOO?* — <https://www.ibm.com/think/topics/rewoo> · IBM,
*Building a ReWOO Reasoning Agent Using IBM Granite* —
<https://www.ibm.com/think/tutorials/build-rewoo-reasoning-agent-granite> (accessed 2026-07-03).
