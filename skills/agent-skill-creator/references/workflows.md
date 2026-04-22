# Workflow Patterns

## Sequential Workflows

For complex tasks, break operations into clear, sequential steps. It is often helpful to give the agent an overview of the process towards the beginning of SKILL.md:

```markdown
Filling a PDF form involves these steps:

1. Analyze the form (run analyze_form.py)
2. Create field mapping (edit fields.json)
3. Validate mapping (run validate_fields.py)
4. Fill the form (run fill_form.py)
5. Verify output (run verify_output.py)
```

## Install Scripts and CLI Wrappers

Skills with Python scripts often need an `install.sh` that sets up dependencies (via `uv`) and creates a global CLI wrapper in `~/.local/bin/`. Follow these conventions to avoid common pitfalls.

### Required Structure

```
skill-name/
├── SKILL.md
├── install.sh          # Sets up deps + creates global wrapper
├── pyproject.toml      # Python deps (managed by uv)
└── scripts/
    └── my_script.py    # Actual entry point
```

### install.sh Pattern

The wrapper must resolve paths relative to the **skill directory**, not the caller's cwd. Use this proven pattern:

```bash
#!/bin/bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing <skill-name> skill..."

# Ensure uv is available
if ! command -v uv &> /dev/null; then
    echo "  uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Sync dependencies from pyproject.toml
echo "  Syncing dependencies..."
uv sync

# Create global CLI wrapper in ~/.local/bin
# IMPORTANT: The wrapper must cd into the skill directory so
# relative paths (scripts/*.py) resolve correctly regardless
# of the caller's working directory.
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/<command-name>" << EOF
#!/usr/bin/env bash
cd "$SKILL_DIR" && exec uv run scripts/my_script.py "\$@"
EOF
chmod +x "$BIN_DIR/<command-name>"

echo "✓ Installation complete!"
```

### Key Rules

1. **Always `cd` into the skill directory in the wrapper** — The wrapper runs from whatever directory the user is in. Relative paths like `scripts/my_script.py` will fail unless you `cd "$SKILL_DIR"` first.

2. **Use `exec uv run`** — Always use `uv run` to execute scripts. This ensures the script runs in the skill's virtual environment with the correct dependencies, regardless of the user's global Python setup.

3. **Don't use symlinks without `readlink -f`** — A bare symlink (`ln -s skill-dir/script ~/.local/bin/cmd`) works, but only if the script itself resolves its directory correctly via `readlink -f "$0"`. The `cd` pattern above is simpler and more portable (works on macOS where `readlink -f` may not exist).

4. **Set `requires-python` correctly in pyproject.toml** — Must be `>=3.9` or higher if any dependency requires it. A too-low value (e.g. `>=3.8`) causes `uv sync` to fail when dependencies need 3.9+.

5. **Always use `uv`, never `pip`** — All dependency management goes through `uv`. Never instruct users to `pip install` anything.

### Anti-Patterns (Avoid These)

```bash
# ❌ BROKEN: Relative path, fails from any directory except skill dir
exec "$SCRIPT_DIR/my_script.py" "$@"

# ❌ BROKEN: Symlink without readlink resolution
ln -sf "$SKILL_DIR/scripts/my_script.py" "$BIN_DIR/my_command"

# ❌ BROKEN: No cd, relative paths won't resolve
cat > "$BIN_DIR/my_command" << EOF
#!/usr/bin/env bash
exec uv run scripts/my_script.py "\$@"
EOF

# ❌ FRAGILE: Assumes macOS readlink -f exists
SCRIPT="$(readlink -f "$0")"

# ❌ WRONG: Too-low Python version requirement
requires-python = ">=3.8"  # credgoo and many modern packages need >=3.9
```

### Verification

After installation, always test the wrapper from an unrelated directory:

```bash
cd /tmp && <command-name> "test query" -v
```

If this fails, the wrapper path resolution is broken.

## Conditional Workflows

For tasks with branching logic, guide the agent through decision points:

```markdown
1. Determine the modification type:
   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow: [steps]
3. Editing workflow: [steps]
```
