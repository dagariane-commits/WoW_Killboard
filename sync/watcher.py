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
import ssl

try:
    from sync import gui as sync_gui
except ImportError:
    try:
        import gui as sync_gui
    except ImportError:
        sync_gui = None

SYNC_VERSION = "1.0.3"

def safe_urlopen(req, timeout=5):
    """Executes urllib.request.urlopen with User-Agent and verified TLS/SSL context."""
    if isinstance(req, str):
        req = urllib.request.Request(req, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
    elif isinstance(req, urllib.request.Request):
        if not req.has_header("User-Agent"):
            req.add_header("User-Agent", f"WoWKillboardSync/{SYNC_VERSION}")

    # Standard verified SSL/TLS context
    ctx = ssl.create_default_context()
    if os.environ.get("WOWKB_INSECURE_SSL") == "1":
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        return urllib.request.urlopen(req, timeout=timeout, context=ctx)

    try:
        return urllib.request.urlopen(req, timeout=timeout, context=ctx)
    except urllib.error.URLError as e:
        err_str = str(e)
        if "certificate verify failed" in err_str and ("certificate has expired" in err_str or "clock skew" in err_str):
            log_event(f"[Watcher] [TLS WARNING] SSL verification failed due to system clock discrepancy: {e}. Falling back.")
            fallback_ctx = ssl.create_default_context()
            fallback_ctx.check_hostname = False
            fallback_ctx.verify_mode = ssl.CERT_NONE
            return urllib.request.urlopen(req, timeout=timeout, context=fallback_ctx)
        raise

# Ensure UTF-8 console output across all Windows terminals
if sys.platform == "win32":
    try:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

LOG_HOOKS = []

def register_log_hook(fn):
    """Registers a callback hook to receive formatted log events."""
    if fn not in LOG_HOOKS:
        LOG_HOOKS.append(fn)

def unregister_log_hook(fn):
    """Removes a callback hook."""
    if fn in LOG_HOOKS:
        LOG_HOOKS.remove(fn)

def get_app_data_dir() -> str:
    """Returns the persistent application data directory (%LOCALAPPDATA%/WoWKillboard or ~/.wowkillboard)."""
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA") or os.path.expanduser("~")
        d = os.path.join(base, "WoWKillboard")
    else:
        d = os.path.join(os.path.expanduser("~"), ".wowkillboard")
    try:
        os.makedirs(d, exist_ok=True)
    except Exception:
        pass
    return d

def get_install_dir() -> str:
    """Returns the target permanent installation folder (%LOCALAPPDATA%/Programs/WoWKillboard)."""
    if sys.platform == "win32":
        base = os.environ.get("LOCALAPPDATA") or os.environ.get("APPDATA") or os.path.expanduser("~")
        return os.path.join(base, "Programs", "WoWKillboard")
    return os.path.join(os.path.expanduser("~"), ".local", "bin", "WoWKillboard")

def create_windows_shortcut(target_exe: str, shortcut_path: str, description: str = "WoW Killboard Desktop Companion") -> bool:
    """Creates a Windows shell shortcut without external process spawning or binary injection."""
    if sys.platform != "win32":
        return False
    try:
        clean_target = os.path.abspath(target_exe)
        base_path = os.path.splitext(shortcut_path)[0]
        url_path = base_path + ".url"
        with open(url_path, "w", encoding="utf-8") as f:
            f.write(f"[InternetShortcut]\nURL=file:///{clean_target.replace(os.sep, '/')}\nIconIndex=0\nIconFile={clean_target}\n")
        return os.path.exists(url_path)
    except Exception:
        return False

def install_application_to_pc(current_exe: str) -> str:
    """Installs the running executable into %LOCALAPPDATA%/Programs/WoWKillboard, creating Desktop & Start Menu shortcuts."""
    import shutil
    install_dir = get_install_dir()
    os.makedirs(install_dir, exist_ok=True)
    target_exe = os.path.join(install_dir, "WoWKillboardSync.exe")

    # If running script directly (not compiled exe)
    if current_exe.endswith(".py"):
        target_exe = current_exe

    # If different paths, copy executable
    if os.path.abspath(current_exe).lower() != os.path.abspath(target_exe).lower():
        try:
            shutil.copy2(current_exe, target_exe)
        except Exception as e:
            log_event(f"[Installer] Error copying executable to install dir: {e}")

    # Create Desktop Shortcut
    desktop = os.path.join(os.environ.get("USERPROFILE", ""), "Desktop")
    if os.path.exists(desktop):
        create_windows_shortcut(target_exe, os.path.join(desktop, "WoW Killboard.lnk"))

    # Create Start Menu Shortcut
    appdata = os.environ.get("APPDATA", "")
    start_menu = os.path.join(appdata, r"Microsoft\Windows\Start Menu\Programs")
    if os.path.exists(start_menu):
        create_windows_shortcut(target_exe, os.path.join(start_menu, "WoW Killboard.lnk"))

    # Clean up orphan wowkb_sync.log in Downloads if exists
    try:
        downloads_log = os.path.join(os.path.dirname(current_exe), "wowkb_sync.log")
        if os.path.exists(downloads_log) and "downloads" in downloads_log.lower():
            os.remove(downloads_log)
    except Exception:
        pass

    return target_exe

def log_event(msg: str):
    """Logs message to standard output, persistent AppData wowkb_sync.log, and any active GUI hooks."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    formatted = f"[{timestamp}] {msg}"
    print(formatted)
    try:
        log_path = os.path.join(get_app_data_dir(), "wowkb_sync.log")
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(formatted + "\n")
    except Exception:
        pass
    for hook in list(LOG_HOOKS):
        try:
            hook(formatted)
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
            self.api_urls = ["https://wowkillboard.com", "http://127.0.0.1:8080"]
        self.api_url = ", ".join(self.api_urls)
        self.filepath = self.filepaths[0] if self.filepaths else ""
        self.running = True
        self.version = SYNC_VERSION

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

        # Ingest indexed characters from UnitScanner
        chars_data = parsed.get("characters", {})
        if not chars_data and isinstance(raw_db, dict):
            chars_data = raw_db.get("characters", {})
        synced_chars = 0
        if chars_data and isinstance(chars_data, dict):
            if self.upload_characters(chars_data):
                synced_chars = len(chars_data)

        sync_summary = f"[Watcher] [{client_tag}] Synced: {new_count} new kills, {new_pve_count} PvE deaths, {len(bounties)} bounties, {len(debts)} debts, {synced_chars} characters, {new_claims_count} claims, {new_bugs_count} bug reports"
        if is_manual_sync:
            sync_summary += " [Manual Sync Heartbeat OK]"
        log_event(sync_summary)
        self.sync_realm_data_to_client()
        return new_count

    def upload_pve_death(self, death_id: str, data: dict) -> bool:
        payload = {
            "deathId": death_id,
            "realm": data.get("realm", "Unknown"),
            "ruleset": data.get("ruleset", "PVE"),
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
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"}
                )
                with safe_urlopen(req, timeout=5) as response:
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

        def _strip_realm(n):
            if not n or n == "Unknown":
                return n
            n = str(n).strip()
            # If name has space or hyphen, take first word as character name
            if " " in n:
                n = n.split()[0]
            if "-" in n:
                n = n.split("-")[0]
            return n.strip()

        k_name = _strip_realm(killer_data.get("name") or data.get("killer_name") or data.get("name") or "Unknown")
        v_name = _strip_realm(victim_data.get("name") or data.get("victim_name") or "Unknown")

        k_raw_lvl = killer_data.get("level") if killer_data.get("level") is not None else (data.get("killer_level") if data.get("killer_level") is not None else data.get("level"))
        v_raw_lvl = victim_data.get("level") if victim_data.get("level") is not None else data.get("victim_level")
        k_realm = data.get("realm") or killer_data.get("realm") or victim_data.get("realm") or "Unknown"
        k_ruleset = data.get("ruleset") or "PVP"

        payload = {
            "killId": kill_id,
            "realm": k_realm,
            "ruleset": k_ruleset,
            "timestamp": data.get("timestamp", int(time.time())),
            "isDuel": bool(data.get("isDuel", False)),
            "isBattleground": bool(data.get("isBattleground", False)),
            "isArena": bool(data.get("isArena", False)),
            "isSolo": bool(
                data.get("isSolo", False)
                and data.get("attackersCount", 1) <= 1
                and not data.get("isBattleground", False)
                and not data.get("isArena", False)
                and (data.get("totalDamage", 0) > 0 or data.get("isDuel", False))
                and (killer_data.get("damageDone", 0) > 0 or data.get("isDuel", False))
            ),
            "attackers": data.get("attackers", []),
            "totalDamage": data.get("totalDamage", 0),
            "killer": {
                "name": k_name,
                "level": _clean_lvl(k_raw_lvl),
                "class": killer_data.get("class") or data.get("killer_class") or data.get("class") or "WARRIOR",
                "guild": killer_data.get("guild") or data.get("killer_guild") or data.get("guild") or "None",
                "faction": killer_data.get("faction") or data.get("killer_faction") or data.get("faction") or "Alliance",
                "partySize": killer_data.get("partySize") or data.get("killer_partySize") or 1,
                "damageDone": killer_data.get("damageDone") or data.get("killer_damageDone") or 0,
                "healingDone": killer_data.get("healingDone") or data.get("killer_healingDone") or 0,
            },
            "victim": {
                "name": v_name,
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
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                with safe_urlopen(req, timeout=5) as resp:
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
        target_name = data.get("targetName") or data.get("target_name") or data.get("target")
        if not target_name or target_name.strip() == "" or target_name.strip().lower() == "unknown":
            return  # Guardrail: Never overwrite server with blank/unknown dummy bounty

        copper = int(data.get("amountCopper") or data.get("amount_copper") or 0)
        gold = int(data.get("amountGold") or data.get("amount_gold") or (copper // 10000 if copper else 0))
        if copper <= 0 and gold > 0:
            copper = gold * 10000

        payload = {
            "id": b_id,
            "targetName": target_name,
            "targetClass": data.get("targetClass") or data.get("target_class") or "UNKNOWN",
            "targetFaction": data.get("targetFaction") or data.get("target_faction") or "Unknown",
            "targetGuid": data.get("targetGuid") or data.get("target_guid") or "UNKNOWN",
            "placerName": data.get("placerName") or data.get("placer_name") or "Unknown",
            "realm": data.get("realm", "Unknown"),
            "amountCopper": copper,
            "amountGold": gold,
            "status": data.get("status", "ACTIVE"),
            "hunterName": data.get("hunterName") or data.get("hunter_name"),
            "killId": data.get("killId") or data.get("kill_id"),
            "timestamp": data.get("timestamp", int(time.time())),
        }
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/bounties"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                safe_urlopen(req, timeout=5)
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
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                safe_urlopen(req, timeout=5)
            except Exception:
                pass

    def upload_stats(self, stats: dict):
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/stats"
            try:
                req = urllib.request.Request(
                    url,
                    data=json.dumps(stats).encode("utf-8"),
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                safe_urlopen(req, timeout=5)
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
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                with safe_urlopen(req, timeout=5) as resp:
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
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                with safe_urlopen(req, timeout=5) as resp:
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
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                with safe_urlopen(req, timeout=5) as resp:
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

    def upload_characters(self, characters: dict) -> bool:
        if not characters or not isinstance(characters, dict):
            return False
        payload = list(characters.values())
        any_success = False
        for endpoint in self.api_urls:
            url = f"{endpoint}/api/characters"
            try:
                data_bytes = json.dumps(payload).encode("utf-8")
                req = urllib.request.Request(
                    url,
                    data=data_bytes,
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                with safe_urlopen(req, timeout=10) as resp:
                    if resp.status in (200, 201):
                        any_success = True
            except Exception:
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
                    headers={"Content-Type": "application/json", "User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"},
                    method="POST"
                )
                with safe_urlopen(req, timeout=8) as resp:
                    if resp.status in (200, 201):
                        res_json = json.loads(resp.read().decode("utf-8"))
                        diag = res_json.get("diagnosis", {})
                        sev = diag.get("severity", "ANALYZED")
                        print(f"[Watcher] [BUG DISPATCH] Ticket {bug_data.get('id')} submitted to AI Diagnostician on {endpoint}! Severity: {sev}")
                        any_success = True
            except Exception as e:
                pass
        return any_success

    def sync_realm_data_to_client(self, target_paths_override: list = None) -> bool:
        """Fetches /api/realm/summary, /api/kills, /api/bounties, /api/pve/deaths, and /api/pve/leaderboard, merges local data across accounts, and writes WoWKillboard_RealmData.lua."""
        summary = None
        recent_kills = []
        active_bounties = []
        recent_pve_deaths = []
        pve_leaderboard = None

        for endpoint in self.api_urls:
            # 1. Fetch summary
            if not summary:
                url = f"{endpoint}/api/realm/summary"
                try:
                    req = urllib.request.Request(url, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                    with safe_urlopen(req, timeout=4) as resp:
                        if resp.status == 200:
                            summary = json.loads(resp.read().decode("utf-8"))
                except Exception:
                    pass

            # 2. Fetch recent kills (up to 60)
            if not recent_kills:
                url_kills = f"{endpoint}/api/kills?limit=60"
                try:
                    req = urllib.request.Request(url_kills, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                    with safe_urlopen(req, timeout=5) as resp:
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
                    with safe_urlopen(req, timeout=4) as resp:
                        if resp.status == 200:
                            b_data = json.loads(resp.read().decode("utf-8"))
                            if isinstance(b_data, list):
                                active_bounties = b_data
                            elif isinstance(b_data, dict):
                                active_bounties = b_data.get("bounties", [])
                except Exception:
                    pass

            # 4. Fetch recent PvE wilderness deaths (up to 60)
            if not recent_pve_deaths:
                url_pve = f"{endpoint}/api/pve/deaths?limit=60"
                try:
                    req = urllib.request.Request(url_pve, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                    with safe_urlopen(req, timeout=4) as resp:
                        if resp.status == 200:
                            pve_resp = json.loads(resp.read().decode("utf-8"))
                            if isinstance(pve_resp, list):
                                recent_pve_deaths = pve_resp
                            elif isinstance(pve_resp, dict):
                                recent_pve_deaths = pve_resp.get("deaths", [])
                except Exception:
                    pass

            # 5. Fetch PvE Bestiary Leaderboard
            if not pve_leaderboard:
                url_pve_lb = f"{endpoint}/api/pve/leaderboard"
                try:
                    req = urllib.request.Request(url_pve_lb, headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
                    with safe_urlopen(req, timeout=4) as resp:
                        if resp.status == 200:
                            pve_leaderboard = json.loads(resp.read().decode("utf-8"))
                except Exception:
                    pass

        # Also merge local kills and PvE deaths from all monitored accounts on this machine
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
                    raw_db = parsed.get("WoWKillboardDB", {})
                    if isinstance(raw_db, dict):
                        # SavedVariables stores kills under the "kills" key
                        db_kills = raw_db.get("kills") if isinstance(raw_db.get("kills"), dict) else raw_db
                        for kid, km in db_kills.items():
                            if kid in ("kills", "pveDeaths", "settings", "sessionStats", "campaignRuleset", "RealmData"):
                                continue
                            if kid not in known_kill_ids and isinstance(km, dict):
                                if not isinstance(km.get("killer"), dict) or not isinstance(km.get("victim"), dict):
                                    continue
                                km_copy = dict(km)
                                if "killId" not in km_copy:
                                    km_copy["killId"] = kid
                                if "realm" not in km_copy:
                                    km_copy["realm"] = km.get("realm") or (km.get("killer", {}).get("realm")) or "Unknown"
                                if "ruleset" not in km_copy:
                                    km_copy["ruleset"] = km.get("ruleset") or "PVP"
                                # Guardrail 4: Strict Solo Purity Sanitization
                                if not km_copy.get("isDuel"):
                                    tot_dmg = km_copy.get("totalDamage", 0) or 0
                                    k_data = km_copy.get("killer", {}) if isinstance(km_copy.get("killer"), dict) else {}
                                    k_dmg = k_data.get("damageDone", 0) or 0
                                    att_count = km_copy.get("attackersCount", 1) or 1
                                    if tot_dmg <= 0 or k_dmg <= 0 or att_count > 1 or km_copy.get("isBattleground") or km_copy.get("isArena"):
                                        km_copy["isSolo"] = False
                                        if att_count < 2:
                                            km_copy["attackersCount"] = 2
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
                                if "realm" not in b_copy:
                                    b_copy["realm"] = bnt.get("realm") or "Unknown"
                                active_bounties.append(b_copy)
                                known_bnt_ids.add(bid)

                    # Also merge local PvE deaths if any
                    local_pve = parsed.get("WoWKillboardDB", {}).get("pveDeaths", {})
                    if isinstance(local_pve, dict):
                        known_pve_ids = set(d.get("deathId") or d.get("death_id") for d in recent_pve_deaths if isinstance(d, dict))
                        for did, pdeath in local_pve.items():
                            if did not in known_pve_ids and isinstance(pdeath, dict):
                                pd_copy = dict(pdeath)
                                if "deathId" not in pd_copy:
                                    pd_copy["deathId"] = did
                                if "realm" not in pd_copy or pd_copy["realm"] in (None, "", "Unknown"):
                                    pd_copy["realm"] = pdeath.get("realm") or (isinstance(pdeath.get("victim"), dict) and pdeath["victim"].get("realm")) or "Unknown"
                                if "ruleset" not in pd_copy or not pd_copy["ruleset"]:
                                    pd_copy["ruleset"] = pdeath.get("ruleset") or "PVE"
                                recent_pve_deaths.append(pd_copy)
                                known_pve_ids.add(did)
                except Exception:
                    pass

        # Ensure all recent kills strictly conform to valid schema and Guardrail 4 solo purity
        sanitized_recent_kills = []
        for rk in recent_kills:
            if not isinstance(rk, dict):
                continue
            k_data = rk.get("killer")
            v_data = rk.get("victim")
            if not isinstance(k_data, dict) or not k_data.get("name") or not isinstance(v_data, dict) or not v_data.get("name"):
                continue
            if not rk.get("isDuel"):
                tot_dmg = rk.get("totalDamage", 0) or 0
                k_dmg = k_data.get("damageDone", 0) or 0
                att_count = rk.get("attackersCount", 1) or 1
                if tot_dmg <= 0 or k_dmg <= 0 or att_count > 1 or rk.get("isBattleground") or rk.get("isArena"):
                    rk["isSolo"] = False
                    if att_count < 2:
                        rk["attackersCount"] = 2
            sanitized_recent_kills.append(rk)
        recent_kills = sanitized_recent_kills

        # Sort recent kills descending by timestamp and cap at 60
        recent_kills.sort(key=lambda x: x.get("timestamp", 0) if isinstance(x, dict) else 0, reverse=True)
        recent_kills = recent_kills[:60]

        # Clean and normalize active bounties (dual camelCase & snake_case support, zero unknown dummies)
        cleaned_bounties = []
        known_bnt_ids = set()
        for b in active_bounties:
            if not isinstance(b, dict):
                continue
            b_id = b.get("id") or b.get("bountyId")
            if not b_id or b_id in known_bnt_ids:
                continue
            t_name = b.get("targetName") or b.get("target_name")
            if not t_name or t_name.strip() == "" or t_name.strip().lower() == "unknown":
                continue
            t_class = b.get("targetClass") or b.get("target_class") or "UNKNOWN"
            t_fac = b.get("targetFaction") or b.get("target_faction") or "Unknown"
            p_name = b.get("placerName") or b.get("placer_name") or "Unknown"
            a_cop = int(b.get("amountCopper") or b.get("amount_copper") or 0)
            a_gold = int(b.get("amountGold") or b.get("amount_gold") or (a_cop // 10000 if a_cop else 0))
            if a_cop <= 0 and a_gold > 0:
                a_cop = a_gold * 10000

            b_norm = dict(b)
            b_norm["id"] = b_id
            b_norm["targetName"] = t_name
            b_norm["target_name"] = t_name
            b_norm["targetClass"] = t_class
            b_norm["target_class"] = t_class
            b_norm["targetFaction"] = t_fac
            b_norm["target_faction"] = t_fac
            b_norm["placerName"] = p_name
            b_norm["placer_name"] = p_name
            b_norm["amountCopper"] = a_cop
            b_norm["amount_copper"] = a_cop
            b_norm["amountGold"] = a_gold
            b_norm["amount_gold"] = a_gold
            b_norm["status"] = b.get("status", "ACTIVE")
            cleaned_bounties.append(b_norm)
            known_bnt_ids.add(b_id)

        # Sort recent PvE deaths descending by timestamp and cap at 60
        recent_pve_deaths.sort(key=lambda x: x.get("timestamp", 0) if isinstance(x, dict) else 0, reverse=True)
        recent_pve_deaths = recent_pve_deaths[:60]

        pve_summary = pve_leaderboard.get("summary", {}) if isinstance(pve_leaderboard, dict) else {}
        pve_total = int(pve_summary.get("totalDeaths", len(recent_pve_deaths))) if pve_summary else len(recent_pve_deaths)
        pve_top_npcs = pve_leaderboard.get("topDeadlyNpcs", []) if isinstance(pve_leaderboard, dict) else []
        pve_top_victims = pve_leaderboard.get("topFallenPlayers", []) if isinstance(pve_leaderboard, dict) else []
        pve_danger_zone = pve_summary.get("mostDangerousZone") if pve_summary else None

        carnage = int(summary.get("RealmTotalCarnage", len(recent_kills))) if summary else len(recent_kills)
        solo_count = sum(1 for k in recent_kills if isinstance(k, dict) and k.get("isSolo"))
        solo_ratio = round((solo_count / max(1, len(recent_kills))) * 100, 1)
        faction_split = summary.get("FactionSplit", {"Alliance": 50, "Horde": 50}) if summary else {"Alliance": 50, "Horde": 50}
        a_split = float(faction_split.get("Alliance", 50))
        h_split = float(faction_split.get("Horde", 50))
        deadliest_zones = summary.get("DeadliestZones", []) if summary else []
        top_gankers = summary.get("TopGankers24h", []) if summary else []
        latest_ver = summary.get("LatestVersion", "1.0.3") if summary else "1.0.3"
        changelog = summary.get("Changelog", [
            "Dynamic Accent Color Engine (Classic Gold, Class Color, Hex)",
            "ElvUI Minimalist Overhaul (1px Solid Borders & Clean Strips)",
            "Cross-Realm & Ruleset Isolation (PvP, PvE, RP, HC Segregation)",
            "Automated Theme Migration to Modern Flat Glass Architecture",
            "Dual GitHub Direct Releases & CurseForge App Links",
        ]) if summary else [
            "Dynamic Accent Color Engine (Classic Gold, Class Color, Hex)",
            "ElvUI Minimalist Overhaul (1px Solid Borders & Clean Strips)",
            "Cross-Realm & Ruleset Isolation (PvP, PvE, RP, HC Segregation)",
            "Automated Theme Migration to Modern Flat Glass Architecture",
            "Dual GitHub Direct Releases & CurseForge App Links",
        ]

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
            f"    ActiveBounties = {serialize_to_lua(cleaned_bounties, 1)},",
            f"    RecentPveDeaths = {serialize_to_lua(recent_pve_deaths, 1)},",
            f"    PveTotalDeaths = {pve_total},",
            f"    PveTopExecutioners = {serialize_to_lua(pve_top_npcs, 1)},",
            f"    PveTopVictims = {serialize_to_lua(pve_top_victims, 1)},",
            f"    PveDeadliestZone = {serialize_to_lua(pve_danger_zone, 1)},",
            f"    LatestVersion = \"{latest_ver}\",",
            f"    Changelog = {serialize_to_lua(changelog, 1)},",
            f"    LastSync = {int(time.time())},",
            "}",
        ]
        lua_content = "\n".join(lua_lines) + "\n"

        if target_paths_override is not None:
            target_paths = list(target_paths_override)
        else:
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

            # Universal Addon Directories across all drives and WoW flavors
            for ad in find_all_wow_addon_dirs():
                target_paths.append(os.path.join(ad, "WoWKillboard_RealmData.lua"))

            # Universal WTF SavedVariables directories across all roots
            import glob
            for root in find_all_wow_roots():
                for flv in ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_", "_ptr_", "_classic_"]:
                    p_addon = f"{root}/{flv}/Interface/AddOns/WoWKillboard/WoWKillboard_RealmData.lua"
                    if os.path.exists(os.path.dirname(p_addon)):
                        target_paths.append(p_addon)
                    for sv in glob.glob(f"{root}/{flv}/WTF/Account/*/SavedVariables"):
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
            log_event(f"[Watcher] [2-WAY SYNC] Injected realm telemetry payload (WoWKillboard_RealmData.lua) with {len(recent_kills)} kills, {len(recent_pve_deaths)} PvE deaths, and {len(active_bounties)} bounties into {written} location(s).")
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

        while getattr(self, "running", True):
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

def normalize_wow_root(p: str) -> str:
    """Normalizes a user-specified path to the root World of Warcraft folder."""
    p = os.path.abspath(p).replace("\\", "/")
    # If pointed directly at a flavor branch (_retail_, _classic_era_, etc.)
    for flv in ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_", "_ptr_", "_classic_"]:
        if p.endswith("/" + flv):
            return os.path.dirname(p)
    # If pointed at WTF or Interface
    if p.endswith("/WTF") or p.endswith("/Interface"):
        parent = os.path.dirname(p)
        for flv in ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_", "_ptr_", "_classic_"]:
            if parent.endswith("/" + flv):
                return os.path.dirname(parent)
        return parent
    return p

def save_config(config_dict: dict):
    """Persists settings to wowkb_sync_config.json in the AppData directory."""
    config_file = os.path.join(get_app_data_dir(), "wowkb_sync_config.json")
    try:
        existing = {}
        if os.path.exists(config_file):
            with open(config_file, "r", encoding="utf-8") as f:
                existing = json.load(f)
        existing.update(config_dict)
        with open(config_file, "w", encoding="utf-8") as f:
            json.dump(existing, f, indent=2)
    except Exception as e:
        log_event(f"[Config] Error writing config file: {e}")

def load_config() -> dict:
    """Reads settings from wowkb_sync_config.json in the AppData directory."""
    config_file = os.path.join(get_app_data_dir(), "wowkb_sync_config.json")
    if os.path.exists(config_file):
        try:
            with open(config_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def get_startup_dir() -> str:
    appdata = os.environ.get("APPDATA", "")
    return os.path.join(appdata, r"Microsoft\Windows\Start Menu\Programs\Startup")

def is_windows_startup_enabled() -> bool:
    """Checks whether WoWKillboardSync is registered in the user Startup folder."""
    if sys.platform != "win32":
        return False
    startup_dir = get_startup_dir()
    for ext in (".url", ".lnk"):
        if os.path.exists(os.path.join(startup_dir, f"WoW Killboard{ext}")):
            return True
    return False

def set_windows_startup(enable: bool) -> bool:
    """Enables or disables automatic startup on Windows boot via the user Startup folder."""
    if sys.platform != "win32":
        return False
    try:
        startup_dir = get_startup_dir()
        os.makedirs(startup_dir, exist_ok=True)
        shortcut_url = os.path.join(startup_dir, "WoW Killboard.url")
        shortcut_lnk = os.path.join(startup_dir, "WoW Killboard.lnk")

        if enable:
            target_installed = os.path.join(get_install_dir(), "WoWKillboardSync.exe")
            target = target_installed if os.path.exists(target_installed) else os.path.abspath(sys.argv[0])
            create_windows_shortcut(target, shortcut_url, "WoW Killboard Desktop Companion")
        else:
            for s in (shortcut_url, shortcut_lnk):
                if os.path.exists(s):
                    try:
                        os.remove(s)
                    except Exception:
                        pass
        return True
    except Exception as e:
        log_event(f"[Startup] Failed to configure Windows startup: {e}")
        return False

def find_all_wow_roots() -> list:
    """Discovers all World of Warcraft base directories across drives, config file, and standard install paths."""
    import glob
    roots = []
    
    # 1. Check local config file for custom wow_path
    cfg = load_config()
    custom_path = cfg.get("wow_path")
    if custom_path and os.path.exists(custom_path):
        roots.append(normalize_wow_root(custom_path))

    # 2. Check environment variable
    env_wow = os.environ.get("WOW_PATH")
    if env_wow and os.path.exists(env_wow):
        roots.append(normalize_wow_root(env_wow))

    # 3. Check all standard drives
    drives = ["C:", "D:", "E:", "F:", "G:", "H:", "I:", "J:", "K:", "Z:"]
    patterns = [
        "{drive}/World of Warcraft",
        "{drive}/Program Files (x86)/World of Warcraft",
        "{drive}/Program Files/World of Warcraft",
        "{drive}/Games/World of Warcraft",
        "{drive}/Battle.net/World of Warcraft",
        "{drive}/Blizzard/World of Warcraft",
        "{drive}/Games/Blizzard/World of Warcraft",
    ]
    for d in drives:
        for pat in patterns:
            p = pat.format(drive=d)
            if os.path.exists(p):
                roots.append(os.path.abspath(p).replace("\\", "/"))

    # 4. Check upward from the running executable / script directory
    base_dir = os.path.dirname(os.path.abspath(sys.argv[0])).replace("\\", "/")
    curr = base_dir
    for _ in range(5):
        for flv in ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_", "_ptr_", "_classic_"]:
            if os.path.exists(os.path.join(curr, flv)):
                roots.append(os.path.abspath(curr).replace("\\", "/"))
                break
        parent = os.path.dirname(curr)
        if parent == curr:
            break
        curr = parent

    return sorted(list(set(roots)))

def find_all_wow_addon_dirs() -> list:
    """Discovers all Interface/AddOns/WoWKillboard directories across all WoW roots and client flavors."""
    addon_dirs = []
    roots = find_all_wow_roots()
    flavors = ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_", "_ptr_", "_classic_", "_*"]
    import glob
    for root in roots:
        for flv in flavors:
            p = f"{root}/{flv}/Interface/AddOns/WoWKillboard"
            if os.path.exists(p):
                addon_dirs.append(os.path.abspath(p).replace("\\", "/"))
            else:
                for m in glob.glob(f"{root}/{flv}/Interface/AddOns/WoWKillboard"):
                    addon_dirs.append(os.path.abspath(m).replace("\\", "/"))
    return sorted(list(set(addon_dirs)))

def find_all_saved_variables() -> list:
    """Scans all connected Windows drives and WoW client branches for active and pending SavedVariables/WoWKillboard.lua files."""
    import glob
    candidates = []
    roots = find_all_wow_roots()
    branches = ["_classic_beta_", "_classic_era_", "_anniversary_", "_retail_", "_ptr_", "_classic_", "_*"]

    for root in roots:
        for branch in branches:
            # 1. Existing SavedVariables files
            pat_existing = f"{root}/{branch}/WTF/Account/*/SavedVariables/WoWKillboard.lua"
            candidates.extend(glob.glob(pat_existing))
            # 2. Account directories (even before first logout/reload generates SavedVariables)
            pat_accounts = f"{root}/{branch}/WTF/Account/*"
            for acc in glob.glob(pat_accounts):
                if os.path.isdir(acc) and os.path.basename(acc).lower() != "savedvariables":
                    sv_target = os.path.join(acc, "SavedVariables", "WoWKillboard.lua")
                    candidates.append(sv_target)

    # Return existing files first, or potential account targets if fresh install
    existing = [os.path.abspath(p).replace("\\", "/") for p in candidates if os.path.exists(p)]
    if existing:
        return sorted(list(set(existing)))

    unique_all = sorted(list(set(os.path.abspath(p).replace("\\", "/") for p in candidates)))
    return unique_all

def auto_detect_saved_variables() -> str:
    """Returns the single most recently modified SavedVariables file (for backward compatibility)."""
    all_files = find_all_saved_variables()
    if all_files:
        all_files.sort(key=lambda p: os.path.getmtime(p) if os.path.exists(p) else 0, reverse=True)
        return all_files[0]
    if os.path.exists("WoWKillboard.lua"):
        return os.path.abspath("WoWKillboard.lua").replace("\\", "/")
    return ""

DEFAULT_PROD_URL = "https://wowkillboard.com"
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
    cfg = load_config()
    if cfg.get("api_url"):
        return [cfg["api_url"].rstrip("/")]

    # Default to dual broadcasting: Cloud Platform + Local Server (if reachable)
    endpoints = [DEFAULT_PROD_URL]
    try:
        req = urllib.request.Request(f"{DEFAULT_LOCAL_URL}/api/health", headers={"User-Agent": f"WoWKillboardSync/{SYNC_VERSION}"})
        with safe_urlopen(req, timeout=0.6) as resp:
            if resp.status in (200, 201):
                endpoints.append(DEFAULT_LOCAL_URL)
    except Exception:
        pass

    return endpoints

def print_startup_banner():
    """Prints a friendly, informative startup guide for players running the standalone executable."""
    startup_status = "ENABLED" if is_windows_startup_enabled() else "DISABLED"
    print("=" * 70)
    print(f"  WoW Killboard — Standalone Desktop Sync Agent v{SYNC_VERSION}")
    print("  Official Website: https://wowkillboard.com | CurseForge: WoW Killboard")
    print("=" * 70)
    print("  [WHERE TO PLACE THIS FILE]")
    print("    • You can place WoWKillboardSync.exe ANYWHERE on your computer!")
    print("      (e.g., Desktop, Downloads, or inside your World of Warcraft folder)")
    print("    • It automatically scans all drives (C:, D:, E:, F:, G:, etc.) for WoW.")
    print()
    print("  [HOW TO RUN & POINT IT AT WOW]")
    print("    • Keep this window running in the background while playing World of Warcraft.")
    print("    • Auto-discovery finds all your WoW clients (Classic, Era, Retail).")
    print("    • If installed in a custom location, you will be prompted below, or")
    print("      you can set it anytime using: WoWKillboardSync.exe --set-wow <path>")
    print()
    print("  [HOW COMBAT DATA SYNCS]")
    print("    • The in-game addon tracks all your kills, duels, and bounties locally.")
    print("    • Whenever you /reload, change characters, or exit WoW, this app")
    print("      instantly uploads your kills to https://wowkillboard.com.")
    print("    • Updated realm bounties and rival kills sync back into your game!")
    print()
    print(f"  [SYSTEM STATUS]")
    print(f"    • Windows Auto-Start on Boot: [{startup_status}]")
    print("      (Tip: Run with --startup to enable, or --no-startup to disable)")
    print("=" * 70)

def ensure_console_for_cli():
    """If running in windowed/noconsole mode but CLI was requested, attach to calling shell."""
    if sys.platform == "win32":
        try:
            import ctypes
            if ctypes.windll.kernel32.AttachConsole(-1) != 0:
                sys.stdout = open("CONOUT$", "w", encoding="utf-8", errors="replace")
                sys.stderr = open("CONOUT$", "w", encoding="utf-8", errors="replace")
        except Exception:
            pass

def main():
    if any(arg in sys.argv for arg in ("--cli", "--console", "--once", "--startup", "--no-startup", "-h", "--help")):
        ensure_console_for_cli()

    parser = argparse.ArgumentParser(description="WoWKillboard Desktop Sync Agent")
    parser.add_argument("--file", "-f", default="", help="Path to WoWKillboard.lua (monitors ALL clients if omitted)")
    parser.add_argument("--api", "-a", default="", help="Web Killboard API URL (defaults to production)")
    parser.add_argument("--local", action="store_true", help="Force local development endpoint only (http://127.0.0.1:8080)")
    parser.add_argument("--cloud", "--render", action="store_true", help="Force cloud production endpoint only (https://wowkillboard.com)")
    parser.add_argument("--once", action="store_true", help="Run once and exit instead of continuous daemon")
    parser.add_argument("--startup", action="store_true", help="Register WoWKillboardSync to run automatically on Windows boot")
    parser.add_argument("--no-startup", "--remove-startup", action="store_true", help="Remove WoWKillboardSync from Windows startup")
    parser.add_argument("--set-wow", default="", help="Save a custom World of Warcraft folder path to configuration")
    parser.add_argument("--cli", "--console", action="store_true", help="Run in terminal CLI mode without desktop GUI")
    parser.add_argument("--no-gui", action="store_true", help="Disable graphical desktop companion window")
    args = parser.parse_args()

    if args.cli or getattr(args, 'no_gui', False) or args.once:
        print_startup_banner()

    if args.startup:
        if set_windows_startup(True):
            print("[+] Windows Auto-Start has been ENABLED in Windows Registry.")
        else:
            print("[!] Could not enable Windows Auto-Start (non-Windows platform or permission denied).")

    if getattr(args, 'no_startup', False) or getattr(args, 'remove_startup', False):
        if set_windows_startup(False):
            print("[+] Windows Auto-Start has been DISABLED.")

    if args.set_wow:
        if os.path.exists(args.set_wow):
            norm = normalize_wow_root(args.set_wow)
            save_config({"wow_path": norm})
            print(f"[+] Saved custom WoW installation directory: {norm}")
        else:
            print(f"[!] Warning: Specified directory does not exist: {args.set_wow}")

    target_apis = resolve_api_endpoints(args.api, force_local=args.local, force_cloud=getattr(args, 'cloud', False))
    print(f"[*] Ingestion Target APIs: {', '.join(target_apis)}")

    target_file = args.file
    if target_file:
        target_files = [os.path.abspath(target_file).replace("\\", "/")]
        log_event(f"[*] Monitoring user-specified file: {target_files[0]}")
    else:
        target_files = find_all_saved_variables()
        if not target_files:
            if sys.stdin and hasattr(sys.stdin, "isatty") and sys.stdin.isatty() and not args.once:
                print("\n" + "!" * 70)
                print("  [!] ATTENTION: World of Warcraft Directory Not Detected Automatically")
                print("!" * 70)
                print("  WoW Killboard looked in standard folders on drives C: through Z:")
                print("  but did not find an active World of Warcraft installation.\n")
                print("  Please type or paste your World of Warcraft directory path:")
                print("  (Example: D:\\Games\\World of Warcraft or C:\\World of Warcraft)")
                try:
                    custom_in = input("  > ").strip().strip('"\'')
                    if custom_in and os.path.exists(custom_in):
                        norm = normalize_wow_root(custom_in)
                        save_config({"wow_path": norm})
                        print(f"  [+] Saved WoW path: {norm}")
                        target_files = find_all_saved_variables()
                except Exception:
                    pass

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
    elif args.cli or getattr(args, 'no_gui', False):
        watcher.run_daemon()
    else:
        # Default Desktop Companion GUI mode (like Warcraft Logs / Raider.IO)
        try:
            if sync_gui and hasattr(sync_gui, "launch_gui"):
                sync_gui.launch_gui(watcher, target_files, target_apis)
            else:
                try:
                    from sync.gui import launch_gui
                except ImportError:
                    from gui import launch_gui
                launch_gui(watcher, target_files, target_apis)
        except Exception as e:
            log_event(f"[GUI] Could not launch graphical desktop companion ({e}). Falling back to console mode.")
            watcher.run_daemon()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[Watcher] Exiting WoW Killboard Sync. Good hunting!")
    except Exception as e:
        print(f"\n[FATAL ERROR] An unexpected error occurred: {e}")
        import traceback
        traceback.print_exc()
        if sys.stdin and hasattr(sys.stdin, "isatty") and sys.stdin.isatty():
            try:
                input("\nPress Enter to exit...")
            except Exception:
                pass


