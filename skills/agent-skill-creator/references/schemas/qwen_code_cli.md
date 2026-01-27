# Agent: qwen code cli

## Source

- URL: https://qwenlm.github.io/qwen-code-docs/en/users/features/skills/

## Skill Package

- **Main Definition File**: `SKILL.md`
- **Container Structure**: Folder named `<skill_name>`
- **Required Files**:
  - `SKILL.md`

## Storage Locations

### User Level

- **Primary**: `~/.qwen/skills/`
- **Secondary**:
  - N/A

### Project Level

- **Primary**: `.qwen/skills/`
- **Secondary**:
  - N/A

## File Format

- **Type**: markdown
- **Frontmatter Fields**:
  | Field | Status | Description |
  |-------|--------|-------------|
  | name | Required | Non-empty string identifying the skill |
  | description | Required | Non-empty string describing what the skill does and when to use it |