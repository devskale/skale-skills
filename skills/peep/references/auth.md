# Auth Details

## Browser Cookie Sources

### Firefox
```bash
peep --firefox-profile default-release whoami
```
- Default profile: `default-release`

### Chrome
```bash
peep --chrome-profile Default whoami
peep --chrome-profile "Profile 2" whoami
```
- Default profile: `Profile 2`

### Chromium (Brave, Arc, etc.)
```bash
peep --chrome-profile-dir "/path/to/Chromium/Profile" whoami
peep --chrome-profile-dir "/path/to/Arc/User Data/Default" whoami
```

### Safari
```bash
peep --cookie-source safari whoami
```

### Multiple Sources
```bash
peep --cookie-source firefox --cookie-source chrome whoami
```

## Manual Tokens

```bash
peep --auth-token <token> --ct0 <token> whoami
```

Or via environment variables:
- `AUTH_TOKEN` or `TWITTER_AUTH_TOKEN`
- `CT0` or `TWITTER_CT0`

## Timeout Options

```bash
peep --cookie-timeout 60000 whoami   # 60s for cookie extraction
peep --timeout 30000 whoami          # 30s for requests
```

## Config File

`~/.config/peep/config.json5`:
```json5
{
  cookieSource: ["firefox", "safari"],
  chromeProfileDir: "/path/to/Chromium/Profile",
  firefoxProfile: "default-release",
  cookieTimeoutMs: 30000,
  timeoutMs: 20000,
  quoteDepth: 1
}
```
