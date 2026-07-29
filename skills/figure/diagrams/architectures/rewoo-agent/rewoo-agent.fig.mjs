// P2 — ReWOO, DETAILED variant (Option A), faithful to Xu et al. 2023 (arXiv:2305.18323).
// Planner (LLM) breaks the task into a blueprint of INTERDEPENDENT (Plan, #E) steps in
// one pass, BEFORE any tool runs. The Worker is a TOOL EXECUTOR (not an LLM): it resolves
// #E1…#En IN ORDER by calling the retrieval tool, and a later step may reference an earlier
// step's evidence (e.g. #E2 = Tool[… #E1]). The Solver (LLM) then synthesises task + plan +
// evidence into the answer. No observation ever feeds back into the Planner.
// Build:  NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs figure/diagrams/architectures/rewoo-agent/rewoo-agent.fig.mjs

export default {
  name: 'rewoo-agent',
  title: 'ReWOO Agent',
  width: 1120,
  height: 800,

  nodes: [
    { id: 'query',   x: 60,  y: 340, icon: 'doc-envelope',    color: 'tan',   label: 'Query\n(criterion)' },
    { id: 'planner', x: 300, y: 340, icon: 'llm-agent-brain', agent: true,    label: 'Planner:\nfull plan,\none pass' },
    { id: 'plan',    x: 560, y: 340, icon: 'doc-lines',       color: 'lilac', label: 'Plan:\n#E1 = Tool[…]\n#E2 = Tool[#E1]' },

    { id: 'rtool',   x: 830, y: 110, icon: 'code-tools',      color: 'green', label: 'Retrieval\ntool' },
    { id: 'worker',  x: 830, y: 340, icon: 'code-tools',      color: 'blue',  label: 'Worker:\nrun #E1…#En\nin order' },
    { id: 'evidence',x: 830, y: 590, icon: 'doc-lines',       color: 'lilac', label: 'Evidence:\n#E1 … #En' },

    { id: 'solver',  x: 560, y: 590, icon: 'llm-agent-brain', agent: true,    label: 'Solver:\nplan + evidence' },
    { id: 'answer',  x: 60,  y: 590, icon: 'doc-lines-success', color: 'green', label: 'Answer\n+ citations' },
  ],

  edges: [
    { from: 'query',   to: 'planner', badge: 1 },
    { from: 'planner', to: 'plan',    badge: 2, label: 'one pass' },
    { from: 'plan',    to: 'worker',  badge: 3 },

    // the worker resolves each step by calling the retrieval tool (sequential, interdependent)
    { from: 'worker', to: 'rtool', badge: 4, label: 'call', labelOffset: [-46, 0],
      path: [[890, 340], [890, 260]] },
    { from: 'rtool', to: 'worker', label: 'passages', labelOffset: [58, 0],
      path: [[920, 260], [920, 340]] },

    // resolved evidence variables flow down to the solver
    { from: 'worker', to: 'evidence', fromSide: 'bottom', toSide: 'top', badge: 5, label: 'resolve #E*',
      path: [[905, 490], [905, 590]] },
    { from: 'evidence', to: 'solver', fromSide: 'left', toSide: 'right', badge: 6, label: 'evidence',
      path: [[830, 665], [710, 665]] },
    // the Solver also reads the plan itself
    { from: 'plan', to: 'solver', fromSide: 'bottom', toSide: 'top', dashed: true, label: 'plan',
      path: [[635, 490], [635, 590]] },

    { from: 'solver', to: 'answer', fromSide: 'left', toSide: 'right', badge: 7, label: 'compose',
      path: [[560, 665], [210, 665]] },
  ],
};
