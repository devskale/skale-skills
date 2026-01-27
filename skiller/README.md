# Skiller

Helper script to discover, install and manage skills for AI agents.

## Setup

1. Ensure you have `uv` installed. If not, install it from https://pypi.org/project/uv/

2. Navigate to the `skilllib/skiller` directory.

3. Create a virtual environment using uv:

   ```bash
   uv venv
   ```

4. Activate the virtual environment:

   ```bash
   source .venv/bin/activate  # On Unix/macOS
   # or on Windows: .venv\Scripts\activate
   ```

5. Install the package in editable mode:

   ```bash
   uv pip install -e .
   ```

6. Run the script:

   ```bash
   skiller
   ```

   Running without arguments displays the help message.

## Usage

- `skiller` : Show help message (default behavior)
- `skiller --list` : List all installed skills (not implemented yet)
- `skiller --dd <dir>` : Discovery: look for known agents dirs in `<dir>` and list potential skills (not implemented yet)
- `skiller --install` : Launch the install prompt to copy a discovered skill into one or more configured agent paths

## Development

To modify the script, edit `skiller.py` and reinstall if needed:

```bash
uv pip install -e .
```
