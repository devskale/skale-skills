#!/usr/bin/env python3
"""Reindex skills, extensions, and prompts — update SKILL-INDEX.md.

Scans local source dirs, global install dirs, and packages to produce
a single index of all resources, their status, and where they're active.

Usage:
    uv run index-skills.py            # Update SKILL-INDEX.md in cwd
    uv run index-skills.py --check    # Print index without writing
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

@dataclass
class NotablePackage:
    name: str
    description: str
    install: str = ""
    repo: str = ""
    provides: str = ""
    config: str = ""
    scope: str = ""  # project | global


@dataclass
class Skill:
    name: str
    description: str
    local_path: Optional[str] = None
    global_link: Optional[str] = None
    package: Optional[str] = None
    status: str = "available"  # available | global | package

    @property
    def source(self) -> str:
        if self.global_link:
            return f"~/.pi/agent/skills/{self.name}"
        if self.package:
            return f"pkg:{self.package}"
        return f"skills/{self.name}"

    @property
    def status_badge(self) -> str:
        return _badge(self.status)


@dataclass
class Extension:
    name: str
    description: str
    local_path: Optional[str] = None
    global_path: Optional[str] = None
    package: Optional[str] = None
    status: str = "available"  # available | global | package | notable

    @property
    def source(self) -> str:
        if self.global_path:
            return f"~/.pi/agent/extensions/{self.name}"
        if self.package:
            return f"pkg:{self.package}"
        return f"extensions/{self.name}"

    @property
    def status_badge(self) -> str:
        return _badge(self.status)


@dataclass
class Prompt:
    name: str
    description: str
    local_path: Optional[str] = None
    global_path: Optional[str] = None
    package: Optional[str] = None
    status: str = "available"  # available | global | package | notable

    @property
    def source(self) -> str:
        if self.global_path:
            return f"~/.pi/agent/prompts/{self.name}"
        if self.package:
            return f"pkg:{self.package}"
        return f"prompts/{self.name}"

    @property
    def status_badge(self) -> str:
        return _badge(self.status)


def _badge(status: str) -> str:
    badges = {
        "global": "🟢 global",
        "package": "🔵 package",
        "notable": "📝 notable",
        "available": "⚪ available",
    }
    return badges.get(status, status)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def parse_frontmatter(text: str) -> dict[str, str]:
    """Extract YAML frontmatter from a file."""
    match = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not match:
        return {}
    meta: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" in line:
            key, _, val = line.partition(":")
            meta[key.strip().lower()] = val.strip().strip('"').strip("'")
    return meta


def read_first_line(path: Path) -> str:
    """Read first non-empty, non-frontmatter line from a markdown file."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return ""
    # Skip frontmatter
    if text.startswith("---"):
        end = text.find("---", 3)
        if end != -1:
            text = text[end + 3:]
    for line in text.strip().splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            return stripped
    return ""


def truncate(text: str, length: int = 100) -> str:
    text = text.strip()
    if len(text) > length:
        return text[: length - 3] + "..."
    return text


# ---------------------------------------------------------------------------
# Scanners
# ---------------------------------------------------------------------------

def scan_skills_dir(dir_path: str) -> list[Skill]:
    """Scan a directory for skills (subdirs with SKILL.md)."""
    results: list[Skill] = []
    root = Path(dir_path)
    if not root.is_dir():
        return results
    for entry in sorted(root.iterdir()):
        if not entry.is_dir():
            continue
        skill_file = entry / "SKILL.md"
        if not skill_file.is_file():
            continue
        text = skill_file.read_text(encoding="utf-8", errors="ignore")
        meta = parse_frontmatter(text)
        name = meta.get("name", entry.name)
        desc = truncate(meta.get("description", ""))
        results.append(Skill(name=name, description=desc, local_path=str(entry)))
    return results


def scan_extensions_dir(dir_path: str) -> list[Extension]:
    """Scan a directory for extensions (*.ts or subdirs with index.ts)."""
    results: list[Extension] = []
    root = Path(dir_path)
    if not root.is_dir():
        return results
    for entry in sorted(root.iterdir()):
        if entry.name.startswith(".") or entry.name == "node_modules":
            continue
        if entry.is_file() and entry.suffix == ".ts":
            desc = truncate(read_first_line(entry))
            name = entry.stem
            results.append(Extension(name=name, description=desc, local_path=str(entry)))
        elif entry.is_dir():
            index = entry / "index.ts"
            if index.is_file():
                desc = truncate(read_first_line(index))
                results.append(Extension(name=entry.name, description=desc, local_path=str(entry)))
    return results


def scan_prompts_dir(dir_path: str) -> list[Prompt]:
    """Scan a directory for prompt templates (*.md files)."""
    results: list[Prompt] = []
    root = Path(dir_path)
    if not root.is_dir():
        return results
    for entry in sorted(root.iterdir()):
        if not entry.is_file() or entry.suffix != ".md":
            continue
        text = entry.read_text(encoding="utf-8", errors="ignore")
        meta = parse_frontmatter(text)
        desc = truncate(meta.get("description", read_first_line(entry)))
        name = entry.stem
        results.append(Prompt(name=name, description=desc, local_path=str(entry)))
    return results


def scan_global_skills(global_dir: str) -> dict[str, str]:
    """Return {name: resolved_target} for entries in global skills dir."""
    result: dict[str, str] = {}
    root = Path(global_dir).expanduser()
    if not root.is_dir():
        return result
    for entry in root.iterdir():
        if entry.name.startswith("."):
            continue
        if entry.is_symlink():
            result[entry.name] = str(entry.resolve())
        elif entry.is_dir() and (entry / "SKILL.md").is_file():
            result[entry.name] = str(entry)
    return result


def scan_global_extensions(global_dir: str) -> dict[str, str]:
    """Return {name: resolved_path} for entries in global extensions dir."""
    result: dict[str, str] = {}
    root = Path(global_dir).expanduser()
    if not root.is_dir():
        return result
    for entry in root.iterdir():
        if entry.name.startswith("."):
            continue
        if entry.is_file() and entry.suffix == ".ts":
            result[entry.stem] = str(entry)
        elif entry.is_dir() and (entry / "index.ts").is_file():
            result[entry.name] = str(entry)
    return result


def scan_global_prompts(global_dir: str) -> dict[str, str]:
    """Return {name: resolved_path} for entries in global prompts dir."""
    result: dict[str, str] = {}
    root = Path(global_dir).expanduser()
    if not root.is_dir():
        return result
    for entry in root.iterdir():
        if not entry.is_file() or entry.suffix != ".md":
            continue
        result[entry.stem] = str(entry)
    return result


def scan_package_resources(project_dir: str) -> tuple[list[tuple], list[tuple], list[tuple]]:
    """Scan npm packages for bundled skills, extensions, prompts.
    Returns (skills, extensions, prompts) as [(name, desc, pkg_name)].
    """
    skills: list[tuple[str, str, str]] = []
    extensions: list[tuple[str, str, str]] = []
    prompts: list[tuple[str, str, str]] = []

    npm_dir = Path(project_dir) / ".pi" / "npm" / "node_modules"
    if not npm_dir.is_dir():
        return skills, extensions, prompts

    for pkg_entry in sorted(npm_dir.iterdir()):
        if not pkg_entry.is_dir() or pkg_entry.name.startswith("@"):
            continue

        # Skills
        skills_dir = pkg_entry / "skills"
        if skills_dir.is_dir():
            for skill_entry in skills_dir.iterdir():
                if not skill_entry.is_dir():
                    continue
                skill_file = skill_entry / "SKILL.md"
                if not skill_file.is_file():
                    continue
                text = skill_file.read_text(encoding="utf-8", errors="ignore")
                meta = parse_frontmatter(text)
                name = meta.get("name", skill_entry.name)
                desc = truncate(meta.get("description", ""))
                skills.append((name, desc, pkg_entry.name))

        # Extensions
        ext_dir = pkg_entry / "extensions"
        if ext_dir.is_dir():
            for ext_entry in ext_dir.iterdir():
                if ext_entry.is_file() and ext_entry.suffix == ".ts":
                    desc = truncate(read_first_line(ext_entry))
                    extensions.append((ext_entry.stem, desc, pkg_entry.name))
                elif ext_entry.is_dir() and (ext_entry / "index.ts").is_file():
                    desc = truncate(read_first_line(ext_entry / "index.ts"))
                    extensions.append((ext_entry.name, desc, pkg_entry.name))

        # Prompts
        prompts_dir = pkg_entry / "prompts"
        if prompts_dir.is_dir():
            for prompt_entry in prompts_dir.iterdir():
                if not prompt_entry.is_file() or prompt_entry.suffix != ".md":
                    continue
                text = prompt_entry.read_text(encoding="utf-8", errors="ignore")
                meta = parse_frontmatter(text)
                desc = truncate(meta.get("description", read_first_line(prompt_entry)))
                prompts.append((prompt_entry.stem, desc, pkg_entry.name))

    return skills, extensions, prompts


def scan_notable_packages(notable_dir: str) -> list[NotablePackage]:
    """Scan notable/ directory for package reference cards.
    Each .md file is a notable package with structured metadata.
    """
    results: list[NotablePackage] = []
    root = Path(notable_dir)
    if not root.is_dir():
        return results
    for entry in sorted(root.iterdir()):
        if not entry.is_file() or entry.suffix != ".md":
            continue
        text = entry.read_text(encoding="utf-8", errors="ignore")
        lines = text.strip().splitlines()
        # First heading is the name, description is everything until first list item
        description = ""
        past_heading = False
        for line in lines:
            if line.startswith("# "):
                past_heading = True
                continue
            if past_heading and line.startswith("- "):
                break
            if past_heading and line.strip():
                description += (" " if description else "") + line.strip()
        # Parse structured fields from list items
        fields: dict[str, str] = {}
        for line in lines:
            match = re.match(r"^- \*\*(\w[\w-]*):?\*\*\s+(.+)$", line)
            if match:
                fields[match.group(1).lower()] = match.group(2).strip()
        results.append(NotablePackage(
            name=entry.stem,
            description=description,
            install=fields.get("install", ""),
            repo=fields.get("repo", ""),
            provides=fields.get("provides", ""),
            config=fields.get("config", ""),
            scope=fields.get("scope", ""),
        ))
    return results

# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------

def load_packages(
    project_dir: str, global_settings: str,
) -> tuple[list[str], list[str]]:
    """Collect package refs from project and global settings.
    Returns (global_packages, project_packages) — both deduped.
    """
    global_pkgs: list[str] = []
    project_pkgs: list[str] = []

    project_settings = Path(project_dir) / ".pi" / "settings.json"
    if project_settings.is_file():
        try:
            data = json.loads(project_settings.read_text())
            project_pkgs.extend(data.get("packages", []))
        except (json.JSONDecodeError, OSError):
            pass

    global_path = Path(global_settings).expanduser()
    if global_path.is_file():
        try:
            data = json.loads(global_path.read_text())
            global_pkgs.extend(data.get("packages", []))
        except (json.JSONDecodeError, OSError):
            pass

    def dedup(items: list[str]) -> list[str]:
        seen: set[str] = set()
        out: list[str] = []
        for p in items:
            if p not in seen:
                seen.add(p)
                out.append(p)
        return out

    return dedup(global_pkgs), dedup(project_pkgs)


# ---------------------------------------------------------------------------
# Index builder
# ---------------------------------------------------------------------------

def build_index(project_dir: str, global_dir: str, global_settings: str):
    """Build the full index of all resources."""
    home = Path.home()
    base = Path(project_dir)

    # --- Local source dirs ---
    local_skills = scan_skills_dir(base / "skills")
    local_extensions = scan_extensions_dir(base / "extensions")
    local_prompts = scan_prompts_dir(base / "prompts")

    # --- Global installs ---
    global_skills = scan_global_skills(home / ".pi" / "agent" / "skills")
    global_extensions = scan_global_extensions(home / ".pi" / "agent" / "extensions")
    global_prompts = scan_global_prompts(home / ".pi" / "agent" / "prompts")

    # --- Packages ---
    pkg_skills, pkg_extensions, pkg_prompts = scan_package_resources(project_dir)

    # --- Merge ---
    # Skills: mark local skills that are globally active
    for s in local_skills:
        if s.name in global_skills:
            s.global_link = global_skills[s.name]
            s.status = "global"
    for name, desc, pkg in pkg_skills:
        found = False
        for s in local_skills:
            if s.name == name:
                s.package = pkg
                s.status = "package"
                found = True
                break
        if not found:
            local_skills.append(Skill(name=name, description=desc, package=pkg, status="package"))

    # Extensions
    for e in local_extensions:
        if e.name in global_extensions:
            e.global_path = global_extensions[e.name]
            e.status = "global"
    for name, desc, pkg in pkg_extensions:
        found = False
        for e in local_extensions:
            if e.name == name:
                e.package = pkg
                e.status = "package"
                found = True
                break
        if not found:
            local_extensions.append(Extension(name=name, description=desc, package=pkg, status="package"))

    # Prompts
    for p in local_prompts:
        if p.name in global_prompts:
            p.global_path = global_prompts[p.name]
            p.status = "global"
    for name, desc, pkg in pkg_prompts:
        found = False
        for p in local_prompts:
            if p.name == name:
                p.package = pkg
                p.status = "package"
                found = True
                break
        if not found:
            local_prompts.append(Prompt(name=name, description=desc, package=pkg, status="package"))

    global_packages, project_packages = load_packages(project_dir, global_settings)

    # Mark skills from project packages as notable (not active)
    project_pkg_names = set(p.replace("npm:", "") for p in project_packages)
    for s in local_skills:
        if s.status == "package" and s.package in project_pkg_names:
            s.status = "notable"
    for e in local_extensions:
        if e.status == "package" and e.package in project_pkg_names:
            e.status = "notable"
    for p in local_prompts:
        if p.status == "package" and p.package in project_pkg_names:
            p.status = "notable"

    # --- Notable packages ---
    notables = scan_notable_packages(base / "notable")

    # Match notable cards to project packages
    project_pkg_names = set(p.replace("npm:", "") for p in project_packages)
    for n in notables:
        if n.name in project_pkg_names:
            n.scope = "project"
        elif any(n.name in gp.replace("npm:", "") for gp in global_packages):
            n.scope = "global"

    return local_skills, local_extensions, local_prompts, global_packages, project_packages, notables


# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

def render_section(title: str, items: list, source_col: bool = True) -> list[str]:
    """Render a table section."""
    lines: list[str] = []
    lines.append(f"### {title}")
    lines.append("")
    if not items:
        lines.append("_None._")
        lines.append("")
        return lines

    if source_col:
        lines.append("| Status | Name | Description | Source |")
        lines.append("|--------|------|-------------|--------|")
        for item in items:
            src = f"`{item.source}`" if item.source else ""
            lines.append(f"| {item.status_badge} | **{item.name}** | {item.description} | {src} |")
    else:
        lines.append("| Status | Name | Description |")
        lines.append("|--------|------|-------------|")
        for item in items:
            lines.append(f"| {item.status_badge} | **{item.name}** | {item.description} |")
    lines.append("")
    return lines


def render_index(
    skills: list[Skill],
    extensions: list[Extension],
    prompts: list[Prompt],
    global_packages: list[str],
    project_packages: list[str],
    notables: list[NotablePackage],
) -> str:
    """Render the full index as markdown."""
    lines: list[str] = []

    lines.append("# Skill Index")
    lines.append("")
    lines.append("> Auto-generated by `uv run index-skills.py` — do not edit manually.")
    lines.append("")

    # Notable packages
    if notables:
        lines.append("## Notable Packages")
        lines.append("")
        lines.append("External packages referenced in this repo. Not active here (dev repo) but documented for reference.")
        lines.append("")
        for n in notables:
            lines.append(f"### {n.name}")
            lines.append("")
            lines.append(f"{n.description}")
            lines.append("")
            detail_lines: list[str] = []
            if n.install:
                detail_lines.append(f"- **Install:** `{n.install}`")
            if n.repo:
                detail_lines.append(f"- **Repo:** {n.repo}")
            if n.provides:
                detail_lines.append(f"- **Provides:** {n.provides}")
            if n.config:
                detail_lines.append(f"- **Config:** {n.config}")
            if n.scope:
                detail_lines.append(f"- **Scope:** {n.scope}")
            lines.extend(detail_lines)
            lines.append("")
        lines.append("")

    # Global packages
    lines.append("## Global Packages")
    lines.append("")
    if global_packages:
        for pkg in global_packages:
            # Enrich with notable card if available
            pkg_name = pkg.replace("npm:", "")
            notable = next((n for n in notables if n.name == pkg_name), None)
            if notable:
                lines.append(f"- `{pkg}` — {notable.description}")
            else:
                lines.append(f"- `{pkg}`")
    else:
        lines.append("_None._")
    lines.append("")

    # Skills
    active_skills = [s for s in skills if s.status in ("global", "package")]
    notable_skills = [s for s in skills if s.status == "notable"]
    avail_skills = [s for s in skills if s.status == "available"]
    lines.append("## Skills")
    lines.append("")
    lines.extend(render_section("Active", active_skills))
    if notable_skills:
        lines.extend(render_section("Notable (from project packages)", notable_skills))
    lines.extend(render_section("Available (not installed)", avail_skills, source_col=False))

    # Extensions
    active_exts = [e for e in extensions if e.status in ("global", "package")]
    notable_exts = [e for e in extensions if e.status == "notable"]
    avail_exts = [e for e in extensions if e.status == "available"]
    lines.append("## Extensions")
    lines.append("")
    lines.extend(render_section("Active", active_exts))
    if notable_exts:
        lines.extend(render_section("Notable (from project packages)", notable_exts))
    lines.extend(render_section("Available (not installed)", avail_exts, source_col=False))

    # Prompts
    active_prompts = [p for p in prompts if p.status in ("global", "package")]
    notable_prompts = [p for p in prompts if p.status == "notable"]
    avail_prompts = [p for p in prompts if p.status == "available"]
    lines.append("## Prompts")
    lines.append("")
    lines.extend(render_section("Active", active_prompts))
    if notable_prompts:
        lines.extend(render_section("Notable (from project packages)", notable_prompts))
    lines.extend(render_section("Available (not installed)", avail_prompts, source_col=False))

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="Reindex skills, extensions, and prompts")
    parser.add_argument("--check", action="store_true", help="Print index without writing")
    parser.add_argument("--project-dir", default=".", help="Project root (default: cwd)")
    parser.add_argument("--global-dir", default="~/.pi/agent", help="Global pi dir")
    parser.add_argument(
        "--global-settings",
        default="~/.pi/agent/settings.json",
        help="Global settings path",
    )
    args = parser.parse_args()

    project_dir = os.path.abspath(args.project_dir)
    global_dir = args.global_dir
    global_settings = args.global_settings

    skills, extensions, prompts, global_packages, project_packages, notables = build_index(
        project_dir, global_dir, global_settings
    )
    output = render_index(skills, extensions, prompts, global_packages, project_packages, notables)

    if args.check:
        print(output)
        return 0

    index_path = os.path.join(project_dir, "SKILL-INDEX.md")
    with open(index_path, "w", encoding="utf-8") as f:
        f.write(output)

    total = len(skills) + len(extensions) + len(prompts) + len(notables)
    active = (
        sum(1 for s in skills if s.status in ("global", "package"))
        + sum(1 for e in extensions if e.status in ("global", "package"))
        + sum(1 for p in prompts if p.status in ("global", "package"))
    )
    notable = (
        sum(1 for s in skills if s.status == "notable")
        + sum(1 for e in extensions if e.status == "notable")
        + sum(1 for p in prompts if p.status == "notable")
        + len(notables)
    )
    available = total - active - notable
    print(f"Updated {index_path}")
    print(f"  {total} resources: {active} active, {notable} notable, {available} available")
    return 0


if __name__ == "__main__":
    sys.exit(main())
