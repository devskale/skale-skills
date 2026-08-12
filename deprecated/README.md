# Deprecated tools

Retired components kept for reference and archaeology. Nothing here is installed,
built, or loaded by the package. Each entry carries its own note on why it was retired
and what replaced it.

| Tool | Was | Replaced by |
|------|-----|-------------|
| [`skiller/`](skiller/) | Cross-agent skill installer CLI (`install`/`remove`/`list`/`discovery`) | `openskills`, `npx @anthropic-ai/skills add`, `skills.sh` |

## Why skiller was retired

`skiller` was a Python CLI that installed **our own** skills into every agent's skill
folder at once (pi, claude, opencode, qwen, gemini, codex, trae). Its original
crawler/search feature was already retired in June 2026; the remaining multi-agent
install niche is now served by the ecosystem's standard tools:

```bash
openskills install <org>/<repo>       # multi-agent skill installer
npx @anthropic-ai/skills add <name>   # Anthropic skills
# browse/discover: https://skills.sh
```

`skiller` was not installed anywhere on the machine, had no tests or CI, and had seen
no active development since its own retire-crawler refactor. Rather than ship a
third parallel install path, it is deprecated in favor of the ecosystem tools the docs
already recommend.
