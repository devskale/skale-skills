# Rodney — Setup Guide

## What

Headless Chrome automation from the CLI. Scrape, screenshot, fill forms, export PDFs, accessibility audits, smoke tests.

## Install

```bash
uv tool install rodney
```

Requires Chrome or Chromium.

## Verify

```bash
rodney start && rodney stop
```

## Add to a Pi Project

```bash
# In your project root
mkdir -p .pi/skills
ln -s /Users/johannwaldherr/code/skale-skills/skills/rodney .pi/skills/rodney
```

Done. Restart pi and the agent will have the rodney skill available.

## Quick Test

```bash
rodney start
rodney open https://example.com
rodney waitstable
rodney screenshot page.png
rodney stop
```

## Skill Source

- **Skill:** `/Users/johannwaldherr/code/skale-skills/skills/rodney/`
- **Repo:** https://github.com/nicobailon/rodney
- **Docs:** See `SKILL.md` and `references/` in the skill directory
