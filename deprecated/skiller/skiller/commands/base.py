"""Command registration primitives."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Callable, Optional


@dataclass(frozen=True)
class Command:
    """Represents a CLI command entry."""

    name: str
    help: str
    add_arguments: Callable[[argparse.ArgumentParser], None]
    run: Callable[[argparse.Namespace, dict], None]
    run_interactive: Optional[Callable[[dict], None]] = None
