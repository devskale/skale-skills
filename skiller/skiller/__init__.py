# Package initializer for the skiller package
# Expose `main` at package level so the entry point `skiller = "skiller:main"` works.
from .cli import main

__all__ = ["main"]
