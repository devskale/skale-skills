#!/usr/bin/env python3
"""Quick RAM + timing benchmark for CloakBrowser."""
import time
import subprocess
import sys
import os

def get_rss_kb(pattern="chrome|chromium|cloak"):
    """Get total RSS in KB for matching processes (macOS/Linux)."""
    try:
        result = subprocess.run(
            ["ps", "-eo", "rss=,comm="],
            capture_output=True, text=True, timeout=5
        )
        total = 0
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split(None, 1)
            if len(parts) >= 2:
                rss = int(parts[0])
                comm = parts[1].lower()
                if any(p in comm for p in pattern.split("|")):
                    total += rss
        return total
    except Exception:
        return 0

def count_procs(pattern="chrome"):
    try:
        result = subprocess.run(
            ["ps", "-eo", "comm="],
            capture_output=True, text=True, timeout=5
        )
        return sum(1 for line in result.stdout.strip().split("\n") 
                   if line and pattern.lower() in line.lower())
    except:
        return 0

print("═══════════════════════════════════════════════════════")
print("  CLOAKBROWSER RAM & PERFORMANCE BENCHMARK")
print("═══════════════════════════════════════════════════════")

from cloakbrowser import launch

URLS = [
    ("https://example.com", "static page"),
    ("https://github.com", "JS-heavy site"),
]

for url, desc in URLS:
    print(f"\n━━━ {desc}: {url} ━━━")
    
    # Baseline
    baseline_rss = get_rss_kb("chrom")
    baseline_cnt = count_procs("chrom")
    
    # Launch headless
    t0 = time.perf_counter()
    browser = launch(headless=True)
    t_launch = (time.perf_counter() - t0) * 1000
    
    time.sleep(0.5)
    post_launch_rss = get_rss_kb("chrom")
    post_launch_cnt = count_procs("chrom")
    
    # Navigate
    page = browser.new_page()
    t0 = time.perf_counter()
    page.goto(url, wait_until="domcontentloaded", timeout=30000)
    t_nav = (time.perf_counter() - t0) * 1000
    
    page.wait_for_timeout(3000)  # let JS settle
    
    post_nav_rss = get_rss_kb("chrom")
    post_nav_cnt = count_procs("chrom")
    
    # Snapshot / extract text
    t0 = time.perf_counter()
    title = page.title()
    body_text = page.evaluate("document.body?.innerText?.substring(0, 200) || ''")
    t_extract = (time.perf_counter() - t0) * 1000
    
    # Click something
    t0 = time.perf_counter()
    try:
        link = page.query_selector("a") or page.query_selector("h1")
        if link:
            link.click()
            t_click = (time.perf_counter() - t0) * 1000
        else:
            t_click = 0
    except:
        t_click = (time.perf_counter() - t0) * 1000
    
    # Final RAM
    final_rss = get_rss_kb("chrom")
    final_cnt = count_procs("chrom")
    
    print(f"  launch:          {t_launch:.0f} ms")
    print(f"  navigate:        {t_nav:.0f} ms")
    print(f"  text extract:    {t_extract:.0f} ms  ({len(body_text)} chars)")
    print(f"  click:           {t_click:.0f} ms")
    print(f"  title:           '{title}'")
    print()
    print(f"  RAM after launch:  {post_launch_rss:,} KB  (+{post_launch_rss - baseline_rss:,} KB)")
    print(f"  RAM after nav:     {post_nav_rss:,} KB  (+{post_nav_rss - baseline_rss:,} KB)")
    print(f"  RAM final:         {final_rss:,} KB  ({final_rss / 1024:.1f} MB)")
    print(f"  Chrome procs:      {final_cnt}  (+{final_cnt - baseline_cnt})")
    
    browser.close()
    time.sleep(1)

# Also test with humanize mode (more overhead)
print(f"\n━━━ HUMANIZE MODE: example.com ━━━")
baseline_rss = get_rss_kb("chrom")

t0 = time.perf_counter()
browser = launch(headless=True, humanize=True)
t_launch = (time.perf_counter() - t0) * 1000

page = browser.new_page()
page.goto("https://example.com", wait_until="domcontentloaded", timeout=30000)
page.wait_for_timeout(2000)

humanize_rss = get_rss_kb("chrom")
humanize_cnt = count_procs("chrom")

print(f"  launch+nav:      {t_launch:.0f} ms")
print(f"  RAM:              {humanize_rss:,} KB  ({humanize_rss / 1024:.1f} MB)  (+{humanize_rss - baseline_rss:,} KB)")
print(f"  Chrome procs:     {humanize_cnt}")

browser.close()

print("\n═══════════════════════════════════════════════════════")
print("  DONE")
print("═══════════════════════════════════════════════════════")
