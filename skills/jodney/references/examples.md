# Jodney Example Workflows

## Web Scraping

```bash
#!/usr/bin/env bash
set -euo pipefail

jodney start
jodney open https://news.ycombinator.com
jodney waitstable

titles=$(jodney js 'Array.from(document.querySelectorAll(".titleline > a")).map(a => a.textContent.trim()).join("\n")')
echo "$titles" | head -10

jodney stop
```

## Form Fill + Screenshot

```bash
#!/usr/bin/env bash
set -euo pipefail

jodney start
jodney open https://httpbin.org/forms/post

jodney input "input[name='custname']" "Jane Doe"
jodney input "input[name='custtel']" "+1-555-0123"
jodney input "input[name='custemail']" "jane@example.com"

jodney screenshot form-filled.png
jodney pdf form.pdf

jodney stop
```

## Smoke Test (CI/CD)

```bash
#!/usr/bin/env bash
set -euo pipefail

jodney start
jodney open "https://myapp.com"
jodney waitstable

jodney exists "h1"
jodney visible "#main-content"
jodney assert 'document.title' 'My App'

jodney stop
echo "✅ All checks passed"
```

## Accessibility Audit

```bash
#!/usr/bin/env bash
set -euo pipefail

jodney start
jodney open "https://myapp.com"
jodney waitstable

# Dump tree for manual review
jodney ax-tree --depth 3

# Find unnamed buttons (accessibility failure)
jodney ax-find --role button --json | python3 -c "
import json, sys
buttons = json.load(sys.stdin)
unnamed = [b for b in buttons if not b.get('name', {}).get('value')]
if unnamed:
    print(f'FAIL: {len(unnamed)} buttons missing accessible names')
    sys.exit(1)
print(f'PASS: all {len(buttons)} buttons have accessible names')
"

jodney stop
```
