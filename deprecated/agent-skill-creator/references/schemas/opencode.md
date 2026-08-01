# Agent: opencode

## Source

- URL: https://opencode.ai/docs/skills/

## Skill Package

- **Main Definition File**: `SKILL.md`
- **Container Structure**: Folder named `<skill_name>`
- **Required Files**:
  - SKILL.md

## Storage Locations

### User Level

- **Primary**: `~/.config/opencode/skill/<name>/SKILL.md`
- **Secondary**:
  - `~/.claude/skills/<name>/SKILL.md`

### Project Level

- **Primary**: `.opencode/skill/<name>/SKILL.md`
- **Secondary**:
  - `.claude/skills/<name>/SKILL.md`

## File Format

- **Type**: markdown
- **Frontmatter Fields**:
  | Field | Status | Description |
  |-------|--------|-------------|
  | name | Required | Unique identifier for the skill |
  | description | Required | Brief description of what the skill does |
  | license | Optional | License information for the skill |
  | compatibility | Optional | Compatibility information (e.g., 'opencode') |
  | metadata | Optional | String-to-string map of additional metadata |