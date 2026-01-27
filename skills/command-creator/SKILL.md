---
name: command-creator
description: Create custom OpenCode commands for repetitive tasks. Define command prompts, arguments, shell output injection, file references, and configure agents, models, and descriptions.
license: MIT
compatibility: opencode
metadata:
  version: "1.0.0"
---

# Command Creator

Create custom OpenCode commands to automate repetitive tasks. Custom commands let you define prompts that run when you type `/command-name` in the TUI.

## Quick Start

Create a markdown file in `.opencode/commands/` or configure via `opencode.jsonc`:

**Markdown format** (`.opencode/commands/test.md`):
```yaml
---
description: Run tests with coverage
agent: build
model: anthropic/claude-3-5-sonnet-20241022
---
Run the full test suite with coverage report and show any failures.
```

**JSON format** (`opencode.jsonc`):
```json
{
  "command": {
    "test": {
      "template": "Run the full test suite with coverage report and show any failures.",
      "description": "Run tests with coverage",
      "agent": "build",
      "model": "anthropic/claude-3-5-sonnet-20241022"
    }
  }
}
```

## Command Locations

| Scope | Path |
|-------|------|
| Global | `~/.config/opencode/commands/` |
| Project | `.opencode/commands/` |

## Arguments

Pass dynamic values using placeholders:

| Placeholder | Description |
|-------------|-------------|
| `$ARGUMENTS` | All arguments passed to command |
| `$1`, `$2`, `$3` | Individual positional arguments |

Example:
```yaml
---
description: Create a component
---
Create a React component named $ARGUMENTS with TypeScript.
```

Usage: `/create-component Button`

## Shell Output Injection

Use backticks to inject bash command output:

```yaml
---
description: Analyze coverage
---
Current test results:
!`npm test`
Suggest improvements based on these results.
```

## File References

Include file contents using `@`:

```yaml
---
description: Review component
---
Review @src/components/Button.tsx for performance issues.
```

## Options Reference

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `template` | string | Yes | Prompt sent to LLM |
| `description` | string | Yes | Shown in TUI command list |
| `agent` | string | No | Agent to use (defaults to current) |
| `subtask` | boolean | No | Force subagent invocation |
| `model` | string | No | Override default model |

## Built-in Commands

OpenCode includes: `/init`, `/undo`, `/redo`, `/share`, `/help`. Custom commands with the same name override built-ins.

## Best Practices

1. Use descriptive names that don't conflict with built-ins
2. Keep prompts focused and specific
3. Use arguments for reusable commands
4. Leverage shell output for dynamic context
5. Include file references for context-aware commands
