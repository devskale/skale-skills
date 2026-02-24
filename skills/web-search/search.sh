#!/bin/bash

# Ensure we're in the skill directory
cd "$(dirname "$0")"

# Detect OS and activate virtual environment accordingly
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    # Windows (Git Bash, MSYS2, Cygwin)
    if [ -f ".venv/Scripts/activate" ]; then
        source .venv/Scripts/activate
    else
        echo "Error: Virtual environment not found. Please run install.sh first."
        exit 1
    fi
else
    # Linux/Mac
    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    else
        echo "Error: Virtual environment not found. Please run install.sh first."
        exit 1
    fi
fi

# Run the search script
python scripts/search.py "$@"
