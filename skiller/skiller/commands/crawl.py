"""Crawl command implementation to discover skills from external sites.

This module uses efficient GitHub API patterns to minimize API calls:
- Uses Tree API with recursive=1 to get all repository files in ONE call
- Fetches SKILL.md contents in parallel with rate limiting
- Implements exponential backoff for rate limit handling
"""

from __future__ import annotations

import argparse
import os
import re
import time
import json
import urllib.request
import urllib.error
from typing import Any
from concurrent.futures import ThreadPoolExecutor

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


def _get_headers() -> dict:
    """Get request headers with optional auth token."""
    token = os.environ.get("GITHUB_TOKEN")
    headers = {
        "User-Agent": "Skiller-Crawl",
        "Accept": "application/vnd.github.v3+json"
    }
    if token:
        headers["Authorization"] = f"token {token}"
    return headers


def _make_request(url: str, headers: dict, max_retries: int = 3) -> Any:
    """Make API request with rate limit handling and retries."""
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as response:
                return json.loads(response.read().decode())
        except urllib.error.HTTPError as e:
            if e.code == 403:
                reset_time = e.headers.get("X-RateLimit-Reset")
                if reset_time:
                    sleep_time = max(0, int(reset_time) - time.time())
                    if sleep_time > 0 and attempt < max_retries - 1:
                        print(f"    Rate limited. Waiting {sleep_time:.0f}s...")
                        time.sleep(sleep_time + 1)
                        continue
            if e.code == 404:
                return None
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
            else:
                print(f"    API Error {e.code}: {e.reason}")
                return None
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
            else:
                print(f"    Request error: {e}")
                return None
    return None


def _add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--file",
        default="skill-sites.md",
        help="Path to markdown file containing skill sites",
    )
    parser.add_argument(
        "--delay",
        type=float,
        default=0.5,
        help="Delay in seconds between requests (default: 0.5)",
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Test mode - show what would be crawled without saving",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Limit number of repos to crawl (0 = no limit, default: 0)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=5,
        help="Number of parallel workers for fetching descriptions (default: 5)",
    )


def _extract_urls(file_path: str) -> list[str]:
    """Extract URLs from markdown file, only from skill repos section."""
    urls = []
    if not os.path.exists(file_path):
        root_path = os.path.join(os.getcwd(), file_path)
        if os.path.exists(root_path):
            file_path = root_path
        else:
            print(f"Error: File {file_path} not found.")
            return []

    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
        
    repo_section_match = re.search(
        r"# skill repos(.*?)(?=\n##|$)", 
        content, 
        re.DOTALL | re.IGNORECASE
    )
    if repo_section_match:
        section_content = repo_section_match.group(1)
        urls = re.findall(r'https?://[^\s\)]+', section_content)
    else:
        print("Warning: Section '# skill repos' not found in file.")
    
    # Deduplicate URLs while preserving order
    seen = set()
    unique_urls = []
    for url in urls:
        if url not in seen:
            seen.add(url)
            unique_urls.append(url)
    return unique_urls


def _get_github_repo_info(url: str):
    """Extract owner and repo from a GitHub URL."""
    match = re.search(r"github\.com/([^/]+)/([^/]+)", url)
    if match:
        owner = match.group(1)
        repo = match.group(2).replace(".git", "")
        return owner, repo
    return None


def _get_github_repo_branch(owner: str, repo: str, headers: dict) -> str:
    """Get the default branch for a GitHub repository."""
    api_url = f"https://api.github.com/repos/{owner}/{repo}"
    result = _make_request(api_url, headers)
    if result:
        return result.get("default_branch", "main")
    return "main"


def _fetch_repo_tree(owner: str, repo: str, headers: dict) -> list[dict]:
    """Fetch entire repository tree using Git Tree API (single request).
    
    This is much more efficient than Contents API which requires
    multiple requests for nested directories.
    """
    api_url = f"https://api.github.com/repos/{owner}/{repo}/git/trees/HEAD?recursive=1"
    
    result = _make_request(api_url, headers)
    if result and "tree" in result:
        return result["tree"]
    return []


def _parse_skills_from_tree(tree: list[dict], owner: str, repo: str, default_branch: str = "main") -> list[dict]:
    """Parse repository tree to find all SKILL.md files."""
    skills = []
    
    for item in tree:
        if item.get("type") != "blob":
            continue
            
        path = item.get("path", "")
        path_lower = path.lower()
        
        if not path_lower.endswith("skill.md"):
            continue
            
        parts = path.split("/")
        
        if len(parts) == 1:
            skill_name = f"{owner}/{repo}"
            skill_url = f"https://github.com/{owner}/{repo}"
            skill_path = ""
        elif len(parts) >= 2 and parts[0].lower() == "skills":
            skill_dir = parts[1] if len(parts) > 1 else ""
            skill_name = f"{owner}/{repo}/{skill_dir}"
            skill_url = f"https://github.com/{owner}/{repo}/tree/{default_branch}/{parts[0]}/{skill_dir}"
            skill_path = f"{parts[0]}/{skill_dir}"
        else:
            skill_name = f"{owner}/{repo}/{path}"
            skill_url = f"https://github.com/{owner}/{repo}/blob/{default_branch}/{path}"
            skill_path = path
            
        raw_url = f"https://raw.githubusercontent.com/{owner}/{repo}/{default_branch}/{path}"
        
        skills.append({
            "name": skill_name,
            "source": "github",
            "url": skill_url,
            "skill_file_url": raw_url,
            "path": skill_path,
            "description": "",
        })
    
    return skills


def _fetch_skill_description(skill_info: dict, headers: dict) -> dict:
    """Fetch and parse SKILL.md to extract description from frontmatter."""
    url = skill_info["skill_file_url"]
    
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10) as response:
            content = response.read().decode('utf-8')
            
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
                                skill_info["description"] = str(desc).replace("\n", " ")
                                return skill_info
                    except Exception:
                        pass
    except Exception:
        pass
    
    skill_info["description"] = "(No description available)"
    return skill_info


def _fetch_github_skills(owner: str, repo: str, headers: dict, workers: int = 5, default_branch: str = "main") -> list[dict]:
    """Fetch skills from a GitHub repository efficiently."""
    print(f"  [GitHub] Scanning {owner}/{repo}...")
    
    tree = _fetch_repo_tree(owner, repo, headers)
    if not tree:
        print(f"    No tree found for {owner}/{repo}")
        return []
    
    skills = _parse_skills_from_tree(tree, owner, repo, default_branch)
    if not skills:
        print(f"    No SKILL.md files found")
        return []
    
    print(f"    Found {len(skills)} skills. Fetching descriptions...")
    
    with ThreadPoolExecutor(max_workers=workers) as executor:
        results = list(executor.map(
            lambda s: _fetch_skill_description(s.copy(), headers),
            skills
        ))
    
    with_desc_count = len([r for r in results if r.get("description") and r["description"] != "(No description available)"])
    print(f"    Completed fetching descriptions for {with_desc_count} skills")
    return results


def _validate_skill_structure(skill: dict) -> list[str]:
    """Validate a skill entry has all required fields."""
    errors = []
    
    required_fields = ["name", "source", "url", "skill_file_url", "description"]
    for field in required_fields:
        if field not in skill or not skill[field]:
            errors.append(f"Missing or empty field: {field}")
    
    if skill.get("name"):
        if "/" not in skill["name"]:
            errors.append(f"Invalid skill name format: {skill['name']} (should contain '/')")
    
    return errors


def _load_index() -> list[dict[str, Any]]:
    """Load existing skills from local index file."""
    index_path = os.path.join(os.getcwd(), "skiller_index.json")
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("skills", [])
        except Exception:
            return []
    return []


def _save_index(skills: list[dict[str, Any]], quiet: bool = False) -> None:
    """Save discovered skills to a local index file.
    
    Args:
        skills: New skills to save
        quiet: If True, suppress "Index updated" message
    """
    index_path = os.path.join(os.getcwd(), "skiller_index.json")
    
    existing_skills = _load_index()
    skill_map = {s["name"]: s for s in existing_skills}
    new_count = 0
    for s in skills:
        if s["name"] not in skill_map:
            new_count += 1
        skill_map[s["name"]] = s
    
    final_skills = sorted(list(skill_map.values()), key=lambda x: x["name"])
    
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump({
            "updated_at": "now",
            "count": len(final_skills),
            "skills": final_skills
        }, f, indent=2)
    
    if not quiet:
        print(f"\nIndex updated. Total skills: {len(final_skills)} (Saved to {index_path})")


def _run(args: argparse.Namespace, config: dict) -> None:
    """Run the crawl command."""
    test_mode = getattr(args, "test", False)
    limit = getattr(args, "limit", 0)
    _load_env()
    print(f"Crawling skills from {args.file}...")
    urls = _extract_urls(args.file)
    
    if not urls:
        print("No URLs found to crawl.")
        return
    
    if limit > 0:
        urls = urls[:limit]
        print(f"Limit: Crawling first {len(urls)} repos only.")
    
    all_discovered_skills = []
    print(f"Found {len(urls)} potential sources. Starting crawl...")
    
    headers = _get_headers()
    
    for i, url in enumerate(urls):
        if i > 0 and args.delay > 0:
            time.sleep(args.delay)
            
        if "github.com" in url:
            info = _get_github_repo_info(url)
            if info:
                owner, repo = info
                default_branch = _get_github_repo_branch(owner, repo, headers)
                discovered = _fetch_github_skills(
                    owner, repo, headers, args.workers, default_branch
                )
                if discovered:
                    all_discovered_skills.extend(discovered)
                    # Save after each repo if not in test mode
                    if not test_mode:
                        _save_index(all_discovered_skills, quiet=True)
                        print(f"  -> Saved to index. Total: {len(all_discovered_skills)} skills")
        else:
            print(f"  [Web] Skipping {url} (Web crawling not yet implemented)")
    
    if not all_discovered_skills:
        print("\nNo skills discovered.")
        return
    
    print(f"\n=== Crawl Complete ===")
    print(f"Total repos scanned: {len(urls)}")
    print(f"Total skills found: {len(all_discovered_skills)}")
    
    validation_errors = []
    for skill in all_discovered_skills:
        errors = _validate_skill_structure(skill)
        if errors:
            validation_errors.extend([
                f"  - {skill.get('name', 'Unknown')}: {', '.join(errors)}"
            ])
    
    if validation_errors:
        print(f"\nValidation warnings ({len(validation_errors)}):")
        for error in validation_errors:
            print(error)
    else:
        print(f"\nAll {len(all_discovered_skills)} skills validated successfully!")
    
    if test_mode:
        print(f"\n=== Test Mode Output ===")
        print(f"Found {len(all_discovered_skills)} skills (NOT SAVED):")
        for skill in all_discovered_skills:
            desc = skill.get('description', '(no description)')[:60]
            print(f"  - {skill['name']}: {desc}...")
        print("\nRun without --test to save these skills to index.")


def _run_interactive(config: dict) -> None:
    """Interactive version of the crawl command."""
    class Args:
        file = "skill-sites.md"
        delay = 0.5
        test = False
        limit = 0
        workers = 5
    _run(Args(), config)


command = Command(
    name="crawl",
    help="Crawl external sites for skills",
    add_arguments=_add_arguments,
    run=_run,
    run_interactive=_run_interactive,
)
