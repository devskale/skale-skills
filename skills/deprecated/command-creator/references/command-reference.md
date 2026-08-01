# OpenCode Command Reference

## Full Frontmatter Options

```yaml
---
description: [Required] Brief description shown in TUI
agent: [Optional] Agent name (defaults to current agent)
model: [Optional] Model override (e.g., anthropic/claude-3-5-sonnet-20241022)
subtask: [Optional] true/false - force subagent invocation
---
[Required] Prompt template for the command
```

## Complete Example

`.opencode/commands/review-pr.md`:
```yaml
---
description: Review pull request changes
agent: review
model: anthropic/claude-3-5-sonnet-20241022
---
Review the following PR changes:

Recent commits:
!`git log --oneline -10`

Changed files:
!`git diff --name-only HEAD~1`

Review content:
@!`git diff HEAD~1`

Provide feedback on code quality, potential issues, and suggestions.
```

## Argument Patterns

### Single Argument
```yaml
---
description: Generate component
---
Create $ARGUMENTS component with proper structure.
```
Usage: `/generate ComponentName`

### Multiple Arguments
```yaml
---
description: Create file
---
Create file $1 in $2 with content:
$3
```
Usage: `/create config.json src '{"key": "value"}'`

## Shell Command Examples

### Git Operations
```yaml
---
description: Show uncommitted changes
---
!`git status`
!`git diff --cached`
Analyze these changes.
```

### Package Operations
```yaml
---
description: Check dependencies
---
!`npm outdated`
!`npm audit --audit-level=high`
Suggest updates for vulnerabilities.
```

### File Operations
```yaml
---
description: List large files
---
!`find . -type f -size +1M | head -20`
Which files should be optimized or removed?
```

## File Reference Patterns

### Single File
```yaml
---
description: Review configuration
---
Review @.env.example for security issues.
```

### Multiple Files
```yaml
---
description: Compare configs
---
Compare @config/development.json and @config/production.json
for configuration drift.
```

### Shell Output with File Reference
```yaml
---
description: Analyze test failures
---
Test output:
!`npm test -- --reporter=json`

Failed tests:
@test-results/failures.json

Suggest fixes for these failures.
```

## Command Override Warning

Custom commands override built-ins. These built-in commands can be overridden:

- `/init` - Initialize project
- `/undo` - Undo last action
- `/redo` - Redo last action
- `/share` - Share session
- `/help` - Show help

If you need similar functionality, use a different name like `/review-help` instead of `/help`.

## Configuration Priority

1. Project-level `.opencode/commands/*.md` (highest priority)
2. Global `~/.config/opencode/commands/*.md`
3. `opencode.jsonc` command config

Commands defined in multiple locations use the highest priority location.
