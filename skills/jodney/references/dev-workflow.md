# Jodney Developer Workflow

Jodney's persistent session makes it ideal for local development: start Chrome once, reload between code changes, inspect results instantly.

## Start a dev session

```bash
jodney start --show              # Visible Chrome — watch alongside your editor
jodney open http://localhost:3000
jodney waitstable
```

## The dev loop

After each code change:

```bash
jodney reload && jodney waitstable
```

Then pick your inspection method:

```bash
jodney screenshot after-change.png    # See it
jodney text "h1"                      # Read it
jodney visible ".error"               # Assert it
```

One-liner for rapid feedback:

```bash
jodney reload && jodney waitstable && jodney visible "#success" && echo "✅" || echo "❌"
```

## Inspect page without screenshots

### What's on the page

```bash
jodney title                          # Page title
jodney url                            # Current URL
jodney text "body"                    # All visible text
jodney text "body" | head -50         # First 50 lines
```

### DOM structure

```bash
jodney html "main"                    # HTML of main element
jodney count "section"                # How many sections?
jodney attr ".logo" "src"             # Attribute value
```

### Semantic structure (accessibility tree)

Best for understanding layout without rendering:

```bash
jodney ax-tree --depth 3             # Semantic tree overview
jodney ax-tree --depth 5             # Deeper detail
jodney ax-tree --json                # Machine-readable
```

### Heading hierarchy

```bash
jodney js 'Array.from(document.querySelectorAll("h1,h2,h3,h4")).map(el => el.tagName + ": " + el.textContent.trim().slice(0,60)).join("\n")'
```

### Layout / bounding boxes

```bash
jodney js 'JSON.stringify(
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
jodney js 'document.body.innerText'   # Visible text only (respects CSS)
jodney js 'document.body.textContent' # All text including hidden
```

## Debug a failing page

```bash
jodney reload && jodney waitstable
jodney screenshot debug.png                        # What does it look like?
jodney visible ".error"                            # Any error banners?
jodney text ".error" 2>/dev/null || echo "no .error"
jodney js 'document.querySelector("form").checkValidity()'   # HTML5 validation?
jodney js 'Array.from(document.querySelectorAll("input:invalid")).map(el => el.name).join(", ")'
```

## Tips

- `--show` opens visible Chrome — use it during development, drop it for CI
- Session state persists across reloads: cookies, localStorage, scroll position
- `waitstable` is better than `waitload` for SPAs — waits for client-side renders to settle
- No need to restart jodney between reloads — one `start`, many `reload`s
