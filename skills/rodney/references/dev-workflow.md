# Rodney Developer Workflow

Rodney's persistent session makes it ideal for local development: start Chrome once, reload between code changes, inspect results instantly.

## Start a dev session

```bash
rodney start --show              # Visible Chrome — watch alongside your editor
rodney open http://localhost:3000
rodney waitstable
```

## The dev loop

After each code change:

```bash
rodney reload && rodney waitstable
```

Then pick your inspection method:

```bash
rodney screenshot after-change.png    # See it
rodney text "h1"                      # Read it
rodney visible ".error"               # Assert it
```

One-liner for rapid feedback:

```bash
rodney reload && rodney waitstable && rodney visible "#success" && echo "✅" || echo "❌"
```

## Inspect page without screenshots

### What's on the page

```bash
rodney title                          # Page title
rodney url                            # Current URL
rodney text "body"                    # All visible text
rodney text "body" | head -50         # First 50 lines
```

### DOM structure

```bash
rodney html "main"                    # HTML of main element
rodney count "section"                # How many sections?
rodney attr ".logo" "src"             # Attribute value
```

### Semantic structure (accessibility tree)

Best for understanding layout without rendering:

```bash
rodney ax-tree --depth 3             # Semantic tree overview
rodney ax-tree --depth 5             # Deeper detail
rodney ax-tree --json                # Machine-readable
```

### Heading hierarchy

```bash
rodney js 'Array.from(document.querySelectorAll("h1,h2,h3,h4")).map(el => el.tagName + ": " + el.textContent.trim().slice(0,60)).join("\n")'
```

### Layout / bounding boxes

```bash
rodney js 'JSON.stringify(
  Array.from(document.querySelectorAll("section, header, main, footer, nav")).map(el => ({
    tag: el.tagName,
    id: el.id,
    classes: el.className,
    children: el.children.length,
    rect: el.getBoundingClientRect()
  }))
)'
```

### Visible vs hidden text

```bash
rodney js 'document.body.innerText'   # Visible text only (respects CSS)
rodney js 'document.body.textContent' # All text including hidden
```

## Debug a failing page

```bash
rodney reload && rodney waitstable
rodney screenshot debug.png                        # What does it look like?
rodney visible ".error"                            # Any error banners?
rodney text ".error" 2>/dev/null || echo "no .error"
rodney js 'document.querySelector("form").checkValidity()'   # HTML5 validation?
rodney js 'Array.from(document.querySelectorAll("input:invalid")).map(el => el.name).join(", ")'
```

## Tips

- `--show` opens visible Chrome — use it during development, drop it for CI
- Session state persists across reloads: cookies, localStorage, scroll position
- `waitstable` is better than `waitload` for SPAs — waits for client-side renders to settle
- No need to restart rodney between reloads — one `start`, many `reload`s
