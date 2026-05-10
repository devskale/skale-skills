# Rodney Example Workflows

## Web Scraping

```bash
#!/usr/bin/env bash
set -euo pipefail

rodney start
rodney open https://news.ycombinator.com
rodney waitstable

titles=$(rodney js 'Array.from(document.querySelectorAll(".titleline > a")).map(a => a.textContent.trim()).join("\n")')
echo "$titles" | head -10

rodney stop
```

## Form Fill + Screenshot

```bash
#!/usr/bin/env bash
set -euo pipefail

rodney start
rodney open https://httpbin.org/forms/post

rodney input "input[name='custname']" "Jane Doe"
rodney input "input[name='custtel']" "+1-555-0123"
rodney input "input[name='custemail']" "jane@example.com"

rodney screenshot form-filled.png
rodney pdf form.pdf

rodney stop
```

## Smoke Test (CI/CD)

```bash
#!/usr/bin/env bash
set -euo pipefail

rodney start
rodney open "https://myapp.com"
rodney waitstable

rodney exists "h1"
rodney visible "#main-content"
rodney assert 'document.title' 'My App'

rodney stop
echo "✅ All checks passed"
```

## Accessibility Audit

```bash
#!/usr/bin/env bash
set -euo pipefail

rodney start
rodney open "https://myapp.com"
rodney waitstable

# Dump tree for manual review
rodney ax-tree --depth 3

# Find unnamed buttons (accessibility failure)
rodney ax-find --role button --json | python3 -c "
import json, sys
buttons = json.load(sys.stdin)
unnamed = [b for b in buttons if not b.get('name', {}).get('value')]
if unnamed:
    print(f'FAIL: {len(unnamed)} buttons missing accessible names')
    sys.exit(1)
print(f'PASS: all {len(buttons)} buttons have accessible names')
"

rodney stop
```
