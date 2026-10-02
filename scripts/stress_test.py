#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WoWKillboard - scripts/stress_test.py
Comprehensive End-to-End Stress Testing & Performance Benchmark Suite.

Tests:
1. Lua SavedVariables Parser Benchmark (100 to 5,000 kill records)
2. Desktop Sync Ingestion & Deduplication Cache Benchmark
3. REST API & SQLite WAL Database Concurrency & Throughput Stress Test
4. In-Game Addon Performance & Taint Telemetry Guide
"""

import os
import sys
import time
import json
import random
import argparse
import threading
import statistics
import concurrent.futures
import urllib.request
import urllib.error

# Add parent directory to path so sync & web modules can be imported
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PROJECT_ROOT not in sys.path:
    sys.path.insert(0, PROJECT_ROOT)

from sync.watcher import LuaTableParser

# Character & Zone metadata for realistic synthetic test data
CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]
ALLIANCE_RACES = ["Human", "Dwarf", "NightElf", "Gnome"]
HORDE_RACES = ["Orc", "Undead", "Tauren", "Troll"]
ZONES = [
    {"mapId": 1421, "zone": "Silverpine Forest", "subZone": "The Sepulcher", "x": 43.5, "y": 40.2},
    {"mapId": 1424, "zone": "Hillsbrad Foothills", "subZone": "Southshore", "x": 50.1, "y": 57.4},
    {"mapId": 1417, "zone": "Arathi Highlands", "subZone": "Refuge Pointe", "x": 46.8, "y": 45.2},
    {"mapId": 1448, "zone": "Stranglethorn Vale", "subZone": "Booty Bay", "x": 27.4, "y": 77.1},
    {"mapId": 1445, "zone": "Blackrock Mountain", "subZone": "Blackrock Spire", "x": 48.0, "y": 35.0},
    {"mapId": 1453, "zone": "Warsong Gulch", "subZone": "Silverwing Hold", "x": 50.0, "y": 50.0},
]
GUILDS_A = ["Ironclad Vanguard", "Silver Hand", "Defias Resistance", "Gnomish Mechanics"]
GUILDS_H = ["Grim Syndicate", "Warsong Outriders", "Frostwolf Clan", "Shadowfang Council"]


def generate_synthetic_kill(kill_index: int, now: int = None) -> dict:
    """Generate a realistic, cryptographically consistent synthetic kill record."""
    if now is None:
        now = int(time.time())
    
    is_alliance_killer = (kill_index % 2 == 1)
    k_faction = "Alliance" if is_alliance_killer else "Horde"
    v_faction = "Horde" if is_alliance_killer else "Alliance"
    
    k_race = random.choice(ALLIANCE_RACES if is_alliance_killer else HORDE_RACES)
    v_race = random.choice(HORDE_RACES if is_alliance_killer else ALLIANCE_RACES)
    
    k_class = random.choice(CLASSES)
    v_class = random.choice(CLASSES)
    
    k_guild = random.choice(GUILDS_A if is_alliance_killer else GUILDS_H)
    v_guild = random.choice(GUILDS_H if is_alliance_killer else GUILDS_A)
    
    loc = random.choice(ZONES)
    dmg = random.randint(800, 4200)
    is_solo = (kill_index % 3 != 0)
    attackers_count = 1 if is_solo else random.randint(2, 5)
    
    ts = now - (10000 - kill_index * 15)
    kill_id = f"stress_{kill_index}_{ts}_{hex(abs(hash((ts, kill_index, k_class, v_class))))[2:10]}"
    
    return {
        "killId": kill_id,
        "timestamp": ts,
        "isSolo": is_solo,
        "isBattleground": (loc["mapId"] == 1453),
        "isArena": False,
        "isDuel": False,
        "battlegroundName": "Warsong Gulch" if loc["mapId"] == 1453 else "",
        "attackersCount": attackers_count,
        "totalDamage": dmg,
        "killer": {
            "guid": f"Player-STRESS-{1000 + kill_index}",
            "name": f"Striker_{kill_index % 50}",
            "level": 60,
            "class": k_class,
            "race": k_race,
            "guild": k_guild,
            "faction": k_faction,
            "partySize": 1,
            "damageDone": dmg,
            "healingDone": int(dmg * 0.15) if k_class in ["PALADIN", "PRIEST", "SHAMAN", "DRUID"] else 0,
        },
        "victim": {
            "guid": f"Player-TARGET-{5000 + kill_index}",
            "name": f"Victim_{kill_index % 75}",
            "level": random.randint(55, 60),
            "class": v_class,
            "race": v_race,
            "guild": v_guild,
            "faction": v_faction,
            "partySize": 1,
        },
        "location": {
            "mapId": loc["mapId"],
            "zone": loc["zone"],
            "subZone": loc["subZone"],
            "x": round(loc["x"] + random.uniform(-0.5, 0.5), 1),
            "y": round(loc["y"] + random.uniform(-0.5, 0.5), 1),
        },
        "attackers": [
            {
                "guid": f"Player-STRESS-{1000 + kill_index}",
                "name": f"Striker_{kill_index % 50}",
                "class": k_class,
                "level": 60,
                "guild": k_guild,
                "faction": k_faction,
                "damage": dmg,
                "spell": "Attack",
                "isPlayer": True,
            }
        ],
    }


def generate_saved_variables_lua(num_kills: int) -> str:
    """Generate valid SavedVariables Lua format matching WoW's native output."""
    lines = ["WoWKillboardDB = {", '    ["kills"] = {']
    now = int(time.time())
    
    for i in range(num_kills):
        k = generate_synthetic_kill(i, now)
        k_id = k["killId"]
        lines.append(f'        ["{k_id}"] = {{')
        lines.append(f'            ["killId"] = "{k_id}",')
        lines.append(f'            ["timestamp"] = {k["timestamp"]},')
        lines.append(f'            ["isSolo"] = {"true" if k["isSolo"] else "false"},')
        lines.append(f'            ["isBattleground"] = {"true" if k["isBattleground"] else "false"},')
        lines.append(f'            ["isArena"] = false,')
        lines.append(f'            ["isDuel"] = false,')
        lines.append(f'            ["attackersCount"] = {k["attackersCount"]},')
        lines.append(f'            ["totalDamage"] = {k["totalDamage"]},')
        
        # Killer table
        kr = k["killer"]
        lines.append('            ["killer"] = {')
        lines.append(f'                ["guid"] = "{kr["guid"]}",')
        lines.append(f'                ["name"] = "{kr["name"]}",')
        lines.append(f'                ["level"] = {kr["level"]},')
        lines.append(f'                ["class"] = "{kr["class"]}",')
        lines.append(f'                ["guild"] = "{kr["guild"]}",')
        lines.append(f'                ["faction"] = "{kr["faction"]}",')
        lines.append(f'                ["partySize"] = {kr["partySize"]},')
        lines.append(f'                ["damageDone"] = {kr["damageDone"]},')
        lines.append(f'                ["healingDone"] = {kr["healingDone"]},')
        lines.append('            },')
        
        # Victim table
        vic = k["victim"]
        lines.append('            ["victim"] = {')
        lines.append(f'                ["guid"] = "{vic["guid"]}",')
        lines.append(f'                ["name"] = "{vic["name"]}",')
        lines.append(f'                ["level"] = {vic["level"]},')
        lines.append(f'                ["class"] = "{vic["class"]}",')
        lines.append(f'                ["guild"] = "{vic["guild"]}",')
        lines.append(f'                ["faction"] = "{vic["faction"]}",')
        lines.append(f'                ["partySize"] = {vic["partySize"]},')
        lines.append('            },')
        
        # Location table
        loc = k["location"]
        lines.append('            ["location"] = {')
        lines.append(f'                ["mapId"] = {loc["mapId"]},')
        lines.append(f'                ["zone"] = "{loc["zone"]}",')
        lines.append(f'                ["subZone"] = "{loc["subZone"]}",')
        lines.append(f'                ["x"] = {loc["x"]},')
        lines.append(f'                ["y"] = {loc["y"]},')
        lines.append('            },')
        
        lines.append('        },')
        
    lines.append('    },')
    lines.append('    ["stats"] = {')
    lines.append('        ["duels"] = { ["wins"] = 10, ["losses"] = 3 },')
    lines.append('        ["bgs"] = { ["wins"] = 25, ["losses"] = 8 },')
    lines.append('        ["arenas"] = { ["wins"] = 0, ["losses"] = 0 },')
    lines.append('    },')
    lines.append('}')
    return "\n".join(lines)


# ==============================================================================
# BENCHMARK 1: LUA TABLE PARSER STRESS TEST
# ==============================================================================
def benchmark_parser(counts=[100, 500, 1000, 2500]):
    """Benchmark LuaTableParser against escalating SavedVariables payloads."""
    print("\n" + "=" * 70)
    print("  [BENCHMARK 1] SavedVariables LuaTableParser Stress Benchmark")
    print("=" * 70)
    print(f"{'Records':<10} | {'Payload Size':<14} | {'Parse Time':<12} | {'Throughput':<16} | {'Status'}")
    print("-" * 70)
    
    for count in counts:
        lua_str = generate_saved_variables_lua(count)
        size_kb = len(lua_str.encode("utf-8")) / 1024.0
        
        t0 = time.perf_counter()
        parsed = LuaTableParser.parse_string(lua_str)
        elapsed_ms = (time.perf_counter() - t0) * 1000.0
        
        db_val = parsed.get("WoWKillboardDB", {})
        if isinstance(db_val, dict) and "kills" in db_val:
            kills = db_val["kills"]
        elif isinstance(db_val, dict):
            kills = db_val
        else:
            kills = {}
            
        parsed_count = len(kills)
        rps = (parsed_count / (elapsed_ms / 1000.0)) if elapsed_ms > 0 else 0
        
        status = "[PASS]" if parsed_count == count else f"[FAIL] Got {parsed_count}"
        print(f"{count:<10} | {size_kb:>8.1f} KB    | {elapsed_ms:>8.2f} ms  | {rps:>10.0f} rec/s | {status}")

    print("=" * 70)


# ==============================================================================
# BENCHMARK 2: REST API & DATABASE CONCURRENCY STRESS TEST
# ==============================================================================
def benchmark_api_concurrency(target_url: str, concurrency: int = 15, total_requests: int = 100, mode: str = "mixed"):
    """
    Stress test HTTP REST API & SQLite database under concurrent worker bursts.
    Modes:
      - 'write': Concurrent POST /api/kills
      - 'read': Concurrent GET /api/kills, /api/realm/summary, /api/leaderboard
      - 'mixed': 50% concurrent POST writes + 50% concurrent GET reads
    """
    print("\n" + "=" * 70)
    print("  [BENCHMARK 2] REST API & SQLite Database Concurrency Benchmark")
    print(f"  Target: {target_url} | Concurrency: {concurrency} workers | Total: {total_requests} reqs | Mode: {mode.upper()}")
    print("=" * 70)
    
    # Verify server connectivity first
    try:
        health_req = urllib.request.Request(f"{target_url}/api/health", headers={"User-Agent": "WoWKillboard-StressTester/1.0"})
        with urllib.request.urlopen(health_req, timeout=5.0) as resp:
            health_data = json.loads(resp.read().decode("utf-8"))
            print(f"[*] Connected to server: Version {health_data.get('version', 'unknown')} | Status: {health_data.get('status', 'ok')}")
    except Exception as e:
        print(f"[ERROR] Unable to reach {target_url}/api/health: {e}")
        print("Please start the web server (python web/server.py) or check remote connectivity.")
        return False
        
    latencies = []
    status_counts = {}
    lock_errors = 0
    now = int(time.time())
    
    def worker(index: int):
        nonlocal lock_errors
        is_write = (mode == "write") or (mode == "mixed" and (index % 2 == 0))
        req_start = time.perf_counter()
        
        try:
            if is_write:
                payload = generate_synthetic_kill(index + 90000, now)
                data_bytes = json.dumps(payload).encode("utf-8")
                req = urllib.request.Request(
                    f"{target_url}/api/kills",
                    data=data_bytes,
                    headers={"Content-Type": "application/json", "User-Agent": "WoWKillboard-StressTester/1.0"},
                    method="POST"
                )
            else:
                endpoints = [
                    f"{target_url}/api/kills?limit=25",
                    f"{target_url}/api/realm/summary",
                    f"{target_url}/api/leaderboard",
                    f"{target_url}/api/bounties"
                ]
                chosen_ep = endpoints[index % len(endpoints)]
                req = urllib.request.Request(
                    chosen_ep,
                    headers={"User-Agent": "WoWKillboard-StressTester/1.0"}
                )
                
            with urllib.request.urlopen(req, timeout=10.0) as resp:
                code = resp.status
                resp.read() # consume body
                elapsed_ms = (time.perf_counter() - req_start) * 1000.0
                return (code, elapsed_ms, None)
        except urllib.error.HTTPError as he:
            elapsed_ms = (time.perf_counter() - req_start) * 1000.0
            body = he.read().decode("utf-8", errors="replace")
            if "locked" in body.lower():
                lock_errors += 1
            return (he.code, elapsed_ms, body)
        except Exception as ex:
            elapsed_ms = (time.perf_counter() - req_start) * 1000.0
            return (599, elapsed_ms, str(ex))

    bench_start = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(worker, i) for i in range(total_requests)]
        for f in concurrent.futures.as_completed(futures):
            code, lat, err = f.result()
            latencies.append(lat)
            status_counts[code] = status_counts.get(code, 0) + 1

    bench_total_sec = time.perf_counter() - bench_start
    overall_rps = total_requests / bench_total_sec if bench_total_sec > 0 else 0

    # Calculate statistics
    latencies.sort()
    avg_lat = statistics.mean(latencies) if latencies else 0
    p50_lat = latencies[int(len(latencies) * 0.50)] if latencies else 0
    p90_lat = latencies[int(len(latencies) * 0.90)] if latencies else 0
    p95_lat = latencies[int(len(latencies) * 0.95)] if latencies else 0
    p99_lat = latencies[int(len(latencies) * 0.99)] if latencies else 0
    min_lat = latencies[0] if latencies else 0
    max_lat = latencies[-1] if latencies else 0
    
    success_count = sum(cnt for code, cnt in status_counts.items() if 200 <= code < 300)
    success_rate = (success_count / total_requests) * 100.0 if total_requests > 0 else 0

    print(f"\n[*] Execution Finished in {bench_total_sec:.2f} seconds")
    print(f"    - Requests:     {total_requests} total ({success_count} success, {total_requests - success_count} failed)")
    print(f"    - Success Rate: {success_rate:.1f}%")
    print(f"    - Throughput:   {overall_rps:.1f} Requests / Second (RPS)")
    print(f"    - DB Lock Err:  {lock_errors} lock contention errors")
    print(f"    - Status Codes: {dict(status_counts)}")
    print("\n[*] Latency Distribution (Round-Trip Time):")
    print(f"    - Min: {min_lat:.1f} ms | Avg: {avg_lat:.1f} ms | Max: {max_lat:.1f} ms")
    print(f"    - P50 (Median): {p50_lat:.1f} ms")
    print(f"    - P90:          {p90_lat:.1f} ms")
    print(f"    - P95:          {p95_lat:.1f} ms")
    print(f"    - P99:          {p99_lat:.1f} ms")
    print("=" * 70)
    return True


# ==============================================================================
# IN-GAME ADDON STRESS TESTING GUIDE
# ==============================================================================
def print_addon_stress_guide():
    """Print in-game combat testing instructions and macros."""
    print("\n" + "=" * 70)
    print("  [BENCHMARK 3] In-Game WoW Client Addon Stress Testing Protocol")
    print("=" * 70)
    print("""
1. Single Instant Burst (Generates 50 kills in 1 frame, benchmarks execution):
   Type in game chat:
   /kb stress 50

   Observe:
   - Chat output: Injected 50 kills in X.XX ms (Addon Mem: XXX KB).
   - Zero frame rate drops or Blizzard UI ActionBlocked popups.
   - Kill feed in /kb will display all 50 recorded kills.

2. Heavy Frontline Zerg Macro (Injects 100 kills across simulated 40v40 combat):
   /kb stress 100

3. Addon Memory & Garbage Collection Inspection:
   /run UpdateAddOnMemoryUsage(); print("[WoWKB Mem]", math.floor(GetAddOnMemoryUsage("WoWKillboard")), "KB")

4. Purge All Stress Testing Records:
   /kb reset
""")
    print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description="WoWKillboard Stress Testing & Performance Benchmark Suite")
    parser.add_argument("--mode", choices=["all", "parser", "api", "addon"], default="all",
                        help="Benchmark suite to run (default: all)")
    parser.add_argument("--target", default="http://127.0.0.1:8080",
                        help="Target API URL for API stress testing (e.g. https://wowkillboard.com or http://127.0.0.1:8080)")
    parser.add_argument("--concurrency", type=int, default=15,
                        help="Number of concurrent worker threads for API load test (default: 15)")
    parser.add_argument("--requests", type=int, default=100,
                        help="Total requests for API load test (default: 100)")
    parser.add_argument("--api-mode", choices=["mixed", "write", "read"], default="mixed",
                        help="API load test traffic distribution (default: mixed)")
    args = parser.parse_args()

    print("================================================================")
    print("       WoW Killboard — Telemetry Stress Benchmark Suite")
    print("================================================================")

    if args.mode in ["all", "parser"]:
        benchmark_parser([100, 500, 1000, 2500])

    if args.mode in ["all", "api"]:
        benchmark_api_concurrency(
            target_url=args.target,
            concurrency=args.concurrency,
            total_requests=args.requests,
            mode=args.api_mode
        )

    if args.mode in ["all", "addon"]:
        print_addon_stress_guide()


if __name__ == "__main__":
    main()
