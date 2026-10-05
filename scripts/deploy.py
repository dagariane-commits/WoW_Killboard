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
    # Local Desktop Clients
    r"D:\World of Warcraft\_classic_beta_\Interface\AddOns\WoWKillboard",
    r"D:\World of Warcraft\_classic_era_\Interface\AddOns\WoWKillboard",
    r"D:\World of Warcraft\_anniversary_\Interface\AddOns\WoWKillboard",
    r"D:\World of Warcraft\_retail_\Interface\AddOns\WoWKillboard",
    # Remote Laptop Clients (via Z:)
    r"Z:\_classic_beta_\Interface\AddOns\WoWKillboard",
    r"Z:\_classic_era_\Interface\AddOns\WoWKillboard",
    r"Z:\_anniversary_\Interface\AddOns\WoWKillboard",
    r"Z:\_retail_\Interface\AddOns\WoWKillboard",
]

def deploy_to_clients():
    synced = 0
    for target in WOW_TARGETS:
        parent_dir = os.path.dirname(target)
        if os.path.exists(parent_dir):
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

    # Synchronize desktop companion binary if laptop share is connected
    laptop_sync_exe = r"Z:\WoWKillboardSync.exe"
    local_sync_exe = os.path.join(BASE_DIR, "WoWKillboardSync.exe")
    if os.path.exists("Z:\\") and os.path.exists(local_sync_exe):
        try:
            shutil.copy2(local_sync_exe, laptop_sync_exe)
            print(f"[DEPLOY] Updated companion binary on laptop: {laptop_sync_exe}")
        except Exception as e:
            print(f"[WARN] Could not update laptop companion binary (process may be running): {e}")

    return synced

def get_addon_version():
    toc_path = os.path.join(ADDON_SRC, "WoWKillboard.toc")
    if os.path.exists(toc_path):
        with open(toc_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("## Version:"):
                    return line.split(":", 1)[1].strip()
    return "1.0.4"

def rebuild_zip():
    version = get_addon_version()
    zip_names = [f"WoWKillboard-v{version}.zip", "WoWKillboard-v1.0.3.zip", "WoWKillboard-v1.0.2.zip", "WoWKillboard-v1.0.1.zip", "WoWKillboard-v1.0.0.zip"]
    
    primary_zip = os.path.join(BASE_DIR, zip_names[0])
    with zipfile.ZipFile(primary_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for root, dirs, files in os.walk(ADDON_SRC):
            for fname in files:
                full_path = os.path.join(root, fname)
                rel_path = os.path.relpath(full_path, ADDON_SRC)
                z.write(full_path, os.path.join("WoWKillboard", rel_path))
    print(f"[BUILD] Rebuilt distribution package: {primary_zip} ({os.path.getsize(primary_zip)} bytes)")

    # Mirror to web/static and build backward-compatible legacy zip
    for z_name in zip_names:
        root_target = os.path.join(BASE_DIR, z_name)
        if root_target != primary_zip:
            shutil.copy2(primary_zip, root_target)
        static_target = os.path.join(BASE_DIR, "web", "static", z_name)
        shutil.copy2(primary_zip, static_target)
        print(f"[BUILD] Mirrored {z_name} to root and web/static")

if __name__ == "__main__":
    print("=== Starting Multi-Client Deployment & Package Build ===")
    deploy_to_clients()
    rebuild_zip()
    print("=== Multi-Client Deployment Complete ===")

