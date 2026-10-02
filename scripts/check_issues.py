#!/usr/bin/env python3
"""
WoWKillboard - scripts/check_issues.py
Fetches and triages open GitHub issues from the public repository.
"""

import urllib.request
import json
import sys

REPO = "dagariane-commits/WoW_Killboard"
API_URL = f"https://api.github.com/repos/{REPO}/issues?state=open"

def fetch_issues():
    req = urllib.request.Request(API_URL, headers={"User-Agent": "WoWKillboard-Issue-Checker"})
    try:
        with urllib.request.urlopen(req) as resp:
            if resp.status != 200:
                print(f"[ERROR] HTTP {resp.status} from GitHub API")
                return []
            data = json.loads(resp.read().decode("utf-8"))
            return data
    except Exception as e:
        print(f"[ERROR] Failed to fetch issues: {e}")
        return []

def main():
    print(f"=== Checking Open Issues for {REPO} ===")
    issues = fetch_issues()
    if not issues:
        print("No open issues found on GitHub. All clear!")
        return

    print(f"Found {len(issues)} open issue(s):\n")
    for issue in issues:
        # Exclude pull requests
        if "pull_request" in issue:
            continue
        num = issue.get("number")
        title = issue.get("title")
        author = issue.get("user", {}).get("login", "unknown")
        labels = [l.get("name") for l in issue.get("labels", [])]
        body = issue.get("body", "").strip()
        first_line = body.split("\n")[0] if body else "No description"

        print(f"• #{num}: {title} (by @{author})")
        if labels:
            print(f"  Labels: {', '.join(labels)}")
        print(f"  Snippet: {first_line[:100]}...")
        print(f"  URL: {issue.get('html_url')}\n")

if __name__ == "__main__":
    main()
