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

# Ensure UTF-8 console output across all Windows terminals
if sys.platform == "win32":
    try:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

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
            if "pveDeaths" in db and isinstance(db["pveDeaths"], dict):
                parsed["pveDeaths"] = db["pveDeaths"]
            if "kills" in db and isinstance(db["kills"], dict):
                parsed["WoWKillboardDB"] = db["kills"]
            if "stats" in db and isinstance(db["stats"], dict):
                parsed["stats"] = db["stats"]
            
        return parsed

class KillboardWatcher:
    def __init__(self, filepath: str, api_urls = None):
        self.filepath = filepath
        if isinstance(api_urls, list):
            self.api_urls = [u.rstrip("/") for u in api_urls if u]
        elif isinstance(api_urls, str) and api_urls:
            self.api_urls = [api_urls.rstrip("/")]
        else:
            self.api_urls = ["http://13.216.102.148", "http://127.0.0.1:8080"]
        self.api_url = ", ".join(self.api_urls)
        self.last_mtime = 0
        self.known_kills = set()
        self.known_pve_deaths = set()
        self.known_events = set()
        self.known_claims = set()
        self.known_bugs = set()
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
        pve_deaths = parsed.get("pveDeaths", {})
        bounties = parsed.get("WoWKillboardBounties", {})
        debts = parsed.get("WoWKillboardDebtLedger", {})
        stats = parsed.get("stats", {})

        new_count = 0
        for kill_id, km_data in db_kills.items():
            if kill_id not in self.known_kills:
                if self.upload_kill(kill_id, km_data):
                    self.known_kills.add(kill_id)
                    new_count += 1

        new_pve_count = 0
        for death_id, death_data in pve_deaths.items():
            if death_id not in self.known_pve_deaths:
                if self.upload_pve_death(death_id, death_data):
                    self.known_pve_deaths.add(death_id)
                    new_pve_count += 1

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

        # Ingest character claim verification tokens
        claim_tokens = parsed.get("WoWKillboardDB", {}).get("claimTokens", {}) if isinstance(parsed.get("WoWKillboardDB"), dict) else {}
        if not claim_tokens and isinstance(parsed.get("claimTokens"), dict):
            claim_tokens = parsed.get("claimTokens")
        for char_name, c_data in claim_tokens.items():
            if isinstance(c_data, dict):
                code = c_data.get("code")
                claim_key = f"{char_name}:{code}"
                if code and claim_key not in self.known_claims:
                    if self.upload_claim_token(char_name, code):
                        self.known_claims.add(claim_key)

        # Ingest Bug Reports for AI Diagnostics
        bug_reports = parsed.get("WoWKillboardDB", {}).get("bugReports", {}) if isinstance(parsed.get("WoWKillboardDB"), dict) else {}
        if not bug_reports and isinstance(parsed.get("bugReports"), dict):
            bug_reports = parsed.get("bugReports")
        new_bugs_count = 0
        for b_id, b_data in bug_reports.items():
            if isinstance(b_data, dict) and b_id not in self.known_bugs:
                if self.upload_bug_report(b_data):
                    self.known_bugs.add(b_id)
                    new_bugs_count += 1

        print(f"[Watcher] Synced {new_count} new kills, {new_pve_count} PvE deaths, {len(bounties)} bounties, {len(debts)} debt records, {new_bugs_count} bug reports.")
        self.sync_realm_data_to_client()
        return new_count

    def upload_pve_death(self, death_id: str, data: dict) -> bool:
        payload = {
            "deathId": death_id,
            "timestamp": data.get("timestamp", int(time.time())),
            "npc": data.get("npc", {}),
            "victim": data.get("victim", {}),
            "location": data.get("location", {})
        }
        any_success = False
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/pve/deaths"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"}
                )
                with urllib.request.urlopen(req, timeout=5) as response:
                    if response.status in (200, 201):
                        any_success = True
            except Exception as e:
                pass
        return any_success

    def upload_kill(self, kill_id: str, data: dict) -> bool:
        killer_data = data.get("killer", {}) if isinstance(data.get("killer"), dict) else {}
        victim_data = data.get("victim", {}) if isinstance(data.get("victim"), dict) else {}
        loc_data = data.get("location", {}) if isinstance(data.get("location"), dict) else {}

        # Format payload structure
        def _clean_lvl(val):
            if val is not None:
                try:
                    iv = int(val)
                    if 0 <= iv <= 85:
                        return iv
                except (ValueError, TypeError):
                    pass
            return 0

        k_raw_lvl = killer_data.get("level") if killer_data.get("level") is not None else (data.get("killer_level") if data.get("killer_level") is not None else data.get("level"))
        v_raw_lvl = victim_data.get("level") if victim_data.get("level") is not None else data.get("victim_level")

        payload = {
            "killId": kill_id,
            "timestamp": data.get("timestamp", int(time.time())),
            "isDuel": bool(data.get("isDuel", False)),
            "isBattleground": bool(data.get("isBattleground", False)),
            "isArena": bool(data.get("isArena", False)),
            "battlegroundName": data.get("battlegroundName", ""),
            "isSolo": bool(data.get("isSolo", False) and data.get("attackersCount", 1) <= 1),
            "attackersCount": data.get("attackersCount", 1),
            "attackers": data.get("attackers", []),
            "totalDamage": data.get("totalDamage", 0),
            "killer": {
                "name": killer_data.get("name") or data.get("killer_name") or data.get("name") or "Unknown",
                "level": _clean_lvl(k_raw_lvl),
                "class": killer_data.get("class") or data.get("killer_class") or data.get("class") or "WARRIOR",
                "guild": killer_data.get("guild") or data.get("killer_guild") or data.get("guild") or "None",
                "faction": killer_data.get("faction") or data.get("killer_faction") or data.get("faction") or "Alliance",
                "partySize": killer_data.get("partySize") or data.get("killer_partySize") or 1,
                "damageDone": killer_data.get("damageDone") or data.get("killer_damageDone") or 0,
                "healingDone": killer_data.get("healingDone") or data.get("killer_healingDone") or 0,
            },
            "victim": {
                "name": victim_data.get("name") or data.get("victim_name") or "Unknown",
                "level": _clean_lvl(v_raw_lvl),
                "class": victim_data.get("class") or data.get("victim_class") or "ROGUE",
                "guild": victim_data.get("guild") or data.get("victim_guild") or "None",
                "faction": victim_data.get("faction") or data.get("victim_faction") or "Horde",
                "partySize": victim_data.get("partySize") or data.get("victim_partySize") or 1,
            },
            "location": {
                "mapId": loc_data.get("mapId") or data.get("mapId") or 0,
                "zone": loc_data.get("zone") or data.get("zone") or "Unknown Zone",
                "subZone": loc_data.get("subZone") if loc_data.get("subZone") is not None else (data.get("subZone") or ""),
                "x": loc_data.get("x") if loc_data.get("x") is not None else data.get("x", 50.0),
                "y": loc_data.get("y") if loc_data.get("y") is not None else data.get("y", 50.0),
            }
        }

        any_success = False
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/kills"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    if resp.status in (200, 201):
                        any_success = True
            except urllib.error.HTTPError as e:
                err_detail = ""
                try:
                    raw_err = e.read().decode("utf-8", errors="replace")
                    err_obj = json.loads(raw_err)
                    err_detail = f" - {err_obj.get('error') or ''} {err_obj.get('tip') or ''}".strip()
                except Exception:
                    pass
                print(f"[Watcher] Notice for {kill_id} -> {endpoint}: {e}{err_detail}")
            except Exception as e:
                print(f"[Watcher] Notice for {kill_id} -> {endpoint}: {e}")
        return any_success

    def upload_bounty(self, b_id: str, data: dict):
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
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/bounties"
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
        payload = {
            "playerName": player_name,
            "creditor": data.get("creditor", "BountyPool"),
            "amountOwedCopper": data.get("amountOwedCopper", 0),
            "principalCopper": data.get("principalCopper", 0),
            "surchargeCopper": data.get("surchargeCopper", 0),
            "status": data.get("status", "OATHBREAKER"),
            "daysInDefault": data.get("daysInDefault", 1),
        }
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/bounties/debt-ledger"
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
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/stats"
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
        any_success = False
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/backup/distress"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(data).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    print(f"[Watcher] [SOS] Broadcasted Call for Backup SOS beacon for {data.get('character_name')} in {data.get('zone')} to {endpoint}!")
                    if resp.status in (200, 201):
                        any_success = True
            except Exception as e:
                print(f"[Watcher] Distress upload notice for {endpoint}: {e}")
        return any_success

    def upload_event(self, data: dict) -> bool:
        any_success = False
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/events"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(data).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    print(f"[Watcher] [EVENT] Broadcasted Guild Event: {data.get('title')} in {data.get('zone')} to {endpoint}!")
                    if resp.status in (200, 201):
                        any_success = True
            except Exception as e:
                print(f"[Watcher] Event upload notice for {endpoint}: {e}")
        return any_success

    def upload_claim_token(self, character_name: str, code: str) -> bool:
        payload = {
            "name": character_name,
            "code": code
        }
        any_success = False
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/auth/verify-claim"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    if resp.status in (200, 201):
                        print(f"[Watcher] [CLAIM] Verified ownership for '{character_name}' on {endpoint} via in-game token {code}!")
                        any_success = True
            except Exception as e:
                pass
        return any_success

    def upload_bug_report(self, bug_data: dict) -> bool:
        any_success = False
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/bugs"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(bug_data).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                with urllib.request.urlopen(req, timeout=8) as resp:
                    if resp.status in (200, 201):
                        res_json = json.loads(resp.read().decode("utf-8"))
                        diag = res_json.get("diagnosis", {})
                        sev = diag.get("severity", "ANALYZED")
                        print(f"[Watcher] [BUG DISPATCH] Ticket {bug_data.get('id')} submitted to AI Diagnostician on {endpoint}! Severity: {sev}")
                        any_success = True
            except Exception as e:
                pass
        return any_success

    def sync_realm_data_to_client(self) -> bool:
        """Fetches /api/realm/summary and writes WoWKillboard_RealmData.lua into AddOn and SavedVariables dirs."""
        summary = None
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/realm/summary"
            try:
                req = urllib.request.Request(url, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                with urllib.request.urlopen(req, timeout=4) as resp:
                    if resp.status == 200:
                        summary = json.loads(resp.read().decode("utf-8"))
                        break
            except Exception:
                pass

        if not summary:
            return False

        carnage = int(summary.get("RealmTotalCarnage", 0))
        solo_ratio = float(summary.get("SoloRatio", 0.0))
        faction_split = summary.get("FactionSplit", {"Alliance": 50, "Horde": 50})
        a_split = float(faction_split.get("Alliance", 50))
        h_split = float(faction_split.get("Horde", 50))

        deadliest_zones = summary.get("DeadliestZones", [])
        top_gankers = summary.get("TopGankers24h", [])

        lua_lines = [
            "-- WoWKillboard_RealmData.lua",
            "-- Automated Realm Intelligence generated by WoWKillboardSync",
            "WoWKillboard_RealmData = {",
            f"    RealmTotalCarnage = {carnage},",
            f"    SoloRatio = {solo_ratio},",
            "    FactionSplit = {",
            f"        Alliance = {a_split},",
            f"        Horde = {h_split},",
            "    },",
            "    DeadliestZones = {",
        ]
        for z in deadliest_zones:
            z_name = str(z.get("zone", "")).replace('"', '\\"')
            z_kills = int(z.get("kills", 0))
            lua_lines.append(f'        {{ zone = "{z_name}", kills = {z_kills} }},')
        lua_lines.append("    },")

        lua_lines.append("    TopGankers24h = {")
        for g in top_gankers:
            g_name = str(g.get("name", "")).replace('"', '\\"')
            g_cls = str(g.get("class", "WARRIOR")).replace('"', '\\"')
            g_fac = str(g.get("faction", "Alliance")).replace('"', '\\"')
            g_gld = str(g.get("guild", "")).replace('"', '\\"')
            g_kills = int(g.get("kills", 0))
            lua_lines.append(f'        {{ name = "{g_name}", class = "{g_cls}", faction = "{g_fac}", guild = "{g_gld}", kills = {g_kills} }},')
        lua_lines.append("    },")
        lua_lines.append(f"    LastSync = {int(time.time())},")
        lua_lines.append("}")
        lua_content = "\n".join(lua_lines) + "\n"

        target_paths = []
        if self.filepath:
            sv_dir = os.path.dirname(os.path.abspath(self.filepath))
            if os.path.exists(sv_dir):
                target_paths.append(os.path.join(sv_dir, "WoWKillboard_RealmData.lua"))
                wow_flavor_dir = os.path.abspath(os.path.join(sv_dir, "..", "..", ".."))
                addon_dir = os.path.join(wow_flavor_dir, "Interface", "AddOns", "WoWKillboard")
                if os.path.exists(addon_dir):
                    target_paths.append(os.path.join(addon_dir, "WoWKillboard_RealmData.lua"))

        local_repo_addon = os.path.join("Addon", "WoWKillboard", "WoWKillboard_RealmData.lua")
        if os.path.exists(os.path.dirname(local_repo_addon)):
            target_paths.append(local_repo_addon)

        import glob
        drives = ["D:", "C:", "E:"]
        flavors = ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_"]
        for d in drives:
            for flv in flavors:
                p = f"{d}/World of Warcraft/{flv}/Interface/AddOns/WoWKillboard/WoWKillboard_RealmData.lua"
                if os.path.exists(os.path.dirname(p)):
                    target_paths.append(p)
                for sv in glob.glob(f"{d}/World of Warcraft/{flv}/WTF/Account/*/SavedVariables"):
                    target_paths.append(os.path.join(sv, "WoWKillboard_RealmData.lua"))

        written = 0
        for tp in set(target_paths):
            try:
                with open(tp, "w", encoding="utf-8") as f:
                    f.write(lua_content)
                written += 1
            except Exception:
                pass

        if written > 0:
            print(f"[Watcher] [2-WAY SYNC] Injected realm telemetry payload (WoWKillboard_RealmData.lua) into {written} location(s).")
        return True

    def run_daemon(self, poll_interval: float = 3.0):
        print(f"[Watcher] Watching '{self.filepath}' -> APIs: {', '.join(self.api_urls)}")
        print("[Watcher] Polling for changes... (Press Ctrl+C to stop)")
        self.sync_realm_data_to_client()
        last_realm_sync = time.time()
        while True:
            try:
                self.process_file()
                if time.time() - last_realm_sync > 30.0:
                    self.sync_realm_data_to_client()
                    last_realm_sync = time.time()
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

SYNC_VERSION = "1.0.0-beta.3"
DEFAULT_PROD_URL = "http://13.216.102.148"
DEFAULT_LOCAL_URL = "http://127.0.0.1:8080"

def resolve_api_endpoints(cli_arg: str = None, force_local: bool = False, force_cloud: bool = False) -> list:
    """Resolves target API endpoints: cloud, local, or dual broadcasting."""
    if cli_arg:
        return [cli_arg.rstrip("/")]
    if force_local:
        return [DEFAULT_LOCAL_URL]
    if force_cloud:
        return [DEFAULT_PROD_URL]

    # Check environment variable
    env_url = os.environ.get("WOWKB_API_URL")
    if env_url:
        return [env_url.rstrip("/")]

    # Check local config file next to executable / script
    base_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
    config_file = os.path.join(base_dir, "wowkb_sync_config.json")
    if os.path.exists(config_file):
        try:
            with open(config_file, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                if cfg.get("api_url"):
                    return [cfg["api_url"].rstrip("/")]
        except Exception:
            pass

    # Default to dual broadcasting: Cloud Render + Local Server (if reachable)
    endpoints = [DEFAULT_PROD_URL]
    try:
        req = urllib.request.Request(f"{DEFAULT_LOCAL_URL}/api/health", headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
        with urllib.request.urlopen(req, timeout=0.6) as resp:
            if resp.status in (200, 201):
                endpoints.append(DEFAULT_LOCAL_URL)
    except Exception:
        pass

    return endpoints

if __name__ == "__main__":
    print("=" * 64)
    print(f"  [WoW Killboard] Desktop Sync Client v{SYNC_VERSION}")
    print("  Automated Combat Telemetry & Marks of Spite Ingestion")
    print("=" * 64)

    parser = argparse.ArgumentParser(description="WoWKillboard SavedVariables Watcher")
    parser.add_argument("--file", "-f", default="", help="Path to WoWKillboard.lua (auto-detected if omitted)")
    parser.add_argument("--api", "-a", default="", help="Web Killboard API URL (defaults to dual sync)")
    parser.add_argument("--local", action="store_true", help="Force local development endpoint only (http://127.0.0.1:8080)")
    parser.add_argument("--cloud", "--render", action="store_true", help="Force cloud production endpoint only (http://13.216.102.148)")
    parser.add_argument("--once", action="store_true", help="Run once and exit instead of continuous daemon")
    args = parser.parse_args()

    target_apis = resolve_api_endpoints(args.api, force_local=args.local, force_cloud=getattr(args, 'cloud', False))
    print(f"[*] Ingestion Target APIs: {', '.join(target_apis)}")

    target_file = args.file
    if not target_file:
        detected = auto_detect_saved_variables()
        if detected:
            print(f"[+] Auto-detected WoW SavedVariables: {detected}")
            target_file = detected
        else:
            target_file = "WoWKillboard.lua"
            print(f"[*] Could not auto-detect WoW directory. Defaulting to local: {target_file}")

    watcher = KillboardWatcher(target_file, target_apis)
    if args.once:
        watcher.process_file()
    else:
        watcher.run_daemon()

