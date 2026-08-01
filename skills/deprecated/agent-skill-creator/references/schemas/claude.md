# Agent: Claude (Anthropic)

## Source

- URL: https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview

## Skill Package

- **Main Definition File**: `SKILL.md`
- **Container Structure**: Folder named `<skill_name>`
- **Required Files**:
  - SKILL.md

## Storage Locations

### User Level

- `~/.claude/skills/<name>/SKILL.md`

### Project Level

- `.claude/skills/<name>/SKILL.md`

## File Format

- **Type**: markdown
- **Frontmatter Fields**:
  | Field | Status | Description |
  |-------|--------|-------------|
  | name | Required | Unique identifier for the skill |
  | description | Required | Brief description of what the skill does |
  | license | Optional | License information for the skill |
