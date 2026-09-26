#!/usr/bin/env python3
"""
WoWKillboard - scripts/backup.py
Automated Full Project Backup & Snapshot Tool.
Packages all source code, configs, addon lua, docs, web app, tests,
and database artifacts into a compressed archive under backups/.
Excludes ephemeral artifacts (.git, build, dist, __pycache__, cloudflared.exe).
"""

import os
import sys
import zipfile
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKUPS_DIR = os.path.join(BASE_DIR, "backups")

EXCLUDE_DIRS = {
    ".git",
    "backups",
    "build",
    "dist",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
}

EXCLUDE_FILES = {
    "cloudflared.exe",
}

EXCLUDE_EXTENSIONS = {
    ".pyc",
    ".pyo",
}

def create_backup():
    os.makedirs(BACKUPS_DIR, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"WoW_Killboard_full_backup_{timestamp}.zip"
    backup_path = os.path.join(BACKUPS_DIR, backup_filename)

    print(f"=== Creating Full Project Backup: {backup_filename} ===")
    
    file_count = 0
    total_uncompressed = 0

    with zipfile.ZipFile(backup_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zipf:
        for root, dirs, files in os.walk(BASE_DIR):
            # Prune excluded directories
            dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
            
            for file in files:
                if file in EXCLUDE_FILES:
                    continue
                ext = os.path.splitext(file)[1].lower()
                if ext in EXCLUDE_EXTENSIONS:
                    continue
                
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, BASE_DIR)
                
                try:
                    file_size = os.path.getsize(full_path)
                    zipf.write(full_path, rel_path)
                    file_count += 1
                    total_uncompressed += file_size
                except Exception as e:
                    print(f"[WARN] Could not package {rel_path}: {e}")

    compressed_size = os.path.getsize(backup_path)
    ratio = (1 - (compressed_size / total_uncompressed)) * 100 if total_uncompressed > 0 else 0

    print(f"[SUCCESS] Packaged {file_count} files.")
    print(f"[STATS] Raw Size: {total_uncompressed / (1024 * 1024):.2f} MB")
    print(f"[STATS] Compressed Size: {compressed_size / (1024 * 1024):.2f} MB ({ratio:.1f}% reduction)")
    print(f"[OUTPUT] {backup_path}")
    return backup_path

if __name__ == "__main__":
    create_backup()
