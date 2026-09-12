# Verify — screenshots + axe-core

> Load at workflow step 5. Nothing is "done" until verified.

## Screenshot loop (rodney — headless Chrome)

```bash
rodney status >/dev/null 2>&1 || rodney start
rodney open file:///abs/path/to/page.html      # or http://localhost:3000/page
rodney waitstable
rodney screenshot -w 1280 -h 900 before.png
# ...apply the change...
rodney reload --hard && rodney waitstable
rodney screenshot -w 1280 -h 900 after.png
rodney stop                                     # ALWAYS stop when done
```

View both screenshots — the intended change should be visible and **nothing
else should have moved**.

## axe-core (a11y gate — needs network, loads from CDN)

```bash
rodney js "(async()=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/axe-core@4/axe.min.js';document.head.appendChild(s);await new Promise(r=>s.onload=r);const r=await axe.run({});return JSON.stringify(r.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length,help:v.help})))})()" | python3 -m json.tool
```

**Gate:** zero violations with `impact` `serious`/`critical` before a pass is
done. Record remaining `moderate`/`minor` items in the findings ledger.

## No rodney available?

Ask the user to eyeball the before/after, or use any headless browser — but
never skip the axe check silently; say so and mark the pass unverified in the
ledger.
