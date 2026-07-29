// Example figure spec — an Agentic-RAG flow assembled from the CC0 icon set.
// Build:  NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs
// Edit the numbers, rebuild, and the SVG + PNG regenerate identically every time.

export default {
  name: 'agentic-rag',
  title: 'Agentic RAG',
  width: 1280,
  height: 760,

  nodes: [
    // top row: the query-refinement loop
    { id: 'query',   x: 60,  y: 110, icon: 'doc-envelope',   color: 'tan',   label: 'Query' },
    { id: 'rewrite', x: 300, y: 110, icon: 'llm-agent-brain', agent: true,   label: 'Rewrite the\ninitial query' },
    { id: 'updated', x: 540, y: 110, icon: 'doc-envelope',   color: 'lilac', label: 'Updated query' },
    { id: 'need',    x: 780, y: 110, icon: 'llm-agent-brain', agent: true,   label: 'Need more\ndetails?' },
    { id: 'source',  x: 1050, y: 110, icon: 'llm-agent-brain', agent: true,  label: 'Which source\nwill help?' },

    // sources cluster (right / lower)
    { id: 'db',    x: 1050, y: 360, w: 130, h: 130, icon: 'vector-db-cylinder', color: 'tan', label: 'Vector DB' },
    { id: 'tools', x: 1050, y: 540, w: 130, h: 130, icon: 'code-tools',         color: 'green', label: 'Tools & APIs' },
    { id: 'web',   x: 880,  y: 540, w: 130, h: 130, icon: 'globe-internet',     color: 'blue',  label: 'Internet' },

    // generation path (lower, right-to-left)
    { id: 'ctx',  x: 620, y: 360, icon: 'doc-lines',         color: 'lilac', label: 'Retrieved\ncontext' },
    { id: 'llm',  x: 360, y: 360, icon: 'llm-brain',         color: 'amber', label: 'LLM' },
    { id: 'resp', x: 60,  y: 360, icon: 'doc-lines-success', color: 'green', label: 'Final\nresponse' },
  ],

  edges: [
    { from: 'query',   to: 'rewrite', badge: 1 },
    { from: 'rewrite', to: 'updated', badge: 2 },
    { from: 'updated', to: 'need',    badge: 3 },
    { from: 'need',    to: 'source',  badge: 4, branch: 'yes' },
    // NO -> route down and left to generate with the current context.
    // Badges/labels are auto-placed in clear space; only the routing is authored.
    { from: 'need', to: 'llm', fromSide: 'bottom', toSide: 'top',
      path: [[855, 260], [855, 300], [435, 300], [435, 360]],
      badge: 12, branch: 'no', label: 'Prompt', labelT: 0.95 },

    { from: 'source', to: 'db', badge: 5 },
    { from: 'db', to: 'ctx', fromSide: 'left', toSide: 'right', badge: 6,
      path: [[1050, 425], [770, 425]] },
    { from: 'web', to: 'ctx', fromSide: 'top', toSide: 'bottom', badge: 7,
      path: [[945, 540], [945, 460], [690, 460], [690, 500]] },

    { from: 'ctx', to: 'llm', badge: 8, label: 'Prompt' },
    { from: 'llm', to: 'resp', badge: 9 },
  ],
};
