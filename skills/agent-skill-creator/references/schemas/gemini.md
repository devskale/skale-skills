# Agent: gemini

## Source

- URL: https://geminicli.com/docs/cli/skills/

## Skill Package

- **Main Definition File**: `SKILL.md`
- **Container Structure**: Folder named `<skill_name>`
- **Required Files**:
  - SKILL.md

## Storage Locations

### User Level

- **Primary**: `~/.gemini/skills/`
- **Secondary**:
  - N/A

### Project Level

- **Primary**: `.gemini/skills/`
- **Secondary**:
  - N/A

## File Format

- **Type**: markdown
- **Frontmatter Fields**:
  | Field | Status | Description |
  |-------|--------|-------------|
  | name | Required | A unique identifier (lowercase, alphanumeric, and dashes) |
  | description | Required | The most critical field. Gemini uses this to decide when the skill is relevant. Be specific about the expertise provided. |