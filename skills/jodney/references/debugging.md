# Jodney Debugging Patterns

## Screenshot time-series

Take screenshots between steps to create a visual debug log:

```bash
jodney screenshot debug-01-landing.png
jodney click "#submit"
jodney waitstable
jodney screenshot debug-02-after-submit.png
```

Open the files to see exactly what Chrome rendered at each step.

## Visible Chrome

Watch Chrome navigate in real time with `--show`:

```bash
jodney start --show
```

Useful when screenshots aren't enough and you need to see transitions, animations, or flickering.

## Form validation checks

When a form won't submit, check HTML5 validity and find failing fields:

```bash
jodney js 'document.querySelector("form").checkValidity()'
jodney js 'Array.from(document.querySelectorAll("input:invalid")).map(el => el.name).join(", ")'
```

## Exit code chaining

Jodney returns 0=success, 1=assertion failed, 2=error. Chain with `&&`/`||`:

```bash
jodney exists "#dashboard" && echo "✅ loaded" || echo "❌ missing"
jodney visible ".loading" && echo "⏳ still loading" || echo "✅ done"
```

## Pull runtime state

Extract JS state that isn't visible in the DOM:

```bash
jodney js 'JSON.stringify({url: location.href, cookies: document.cookie, errors: window.__errors})'
```

## Debug dynamic content

For SPAs, the DOM may not match expectations. List all test IDs or data attributes:

```bash
jodney waitstable
jodney js 'Array.from(document.querySelectorAll("[data-testid]")).map(el => el.dataset.testid).join(", ")'
```
