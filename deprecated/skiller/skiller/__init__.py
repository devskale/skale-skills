# Package initializer for skiller package
# Expose `main` at package level so that entry point `skiller = "skiller:main"` works.
from .cli import main
from .config import ConfigValidationError, validate_config, validate_config_or_exit

__all__ = ["main", "ConfigValidationError", "validate_config", "validate_config_or_exit"]
