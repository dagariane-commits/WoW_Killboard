#!/usr/bin/env python3
"""
WoWKillboard - sync/watcher.py
Automated SavedVariables Watcher & Parser.
Monitors WTF/Account/<ACCOUNT>/SavedVariables/WoWKillboard.lua,
extracts Killmails, Bounties, and Debt Ledger entries,
and ingests them into the Web Killboard API.
"""

import os
import sys
import time
import json
import re
import argparse
import urllib.request
import urllib.error

class LuaTableParser:
    """Robust tokenizer and recursive-descent parser for WoW SavedVariables Lua tables."""
    
    @staticmethod
    def tokenize(s: str):
        token_spec = [
            ('STRING', r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''),
            ('NUMBER', r'[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?'),
            ('BOOL',   r'\b(?:true|false)\b'),
            ('NIL',    r'\bnil\b'),
            ('IDENT',  r'[a-zA-Z_][a-zA-Z0-9_]*'),
            ('LBRACE', r'\{'),
            ('RBRACE', r'\}'),
            ('LBRACK', r'\['),
            ('RBRACK', r'\]'),
            ('EQUALS', r'='),
            ('COMMA',  r'[,;]'),
            ('COMMENT',r'--[^\n]*'),
            ('SKIP',   r'\s+'),
        ]
        tok_regex = '|'.join('(?P<%s>%s)' % pair for pair in token_spec)
        tokens = []
        for mo in re.finditer(tok_regex, s):
            kind = mo.lastgroup
            if kind in ('SKIP', 'COMMENT'):
                continue
            val = mo.group(kind)
            tokens.append((kind, val))
        return tokens

    @staticmethod
    def parse_tokens(tokens):
        pos = 0

        def peek():
            return tokens[pos] if pos < len(tokens) else (None, None)

        def consume(expected=None):
            nonlocal pos
            if pos >= len(tokens):
                return None, None
            k, v = tokens[pos]
            if expected and k != expected:
                return None, None
            pos += 1
            return k, v

        def parse_val():
            k, v = peek()
            if k == 'STRING':
                consume()
                return v[1:-1].replace(r'\"', '"').replace(r"\'", "'").replace(r'\\', '\\')
            elif k == 'NUMBER':
                consume()
                return float(v) if '.' in v or 'e' in v.lower() else int(v)
            elif k == 'BOOL':
                consume()
                return (v == 'true')
            elif k == 'NIL':
                consume()
                return None
            elif k == 'LBRACE':
                return parse_tbl()
            else:
                consume()
                return v

        def parse_tbl():
            consume('LBRACE')
            res = {}
            arr_idx = 1
            while True:
                k, v = peek()
                if k == 'RBRACE' or k is None:
                    consume('RBRACE')
                    break

                if k == 'LBRACK':
                    consume('LBRACK')
                    key = parse_val()
                    consume('RBRACK')
                    consume('EQUALS')
                    val = parse_val()
                    res[key] = val
                elif k == 'IDENT' and pos + 1 < len(tokens) and tokens[pos+1][0] == 'EQUALS':
                    _, key = consume('IDENT')
                    consume('EQUALS')
                    val = parse_val()
                    res[key] = val
                else:
                    val = parse_val()
                    res[arr_idx] = val
                    arr_idx += 1

                if peek()[0] == 'COMMA':
                    consume('COMMA')
            return res

        # Scan for variable assignments: IDENT = { ... }
        root = {}
        while pos < len(tokens):
            k, v = peek()
            if k == 'IDENT' and pos + 1 < len(tokens) and tokens[pos+1][0] == 'EQUALS':
                var_name = v
                consume('IDENT')
                consume('EQUALS')
                root[var_name] = parse_val()
            else:
                pos += 1
        return root

    @staticmethod
    def parse_string(content: str) -> dict:
        tokens = LuaTableParser.tokenize(content)
        parsed = LuaTableParser.parse_tokens(tokens)
        
        # Flatten WoWKillboardDB if it has a nested "kills" table
        db = parsed.get("WoWKillboardDB", {})
        if isinstance(db, dict):
            if "kills" in db and isinstance(db["kills"], dict):
                parsed["WoWKillboardDB"] = db["kills"]
            if "stats" in db and isinstance(db["stats"], dict):
                parsed["stats"] = db["stats"]
            
        return parsed

class KillboardWatcher:
    def __init__(self, filepath: str, api_url: str = "http://127.0.0.1:8080"):
        self.filepath = filepath
        self.api_url = api_url.rstrip("/")
        self.last_mtime = 0
        self.known_kills = set()
        self.known_events = set()
        self.last_distress_time = 0
        self.warned_missing = False

    def process_file(self) -> int:
        if not os.path.exists(self.filepath):
            if not self.warned_missing:
                print(f"[Watcher] Waiting for '{self.filepath}' to be created by WoW (triggers upon /reload or logout)...")
                self.warned_missing = True
            return 0

        self.warned_missing = False

        mtime = os.path.getmtime(self.filepath)
        if mtime == self.last_mtime:
            return 0

        self.last_mtime = mtime
        print(f"[Watcher] Change detected in {self.filepath} at {time.strftime('%X')}")

        try:
            with open(self.filepath, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
        except Exception as e:
            print(f"[Watcher] Error reading file: {e}")
            return 0

        parsed = LuaTableParser.parse_string(content)
        db_kills = parsed.get("WoWKillboardDB", {})
        bounties = parsed.get("WoWKillboardBounties", {})
        debts = parsed.get("WoWKillboardDebtLedger", {})
        stats = parsed.get("stats", {})

        new_count = 0
        for kill_id, km_data in db_kills.items():
            if kill_id not in self.known_kills:
                if self.upload_kill(kill_id, km_data):
                    self.known_kills.add(kill_id)
                    new_count += 1

        for b_id, b_data in bounties.items():
            self.upload_bounty(b_id, b_data)

        for p_name, d_data in debts.items():
            self.upload_debt(p_name, d_data)

        if stats:
            self.upload_stats(stats)

        # Ingest Call for Backup distress beacons
        distress = parsed.get("WoWKillboardDistress", {})
        if not distress and isinstance(parsed.get("WoWKillboardDB"), dict):
            distress_beacon = parsed.get("WoWKillboardDB", {}).get("distressBeacon")
            if distress_beacon and isinstance(distress_beacon, dict):
                distress = {distress_beacon.get("id", "SOS"): distress_beacon}

        for sos_id, sos_data in distress.items():
            if isinstance(sos_data, dict):
                ts = sos_data.get("timestamp", 0)
                if ts > self.last_distress_time:
                    self.upload_distress(sos_data)
                    self.last_distress_time = ts

        # Ingest Guild Events and Rallies
        events = parsed.get("WoWKillboardEvents", {})
        if not events and isinstance(parsed.get("WoWKillboardDB"), dict):
            events = parsed.get("WoWKillboardDB", {}).get("guildEvents", {})

        for evt_id, evt_data in events.items():
            if evt_id not in self.known_events and isinstance(evt_data, dict):
                if self.upload_event(evt_data):
                    self.known_events.add(evt_id)

        print(f"[Watcher] Synced {new_count} new kills, {len(bounties)} bounties, {len(debts)} debt records.")
        return new_count

    def upload_kill(self, kill_id: str, data: dict) -> bool:
        url = f"{self.api_url}/api/kills"
        killer_data = data.get("killer", {}) if isinstance(data.get("killer"), dict) else {}
        victim_data = data.get("victim", {}) if isinstance(data.get("victim"), dict) else {}
        loc_data = data.get("location", {}) if isinstance(data.get("location"), dict) else {}

        # Format payload structure
        payload = {
            "killId": kill_id,
            "timestamp": data.get("timestamp", int(time.time())),
            "isDuel": bool(data.get("isDuel", False)),
            "isBattleground": bool(data.get("isBattleground", False)),
            "isArena": bool(data.get("isArena", False)),
            "battlegroundName": data.get("battlegroundName", ""),
            "isSolo": bool(data.get("isSolo", True)),
            "attackersCount": data.get("attackersCount", 1),
            "totalDamage": data.get("totalDamage", 0),
            "killer": {
                "name": killer_data.get("name") or data.get("killer_name") or data.get("name") or "Unknown",
                "level": killer_data.get("level") or data.get("killer_level") or data.get("level") or 60,
                "class": killer_data.get("class") or data.get("killer_class") or data.get("class") or "WARRIOR",
                "guild": killer_data.get("guild") or data.get("killer_guild") or data.get("guild") or "None",
                "faction": killer_data.get("faction") or data.get("killer_faction") or data.get("faction") or "Alliance",
                "partySize": killer_data.get("partySize") or data.get("killer_partySize") or 1,
                "damageDone": killer_data.get("damageDone") or data.get("killer_damageDone") or 0,
                "healingDone": killer_data.get("healingDone") or data.get("killer_healingDone") or 0,
            },
            "victim": {
                "name": victim_data.get("name") or data.get("victim_name") or "Unknown",
                "level": victim_data.get("level") or data.get("victim_level") or 60,
                "class": victim_data.get("class") or data.get("victim_class") or "ROGUE",
                "guild": victim_data.get("guild") or data.get("victim_guild") or "None",
                "faction": victim_data.get("faction") or data.get("victim_faction") or "Horde",
                "partySize": victim_data.get("partySize") or data.get("victim_partySize") or 1,
            },
            "location": {
                "mapId": loc_data.get("mapId") or data.get("mapId") or 0,
                "zone": loc_data.get("zone") or data.get("zone") or "Stranglethorn Vale",
                "subZone": loc_data.get("subZone") or data.get("subZone") or "Gurubashi Arena",
                "x": loc_data.get("x") if loc_data.get("x") is not None else data.get("x", 50.0),
                "y": loc_data.get("y") if loc_data.get("y") is not None else data.get("y", 50.0),
            }
        }

        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                return resp.status in (200, 201)
        except Exception as e:
            # If server is not yet running, print gracefully
            print(f"[Watcher] Ingestion notice for {kill_id}: {e}")
            return False

    def upload_bounty(self, b_id: str, data: dict):
        url = f"{self.api_url}/api/bounties"
        payload = {
            "id": b_id,
            "targetName": data.get("targetName", "Unknown"),
            "targetClass": data.get("targetClass", "UNKNOWN"),
            "targetFaction": data.get("targetFaction", "Unknown"),
            "placerName": data.get("placerName", "Unknown"),
            "amountCopper": data.get("amountCopper", 0),
            "amountGold": data.get("amountGold", 0),
            "status": data.get("status", "ACTIVE"),
            "hunterName": data.get("hunterName"),
            "killId": data.get("killId"),
            "timestamp": data.get("timestamp", int(time.time())),
        }
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            urllib.request.urlopen(req, timeout=5)
        except Exception:
            pass

    def upload_debt(self, player_name: str, data: dict):
        url = f"{self.api_url}/api/bounties/debt-ledger"
        payload = {
            "playerName": player_name,
            "creditor": data.get("creditor", "BountyPool"),
            "amountOwedCopper": data.get("amountOwedCopper", 0),
            "principalCopper": data.get("principalCopper", 0),
            "surchargeCopper": data.get("surchargeCopper", 0),
            "status": data.get("status", "OATHBREAKER"),
            "daysInDefault": data.get("daysInDefault", 1),
        }
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            urllib.request.urlopen(req, timeout=5)
        except Exception:
            pass

    def upload_stats(self, stats: dict):
        url = f"{self.api_url}/api/stats"
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(stats).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            urllib.request.urlopen(req, timeout=5)
        except Exception:
            pass

    def upload_distress(self, data: dict) -> bool:
        url = f"{self.api_url}/api/backup/distress"
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(data).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                print(f"[Watcher] 🚨 Broadcasted Call for Backup SOS beacon for {data.get('character_name')} in {data.get('zone')}!")
                return resp.status in (200, 201)
        except Exception as e:
            print(f"[Watcher] Distress upload notice: {e}")
            return False

    def upload_event(self, data: dict) -> bool:
        url = f"{self.api_url}/api/events"
        try:
            req = urllib.request.Request(
                url,
                data=json.dumps(data).encode("utf-8"),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                print(f"[Watcher] ⚔️ Broadcasted Guild Event: {data.get('title')} in {data.get('zone')}!")
                return resp.status in (200, 201)
        except Exception as e:
            print(f"[Watcher] Event upload notice: {e}")
            return False

    def run_daemon(self, poll_interval: float = 3.0):
        print(f"[Watcher] Watching '{self.filepath}' -> API: '{self.api_url}'")
        print("[Watcher] Polling for changes... (Press Ctrl+C to stop)")
        while True:
            try:
                self.process_file()
                time.sleep(poll_interval)
            except KeyboardInterrupt:
                print("\n[Watcher] Stopped.")
                break

def auto_detect_saved_variables() -> str:
    """Scans common Windows directories to locate WoW SavedVariables/WoWKillboard.lua automatically."""
    import glob
    
    candidates = []
    drives = ["C:", "D:", "E:", "F:"]
    branches = ["_*_", "_classic_beta_", "_retail_", "_classic_", "_classic_era_", "_ptr_"]
    
    for drive in drives:
        for branch in branches:
            pattern_no_x86 = f"{drive}/World of Warcraft/{branch}/WTF/Account/*/SavedVariables/WoWKillboard.lua"
            candidates.extend(glob.glob(pattern_no_x86))
            pattern_x86 = f"{drive}/Program Files (x86)/World of Warcraft/{branch}/WTF/Account/*/SavedVariables/WoWKillboard.lua"
            candidates.extend(glob.glob(pattern_x86))
            pattern_direct = f"{drive}/Games/World of Warcraft/{branch}/WTF/Account/*/SavedVariables/WoWKillboard.lua"
            candidates.extend(glob.glob(pattern_direct))

    unique_candidates = list(set(candidates))
    if unique_candidates:
        # Return the most recently modified candidate
        unique_candidates.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        return unique_candidates[0]
        
    # Fallback to local test file
    if os.path.exists("WoWKillboard.lua"):
        return "WoWKillboard.lua"

    return ""

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="WoWKillboard SavedVariables Watcher")
    parser.add_argument("--file", "-f", default="", help="Path to WoWKillboard.lua (auto-detected if omitted)")
    parser.add_argument("--api", "-a", default="http://127.0.0.1:8080", help="Web Killboard API URL")
    parser.add_argument("--once", action="store_true", help="Run once and exit instead of continuous daemon")
    args = parser.parse_args()

    target_file = args.file
    if not target_file:
        detected = auto_detect_saved_variables()
        if detected:
            print(f"[+] Auto-detected WoW SavedVariables: {detected}")
            target_file = detected
        else:
            target_file = "WoWKillboard.lua"
            print(f"[*] Could not auto-detect WoW directory. Defaulting to local: {target_file}")

    watcher = KillboardWatcher(target_file, args.api)
    if args.once:
        watcher.process_file()
    else:
        watcher.run_daemon()

