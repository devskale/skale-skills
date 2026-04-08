# Pagination

## Options

| Option | Description |
|--------|-------------|
| `--all` | Fetch all results (enables pagination) |
| `--max-pages <n>` | Stop after N pages |
| `--cursor <string>` | Resume from a previous cursor |
| `--delay <ms>` | Delay between pages (rate limiting) |

## Commands with Pagination

### Requires `--all`
- `peep search <query> --all --max-pages 5`
- `peep bookmarks --all`
- `peep likes --all`
- `peep following --all`
- `peep followers --all`
- `peep list-timeline <id> --all`
- `peep replies <id> --all`
- `peep thread <id> --all`

### Standalone `--max-pages`
- `peep user-tweets <handle> --max-pages 3` (max: 10)

## Resume from Cursor

After pagination, JSON output includes `nextCursor`:
```json
{
  "tweets": [...],
  "nextCursor": "DAABCgFDA..."
}
```

Resume with:
```bash
peep search "query" --cursor "DAABCgFDA..."
```

## Rate Limiting

Add delay between pages:
```bash
peep user-tweets <handle> --delay 1000   # 1s delay
peep bookmarks --all --delay 1000
```
