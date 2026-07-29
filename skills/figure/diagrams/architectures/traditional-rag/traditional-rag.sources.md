# Traditional RAG diagram — source passages

Why `traditional-rag.fig.mjs` is drawn the way it is. P0 is the canonical **retrieve-then-read**
baseline: the original RAG architecture (Lewis et al. 2020) in its frozen-reader, single-pass
form (In-Context RALM, Ram et al. 2023). Each design choice is anchored to an exact sentence.

**Sources** (passages transcribed from the ar5iv HTML renderings):
- Patrick Lewis et al. (2020), *Retrieval-Augmented Generation for Knowledge-Intensive NLP
  Tasks*, arXiv:2005.11401 — <https://ar5iv.labs.arxiv.org/abs/2005.11401>
- Ori Ram et al. (2023), *In-Context Retrieval-Augmented Language Models*, arXiv:2302.00083 —
  <https://ar5iv.labs.arxiv.org/abs/2302.00083>

---

## The passages, and what each fixed in the figure

**1. A retriever returns top-K passages for the query; the generator conditions on them.**
> "a retriever pη(z|x) with parameters η that returns (top-K truncated) distributions over
> text passages given a query x" (Lewis, Section 2)

> "we use them as additional context when generating the target sequence y" (Lewis, Section 2)

→ The linear pipeline `Query → retrieve top-k → passages → LLM reader → answer`.

**2. The reader is conditioned on the query *and* the retrieved passage.**
> "the generator pθ(yi|x,z,y1:i−1) … generates a current token based on … the original input
> x and a retrieved passage z" (Lewis, Section 2)

→ This is why the reader has a second input: the dashed `+ query` edge feeds the original
query in alongside the passages (prompt = query + top-k), not passages alone.

**3. Retrieval is dense, over a vector index (DPR + FAISS).**
> "The retrieval component pη(z|x) is based on DPR. DPR follows a bi-encoder architecture"
> (Lewis, Section 2.2)

> "we build a single MIPS index using FAISS … for fast retrieval" (Lewis, Section 3)

→ The `Vector DB (tender index)` node = the dense embedding index the query is matched against.

**4. Single pass, frozen reader, documents prepended (the In-Context RALM form).**
> "leaving the LM architecture unchanged and prepending grounding documents to the input,
> without any further training of the LM" (Ram, Abstract)

> "In-Context RALM refers to the following specific, simple method of concatenating the
> retrieved documents within the Transformer's input prior to the prefix … which does not
> involve altering the LM weights θ" (Ram, Section 3.1)

→ The `LLM reader (frozen)` node, the `prepend` edge, and `read once` — no loop, no
re-retrieval, no training. This is exactly the P0 baseline.

---

## Caveat on the "Vector DB" label

Labelling the index "Vector DB" commits P0 to **dense** retrieval. That is faithful to Lewis
et al. (DPR + FAISS), but note that In-Context RALM found a sparse retriever competitive:

> "the sparse (lexical) BM25 retriever … outperformed three popular dense (neural)
> retrievers" (Ram, Section 5.1)

So if the retriever family is left open, the node can instead read "Retriever (tender index)".
