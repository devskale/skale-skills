# Rodney — Setup Guide

## What

Headless Chrome automation from the CLI. Scrape, screenshot, fill forms, export PDFs, accessibility audits, smoke tests.

## 1. Install rodney (per machine, once)

Build the Go binary from source (rodney is not on PyPI):

```bash
# Requires Go 1.21+ and Chrome or Chromium
git clone -b skale git@github.com:devskale/rodney.git
cd rodney
go build -o ~/.local/bin/rodney .
```

Verify: `rodney --version` → `0.6.x` (e.g. `0.6.1`).

Requires Chrome or Chromium.

## 2. Add the skill to your project

```bash
mkdir -p .pi/skills
git clone --depth 1 --filter=blob:none --sparse https://github.com/devskale/skale-skills.git /tmp/skale-skills
cd /tmp/skale-skills && git sparse-checkout set skills/rodney
cp -r skills/rodney .pi/skills/rodney
rm -rf /tmp/skale-skills
```

## 3. Verify

```bash
rodney start
rodney open https://example.com
rodney waitstable
rodney screenshot page.png
rodney stop
```

Done. Restart pi — the agent now has the rodney skill available.



