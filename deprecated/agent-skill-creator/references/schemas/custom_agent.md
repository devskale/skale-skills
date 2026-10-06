# Agent: custom agent

## Source

- URL: https://agentskills.io/specification

## Skill Package

- **Main Definition File**: `SKILL.md`
- **Container Structure**: Folder named `<skill_name>`
- **Required Files**:
  - SKILL.md

## Storage Locations

### User Level

- **Primary**: `.agentskills/skills/`
- **Secondary**:
  - `~/.cache/agentskills/`
  - `~/Library/Caches/agentskills/` (macOS)

### Project Level

- **Primary**: `./.agentskills/skills/`
- **Secondary**:
  - `./.cache/agentskills/`
  - `./node_modules/.agentskills/skills/` (for Node.js projects)

## File Format

- **Type**: markdown
- **Frontmatter Fields**:
  | Field | Status | Description |
  |-------|--------|-------------|
  | name | Required | Max 64 characters. Lowercase letters, numbers, and hyphens only. Must not start or end with a hyphen. |
  | description | Required | Max 1024 characters. Non-empty. Describes what the skill does and when to use it. |
  | license | Optional | License name or reference to a bundled license file. |
  | compatibility | Optional | Max 500 characters. Indicates environment requirements (intended product, system packages, network access, etc.). |
  | metadata | Optional | Arbitrary key-value mapping for additional metadata. |
  | allowed-tools | Optional | Space-delimited list of pre-approved tools the skill may use. (Experimental) |