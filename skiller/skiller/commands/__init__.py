"""Command registry for skiller."""

from __future__ import annotations

from skiller.commands.base import Command
from skiller.commands.discovery import command as discovery_command
from skiller.commands.install import command as install_command
from skiller.commands.list_cmd import command as list_command
from skiller.commands.crawl import command as crawl_command
from skiller.commands.search import command as search_command
from skiller.commands.remove import command as remove_command

COMMANDS: list[Command] = [
    discovery_command,
    list_command,
    install_command,
    crawl_command,
    search_command,
    remove_command,
]

COMMAND_MAP = {command.name: command for command in COMMANDS}
