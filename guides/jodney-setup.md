# Jodney — Setup Guide

## What

Headless Chrome automation from the CLI. Scrape, screenshot, fill forms, export PDFs, accessibility audits, smoke tests.

## 1. Install jodney (per machine, once)

```bash
uv tool install jodney
```

Requires Chrome or Chromium.

## 2. Add the skill to your project

```bash
mkdir -p .pi/skills
git clone --depth 1 --filter=blob:none --sparse https://github.com/devskale/skale-skills.git /tmp/skale-skills
cd /tmp/skale-skills && git sparse-checkout set skills/jodney
cp -r skills/jodney .pi/skills/jodney
rm -rf /tmp/skale-skills
```

## 3. Verify

```bash
jodney start
jodney open https://example.com
jodney waitstable
jodney screenshot page.png
jodney stop
```

Done. Restart pi — the agent now has the jodney skill available.



