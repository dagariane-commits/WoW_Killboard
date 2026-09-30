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

def log_event(msg: str):
    """Logs message to both standard output and persistent wowkb_sync.log."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    formatted = f"[{timestamp}] {msg}"
    print(formatted)
    try:
        base_dir = os.path.dirname(os.path.abspath(sys.argv[0]))
        log_path = os.path.join(base_dir, "wowkb_sync.log")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(formatted + "\n")
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
            parsed["rawWoWKillboardDB"] = db
            if "pveDeaths" in db and isinstance(db["pveDeaths"], dict):
                parsed["pveDeaths"] = db["pveDeaths"]
            if "claimTokens" in db and isinstance(db["claimTokens"], dict):
                parsed["claimTokens"] = db["claimTokens"]
            if "bugReports" in db and isinstance(db["bugReports"], dict):
                parsed["bugReports"] = db["bugReports"]
            if "guildEvents" in db and isinstance(db["guildEvents"], dict):
                parsed["guildEvents"] = db["guildEvents"]
            if "distressBeacon" in db and isinstance(db["distressBeacon"], dict):
                parsed["distressBeacon"] = db["distressBeacon"]
            if "lastManualSync" in db:
                parsed["lastManualSync"] = db["lastManualSync"]
            if "stats" in db and isinstance(db["stats"], dict):
                parsed["stats"] = db["stats"]
            if "kills" in db and isinstance(db["kills"], dict):
                parsed["WoWKillboardDB"] = db["kills"]
            
        return parsed

def serialize_to_lua(val, indent=1) -> str:
    """Serializes Python datatypes to syntactically clean, robust Lua literal representation."""
    ind = "    " * indent
    if val is None:
        return "nil"
    elif isinstance(val, bool):
        return "true" if val else "false"
    elif isinstance(val, (int, float)):
        if isinstance(val, float) and val.is_integer():
            return str(int(val))
        return str(val)
    elif isinstance(val, str):
        esc = val.replace('\\', '\\\\').replace('"', '\\"').replace('\r', '').replace('\n', '\\n')
        return f'"{esc}"'
    elif isinstance(val, list):
        if not val:
            return "{}"
        lines = ["{"]
        for item in val:
            lines.append(f"{ind}    {serialize_to_lua(item, indent + 1)},")
        lines.append(f"{ind}}}")
        return "\n".join(lines)
    elif isinstance(val, dict):
        if not val:
            return "{}"
        lines = ["{"]
        for k, v in val.items():
            if isinstance(k, int):
                k_repr = f"[{k}]"
            elif isinstance(k, str) and k.isidentifier() and k not in ('and','break','do','else','elseif','end','false','for','function','goto','if','in','local','nil','not','or','repeat','return','then','true','until','while'):
                k_repr = k
            else:
                esc_k = str(k).replace('\\', '\\\\').replace('"', '\\"')
                k_repr = f'["{esc_k}"]'
            lines.append(f"{ind}    {k_repr} = {serialize_to_lua(v, indent + 1)},")
        lines.append(f"{ind}}}")
        return "\n".join(lines)
    return '""'

class KillboardWatcher:
    def __init__(self, filepaths, api_urls = None):
        if isinstance(filepaths, str):
            self.filepaths = [os.path.abspath(filepaths).replace("\\", "/")] if filepaths else []
        elif isinstance(filepaths, (list, set, tuple)):
            self.filepaths = [os.path.abspath(p).replace("\\", "/") for p in filepaths if p]
        else:
            self.filepaths = []

        if isinstance(api_urls, list):
            self.api_urls = [u.rstrip("/") for u in api_urls if u]
        elif isinstance(api_urls, str) and api_urls:
            self.api_urls = [api_urls.rstrip("/")]
        else:
            self.api_urls = ["http://13.216.102.148", "http://127.0.0.1:8080"]
        self.api_url = ", ".join(self.api_urls)
        self.filepath = self.filepaths[0] if self.filepaths else ""

        self.file_mtimes = {}
        self.last_manual_syncs = {}
        self.known_kills = set()
        self.known_pve_deaths = set()
        self.known_events = set()
        self.known_claims = set()
        self.known_bugs = set()
        self.last_distress_time = 0
        self.warned_missing = set()

    def _client_tag(self, path: str) -> str:
        """Extracts human-readable client flavor and account name from a path."""
        norm = path.replace("\\", "/")
        parts = norm.split("/")
        flavor = "WoW"
        account = "Default"
        for i, p in enumerate(parts):
            if p.startswith("_") and p.endswith("_"):
                flavor = p
            if p.lower() == "account" and i + 1 < len(parts):
                account = parts[i + 1]
        return f"{flavor}/{account}"

    def process_file(self, target_path: str = None) -> int:
        if target_path is None:
            total_synced = 0
            for p in list(self.filepaths):
                total_synced += self.process_file(p)
            return total_synced

        filepath = os.path.abspath(target_path).replace("\\", "/")
        if not os.path.exists(filepath):
            if filepath not in self.warned_missing:
                log_event(f"[Watcher] Waiting for '{filepath}' to be created by WoW (triggers upon /reload or logout)...")
                self.warned_missing.add(filepath)
            return 0

        self.warned_missing.discard(filepath)

        mtime = os.path.getmtime(filepath)
        if mtime == self.file_mtimes.get(filepath, 0):
            return 0

        self.file_mtimes[filepath] = mtime
        client_tag = self._client_tag(filepath)
        log_event(f"[Watcher] Change detected in [{client_tag}] ({filepath}) at {time.strftime('%X')}")

        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
        except Exception as e:
            log_event(f"[Watcher] Error reading {filepath}: {e}")
            return 0

        parsed = LuaTableParser.parse_string(content)
        raw_db = parsed.get("rawWoWKillboardDB", parsed.get("WoWKillboardDB", {}))
        manual_sync_ts = parsed.get("lastManualSync", 0) or (raw_db.get("lastManualSync", 0) if isinstance(raw_db, dict) else 0)

        db_kills = parsed.get("WoWKillboardDB", {})
        pve_deaths = parsed.get("pveDeaths", {})
        bounties = parsed.get("WoWKillboardBounties", {})
        debts = parsed.get("WoWKillboardDebtLedger", {})
        stats = parsed.get("stats", {})

        is_manual_sync = False
        if manual_sync_ts and manual_sync_ts > self.last_manual_syncs.get(filepath, 0):
            is_manual_sync = True
            self.last_manual_syncs[filepath] = manual_sync_ts
            log_event(f"[Watcher] [Manual Sync] In-game 'Sync' button / reload confirmed for [{client_tag}] (Heartbeat TS: {manual_sync_ts})!")

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
        if not distress and isinstance(raw_db, dict):
            distress_beacon = raw_db.get("distressBeacon")
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
        if not events and isinstance(raw_db, dict):
            events = raw_db.get("guildEvents", {})

        for evt_id, evt_data in events.items():
            if evt_id not in self.known_events and isinstance(evt_data, dict):
                if self.upload_event(evt_data):
                    self.known_events.add(evt_id)

        # Ingest character claim verification tokens
        claim_tokens = parsed.get("claimTokens", {})
        if not claim_tokens and isinstance(raw_db, dict):
            claim_tokens = raw_db.get("claimTokens", {})
        new_claims_count = 0
        for char_name, c_data in claim_tokens.items():
            if isinstance(c_data, dict):
                code = c_data.get("code")
            else:
                code = str(c_data) if c_data else None
            claim_key = f"{char_name}:{code}"
            if code and claim_key not in self.known_claims:
                if self.upload_claim_token(char_name, code):
                    self.known_claims.add(claim_key)
                    new_claims_count += 1

        # Ingest Bug Reports for AI Diagnostics
        bug_reports = parsed.get("bugReports", {})
        if not bug_reports and isinstance(raw_db, dict):
            bug_reports = raw_db.get("bugReports", {})
        new_bugs_count = 0
        for b_id, b_data in bug_reports.items():
            if isinstance(b_data, dict) and b_id not in self.known_bugs:
                if self.upload_bug_report(b_data):
                    self.known_bugs.add(b_id)
                    new_bugs_count += 1

        sync_summary = f"[Watcher] [{client_tag}] Synced: {new_count} new kills, {new_pve_count} PvE deaths, {len(bounties)} bounties, {len(debts)} debts, {new_claims_count} claims, {new_bugs_count} bug reports"
        if is_manual_sync:
            sync_summary += " [Manual Sync Heartbeat OK]"
        log_event(sync_summary)
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
                        log_event(f"[Watcher] [CLAIM] Verified ownership for '{character_name}' on {endpoint} via in-game token {code}!")
                        any_success = True
            except urllib.error.HTTPError as e:
                err_msg = ""
                try:
                    err_json = json.loads(e.read().decode("utf-8"))
                    err_msg = err_json.get("error", "")
                except Exception:
                    pass
                msg_suffix = f": {err_msg}" if err_msg else ""
                log_event(f"[Watcher] [CLAIM ERROR] Failed to verify '{character_name}' on {endpoint} (HTTP {e.code}{msg_suffix})")
            except Exception as e:
                if "127.0.0.1" not in endpoint:
                    log_event(f"[Watcher] [CLAIM NOTICE] Could not verify '{character_name}' on {endpoint}: {e}")
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
        """Fetches /api/realm/summary, /api/kills, and /api/bounties, merges local kills across accounts, and writes WoWKillboard_RealmData.lua."""
        summary = None
        recent_kills = []
        active_bounties = []

        for endpoint in self.api_urls:
            # 1. Fetch summary
            if not summary:
                url = f"{endpoint}/api/realm/summary"
                try:
                    req = urllib.request.Request(url, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                    with urllib.request.urlopen(req, timeout=4) as resp:
                        if resp.status == 200:
                            summary = json.loads(resp.read().decode("utf-8"))
                except Exception:
                    pass

            # 2. Fetch recent kills (up to 60)
            if not recent_kills:
                url_kills = f"{endpoint}/api/kills?limit=60"
                try:
                    req = urllib.request.Request(url_kills, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                    with urllib.request.urlopen(req, timeout=5) as resp:
                        if resp.status == 200:
                            k_data = json.loads(resp.read().decode("utf-8"))
                            recent_kills = k_data.get("kills", [])
                except Exception:
                    pass

            # 3. Fetch active bounties
            if not active_bounties:
                url_bnt = f"{endpoint}/api/bounties"
                try:
                    req = urllib.request.Request(url_bnt, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                    with urllib.request.urlopen(req, timeout=4) as resp:
                        if resp.status == 200:
                            b_data = json.loads(resp.read().decode("utf-8"))
                            if isinstance(b_data, list):
                                active_bounties = b_data
                            elif isinstance(b_data, dict):
                                active_bounties = b_data.get("bounties", [])
                except Exception:
                    pass

        # Also merge local kills from all monitored accounts on this machine
        # (guarantees cross-account sharing even offline or before remote indexing)
        known_kill_ids = set()
        for k in recent_kills:
            if isinstance(k, dict) and k.get("killId"):
                known_kill_ids.add(k["killId"])

        for fp in getattr(self, "filepaths", []):
            if os.path.exists(fp):
                try:
                    with open(fp, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read()
                    parsed = LuaTableParser.parse_string(content)
                    db_kills = parsed.get("WoWKillboardDB", {})
                    if isinstance(db_kills, dict):
                        for kid, km in db_kills.items():
                            if kid not in known_kill_ids and isinstance(km, dict):
                                km_copy = dict(km)
                                if "killId" not in km_copy:
                                    km_copy["killId"] = kid
                                recent_kills.append(km_copy)
                                known_kill_ids.add(kid)
                    # Also merge local bounties if any
                    local_bounties = parsed.get("WoWKillboardBounties", {})
                    if isinstance(local_bounties, dict):
                        known_bnt_ids = set(b.get("id") or b.get("bountyId") for b in active_bounties if isinstance(b, dict))
                        for bid, bnt in local_bounties.items():
                            if bid not in known_bnt_ids and isinstance(bnt, dict) and bnt.get("status") == "ACTIVE":
                                b_copy = dict(bnt)
                                if "id" not in b_copy:
                                    b_copy["id"] = bid
                                active_bounties.append(b_copy)
                                known_bnt_ids.add(bid)
                except Exception:
                    pass

        # Sort recent kills descending by timestamp and cap at 60
        recent_kills.sort(key=lambda x: x.get("timestamp", 0) if isinstance(x, dict) else 0, reverse=True)
        recent_kills = recent_kills[:60]

        carnage = int(summary.get("RealmTotalCarnage", len(recent_kills))) if summary else len(recent_kills)
        solo_ratio = float(summary.get("SoloRatio", 0.0)) if summary else 0.0
        faction_split = summary.get("FactionSplit", {"Alliance": 50, "Horde": 50}) if summary else {"Alliance": 50, "Horde": 50}
        a_split = float(faction_split.get("Alliance", 50))
        h_split = float(faction_split.get("Horde", 50))
        deadliest_zones = summary.get("DeadliestZones", []) if summary else []
        top_gankers = summary.get("TopGankers24h", []) if summary else []

        # If summary was empty or offline, compute basic stats from recent_kills
        if not summary and recent_kills:
            carnage = len(recent_kills)
            solo_count = sum(1 for k in recent_kills if isinstance(k, dict) and k.get("isSolo"))
            solo_ratio = round((solo_count / max(1, carnage)) * 100, 1)

        lua_lines = [
            "-- WoWKillboard_RealmData.lua",
            "-- Automated Realm Intelligence & Two-Way Sync generated by WoWKillboardSync",
            "WoWKillboard_RealmData = {",
            f"    RealmTotalCarnage = {carnage},",
            f"    SoloRatio = {solo_ratio},",
            "    FactionSplit = {",
            f"        Alliance = {a_split},",
            f"        Horde = {h_split},",
            "    },",
            f"    DeadliestZones = {serialize_to_lua(deadliest_zones, 1)},",
            f"    TopGankers24h = {serialize_to_lua(top_gankers, 1)},",
            f"    RecentKills = {serialize_to_lua(recent_kills, 1)},",
            f"    ActiveBounties = {serialize_to_lua(active_bounties, 1)},",
            f"    LastSync = {int(time.time())},",
            "}",
        ]
        lua_content = "\n".join(lua_lines) + "\n"

        target_paths = []
        for fp in getattr(self, "filepaths", [self.filepath] if getattr(self, "filepath", None) else []):
            sv_dir = os.path.dirname(os.path.abspath(fp))
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
            log_event(f"[Watcher] [2-WAY SYNC] Injected realm telemetry payload (WoWKillboard_RealmData.lua) with {len(recent_kills)} kills and {len(active_bounties)} bounties into {written} location(s).")
        return True

    def run_daemon(self, poll_interval: float = 2.0):
        log_event(f"[Watcher] Starting Universal Multi-Client Watcher daemon (Polling every {poll_interval}s)...")
        log_event(f"[Watcher] Target Ingestion APIs: {', '.join(self.api_urls)}")
        log_event(f"[Watcher] Actively monitoring {len(self.filepaths)} SavedVariables file(s) across all WoW flavors/accounts:")
        for p in self.filepaths:
            log_event(f"   -> [{self._client_tag(p)}] {p}")

        # Initial pass across all files
        for p in list(self.filepaths):
            self.process_file(p)
        self.sync_realm_data_to_client()

        last_discovery = time.time()
        last_realm_sync = time.time()

        while True:
            try:
                # 1. Process all monitored files
                for p in list(self.filepaths):
                    self.process_file(p)

                # 2. Periodic rescan every 15s to discover new accounts or client flavors
                if time.time() - last_discovery > 15.0:
                    current_set = set(self.filepaths)
                    all_found = set(find_all_saved_variables())
                    new_paths = all_found - current_set
                    if new_paths:
                        for np in new_paths:
                            log_event(f"[Watcher] Discovered new active WoW account / flavor: [{self._client_tag(np)}] {np}")
                            self.filepaths.append(np)
                            self.process_file(np)
                    last_discovery = time.time()

                # 3. Two-way realm data sync every 30s
                if time.time() - last_realm_sync > 30.0:
                    self.sync_realm_data_to_client()
                    last_realm_sync = time.time()

                time.sleep(poll_interval)
            except KeyboardInterrupt:
                log_event("\n[Watcher] Stopped by user.")
                break

def find_all_saved_variables() -> list:
    """Scans all connected Windows drives and WoW client branches for all active SavedVariables/WoWKillboard.lua files."""
    import glob
    candidates = []
    drives = ["C:", "D:", "E:", "F:"]
    branches = ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_", "_ptr_", "_classic_", "_*"]

    for drive in drives:
        for branch in branches:
            pattern_no_x86 = f"{drive}/World of Warcraft/{branch}/WTF/Account/*/SavedVariables/WoWKillboard.lua"
            candidates.extend(glob.glob(pattern_no_x86))
            pattern_x86 = f"{drive}/Program Files (x86)/World of Warcraft/{branch}/WTF/Account/*/SavedVariables/WoWKillboard.lua"
            candidates.extend(glob.glob(pattern_x86))
            pattern_direct = f"{drive}/Games/World of Warcraft/{branch}/WTF/Account/*/SavedVariables/WoWKillboard.lua"
            candidates.extend(glob.glob(pattern_direct))

    unique = sorted(list(set(os.path.abspath(p).replace("\\", "/") for p in candidates)))
    return unique

def auto_detect_saved_variables() -> str:
    """Returns the single most recently modified SavedVariables file (for backward compatibility)."""
    all_files = find_all_saved_variables()
    if all_files:
        all_files.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        return all_files[0]
    if os.path.exists("WoWKillboard.lua"):
        return os.path.abspath("WoWKillboard.lua").replace("\\", "/")
    return ""

SYNC_VERSION = "1.0.0-beta.5"
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

    # Default to dual broadcasting: Cloud Lightsail + Local Server (if reachable)
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
    print(f"  [WoW Killboard] Universal Multi-Client Sync v{SYNC_VERSION}")
    print("  Automated Combat Telemetry & Marks of Spite Ingestion")
    print("=" * 64)

    parser = argparse.ArgumentParser(description="WoWKillboard SavedVariables Watcher")
    parser.add_argument("--file", "-f", default="", help="Path to WoWKillboard.lua (monitors ALL clients if omitted)")
    parser.add_argument("--api", "-a", default="", help="Web Killboard API URL (defaults to production)")
    parser.add_argument("--local", action="store_true", help="Force local development endpoint only (http://127.0.0.1:8080)")
    parser.add_argument("--cloud", "--render", action="store_true", help="Force cloud production endpoint only (http://13.216.102.148)")
    parser.add_argument("--once", action="store_true", help="Run once and exit instead of continuous daemon")
    args = parser.parse_args()

    target_apis = resolve_api_endpoints(args.api, force_local=args.local, force_cloud=getattr(args, 'cloud', False))
    print(f"[*] Ingestion Target APIs: {', '.join(target_apis)}")

    target_file = args.file
    if target_file:
        target_files = [os.path.abspath(target_file).replace("\\", "/")]
        log_event(f"[*] Monitoring user-specified file: {target_files[0]}")
    else:
        target_files = find_all_saved_variables()
        if target_files:
            log_event(f"[+] Discovered {len(target_files)} active WoW client/account SavedVariables:")
            for tf in target_files:
                log_event(f"    - {tf}")
        else:
            fallback = auto_detect_saved_variables()
            target_files = [fallback] if fallback else ["WoWKillboard.lua"]
            log_event(f"[*] Could not auto-detect active WoW directory. Defaulting to: {target_files[0]}")

    watcher = KillboardWatcher(target_files, target_apis)
    if args.once:
        watcher.process_file()
        watcher.sync_realm_data_to_client()
    else:
        watcher.run_daemon()

