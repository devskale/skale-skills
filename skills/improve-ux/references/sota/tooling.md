# Tooling SOTA — automated a11y verification

> Load when choosing how to verify accessibility.

Pair manual review with automation to catch concrete failures:

- **axe-core** — precise, rule-based WCAG checks; the standard for CI gating.
  <https://github.com/dequelabs/axe-core>
- **Lighthouse** — holistic score, but a 100 a11y score does NOT prove WCAG
  conformance (it's a weighted subset of axe rules). Don't gate on it alone.
  <https://www.wcag-audit.org/automated-accessibility-dynamic-content-ingestion/scanner-tool-selection-and-benchmarking/axe-core-vs-lighthouse-for-ci-accessibility/>

Ready-to-run commands (rodney + axe-core): [../verify.md](../verify.md).
