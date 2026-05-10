# Rodney Debugging Patterns

## Screenshot time-series

Take screenshots between steps to create a visual debug log:

```bash
rodney screenshot debug-01-landing.png
rodney click "#submit"
rodney waitstable
rodney screenshot debug-02-after-submit.png
```

Open the files to see exactly what Chrome rendered at each step.

## Visible Chrome

Watch Chrome navigate in real time with `--show`:

```bash
rodney start --show
```

Useful when screenshots aren't enough and you need to see transitions, animations, or flickering.

## Form validation checks

When a form won't submit, check HTML5 validity and find failing fields:

```bash
rodney js 'document.querySelector("form").checkValidity()'
rodney js 'Array.from(document.querySelectorAll("input:invalid")).map(el => el.name).join(", ")'
```

## Exit code chaining

Rodney returns 0=success, 1=assertion failed, 2=error. Chain with `&&`/`||`:

```bash
rodney exists "#dashboard" && echo "✅ loaded" || echo "❌ missing"
rodney visible ".loading" && echo "⏳ still loading" || echo "✅ done"
```

## Pull runtime state

Extract JS state that isn't visible in the DOM:

```bash
rodney js 'JSON.stringify({url: location.href, cookies: document.cookie, errors: window.__errors})'
```

## Debug dynamic content

For SPAs, the DOM may not match expectations. List all test IDs or data attributes:

```bash
rodney waitstable
rodney js 'Array.from(document.querySelectorAll("[data-testid]")).map(el => el.dataset.testid).join(", ")'
```
