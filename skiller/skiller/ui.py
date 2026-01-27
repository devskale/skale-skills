"""Interactive UI helpers for skiller."""

from __future__ import annotations

import sys
from typing import List, Optional

# Try to import questionary for nice cursor-based menus. If it's not installed
# or importing fails, we'll fall back to curses or simple input() prompts.
try:
    import questionary  # type: ignore
    from questionary import Choice  # type: ignore

    _HAVE_QUESTIONARY = True
except Exception:
    _HAVE_QUESTIONARY = False

try:
    import curses

    _HAVE_CURSES = True
except Exception:
    _HAVE_CURSES = False


SINGLE_SELECT_HINT = "Use ↑/↓, Enter to select, q to quit"
MULTI_SELECT_HINT = "Use ↑/↓, Space to toggle, Enter to confirm, q to quit"


def _format_prompt(message: str, hint: Optional[str] = None) -> str:
    if not hint:
        return message
    return f"{message}\n{hint}"


def _can_use_curses() -> bool:
    return _HAVE_CURSES and sys.stdin.isatty() and sys.stdout.isatty()


def _try_curses_single_select(
    message: str, choices: List[str], default: Optional[str]
) -> tuple[bool, Optional[str]]:
    if not _can_use_curses():
        return False, None
    try:
        default_index = choices.index(default) if default in choices else 0

        def _run(stdscr: "curses.window") -> Optional[str]:
            curses.curs_set(0)
            stdscr.keypad(True)
            idx = default_index
            while True:
                stdscr.clear()
                stdscr.addstr(0, 0, message)
                for i, option in enumerate(choices):
                    prefix = "> " if i == idx else "  "
                    if i == idx:
                        stdscr.addstr(i + 2, 0, f"{prefix}{option}", curses.A_REVERSE)
                    else:
                        stdscr.addstr(i + 2, 0, f"{prefix}{option}")
                stdscr.addstr(len(choices) + 3, 0, SINGLE_SELECT_HINT)
                key = stdscr.getch()
                if key in (curses.KEY_UP, ord("k")):
                    idx = (idx - 1) % len(choices)
                elif key in (curses.KEY_DOWN, ord("j")):
                    idx = (idx + 1) % len(choices)
                elif key in (curses.KEY_ENTER, 10, 13):
                    return choices[idx]
                elif key in (27, ord("q")):
                    return None

        return True, curses.wrapper(_run)
    except Exception:
        return False, None


def _try_curses_multi_select(
    message: str, choices: List[str], default: List[str]
) -> tuple[bool, Optional[List[str]]]:
    if not _can_use_curses():
        return False, None
    try:
        default_indices = {choices.index(item) for item in default if item in choices}

        def _run(stdscr: "curses.window") -> Optional[List[str]]:
            curses.curs_set(0)
            stdscr.keypad(True)
            idx = 0
            selected = set(default_indices)
            while True:
                stdscr.clear()
                stdscr.addstr(0, 0, message)
                for i, option in enumerate(choices):
                    marker = "[x]" if i in selected else "[ ]"
                    prefix = ">" if i == idx else " "
                    line = f"{prefix} {marker} {option}"
                    if i == idx:
                        stdscr.addstr(i + 2, 0, line, curses.A_REVERSE)
                    else:
                        stdscr.addstr(i + 2, 0, line)
                stdscr.addstr(len(choices) + 3, 0, MULTI_SELECT_HINT)
                key = stdscr.getch()
                if key in (curses.KEY_UP, ord("k")):
                    idx = (idx - 1) % len(choices)
                elif key in (curses.KEY_DOWN, ord("j")):
                    idx = (idx + 1) % len(choices)
                elif key == ord(" "):
                    if idx in selected:
                        selected.remove(idx)
                    else:
                        selected.add(idx)
                elif key in (curses.KEY_ENTER, 10, 13):
                    return [choices[i] for i in range(len(choices)) if i in selected]
                elif key in (27, ord("q")):
                    return None

        return True, curses.wrapper(_run)
    except Exception:
        return False, None


def select_option(message: str, choices: List[str], default: Optional[str] = None) -> Optional[str]:
    """Select an option from choices using questionary if available, otherwise text input.

    Returns the selected choice string or None if user cancelled.
    """
    if _HAVE_QUESTIONARY:
        try:
            q_choices = [Choice(c) for c in choices]
            prompt = _format_prompt(message, SINGLE_SELECT_HINT)
            if default and default in choices:
                selected = questionary.select(prompt, choices=q_choices, default=default).ask()
            else:
                selected = questionary.select(prompt, choices=q_choices).ask()
            if selected is None:
                return None
            return str(selected)
        except Exception:
            pass

    ran_curses, selected = _try_curses_single_select(message, choices, default)
    if ran_curses:
        return selected

    print()
    print(_format_prompt(message, SINGLE_SELECT_HINT))
    for i, c in enumerate(choices, start=1):
        marker = " (default)" if default and c == default else ""
        print(f"  {i}) {c}{marker}")
    print("  q) Quit")
    while True:
        choice = input("Select an option (number or name): ").strip()
        if choice.lower() in ("q", "quit", "exit"):
            return None
        if choice == "" and default:
            return default
        if choice.isdigit():
            idx = int(choice) - 1
            if 0 <= idx < len(choices):
                return choices[idx]
        else:
            if choice in choices:
                return choice
        print("Invalid choice. Enter a number, exact option name, or 'q' to quit.")


def select_multiple(
    message: str, choices: List[str], default: Optional[List[str]] = None
) -> Optional[List[str]]:
    """Select multiple options using questionary when available."""
    if _HAVE_QUESTIONARY:
        try:
            q_choices = [Choice(c) for c in choices]
            prompt = _format_prompt(message, MULTI_SELECT_HINT)
            picked = questionary.checkbox(prompt, choices=q_choices, default=default or []).ask()
            if picked is None:
                return None
            return [str(item) for item in picked]
        except Exception:
            pass

    ran_curses, selected = _try_curses_multi_select(message, choices, default or [])
    if ran_curses:
        return selected

    print()
    print(_format_prompt(message, MULTI_SELECT_HINT))
    for idx, choice in enumerate(choices, start=1):
        marker = " (default)" if default and choice in default else ""
        print(f"  {idx}) {choice}{marker}")
    print("  q) Quit")
    while True:
        response = input("Select options (numbers or names separated by spaces/comma): ").strip()
        if response.lower() in ("q", "quit", "exit"):
            return None
        if response == "" and default:
            return list(default)
        tokens = [token for token in response.replace(",", " ").split() if token]
        if not tokens:
            print("Enter at least one option or 'q' to quit.")
            continue
        selected: List[str] = []
        seen: set[str] = set()
        invalid = False
        for token in tokens:
            if token.isdigit():
                idx = int(token) - 1
                if 0 <= idx < len(choices):
                    value = choices[idx]
                else:
                    invalid = True
                    break
            else:
                if token in choices:
                    value = token
                else:
                    invalid = True
                    break
            if value not in seen:
                seen.add(value)
                selected.append(value)
        if invalid:
            print("One of the selections was invalid. Try again or 'q' to quit.")
            continue
        if selected:
            return selected


def text_input(message: str, default: Optional[str] = None) -> Optional[str]:
    """Prompt the user for free text. Uses questionary.text when available."""
    if _HAVE_QUESTIONARY:
        try:
            answer = questionary.text(message, default=default or "").ask()
            if answer is None:
                return None
            return str(answer).strip() or default
        except Exception:
            pass

    prompt = f"{message}"
    if default:
        prompt += f" [{default}]"
    prompt += ": "
    val = input(prompt).strip()
    if val == "":
        return default
    return val
