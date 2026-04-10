# Initial Setup

## After Installation

After installing peep, create a default configuration file with these settings:

### Create Config File

```bash
# Create config directory
mkdir -p ~/.config/peep

# Create config.json5 with default settings
cat > ~/.config/peep/config.json5 << 'EOF'
{
  // USER SETTINGS: Set your browser preferences below
  // Find your Chrome profiles: ls -la ~/Library/Application\ Support/Google/Chrome/ (macOS)
  //                            ls -la ~/.config/google-chrome/ (Linux)
  //                            ls -la "%LOCALAPPDATA%\\Google\\Chrome\\User Data\\" (Windows)
  // Find your Firefox profiles: ls -la ~/Library/Application\ Support/Firefox/Profiles/ (macOS)

  // Cookie sources to try (in order): "chrome", "firefox", "safari"
  cookieSource: ["chrome"],

  // Chrome profile for cookie extraction (change to your profile name)
  chromeProfile: "Profile 2",

  // Firefox profile for cookie extraction (change to your profile name)
  firefoxProfile: "default-release",

  // Cookie extraction timeout (milliseconds)
  cookieTimeoutMs: 30000,

  // Request timeout (milliseconds)
  timeoutMs: 20000,

  // Max quoted tweet depth
  quoteDepth: 1,
}
EOF
```

## Find Your Browser Profiles

### Chrome Profiles

**macOS:**
```bash
ls -la ~/Library/Application\ Support/Google/Chrome/
```

**Linux:**
```bash
ls -la ~/.config/google-chrome/
```

**Windows (PowerShell):**
```powershell
ls "$env:LOCALAPPDATA\Google\Chrome\User Data\"
```

**Common Chrome profile names:**
- `Default`
- `Profile 1`, `Profile 2`, `Profile 3`, etc.

### Firefox Profiles

**macOS:**
```bash
ls -la ~/Library/Application\ Support/Firefox/Profiles/
```

**Linux:**
```bash
ls -la ~/.mozilla/firefox/
```

**Windows:**
```powershell
ls "$env:APPDATA\Mozilla\Firefox\Profiles\"
```

**Common Firefox profile names:**
- `default-release` (macOS/Linux)
- `default-release-x` or `xxxxxxxx.default-release` (with random suffix)

## Configuration Settings Reference

| Setting | Description | Default |
|----------|-------------|----------|
| `cookieSource` | Array of cookie sources to try (order matters) | `["chrome"]` |
| `chromeProfile` | Chrome profile name | `"Profile 2"` |
| `firefoxProfile` | Firefox profile name | `"default-release"` |
| `cookieTimeoutMs` | Cookie extraction timeout in milliseconds | `30000` |
| `timeoutMs` | API request timeout in milliseconds | `20000` |
| `quoteDepth` | Maximum quoted tweet depth | `1` |

## Cookie Source Options

Available cookie sources (use in `cookieSource` array):
- `"chrome"` - Google Chrome
- `"firefox"` - Mozilla Firefox
- `"safari"` - Safari (macOS only, may have permission issues)

**Multiple sources example:**
```json5
{
  cookieSource: ["chrome", "firefox", "safari"],
}
```

## Troubleshooting Config Issues

### Config File Not Found
If peep shows "config file not found":
```bash
# Create the config directory
mkdir -p ~/.config/peep

# Verify config exists
cat ~/.config/peep/config.json5
```

### Wrong Profile Name
If cookie extraction fails:
1. List your Chrome/Firefox profiles
2. Update the `chromeProfile` or `firefoxProfile` setting
3. Test with: `peep whoami`

### Permission Issues (Safari on macOS)
If you see "Failed to read Safari cookies":
- Use `"chrome"` or `"firefox"` instead in `cookieSource`
- Safari cookies may be protected by macOS permissions

### Syntax Errors in Config
If you see JSON parsing errors:
1. Verify JSON5 syntax (comments, trailing commas are allowed)
2. Use a JSON5 validator if needed
3. Test config with: `peep check`

## Verify Setup

Test your configuration:
```bash
# Check credentials are available
peep check

# Verify logged-in account
peep whoami
```

Expected output:
```
📍 Chrome profile "Profile 2"
🙋 @username
🪪 1234567890
⚙️ graphql
🔑 Chrome profile "Profile 2"
```
