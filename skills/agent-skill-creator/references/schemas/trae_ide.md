# Agent: trae ide

## Source

- URL: https://docs.trae.ai/ide/skills?_lang=en

## Skill Package

- **Main Definition File**: `SKILL.md`
- **Container Structure**: Folder named `<skill_name>`
- **Required Files**:
  - SKILL.md
  - scripts (optional)
  - references (optional)

## Storage Locations

### User Level

- **Primary**: `.trae/skills/`
- **Secondary**:
  - N/A

### Project Level

- **Primary**: `.trae/skills/`
- **Secondary**:
  - N/A

## File Format

- **Type**: markdown
- **Frontmatter Fields**:
  | Field | Status | Description |
  |-------|--------|-------------|
  | name | Required | Name of the skill |
  | description | Required | Brief description of what the skill does and when to use it |