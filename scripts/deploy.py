#!/usr/bin/env python3
"""
WoWKillboard - scripts/deploy.py
Automated Multi-Client Deployment & Package Build Tool.
Synchronizes Addon files to all local WoW client flavors:
  - WoW Forever Beta (_classic_beta_)
  - Classic Era (_classic_era_)
  - Anniversary (_anniversary_)
  - Retail (_retail_)
Rebuilds distribution package (WoWKillboard-v1.0.0.zip).
"""

import os
import shutil
import zipfile

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON_SRC = os.path.join(BASE_DIR, "Addon", "WoWKillboard")

WOW_TARGETS = [
    r"D:\World of Warcraft\_classic_beta_\Interface\AddOns\WoWKillboard",
    r"D:\World of Warcraft\_classic_era_\Interface\AddOns\WoWKillboard",
    r"D:\World of Warcraft\_anniversary_\Interface\AddOns\WoWKillboard",
    r"D:\World of Warcraft\_retail_\Interface\AddOns\WoWKillboard",
]

def deploy_to_clients():
    synced = 0
    for target in WOW_TARGETS:
        if os.path.exists(target):
            for root, dirs, files in os.walk(ADDON_SRC):
                rel_dir = os.path.relpath(root, ADDON_SRC)
                dest_dir = os.path.join(target, rel_dir) if rel_dir != "." else target
                os.makedirs(dest_dir, exist_ok=True)
                for fname in files:
                    s_path = os.path.join(root, fname)
                    t_path = os.path.join(dest_dir, fname)
                    shutil.copy2(s_path, t_path)
            print(f"[DEPLOY] Successfully synced to: {target}")
            synced += 1
        else:
            print(f"[SKIP] Target directory not found: {target}")
    return synced

def rebuild_zip():
    zip_path = os.path.join(BASE_DIR, "WoWKillboard-v1.0.0.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk(ADDON_SRC):
            for fname in files:
                full_path = os.path.join(root, fname)
                rel_path = os.path.relpath(full_path, ADDON_SRC)
                z.write(full_path, os.path.join("WoWKillboard", rel_path))
    print(f"[BUILD] Rebuilt distribution package: {zip_path} ({os.path.getsize(zip_path)} bytes)")
    static_zip = os.path.join(BASE_DIR, "web", "static", "WoWKillboard-v1.0.0.zip")
    shutil.copy2(zip_path, static_zip)
    print(f"[BUILD] Mirrored distribution package to web/static: {static_zip}")

def sync_to_gdrive_folder():
    gdrive_dir = os.path.join(BASE_DIR, "WoW KB Beta")
    os.makedirs(gdrive_dir, exist_ok=True)
    
    # 1. Copy zip
    zip_path = os.path.join(BASE_DIR, "WoWKillboard-v1.0.0.zip")
    if os.path.exists(zip_path):
        shutil.copy2(zip_path, os.path.join(gdrive_dir, "WoWKillboard-v1.0.0.zip"))
        
    # 2. Copy exe
    exe_path = os.path.join(BASE_DIR, "WoWKillboardSync.exe")
    if os.path.exists(exe_path):
        shutil.copy2(exe_path, os.path.join(gdrive_dir, "WoWKillboardSync.exe"))
        
    # 3. Copy README.txt
    readme_txt = os.path.join(BASE_DIR, "README_GOOGLE_DRIVE.txt")
    if os.path.exists(readme_txt):
        shutil.copy2(readme_txt, os.path.join(gdrive_dir, "README.txt"))
        
    # 4. Copy README.md
    readme_md = os.path.join(BASE_DIR, "README_GOOGLE_DRIVE.md")
    if os.path.exists(readme_md):
        shutil.copy2(readme_md, os.path.join(gdrive_dir, "README.md"))
        
    print(f"[GDRIVE] Synced complete distribution suite to: {gdrive_dir}")

if __name__ == "__main__":
    print("=== Starting Multi-Client Deployment & Package Build ===")
    deploy_to_clients()
    rebuild_zip()
    sync_to_gdrive_folder()
    print("=== Multi-Client Deployment Complete ===")

