"""Command registry for skiller."""

from __future__ import annotations

from skiller.commands.base import Command
from skiller.commands.discovery import command as discovery_command
from skiller.commands.install import command as install_command
from skiller.commands.list_cmd import command as list_command

COMMANDS: list[Command] = [
    discovery_command,
    list_command,
    install_command,
]

COMMAND_MAP = {command.name: command for command in COMMANDS}
