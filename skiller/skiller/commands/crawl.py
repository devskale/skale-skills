"""Crawl command implementation to discover skills from external sites."""

from __future__ import annotations

import argparse
import os
import re
import time
import json
import urllib.request
import urllib.error
from typing import Any

from skiller.commands.base import Command

def _load_env() -> None:
    """Load environment variables from .env file if it exists."""
    env_path = os.path.join(os.getcwd(), ".env")
    if os.path.exists(env_path):
        with open(env_path, "r") as f:
            for line in f:
                if "=" in line and not line.startswith("#"):
                    key, value = line.strip().split("=", 1)
                    os.environ[key] = value

def _add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--file",
        default="skill-sites.md",
        help="Path to the markdown file containing skill sites (default: skill-sites.md)",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=1.0,
        help="Delay in seconds between requests (default: 1.0)",
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Test mode - show what would be crawled without saving",
    )

def _extract_urls(file_path: str) -> list[str]:
    """Extract URLs from a markdown file, only from the '# skill repos' section."""
    urls = []
    if not os.path.exists(file_path):
        # Try to find it in the project root if relative
        root_path = os.path.join(os.getcwd(), file_path)
        if os.path.exists(root_path):
            file_path = root_path
        else:
            print(f"Error: File {file_path} not found.")
            return []

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
        
        # Extract content only between '# skill repos' and the next H2 heading (##)
        repo_section_match = re.search(r"# skill repos(.*?)(?=\n##|$)", content, re.DOTALL | re.IGNORECASE)
        if repo_section_match:
            section_content = repo_section_match.group(1)
            # Simple regex to find https links in that section
            urls = re.findall(r'https?://[^\s\)]+', section_content)
        else:
            print("Warning: Section '# skill repos' not found in file.")
    
    return list(set(urls))

def _get_github_repo_info(url: str) -> tuple[str, str] | None:
    """Extract owner and repo from a GitHub URL."""
    match = re.search(r"github\.com/([^/]+)/([^/]+)", url)
    if match:
        owner = match.group(1)
        repo = match.group(2).replace(".git", "")
        return owner, repo
    return None

def _fetch_skill_description(skill_file_url: str, headers: dict) -> str:
    """Fetch and parse SKILL.md to extract description from frontmatter."""
    try:
        req = urllib.request.Request(skill_file_url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            content = response.read().decode('utf-8')
            
            # Check for YAML frontmatter
            if content.startswith("---\n"):
                end_pos = content.find("\n---\n", 4)
                if end_pos != -1:
                    import yaml
                    frontmatter_str = content[4:end_pos]
                    try:
                        parsed = yaml.safe_load(frontmatter_str)
                        if isinstance(parsed, dict):
                            desc = parsed.get("description")
                            if desc:
                                return str(desc).replace("\n", " ")
                    except Exception:
                        pass
        return ""
    except Exception:
        return ""


def _fetch_github_skills(owner: str, repo: str, delay: float = 0) -> list[dict[str, Any]]:
    """Fetch skills from a GitHub repository using the Content API."""
    skills = []
    api_url = f"https://api.github.com/repos/{owner}/{repo}/contents"
    
    token = os.environ.get("GITHUB_TOKEN")
    headers = {"User-Agent": "Skiller-Crawl"}
    if token:
        headers["Authorization"] = f"token {token}"
    
    try:
        # We search for SKILL.md files in the root or 'skills/' directory
        req = urllib.request.Request(api_url, headers=headers)
        with urllib.request.urlopen(req) as response:
            contents = json.loads(response.read().decode())
            
            # Check for SKILL.md in root
            for item in contents:
                if item["name"].lower() == "skill.md" and item["type"] == "file":
                    description = _fetch_skill_description(item["download_url"], headers)
                    skills.append({
                        "name": f"{owner}/{repo}",
                        "source": "github",
                        "url": f"https://github.com/{owner}/{repo}",
                        "skill_file_url": item["download_url"],
                        "path": "",
                        "description": description or "(No description available)"
                    })
                
                # If there's a skills/ directory, look inside
                if item["name"].lower() == "skills" and item["type"] == "dir":
                    if delay > 0:
                        time.sleep(delay)
                    skills_req = urllib.request.Request(item["url"], headers=headers)
                    with urllib.request.urlopen(skills_req) as skills_response:
                        skills_contents = json.loads(skills_response.read().decode())
                        for s_item in skills_contents:
                            if s_item["type"] == "dir":
                                if delay > 0:
                                    time.sleep(delay)
                                # Look for SKILL.md inside each subdirectory
                                sub_req = urllib.request.Request(s_item["url"], headers=headers)
                                with urllib.request.urlopen(sub_req) as sub_response:
                                    sub_contents = json.loads(sub_response.read().decode())
                                    for sub_file in sub_contents:
                                        if sub_file["name"].lower() == "skill.md":
                                            description = _fetch_skill_description(sub_file["download_url"], headers)
                                            skills.append({
                                                "name": f"{owner}/{repo}/{s_item['name']}",
                                                "source": "github",
                                                "url": f"https://github.com/{owner}/{repo}/tree/main/skills/{s_item['name']}",
                                                "skill_file_url": sub_file["download_url"],
                                                "path": f"skills/{s_item['name']}",
                                                "description": description or "(No description available)"
                                            })
    except Exception as e:
        print(f"  [Error] Failed to fetch from {owner}/{repo}: {e}")
        
    return skills

def _load_index() -> list[dict[str, Any]]:
    """Load existing skills from the local index file."""
    index_path = os.path.join(os.getcwd(), "skiller_index.json")
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("skills", [])
        except Exception:
            return []
    return []

def _save_index(skills: list[dict[str, Any]]) -> None:
    """Save the discovered skills to a local index file, merging with existing ones."""
    index_path = os.path.join(os.getcwd(), "skiller_index.json")
    
    # Simple merge: use name as unique key
    existing_skills = _load_index()
    skill_map = {s["name"]: s for s in existing_skills}
    for s in skills:
        skill_map[s["name"]] = s
    
    final_skills = sorted(list(skill_map.values()), key=lambda x: x["name"])
    
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump({
            "updated_at": "now", 
            "count": len(final_skills),
            "skills": final_skills
        }, f, indent=2)
    print(f"\nIndex updated. Total skills: {len(final_skills)} (Saved to {index_path})")

def _run(args: argparse.Namespace, config: dict) -> None:
    """Run the crawl command."""
    test_mode = getattr(args, "test", False)
    _load_env()
    print(f"Crawling skills from {args.file}...")
    urls = _extract_urls(args.file)
    
    if not urls:
        print("No URLs found to crawl.")
        return

    all_discovered_skills = []
    print(f"Found {len(urls)} potential sources. Starting crawl...")
    
    for i, url in enumerate(urls):
        if i > 0 and args.delay > 0:
            time.sleep(args.delay)
            
        if "github.com" in url:
            info = _get_github_repo_info(url)
            if info:
                owner, repo = info
                print(f"  [GitHub] Scanning {owner}/{repo}...")
                discovered = _fetch_github_skills(owner, repo, args.delay)
                if discovered:
                    print(f"    Found {len(discovered)} skills.")
                    all_discovered_skills.extend(discovered)
        else:
            # Web scraping could be added here later
            print(f"  [Web] Skipping {url} (Web crawling not yet implemented)")
    
    if test_mode:
        print(f"\nTest mode - found {len(all_discovered_skills)} skills:")
        for skill in all_discovered_skills:
            print(f"  - {skill['name']}: {skill.get('description', '(no description)')[:60]}...")
        print("\nRun without --test to save these skills to the index.")
    elif all_discovered_skills:
        _save_index(all_discovered_skills)
    else:
        print("\nNo skills discovered.")

def _run_interactive(config: dict) -> None:
    """Interactive version of the crawl command."""
    # Simple default run for now
    class Args:
        file = "skill-sites.md"
    _run(Args(), config)

command = Command(
    name="crawl",
    help="Crawl external sites for skills",
    add_arguments=_add_arguments,
    run=_run,
    run_interactive=_run_interactive,
)
