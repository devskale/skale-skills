// P1 — ReAct, DETAILED variant (Option A: fixed control flow, explicit steps).
// The reasoning step is the decision point: after reasoning over the evidence so
// far, the agent either FINISHES (enough) or issues another ACTION (retrieve more).
// The observation ALWAYS loops back into reasoning — it is not itself a branch.
// Interleaved reason/act (Yao et al. 2023).
// Build:  NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs figure/diagrams/architectures/react-agent/react-agent.fig.mjs

export default {
  name: 'react-agent',
  title: 'ReAct Agent',
  width: 1150,
  height: 820,

  nodes: [
    { id: 'answer', x: 340, y: 120, icon: 'doc-lines-success', color: 'green', label: 'Answer\n+ citations' },

    { id: 'query',  x: 60,  y: 380, icon: 'doc-envelope',      color: 'tan',   label: 'Query\n(criterion)' },
    { id: 'think',  x: 340, y: 380, icon: 'llm-agent-brain',   agent: true,    label: 'Thought:\nenough\nevidence?' },
    { id: 'act',    x: 620, y: 380, icon: 'llm-agent-brain',   agent: true,    label: 'Action:\ncall retrieval\ntool' },
    { id: 'rtool',  x: 900, y: 380, icon: 'code-tools',        color: 'green',  label: 'Retrieval\ntool' },

    { id: 'obs',    x: 620, y: 600, icon: 'doc-lines',         color: 'lilac',  label: 'Observation:\nretrieved\npassages' },
  ],

  edges: [
    { from: 'query', to: 'think', badge: 1 },

    // reasoning decides: NO -> act again (retrieve more);  YES -> finish (answer)
    { from: 'think', to: 'act',    fromSide: 'right', toSide: 'left', badge: 2, branch: 'no' },
    { from: 'think', to: 'answer', fromSide: 'top',   toSide: 'bottom', branch: 'yes' },

    { from: 'act',   to: 'rtool',  fromSide: 'right', toSide: 'left', badge: 3, label: 'call' },

    // tool returns passages as the observation
    { from: 'rtool', to: 'obs', fromSide: 'bottom', toSide: 'top', badge: 4, label: 'passages',
      path: [[975, 530], [975, 560], [695, 560], [695, 600]] },

    // observation ALWAYS feeds back into reasoning (unconditional — not a branch)
    { from: 'obs', to: 'think', fromSide: 'left', toSide: 'bottom', badge: 5, label: 'observe',
      path: [[620, 675], [415, 675], [415, 530]] },
  ],
};
