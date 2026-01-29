#!/usr/bin/env python3
"""skiller - Helper script to discover, install and manage skills for AI agents."""

from __future__ import annotations

import argparse
import os
import sys

from skiller.commands import COMMANDS, COMMAND_MAP
from skiller.config import load_config
from skiller.ui import select_option


def _add_legacy_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--list", action="store_true", help="List all installed skills")
    parser.add_argument(
        "--dd",
        nargs="?",
        const=os.getcwd(),
        metavar="DIR",
        help=(
            "Discovery: look for known agents dirs in DIR "
            "(default: current directory) and list potential skills"
        ),
    )
    parser.add_argument("--interactive", action="store_true", help="Run interactive TUI")
    parser.add_argument("--install", action="store_true", help="Install a discovered skill")
    parser.add_argument("--crawl", action="store_true", help="Crawl external sites for skills")


def _run_interactive(config: dict) -> None:
    commands = [cmd.name for cmd in COMMANDS] + ["quit"]
    cmd_name = select_option("Choose a command:", commands, default="discovery")
    if not cmd_name or cmd_name == "quit":
        return
    cmd = COMMAND_MAP.get(cmd_name)
    if not cmd:
        return
    if cmd.run_interactive:
        cmd.run_interactive(config)
        return
    cmd.run(argparse.Namespace(), config)


def _dispatch_legacy(args: argparse.Namespace, config: dict) -> bool:
    if args.interactive:
        _run_interactive(config)
        return True

    if args.list:
        COMMAND_MAP["list"].run(args, config)
        return True

    if args.install:
        COMMAND_MAP["install"].run(args, config)
        return True

    if args.crawl:
        COMMAND_MAP["crawl"].run(args, config)
        return True

    if args.dd is not None:
        args.command = "discovery"
        args.dir = args.dd or os.getcwd()
        COMMAND_MAP["discovery"].run(args, config)
        return True

    return False


def main() -> None:
    """Main entry point for the skiller CLI."""
    config = load_config()

    parser = argparse.ArgumentParser(
        prog="skiller",
        description="Helper script to discover, install and manage skills for AI agents",
        epilog="Run without arguments to show help.",
    )
    _add_legacy_flags(parser)

    subparsers = parser.add_subparsers(dest="command")
    for cmd in COMMANDS:
        sub = subparsers.add_parser(cmd.name, help=cmd.help)
        cmd.add_arguments(sub)

    args = parser.parse_args()

    if len(sys.argv) == 1:
        _run_interactive(config)
        return

    if _dispatch_legacy(args, config):
        return

    if args.command and args.command in COMMAND_MAP:
        COMMAND_MAP[args.command].run(args, config)
        return


if __name__ == "__main__":
    main()
