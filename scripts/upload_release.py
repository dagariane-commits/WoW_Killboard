import os
import sys
import json
import urllib.request
import subprocess

def get_github_token():
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        return token
    try:
        proc = subprocess.run(
            ["git", "credential", "fill"],
            input="protocol=https\nhost=github.com\n",
            capture_output=True,
            text=True,
            check=True
        )
        for line in proc.stdout.splitlines():
            if line.startswith("password="):
                return line.split("=", 1)[1].strip()
    except Exception as e:
        print(f"Could not retrieve token via git credential: {e}")
    return None

def main():
    token = get_github_token()
    if not token:
        print("Error: No GitHub token found via environment or git credential helper.")
        sys.exit(1)
    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'WoWKillboard-Release-Script'
    }

    # 1. Check if release already exists for v1.0.5
    req = urllib.request.Request(
        'https://api.github.com/repos/dagariane-commits/WoW_Killboard/releases/tags/v1.0.5',
        headers=headers
    )
    release = None
    try:
        with urllib.request.urlopen(req) as resp:
            release = json.loads(resp.read().decode('utf-8'))
            print(f"Found existing release v1.0.5 with ID: {release['id']}")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print("Release v1.0.5 does not exist yet. Creating...")
        else:
            print(f"Error checking release: {e.code} {e.read().decode('utf-8')}")
            return

    if not release:
        data = {
            'tag_name': 'v1.0.5',
            'name': 'v1.0.5: Cross-Client Combat Hardening, Responsive Navigation & Multi-Character Roster',
            'body': 'Official Release v1.0.5\n\n- Zero Blizzard UI Taint Hardening: Strict InCombatLockdown gating on player death routines, chat broadcasts, and guild info checks eliminates Action Blocked popups\n- Responsive Navigation Suite: Fluid flex layout, 1180px adaptive navigation breakpoint, mobile slide-in drawer, and unclipped touch controls\n- Multi-Character Realm Roster: Seamless operative switching, custom realm mains (⭐ Main), and dedicated combat stats tracking across all characters\n- Mode-Specific Leaderboards: Dedicated combat columns for World (Kills, Solo, K/D), BGs, Duels (W/L), and Arenas\n- Economy & Marked Overhaul: Formatted G / S / C currency displays and unified bounty contract highlights\n- Desktop Companion Synchronizer v1.0.5',
            'draft': False,
            'prerelease': False
        }
        create_req = urllib.request.Request(
            'https://api.github.com/repos/dagariane-commits/WoW_Killboard/releases',
            data=json.dumps(data).encode('utf-8'),
            headers=headers,
            method='POST'
        )
        try:
            with urllib.request.urlopen(create_req) as resp:
                release = json.loads(resp.read().decode('utf-8'))
                print(f"Created release v1.0.5 with ID: {release['id']}")
        except urllib.error.HTTPError as e:
            print(f"HTTP Error creating release: {e.code} {e.read().decode('utf-8')}")
            return

    release_id = release['id']
    upload_url_template = release['upload_url'].split('{')[0]

    # Existing asset names
    existing_assets = {a['name']: a['id'] for a in release.get('assets', [])}
    print(f"Existing assets for v1.0.5: {list(existing_assets.keys())}")

    assets_to_upload = [
        ('WoWKillboard-v1.0.5.zip', 'application/zip'),
        ('WoWKillboard-v1.0.4.zip', 'application/zip'),
        ('WoWKillboardSync.exe', 'application/vnd.microsoft.portable-executable')
    ]

    for fname, content_type in assets_to_upload:
        if not os.path.exists(fname):
            print(f"File not found: {fname}")
            continue

        if fname in existing_assets:
            print(f"Asset {fname} already exists on v1.0.3 (ID: {existing_assets[fname]}). Deleting old asset...")
            del_req = urllib.request.Request(
                f"https://api.github.com/repos/dagariane-commits/WoW_Killboard/releases/assets/{existing_assets[fname]}",
                headers=headers,
                method='DELETE'
            )
            with urllib.request.urlopen(del_req) as del_resp:
                print(f"Deleted old {fname} asset (status: {del_resp.status})")

        print(f"Uploading {fname} ({os.path.getsize(fname)} bytes)...")
        with open(fname, 'rb') as f:
            file_data = f.read()

        upload_req = urllib.request.Request(
            f"{upload_url_template}?name={fname}",
            data=file_data,
            headers={
                'Authorization': f'token {token}',
                'Content-Type': content_type,
                'User-Agent': 'WoWKillboard-Release-Script'
            },
            method='POST'
        )
        with urllib.request.urlopen(upload_req) as up_resp:
            res_asset = json.loads(up_resp.read().decode('utf-8'))
            print(f"Uploaded {fname} successfully! Download URL: {res_asset.get('browser_download_url')}")

    print("All release assets uploaded successfully!")

if __name__ == '__main__':
    main()
