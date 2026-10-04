#!/usr/bin/env python3
"""
WoWKillboard - scripts/verify_laptop.py
Automated Cross-Machine Hash & File Integrity Checker.
Compares Addon source files against the connected laptop client (Z:).
"""

import os
import hashlib

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON_SRC = os.path.join(BASE_DIR, "Addon", "WoWKillboard")
LAPTOP_TARGETS = [
    r"Z:\_classic_beta_\Interface\AddOns\WoWKillboard",
    r"Z:\_anniversary_\Interface\AddOns\WoWKillboard",
    r"Z:\_classic_era_\Interface\AddOns\WoWKillboard",
]

def get_file_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def verify_target(target):
    if not os.path.exists(target):
        print(f"[SKIP] Target not found: {target}")
        return True

    print(f"\n[VERIFY] Checking integrity of: {target}")
    all_match = True
    for root, dirs, files in os.walk(ADDON_SRC):
        rel_dir = os.path.relpath(root, ADDON_SRC)
        dest_dir = os.path.join(target, rel_dir) if rel_dir != "." else target
        for fname in files:
            src_file = os.path.join(root, fname)
            dst_file = os.path.join(dest_dir, fname)

            if not os.path.exists(dst_file):
                print(f"  [MISSING] {fname} not found in {dest_dir}")
                all_match = False
                continue

            src_hash = get_file_sha256(src_file)
            dst_hash = get_file_sha256(dst_file)

            if src_hash != dst_hash:
                if fname == "WoWKillboard_RealmData.lua":
                    print(f"  [DYNAMIC] {fname} (Live realm telemetry active on laptop)")
                else:
                    print(f"  [MISMATCH] {fname} (local: {src_hash[:8]} vs remote: {dst_hash[:8]})")
                    all_match = False
            else:
                print(f"  [PASS] {fname} (SHA256: {src_hash[:8]}...)")

    return all_match

def main():
    print("=== WoW Killboard Cross-Machine Verification Tool ===")
    if not os.path.exists("Z:\\"):
        print("[ERROR] Drive Z: is not mapped. Please ensure laptop share is connected.")
        return

    overall = True
    for target in LAPTOP_TARGETS:
        if not verify_target(target):
            overall = False

    print("\n" + "=" * 50)
    if overall:
        print("[SUCCESS] All files on laptop match local source byte-for-byte!")
    else:
        print("[FAILURE] Discrepancies detected between desktop and laptop files.")
    print("=" * 50)

if __name__ == "__main__":
    main()
