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
            for fname in os.listdir(ADDON_SRC):
                s_path = os.path.join(ADDON_SRC, fname)
                t_path = os.path.join(target, fname)
                if os.path.isfile(s_path):
                    shutil.copy2(s_path, t_path)
            print(f"[DEPLOY] Successfully synced to: {target}")
            synced += 1
        else:
            print(f"[SKIP] Target directory not found: {target}")
    return synced

def rebuild_zip():
    zip_path = os.path.join(BASE_DIR, "WoWKillboard-v1.0.0.zip")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for fname in os.listdir(ADDON_SRC):
            full_path = os.path.join(ADDON_SRC, fname)
            if os.path.isfile(full_path):
                z.write(full_path, os.path.join("WoWKillboard", fname))
    print(f"[BUILD] Rebuilt distribution package: {zip_path} ({os.path.getsize(zip_path)} bytes)")

if __name__ == "__main__":
    print("=== Starting Multi-Client Deployment & Package Build ===")
    deploy_to_clients()
    rebuild_zip()
    print("=== Multi-Client Deployment Complete ===")
