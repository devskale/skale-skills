// P0 — Traditional (baseline) retrieve-then-read RAG.
// Embed the criterion query, retrieve top-k passages in ONE pass, and read once.
// The reader's prompt = query + retrieved passages (no reasoning loop, no re-retrieval).
// Build:  NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs figure/diagrams/architectures/traditional-rag/traditional-rag.fig.mjs

export default {
  name: 'traditional-rag',
  title: 'Traditional RAG',
  width: 1280,
  height: 540,

  nodes: [
    { id: 'query',  x: 60,   y: 150, icon: 'doc-envelope',      color: 'tan',   label: 'Query\n(criterion)' },
    { id: 'db',     x: 310,  y: 150, icon: 'vector-db-cylinder', color: 'tan',   label: 'Vector DB\n(tender index)' },
    { id: 'ctx',    x: 560,  y: 150, icon: 'doc-lines',          color: 'lilac', label: 'Top-k\npassages' },
    { id: 'llm',    x: 810,  y: 150, icon: 'llm-brain',          color: 'amber', label: 'LLM reader\n(frozen)' },
    { id: 'answer', x: 1060, y: 150, icon: 'doc-lines-success',  color: 'green', label: 'Judgement\n+ citations' },
  ],

  edges: [
    { from: 'query', to: 'db',     badge: 1, label: 'embed +\nretrieve' },
    { from: 'db',    to: 'ctx',    badge: 2, label: 'top-k' },
    { from: 'ctx',   to: 'llm',    badge: 3, label: 'prepend' },
    { from: 'llm',   to: 'answer', badge: 4, label: 'read once' },

    // the reader is prompted with the ORIGINAL query alongside the passages
    { from: 'query', to: 'llm', fromSide: 'bottom', toSide: 'bottom', label: '+ query', labelT: 0.5,
      path: [[135, 300], [135, 400], [885, 400], [885, 300]] },
  ],
};
