#!/usr/bin/env python3
"""
WoWKillboard - web/server.py
zKillboard-style Web Platform & REST API Server for World of Warcraft.
Provides real-time kill feed, leaderboards, battleground telemetry,
bounty board, and Oathbreaker Debt Ledger.
"""

import os
import sys
import json
import time
import sqlite3
import urllib.request
import urllib.error
from flask import Flask, request, jsonify, send_from_directory, render_template_string
from flask_cors import CORS

APP_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(APP_DIR, "static")
DB_PATH = os.environ.get("DB_PATH", os.path.join(APP_DIR, "killboard.db"))
ADMIN_SECRET_KEY = os.environ.get("ADMIN_SECRET_KEY", "valor2026")

try:
    from sync.watcher import LuaTableParser
except ImportError:
    parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)
    try:
        from sync.watcher import LuaTableParser
    except ImportError:
        LuaTableParser = None

app = Flask(__name__, static_folder=STATIC_DIR)
CORS(app)

def get_db():
    db_dir = os.path.dirname(DB_PATH)
    if db_dir and not os.path.exists(db_dir):
        os.makedirs(db_dir, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS kills (
                kill_id TEXT PRIMARY KEY,
                timestamp INTEGER,
                is_duel INTEGER DEFAULT 0,
                is_battleground INTEGER,
                is_arena INTEGER,
                bg_name TEXT,
                is_solo INTEGER,
                attackers_count INTEGER,
                total_damage INTEGER,
                killer_name TEXT,
                killer_level INTEGER,
                killer_class TEXT,
                killer_guild TEXT,
                killer_faction TEXT,
                killer_party_size INTEGER,
                killer_damage_done INTEGER,
                killer_healing_done INTEGER,
                victim_name TEXT,
                victim_level INTEGER,
                victim_class TEXT,
                victim_guild TEXT,
                victim_faction TEXT,
                victim_party_size INTEGER,
                map_id INTEGER,
                zone TEXT,
                subzone TEXT,
                coord_x REAL,
                coord_y REAL,
                killer_spec TEXT,
                victim_spec TEXT,
                raw_json TEXT
            )
        """)
        # Safe migration if table exists without is_duel, killer_spec, victim_spec
        try:
            conn.execute("ALTER TABLE kills ADD COLUMN is_duel INTEGER DEFAULT 0")
        except sqlite3.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE kills ADD COLUMN killer_spec TEXT")
        except sqlite3.OperationalError:
            pass
        try:
            conn.execute("ALTER TABLE kills ADD COLUMN victim_spec TEXT")
        except sqlite3.OperationalError:
            pass

        conn.execute("""
            CREATE TABLE IF NOT EXISTS platform_stats (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS bounties (
                id TEXT PRIMARY KEY,
                target_name TEXT,
                target_guid TEXT,
                target_class TEXT,
                target_faction TEXT,
                placer_name TEXT,
                amount_copper INTEGER,
                amount_gold INTEGER,
                status TEXT,
                hunter_name TEXT,
                kill_id TEXT,
                timestamp INTEGER,
                expiry INTEGER,
                payment_deadline INTEGER
            )
        """)
        try:
            conn.execute("ALTER TABLE bounties ADD COLUMN target_guid TEXT")
        except sqlite3.OperationalError:
            pass

        conn.execute("""
            CREATE TABLE IF NOT EXISTS bounty_acceptances (
                bounty_id TEXT,
                hunter_name TEXT,
                accepted_at INTEGER,
                PRIMARY KEY (bounty_id, hunter_name)
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS debt_ledger (
                player_name TEXT PRIMARY KEY,
                creditor TEXT,
                amount_owed_copper INTEGER,
                principal_copper INTEGER,
                surcharge_copper INTEGER,
                status TEXT,
                default_date INTEGER,
                days_in_default INTEGER,
                bounty_id TEXT
            )
        """)
        try:
            conn.execute("ALTER TABLE debt_ledger ADD COLUMN player_guid TEXT")
        except sqlite3.OperationalError:
            pass

        conn.execute("""
            CREATE TABLE IF NOT EXISTS character_guild_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                character_name TEXT,
                guild_name TEXT,
                faction TEXT,
                first_seen INTEGER,
                last_seen INTEGER,
                UNIQUE(character_name, guild_name)
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS characters (
                name TEXT PRIMARY KEY,
                realm TEXT,
                guid TEXT,
                class TEXT,
                race TEXT,
                level INTEGER,
                faction TEXT,
                guild TEXT,
                last_seen INTEGER
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS character_claims (
                character_name TEXT PRIMARY KEY,
                owner_token TEXT,
                claim_code TEXT,
                claimed_at INTEGER,
                verified INTEGER DEFAULT 0
            )
        """)
        # Backfill characters from known kills if empty or updated
        try:
            conn.execute("""
                INSERT OR IGNORE INTO characters (name, realm, guid, class, race, level, faction, guild, last_seen)
                SELECT killer_name, 'WoW Forever', 'UNKNOWN', killer_class, 'Unknown', killer_level, killer_faction, killer_guild, MAX(timestamp)
                FROM kills WHERE killer_name IS NOT NULL AND killer_name != 'Unknown' AND killer_name != ''
                GROUP BY killer_name
            """)
            conn.execute("""
                INSERT OR IGNORE INTO characters (name, realm, guid, class, race, level, faction, guild, last_seen)
                SELECT victim_name, 'WoW Forever', 'UNKNOWN', victim_class, 'Unknown', victim_level, victim_faction, victim_guild, MAX(timestamp)
                FROM kills WHERE victim_name IS NOT NULL AND victim_name != 'Unknown' AND victim_name != ''
                GROUP BY victim_name
            """)
        except Exception:
            pass
        conn.execute("""
            CREATE TABLE IF NOT EXISTS distress_beacons (
                id TEXT PRIMARY KEY,
                character_name TEXT,
                character_class TEXT,
                character_level INTEGER,
                guild_name TEXT,
                faction TEXT,
                zone TEXT,
                subzone TEXT,
                coord_x REAL,
                coord_y REAL,
                hostile_count INTEGER,
                hostile_names TEXT,
                timestamp INTEGER,
                status TEXT DEFAULT 'ACTIVE',
                group_type TEXT DEFAULT 'PARTY',
                content_type TEXT DEFAULT 'WORLD',
                min_level INTEGER DEFAULT 1,
                max_level INTEGER DEFAULT 60,
                roles TEXT DEFAULT 'TANK,HEAL,DPS',
                message TEXT
            )
        """)
        for col_def in [
            ("group_type", "TEXT DEFAULT 'PARTY'"),
            ("content_type", "TEXT DEFAULT 'WORLD'"),
            ("min_level", "INTEGER DEFAULT 1"),
            ("max_level", "INTEGER DEFAULT 60"),
            ("roles", "TEXT DEFAULT 'TANK,HEAL,DPS'"),
            ("message", "TEXT DEFAULT ''"),
        ]:
            try:
                conn.execute(f"ALTER TABLE distress_beacons ADD COLUMN {col_def[0]} {col_def[1]}")
            except Exception:
                pass
        conn.execute("""
            CREATE TABLE IF NOT EXISTS guild_events (
                id TEXT PRIMARY KEY,
                title TEXT,
                description TEXT,
                guild_name TEXT,
                creator_name TEXT,
                zone TEXT,
                time_str TEXT,
                created_at INTEGER,
                status TEXT DEFAULT 'SCHEDULED'
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS guild_discord_configs (
                guild_name TEXT PRIMARY KEY,
                webhook_url TEXT,
                alerts_enabled INTEGER DEFAULT 1,
                events_enabled INTEGER DEFAULT 1
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS blood_feuds (
                id TEXT PRIMARY KEY,
                feud_type TEXT DEFAULT 'GUILD',
                challenger_name TEXT,
                challenger_guild TEXT,
                challenger_faction TEXT,
                target_name TEXT,
                target_guild TEXT,
                target_faction TEXT,
                target_score INTEGER DEFAULT 100,
                challenger_score INTEGER DEFAULT 0,
                target_score_current INTEGER DEFAULT 0,
                roe_min_level INTEGER DEFAULT 55,
                roe_underdog_bonus INTEGER DEFAULT 1,
                roe_zone TEXT,
                status TEXT DEFAULT 'ACTIVE',
                winner_name TEXT,
                created_at INTEGER,
                expires_at INTEGER
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS kos_blacklist (
                entity_name TEXT PRIMARY KEY,
                entity_type TEXT DEFAULT 'GUILD',
                reason TEXT,
                branded_at INTEGER,
                status TEXT DEFAULT 'KOS'
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS kos_deserters (
                player_guid TEXT PRIMARY KEY,
                player_name TEXT,
                former_guild TEXT,
                branded_at INTEGER,
                expires_at INTEGER
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS intel_sightings (
                id TEXT PRIMARY KEY,
                reporter_name TEXT,
                reporter_guild TEXT,
                target_name TEXT,
                target_class TEXT,
                target_level INTEGER,
                target_guild TEXT,
                target_faction TEXT,
                zone TEXT,
                subzone TEXT,
                coord_x REAL,
                coord_y REAL,
                notes TEXT,
                timestamp INTEGER
            )
        """)

        conn.execute("""
            CREATE TABLE IF NOT EXISTS pve_deaths (
                death_id TEXT PRIMARY KEY,
                timestamp INTEGER,
                npc_name TEXT,
                npc_id INTEGER,
                npc_guid TEXT,
                npc_spell TEXT,
                npc_damage INTEGER,
                victim_name TEXT,
                victim_guid TEXT,
                victim_level INTEGER,
                victim_class TEXT,
                victim_guild TEXT,
                victim_faction TEXT,
                map_id INTEGER,
                zone TEXT,
                subzone TEXT,
                coord_x REAL,
                coord_y REAL,
                raw_json TEXT
            )
        """)

        # Initialize default flavor in platform_stats
        try:
            conn.execute("INSERT OR IGNORE INTO platform_stats (key, value) VALUES ('client_flavor', '\"CLASSIC_ERA\"')")
        except Exception:
            pass

        # Seed iconic PvE execution data if table is empty
        try:
            cur = conn.execute("SELECT COUNT(*) FROM pve_deaths")
            if cur.fetchone()[0] == 0:
                now_ts = int(time.time())
                sample_pve = [
                    ("PVE-1001", now_ts - 360, "Hogger", 448, "Creature-0-1-0-0-448-1", "Vicious Bite", 650, "Noviceadventurer", "Player-01", 11, "WARRIOR", "Goldshire Militia", "Alliance", 1429, "Elwynn Forest", "Forest's Edge", 26.4, 76.8),
                    ("PVE-1002", now_ts - 1200, "Hogger", 448, "Creature-0-1-0-0-448-1", "Skull Cracker", 720, "Elwynnhealer", "Player-02", 10, "PRIEST", "None", "Alliance", 1429, "Elwynn Forest", "Forest's Edge", 26.5, 76.9),
                    ("PVE-1003", now_ts - 2100, "Defias Pillager", 589, "Creature-0-1-0-0-589-2", "Pyroblast", 1850, "Moonbrookscout", "Player-03", 15, "ROGUE", "Westfall Watch", "Alliance", 1436, "Westfall", "Moonbrook", 42.1, 68.3),
                    ("PVE-1004", now_ts - 3400, "Son of Arugal", 4275, "Creature-0-1-0-0-4275-3", "Shadow Bolt", 2400, "Undeadshadow", "Player-04", 18, "WARLOCK", "Deathstalkers", "Horde", 1421, "Silverpine Forest", "The Decrepit Ferry", 54.3, 41.2),
                    ("PVE-1005", now_ts - 4800, "Mor'Ladim", 522, "Creature-0-1-0-0-522-4", "Unholy Cleave", 3100, "Duskwoodrider", "Player-05", 28, "PALADIN", "Night's Watch", "Alliance", 1431, "Duskwood", "Raven Hill Cemetery", 18.2, 56.4),
                    ("PVE-1006", now_ts - 6200, "Stitches", 412, "Creature-0-1-0-0-412-5", "Hook & Slam", 4500, "Towncrier", "Player-06", 32, "MAGE", "Darkshire Guardians", "Alliance", 1431, "Duskwood", "Darkshire Road", 73.1, 46.8),
                    ("PVE-1007", now_ts - 8900, "Devilsaur", 6584, "Creature-0-1-0-0-6584-6", "Crush & Swallow", 5800, "Un'Gorobotanist", "Player-07", 52, "DRUID", "Cenarion Circle", "Alliance", 1449, "Un'Goro Crater", "Tar Pits", 51.2, 28.6),
                    ("PVE-1008", now_ts - 11000, "Baron Geddon", 12056, "Creature-0-1-0-0-12056-7", "Living Bomb", 8200, "Raidtank", "Player-08", 60, "WARRIOR", "Vanguard Brigade", "Alliance", 1541, "Molten Core", "The Core", 44.0, 52.0),
                    ("PVE-1009", now_ts - 14500, "Hogger", 448, "Creature-0-1-0-0-448-1", "Vicious Bite", 590, "Gnomecaster", "Player-09", 9, "MAGE", "Gnomeregan Exiles", "Alliance", 1429, "Elwynn Forest", "Forest's Edge", 26.2, 77.0),
                    ("PVE-1010", now_ts - 18000, "Defias Pillager", 589, "Creature-0-1-0-0-589-2", "Fireball", 1420, "Farmboy", "Player-10", 14, "HUNTER", "None", "Alliance", 1436, "Westfall", "Moonbrook", 42.8, 67.9),
                ]
                for p in sample_pve:
                    conn.execute("""
                        INSERT OR IGNORE INTO pve_deaths (
                            death_id, timestamp, npc_name, npc_id, npc_guid, npc_spell, npc_damage,
                            victim_name, victim_guid, victim_level, victim_class, victim_guild, victim_faction,
                            map_id, zone, subzone, coord_x, coord_y, raw_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '{}')
                    """, p)
        except Exception:
            pass

        # Backfill character_guild_history from existing kills if any
        try:
            conn.execute("""
                INSERT OR IGNORE INTO character_guild_history (character_name, guild_name, faction, first_seen, last_seen)
                SELECT killer_name, killer_guild, killer_faction, MIN(timestamp), MAX(timestamp)
                FROM kills
                WHERE killer_name IS NOT NULL AND killer_guild IS NOT NULL AND killer_guild != 'None' AND killer_guild != ''
                GROUP BY killer_name, killer_guild
            """)
            conn.execute("""
                INSERT OR IGNORE INTO character_guild_history (character_name, guild_name, faction, first_seen, last_seen)
                SELECT victim_name, victim_guild, victim_faction, MIN(timestamp), MAX(timestamp)
                FROM kills
                WHERE victim_name IS NOT NULL AND victim_guild IS NOT NULL AND victim_guild != 'None' AND victim_guild != ''
                GROUP BY victim_name, victim_guild
            """)
        except Exception:
            pass
        conn.commit()

# Ensure database tables and schema are initialized on startup (e.g. under Gunicorn / Docker / Render)
init_db()

@app.route("/api/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "ok",
        "service": "WoW Killboard API",
        "db": "ready"
    })

@app.route("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")

@app.route("/static/<path:path>")
def static_files(path):
    return send_from_directory(STATIC_DIR, path)

GOOGLE_DRIVE_DOWNLOAD_URL = "https://drive.google.com/file/d/1POiV8uple8LxFihPYE1u95IJFAuAAlII/view?usp=sharing"

@app.route("/WoWKillboard-v1.0.0.zip")
@app.route("/download")
@app.route("/addon.zip")
def download_addon():
    root_dir = os.path.dirname(APP_DIR)
    zip_path = os.path.join(root_dir, "WoWKillboard-v1.0.0.zip")
    static_zip = os.path.join(STATIC_DIR, "WoWKillboard-v1.0.0.zip")
    if os.path.exists(static_zip):
        return send_from_directory(STATIC_DIR, "WoWKillboard-v1.0.0.zip", as_attachment=True)
    if os.path.exists(zip_path):
        return send_from_directory(root_dir, "WoWKillboard-v1.0.0.zip", as_attachment=True)
    from flask import redirect
    return redirect(GOOGLE_DRIVE_DOWNLOAD_URL)

@app.route("/drive")
@app.route("/gdrive")
def download_gdrive():
    from flask import redirect
    return redirect(GOOGLE_DRIVE_DOWNLOAD_URL)

@app.route("/WoWKillboardSync.exe")
@app.route("/download/sync")
@app.route("/sync.exe")
def download_sync_exe():
    root_dir = os.path.dirname(APP_DIR)
    exe_path = os.path.join(root_dir, "WoWKillboardSync.exe")
    dist_exe = os.path.join(root_dir, "dist", "WoWKillboardSync.exe")
    static_exe = os.path.join(STATIC_DIR, "WoWKillboardSync.exe")
    if os.path.exists(static_exe):
        return send_from_directory(STATIC_DIR, "WoWKillboardSync.exe", as_attachment=True)
    if os.path.exists(exe_path):
        return send_from_directory(root_dir, "WoWKillboardSync.exe", as_attachment=True)
    if os.path.exists(dist_exe):
        return send_from_directory(os.path.join(root_dir, "dist"), "WoWKillboardSync.exe", as_attachment=True)
    from flask import redirect
    return redirect(GOOGLE_DRIVE_DOWNLOAD_URL)


# ----------------- StreamBox (OBS Overlay) -----------------

STREAMBOX_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>WoW Killboard — War Correspondent HUD: {{ character_name }}</title>
  <style>
    :root {
      --cls-warrior: #c79c6e; --cls-paladin: #f58cba; --cls-hunter: #abd473;
      --cls-rogue: #fff569; --cls-priest: #ffffff; --cls-dk: #c41f3b;
      --cls-shaman: #0070de; --cls-mage: #40c7eb; --cls-warlock: #8787ed;
      --cls-monk: #00ff96; --cls-druid: #ff7d0a; --cls-dh: #a330c9;
      --cls-evoker: #33937f; --cls-unknown: #94a3b8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: transparent;
      color: #e2e8f0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      padding: 8px;
      overflow: hidden;
    }
    .sb-container {
      display: flex;
      flex-direction: {{ 'column' if vertical else 'row' }};
      gap: 8px;
      align-items: {{ 'stretch' if vertical else 'center' }};
    }
    .sb-header {
      background: rgba(10, 14, 22, 0.88);
      border: 1px solid rgba(0, 229, 255, 0.4);
      border-radius: 6px;
      padding: 6px 12px;
      display: flex;
      align-items: center;
      gap: 10px;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.6);
      backdrop-filter: blur(8px);
      white-space: nowrap;
    }
    .sb-name {
      font-weight: 800;
      font-size: 0.95rem;
    }
    .sb-stats {
      font-size: 0.75rem;
      color: #94a3b8;
      display: flex;
      gap: 8px;
    }
    .sb-kills-feed {
      display: flex;
      flex-direction: {{ 'column' if vertical else 'row' }};
      gap: 6px;
      overflow: hidden;
    }
    .sb-card {
      background: rgba(13, 17, 26, 0.85);
      border: 1px solid #1e293b;
      border-radius: 6px;
      padding: 5px 10px;
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 0.75rem;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.5);
      backdrop-filter: blur(6px);
      animation: fadeIn 0.3s ease;
      white-space: nowrap;
    }
    .sb-card.kill { border-left: 3px solid #10b981; }
    .sb-card.death { border-left: 3px solid #ef4444; }
    .sb-badge {
      font-size: 0.65rem;
      font-weight: 800;
      padding: 2px 5px;
      border-radius: 3px;
    }
    .sb-badge-kill { background: rgba(16, 185, 129, 0.2); color: #10b981; }
    .sb-badge-death { background: rgba(239, 68, 68, 0.2); color: #ef4444; }
    @keyframes fadeIn {
      from { opacity: 0; transform: translateY(-4px); }
      to { opacity: 1; transform: translateY(0); }
    }
  </style>
</head>
<body>
  <div class="sb-container">
    <div class="sb-header">
      <div style="font-size: 1.2rem;">⚔️</div>
      <div>
        <div id="sb-char-name" class="sb-name">{{ character_name }}</div>
        <div class="sb-stats">
          <span>K: <strong id="sb-kills" style="color:#10b981;">0</strong></span>
          <span>D: <strong id="sb-deaths" style="color:#ef4444;">0</strong></span>
          <span>K/D: <strong id="sb-kd" style="color:#fbbf24;">0.0</strong></span>
        </div>
      </div>
    </div>
    <div id="sb-events" class="sb-kills-feed">
      <div class="sb-card" style="color:#94a3b8;">Listening for combat telemetry...</div>
    </div>
  </div>

  <script>
    const CHAR_NAME = "{{ character_name }}";
    const LIMIT = {{ limit }};
    const CLASS_COLORS = {
      WARRIOR: "#c79c6e", PALADIN: "#f58cba", HUNTER: "#abd473", ROGUE: "#fff569",
      PRIEST: "#ffffff", DEATHKNIGHT: "#c41f3b", SHAMAN: "#0070de", MAGE: "#40c7eb",
      WARLOCK: "#8787ed", MONK: "#00ff96", DRUID: "#ff7d0a", DEMONHUNTER: "#a330c9",
      EVOKER: "#33937f", UNKNOWN: "#94a3b8"
    };

    function colorClass(name, cls) {
      const col = CLASS_COLORS[(cls||'').toUpperCase()] || CLASS_COLORS.UNKNOWN;
      return `<strong style="color:${col}">${name}</strong>`;
    }

    function timeAgo(epoch) {
      const diff = Math.max(0, Math.floor(Date.now() / 1000) - Number(epoch));
      if (diff < 60) return diff + "s ago";
      if (diff < 3600) return Math.floor(diff / 60) + "m ago";
      return Math.floor(diff / 3600) + "h ago";
    }

    async function updateStreamBox() {
      try {
        const res = await fetch(`/api/character/${encodeURIComponent(CHAR_NAME)}`);
        if (!res.ok) return;
        const data = await res.json();

        const nameEl = document.getElementById("sb-char-name");
        if (nameEl) nameEl.innerHTML = colorClass(data.name, data.class);
        document.getElementById("sb-kills").innerText = (data.stats && data.stats.kills) || 0;
        document.getElementById("sb-deaths").innerText = (data.stats && data.stats.deaths) || 0;
        document.getElementById("sb-kd").innerText = (data.stats && data.stats.kd) || "0.0";

        const events = [];
        (data.recentKills || []).forEach(k => {
          events.push({ type: 'kill', target: k.victim_name, targetClass: k.victim_class, zone: k.zone, timestamp: k.timestamp });
        });
        (data.recentDeaths || []).forEach(d => {
          events.push({ type: 'death', target: d.killer_name, targetClass: d.killer_class, zone: d.zone, timestamp: d.timestamp });
        });
        events.sort((a, b) => b.timestamp - a.timestamp);

        const feedEl = document.getElementById("sb-events");
        if (!events.length) {
          feedEl.innerHTML = `<div class="sb-card" style="color:#64748b;">No recent combat logged</div>`;
          return;
        }

        feedEl.innerHTML = events.slice(0, LIMIT).map(ev => {
          if (ev.type === 'kill') {
            return `
              <div class="sb-card kill">
                <span class="sb-badge sb-badge-kill">KILL</span>
                <span>Defeated ${colorClass(ev.target, ev.targetClass)}</span>
                <span style="color:#64748b;">&bull;</span>
                <span style="color:#94a3b8;">${ev.zone}</span>
                <span style="color:#64748b; font-size:0.7rem;">${timeAgo(ev.timestamp)}</span>
              </div>
            `;
          } else {
            return `
              <div class="sb-card death">
                <span class="sb-badge sb-badge-death">DEATH</span>
                <span>Fell to ${colorClass(ev.target, ev.targetClass)}</span>
                <span style="color:#64748b;">&bull;</span>
                <span style="color:#94a3b8;">${ev.zone}</span>
                <span style="color:#64748b; font-size:0.7rem;">${timeAgo(ev.timestamp)}</span>
              </div>
            `;
          }
        }).join('');
      } catch (e) {
        console.error("StreamBox update error:", e);
      }
    }

    updateStreamBox();
    setInterval(updateStreamBox, 5000);
  </script>
</body>
</html>
"""

@app.route("/war-hud/<character_name>")
@app.route("/streambox/<character_name>")
def streambox_view(character_name):
    vertical = request.args.get("vertical") == "1"
    limit = min(int(request.args.get("limit", 5)), 25)
    return render_template_string(STREAMBOX_HTML, character_name=character_name, vertical=vertical, limit=limit)

# ----------------- Specialization & Percentile Engine -----------------

DEFAULT_CLASS_SPECS = {
    "WARRIOR": "Arms",
    "MAGE": "Frost",
    "ROGUE": "Subtlety",
    "PRIEST": "Shadow",
    "WARLOCK": "Affliction",
    "HUNTER": "Marksmanship",
    "DRUID": "Feral",
    "PALADIN": "Retribution",
    "SHAMAN": "Elemental",
    "DEATHKNIGHT": "Unholy",
    "MONK": "Windwalker",
    "DEMONHUNTER": "Havoc",
    "EVOKER": "Devastation"
}

VALID_SPECS_PER_CLASS = {
    "WARRIOR": ["Arms", "Fury", "Protection"],
    "PALADIN": ["Holy", "Protection", "Retribution"],
    "HUNTER": ["Beast Mastery", "Marksmanship", "Survival"],
    "ROGUE": ["Assassination", "Combat", "Subtlety", "Outlaw"],
    "PRIEST": ["Discipline", "Holy", "Shadow"],
    "DEATHKNIGHT": ["Blood", "Frost", "Unholy"],
    "SHAMAN": ["Elemental", "Enhancement", "Restoration"],
    "MAGE": ["Arcane", "Fire", "Frost"],
    "WARLOCK": ["Affliction", "Demonology", "Destruction"],
    "MONK": ["Brewmaster", "Mistweaver", "Windwalker"],
    "DRUID": ["Balance", "Feral", "Restoration", "Guardian"],
    "DEMONHUNTER": ["Havoc", "Vengeance"],
    "EVOKER": ["Devastation", "Preservation", "Augmentation"]
}

def resolve_character_spec(char_class, spec_candidate=None):
    cls_upper = (char_class or "WARRIOR").upper()
    if spec_candidate and str(spec_candidate).strip():
        sc = str(spec_candidate).strip()
        valid = VALID_SPECS_PER_CLASS.get(cls_upper, [])
        for v in valid:
            if v.lower() == sc.lower():
                return v
        return sc.capitalize()
    return DEFAULT_CLASS_SPECS.get(cls_upper, "Arms")

def compute_character_percentile(conn, char_name, char_class, spec, level, kills, kd):
    cls_upper = (char_class or "WARRIOR").upper()
    spec_resolved = resolve_character_spec(cls_upper, spec)
    lvl = int(level or 60)
    
    player_score = (int(kills or 0) * 1000) + float(kd or 0.0)
    
    cohort_query = """
        SELECT killer_name AS name, killer_class AS class, killer_level AS level
        FROM kills WHERE UPPER(killer_class) = ? AND killer_level = ? AND killer_name IS NOT NULL AND killer_name != 'Unknown'
        UNION
        SELECT victim_name AS name, victim_class AS class, victim_level AS level
        FROM kills WHERE UPPER(victim_class) = ? AND victim_level = ? AND victim_name IS NOT NULL AND victim_name != 'Unknown'
    """
    cohort_rows = conn.execute(cohort_query, (cls_upper, lvl, cls_upper, lvl)).fetchall()
    cohort_names = {r["name"] for r in cohort_rows if r["name"]}
    if char_name:
        cohort_names.add(char_name)

    scores = []
    for c_name in cohort_names:
        if c_name == char_name:
            scores.append((c_name, player_score))
        else:
            k_stat = conn.execute("SELECT COUNT(*) FROM kills WHERE killer_name = ?", (c_name,)).fetchone()
            d_stat = conn.execute("SELECT COUNT(*) FROM kills WHERE victim_name = ?", (c_name,)).fetchone()
            c_k = k_stat[0] or 0
            c_d = d_stat[0] or 0
            c_kd = round(c_k / c_d, 2) if c_d > 0 else float(c_k)
            scores.append((c_name, (c_k * 1000) + c_kd))

    scores.sort(key=lambda x: x[1], reverse=True)
    total_in_cohort = len(scores)
    
    rank = 1
    for idx, (c_name, sc) in enumerate(scores):
        if c_name == char_name:
            rank = idx + 1
            break

    if total_in_cohort <= 1:
        percentile = 99.0
        top_pct = 1.0
    else:
        pct_raw = ((total_in_cohort - rank + 1) / total_in_cohort) * 100.0
        percentile = round(min(99.9, max(1.0, pct_raw)), 1)
        top_pct = round(max(0.1, 100.0 - percentile), 1)

    return {
        "percentile": percentile,
        "topPct": top_pct,
        "rank": rank,
        "totalInCohort": total_in_cohort,
        "cohortLabel": f"Level {lvl} {spec_resolved} {cls_upper.capitalize()}",
        "spec": spec_resolved,
        "class": cls_upper,
        "level": lvl
    }

# ----------------- Kills API -----------------

@app.route("/api/kills", methods=["GET"])
def get_kills():
    mode = request.args.get("mode", "ALL").upper()
    page = int(request.args.get("page", 1))
    limit = min(int(request.args.get("limit", 25)), 100)
    search = request.args.get("search", "").strip()
    offset = (page - 1) * limit

    query = "SELECT * FROM kills WHERE 1=1"
    params = []

    if mode == "WORLD":
        query += " AND is_battleground = 0 AND is_arena = 0 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "BG":
        query += " AND is_battleground = 1 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "ARENA":
        query += " AND is_arena = 1 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "DUEL":
        query += " AND is_duel = 1"
    elif mode == "ALL":
        pass
    else:
        query += " AND is_battleground = 0 AND is_arena = 0 AND (is_duel = 0 OR is_duel IS NULL)"

    if search:
        query += " AND (killer_name LIKE ? OR victim_name LIKE ? OR zone LIKE ? OR killer_guild LIKE ?)"
        pattern = f"%{search}%"
        params.extend([pattern, pattern, pattern, pattern])

    query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
    params.extend([limit, offset])

    with get_db() as conn:
        cursor = conn.execute(query, params)
        rows = cursor.fetchall()
        kills = []
        for r in rows:
            raw_meta = {}
            if "raw_json" in r.keys() and r["raw_json"]:
                try:
                    raw_meta = json.loads(r["raw_json"])
                except Exception:
                    raw_meta = {}
            attackers = raw_meta.get("attackers", [])

            kills.append({
                "killId": r["kill_id"],
                "timestamp": r["timestamp"],
                "isDuel": bool(r["is_duel"]) if "is_duel" in r.keys() else False,
                "isBattleground": bool(r["is_battleground"]),
                "isArena": bool(r["is_arena"]),
                "battlegroundName": r["bg_name"],
                "isSolo": bool(r["is_solo"]),
                "attackersCount": r["attackers_count"],
                "attackers": attackers,
                "totalDamage": r["total_damage"],
                "killer": {
                    "name": r["killer_name"],
                    "level": r["killer_level"],
                    "class": r["killer_class"],
                    "guild": r["killer_guild"],
                    "faction": r["killer_faction"],
                    "partySize": r["killer_party_size"],
                    "damageDone": r["killer_damage_done"],
                    "healingDone": r["killer_healing_done"],
                },
                "victim": {
                    "name": r["victim_name"],
                    "level": r["victim_level"],
                    "class": r["victim_class"],
                    "guild": r["victim_guild"],
                    "faction": r["victim_faction"],
                    "partySize": r["victim_party_size"],
                },
                "location": {
                    "mapId": r["map_id"],
                    "zone": r["zone"],
                    "subZone": r["subzone"],
                    "x": r["coord_x"],
                    "y": r["coord_y"],
                }
            })

    return jsonify({"page": page, "limit": limit, "count": len(kills), "kills": kills})

@app.route("/api/kill/<kill_id>", methods=["GET"])
def get_kill(kill_id):
    with get_db() as conn:
        row = conn.execute("SELECT * FROM kills WHERE kill_id = ?", (kill_id,)).fetchone()
        if not row:
            return jsonify({"error": "Killmail not found"}), 404
        return jsonify(json.loads(row["raw_json"]))

def wipe_database():
    """Drops and re-creates all SQLite tables for a clean slate."""
    tables = [
        "kills", "platform_stats", "bounties", "bounty_acceptances",
        "pve_deaths", "character_guild_history", "debt_ledger",
        "distress_beacons", "guild_events", "discord_config", "intel_sightings",
        "blood_feuds", "kos_blacklist", "kos_deserters"
    ]
    with get_db() as conn:
        for tbl in tables:
            conn.execute(f"DROP TABLE IF EXISTS {tbl}")
        conn.commit()
    init_db()

def ingest_kill_data(data, conn):
    """Surgically ingests or updates a single killmail record with full bounty, feud, and guild tracking."""
    if not data or not isinstance(data, dict):
        return None
    kill_id = data.get("killId")
    if not kill_id:
        return None

    timestamp = data.get("timestamp", int(time.time()))
    is_duel = 1 if data.get("isDuel") else 0
    is_bg = 1 if data.get("isBattleground") else 0
    is_arena = 1 if data.get("isArena") else 0
    bg_name = data.get("battlegroundName", "")
    attackers = data.get("attackers", [])
    raw_attackers_count = data.get("attackersCount", 1)
    attackers_count = max(raw_attackers_count, len(attackers) if isinstance(attackers, list) else 1)
    total_damage = data.get("totalDamage", 0)

    k = data.get("killer", {})
    k_damage = k.get("damageDone") or 0
    is_solo = 1 if data.get("isSolo") else 0
    if attackers_count > 1 or (isinstance(attackers, list) and len(attackers) > 1):
        is_solo = 0
    if not is_duel and k_damage <= 0:
        is_solo = 0
    if k.get("name") in ("Allied Vanguard", "Unknown", ""):
        is_solo = 0
        if isinstance(attackers, list):
            for att in attackers:
                att_name = att.get("name")
                if att_name and att_name not in ("Allied Vanguard", "Unknown", ""):
                    k["name"] = att_name
                    if att.get("class"): k["class"] = att.get("class")
                    if att.get("level"): k["level"] = att.get("level")
                    if att.get("guild"): k["guild"] = att.get("guild")
                    if att.get("faction"): k["faction"] = att.get("faction")
                    break

    v = data.get("victim", {})
    loc = data.get("location", {})
    loc_zone = loc.get("zone", "Unknown")
    loc_subzone = loc.get("subZone", "")
    if loc_subzone == "Gurubashi Arena" and "stranglethorn" not in loc_zone.lower():
        loc_subzone = ""

    k_spec = resolve_character_spec(k.get("class", "WARRIOR"), k.get("spec"))
    v_spec = resolve_character_spec(v.get("class", "ROGUE"), v.get("spec"))

    def _parse_lvl(val):
        if val is not None:
            try:
                iv = int(val)
                if 0 <= iv <= 85:
                    return iv
            except (ValueError, TypeError):
                pass
        return 0

    k_level = _parse_lvl(k.get("level"))
    v_level = _parse_lvl(v.get("level"))

    conn.execute("""
        INSERT OR REPLACE INTO kills (
            kill_id, timestamp, is_duel, is_battleground, is_arena, bg_name,
            is_solo, attackers_count, total_damage,
            killer_name, killer_level, killer_class, killer_guild, killer_faction,
            killer_party_size, killer_damage_done, killer_healing_done,
            victim_name, victim_level, victim_class, victim_guild, victim_faction,
            victim_party_size, map_id, zone, subzone, coord_x, coord_y,
            killer_spec, victim_spec, raw_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        kill_id, timestamp, is_duel, is_bg, is_arena, bg_name,
        is_solo, attackers_count, total_damage,
        k.get("name", "Unknown"), k_level, k.get("class", "WARRIOR"), k.get("guild", "None"), k.get("faction", "Alliance"),
        k.get("partySize", 1), k.get("damageDone", 0), k.get("healingDone", 0),
        v.get("name", "Unknown"), v_level, v.get("class", "ROGUE"), v.get("guild", "None"), v.get("faction", "Horde"),
        v.get("partySize", 1), loc.get("mapId", 0), loc_zone, loc_subzone,
        loc.get("x", 0.0), loc.get("y", 0.0), k_spec, v_spec, json.dumps(data)
    ))

    # Track character guild history
    killer_name = k.get("name", "Unknown")
    killer_guild = k.get("guild", "None")
    killer_faction = k.get("faction", "Unknown")
    if killer_name != "Unknown" and killer_guild and killer_guild != "None" and killer_guild != "":
        try:
            conn.execute("""
                INSERT INTO character_guild_history (character_name, guild_name, faction, first_seen, last_seen)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(character_name, guild_name) DO UPDATE SET last_seen = MAX(last_seen, excluded.last_seen)
            """, (killer_name, killer_guild, killer_faction, timestamp, timestamp))
        except Exception:
            pass

    victim_name = v.get("name", "Unknown")
    victim_guild = v.get("guild", "None")
    victim_faction = v.get("faction", "Unknown")
    if victim_name != "Unknown" and victim_guild and victim_guild != "None" and victim_guild != "":
        try:
            conn.execute("""
                INSERT INTO character_guild_history (character_name, guild_name, faction, first_seen, last_seen)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(character_name, guild_name) DO UPDATE SET last_seen = MAX(last_seen, excluded.last_seen)
            """, (victim_name, victim_guild, victim_faction, timestamp, timestamp))
        except Exception:
            pass

    # Upsert killer and victim into characters directory table
    for c_info in [k, v]:
        c_name = c_info.get("name")
        if c_name and c_name != "Unknown" and c_name != "":
            c_guid = c_info.get("guid") or "UNKNOWN"
            c_cls = c_info.get("class") or "UNKNOWN"
            c_lvl = _parse_lvl(c_info.get("level"))
            c_fac = c_info.get("faction") or "Unknown"
            c_gld = c_info.get("guild") or "None"
            try:
                conn.execute("""
                    INSERT INTO characters (name, realm, guid, class, race, level, faction, guild, last_seen)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(name) DO UPDATE SET
                        guid = COALESCE(excluded.guid, characters.guid),
                        class = CASE WHEN excluded.class != 'UNKNOWN' THEN excluded.class ELSE characters.class END,
                        level = CASE WHEN excluded.level > 0 AND excluded.level <= 85 THEN excluded.level ELSE characters.level END,
                        faction = CASE WHEN excluded.faction != 'Unknown' THEN excluded.faction ELSE characters.faction END,
                        guild = CASE WHEN excluded.guild != 'None' THEN excluded.guild ELSE characters.guild END,
                        last_seen = MAX(characters.last_seen, excluded.last_seen)
                """, (c_name, "WoW Forever", c_guid, c_cls, "Unknown", c_lvl, c_fac, c_gld, timestamp))
            except Exception:
                pass

    # Auto-claim active bounty on victim if killed by another player
    victim_guid = v.get("guid") or "UNKNOWN"
    killer_guid = k.get("guid") or "UNKNOWN"

    # Anti-Name-Change Evasion for Debt Ledger & KOS Blacklist (Immutable GUID Tracking)
    for char_n, char_g in [(victim_name, victim_guid), (killer_name, killer_guid)]:
        if char_n != "Unknown" and char_g != "UNKNOWN":
            debt_row = conn.execute("SELECT player_name, status, amount_owed_copper FROM debt_ledger WHERE player_guid = ?", (char_g,)).fetchone()
            if debt_row:
                old_n = debt_row["player_name"]
                if old_n != char_n:
                    conn.execute("UPDATE debt_ledger SET player_name = ? WHERE player_guid = ?", (char_n, char_g))
                    conn.execute("UPDATE kos_blacklist SET entity_name = ? WHERE entity_name = ?", (char_n, old_n))

    if victim_name != "Unknown" and killer_name != "Unknown" and killer_name != victim_name:
        if victim_guid != "UNKNOWN":
            conn.execute("""
                UPDATE bounties
                SET target_name = ?
                WHERE target_guid = ? AND target_name != ?
            """, (victim_name, victim_guid, victim_name))

        active_bounty = conn.execute("""
            SELECT id, amount_gold FROM bounties
            WHERE (target_name = ? OR (target_guid = ? AND target_guid != 'UNKNOWN')) AND status = 'ACTIVE'
            ORDER BY amount_gold DESC LIMIT 1
        """, (victim_name, victim_guid)).fetchone()

        if active_bounty:
            b_id = active_bounty["id"]
            accepted = conn.execute("SELECT 1 FROM bounty_acceptances WHERE bounty_id = ? AND hunter_name = ?", (b_id, killer_name)).fetchone()
            accepted_via_addon = (data.get("acceptedBounties") and b_id in data.get("acceptedBounties"))
            if accepted or accepted_via_addon:
                conn.execute("""
                    UPDATE bounties
                    SET status = 'CLAIMED', hunter_name = ?, kill_id = ?, payment_deadline = ?
                    WHERE id = ?
                """, (killer_name, kill_id, timestamp, b_id))

    # Process Active Blood Feuds & ROE scoring
    if killer_name != "Unknown" and victim_name != "Unknown" and killer_name != victim_name:
        active_feuds = conn.execute("SELECT * FROM blood_feuds WHERE status = 'ACTIVE'").fetchall()
        for feud in active_feuds:
            f_id = feud["id"]
            c_name = feud["challenger_name"]
            c_guild = feud["challenger_guild"]
            t_name = feud["target_name"]
            t_guild = feud["target_guild"]
            f_type = feud["feud_type"]
            roe_min_lvl = feud["roe_min_level"] or 0
            v_lvl = v_level
            zone_name = loc.get("zone", "")
            roe_zone = feud["roe_zone"]

            # ROE Check 1: Zone restriction
            if roe_zone and roe_zone.strip() and roe_zone.lower() not in zone_name.lower():
                continue

            # ROE Check 2: Minimum level (Anti-lowbie filter)
            if roe_min_lvl > 0 and v_lvl < roe_min_lvl:
                continue

            # ROE Check 3: Underdog Multiplier & Zerg Filter
            victim_party = v.get("partySize", 1)
            points = 1
            if feud["roe_underdog_bonus"]:
                if attackers_count == 1 and victim_party >= 2:
                    points = 2
                elif attackers_count >= 3 and victim_party <= 1:
                    points = 0

            if points == 0:
                continue

            is_challenger_kill = False
            is_target_kill = False

            if f_type == "GUILD":
                if killer_guild and c_guild and killer_guild == c_guild and victim_guild == t_guild:
                    is_challenger_kill = True
                elif killer_guild and t_guild and killer_guild == t_guild and victim_guild == c_guild:
                    is_target_kill = True
            else:
                if killer_name == c_name and victim_name == t_name:
                    is_challenger_kill = True
                elif killer_name == t_name and victim_name == c_name:
                    is_target_kill = True

            now_ts = int(time.time())
            exp_ts = now_ts + (30 * 86400)

            if is_challenger_kill:
                new_score = feud["challenger_score"] + points
                conn.execute("UPDATE blood_feuds SET challenger_score = ? WHERE id = ?", (new_score, f_id))
                if new_score >= feud["target_score"]:
                    winner = c_guild if f_type == "GUILD" else c_name
                    loser = t_guild if f_type == "GUILD" else t_name
                    conn.execute("UPDATE blood_feuds SET status = 'COMPLETED', winner_name = ? WHERE id = ?", (winner, f_id))
                    conn.execute("""
                        INSERT OR REPLACE INTO kos_blacklist (entity_name, entity_type, reason, branded_at, status)
                        VALUES (?, ?, ?, ?, 'KOS')
                    """, (loser, f_type, f"Defeated in Blood Feud by {winner}", now_ts))
                    if f_type == "GUILD":
                        roster = conn.execute("SELECT DISTINCT character_name FROM character_guild_history WHERE guild_name = ?", (loser,)).fetchall()
                        for m in roster:
                            m_name = m["character_name"]
                            conn.execute("""
                                INSERT OR REPLACE INTO kos_deserters (player_guid, player_name, former_guild, branded_at, expires_at)
                                VALUES (?, ?, ?, ?, ?)
                            """, (f"Player-KOS-{m_name}", m_name, loser, now_ts, exp_ts))

            elif is_target_kill:
                new_score = feud["target_score_current"] + points
                conn.execute("UPDATE blood_feuds SET target_score_current = ? WHERE id = ?", (new_score, f_id))
                if new_score >= feud["target_score"]:
                    winner = t_guild if f_type == "GUILD" else t_name
                    loser = c_guild if f_type == "GUILD" else c_name
                    conn.execute("UPDATE blood_feuds SET status = 'COMPLETED', winner_name = ? WHERE id = ?", (winner, f_id))
                    conn.execute("""
                        INSERT OR REPLACE INTO kos_blacklist (entity_name, entity_type, reason, branded_at, status)
                        VALUES (?, ?, ?, ?, 'KOS')
                    """, (loser, f_type, f"Defeated in Blood Feud by {winner}", now_ts))
                    if f_type == "GUILD":
                        roster = conn.execute("SELECT DISTINCT character_name FROM character_guild_history WHERE guild_name = ?", (loser,)).fetchall()
                        for m in roster:
                            m_name = m["character_name"]
                            conn.execute("""
                                INSERT OR REPLACE INTO kos_deserters (player_guid, player_name, former_guild, branded_at, expires_at)
                                VALUES (?, ?, ?, ?, ?)
                            """, (f"Player-KOS-{m_name}", m_name, loser, now_ts, exp_ts))

    return kill_id

@app.route("/api/kills", methods=["POST"])
def post_kill():
    data = request.json
    if not data or "killId" not in data:
        return jsonify({"error": "Invalid payload"}), 400

    with get_db() as conn:
        k_id = ingest_kill_data(data, conn)
        conn.commit()

    if k_id:
        return jsonify({"success": True, "killId": k_id}), 201
    return jsonify({"error": "Failed to ingest kill"}), 400

@app.route("/api/upload", methods=["POST"])
def upload_saved_variables():
    """
    Drag-and-Drop & File Upload Endpoint.
    Ingests raw SavedVariables (WoWKillboard.lua) or JSON combat logs idempotently.
    Commutative and safe across arbitrary upload timestamps from multiple players.
    """
    raw_text = ""
    if "file" in request.files:
        f = request.files["file"]
        raw_text = f.read().decode("utf-8", errors="replace")
    elif request.data:
        raw_text = request.data.decode("utf-8", errors="replace")
    elif request.is_json:
        raw_text = json.dumps(request.json)

    if not raw_text.strip():
        return jsonify({"error": "No content received. Please select or drop a valid WoWKillboard.lua file."}), 400

    parsed = {}
    is_lua = "WoWKillboardDB" in raw_text or ("=" in raw_text and "{" in raw_text)
    if is_lua:
        if not LuaTableParser:
            return jsonify({"error": "LuaTableParser not available on this server instance."}), 500
        try:
            parsed = LuaTableParser.parse_string(raw_text)
        except Exception as e:
            return jsonify({"error": f"Failed to parse Lua SavedVariables: {str(e)}"}), 400
    else:
        try:
            parsed = json.loads(raw_text)
        except Exception as e:
            return jsonify({"error": f"Failed to parse JSON content: {str(e)}"}), 400

    kills_to_ingest = []
    if isinstance(parsed, dict):
        if "WoWKillboardDB" in parsed and isinstance(parsed["WoWKillboardDB"], dict):
            w_db = parsed["WoWKillboardDB"]
            if "kills" in w_db and isinstance(w_db["kills"], dict):
                kills_to_ingest.extend(w_db["kills"].values())
            else:
                for v in w_db.values():
                    if isinstance(v, dict) and ("killId" in v or "victim" in v):
                        kills_to_ingest.append(v)
        elif "kills" in parsed and isinstance(parsed["kills"], dict):
            kills_to_ingest.extend(parsed["kills"].values())
        elif "kills" in parsed and isinstance(parsed["kills"], list):
            kills_to_ingest.extend(parsed["kills"])
        elif "killId" in parsed:
            kills_to_ingest.append(parsed)
        else:
            for v in parsed.values():
                if isinstance(v, dict) and ("killId" in v or "victim" in v):
                    kills_to_ingest.append(v)
    elif isinstance(parsed, list):
        kills_to_ingest.extend(parsed)

    processed_count = 0
    with get_db() as conn:
        for k in kills_to_ingest:
            if isinstance(k, dict) and "killId" in k:
                res = ingest_kill_data(k, conn)
                if res:
                    processed_count += 1

        # Also extract pveDeaths if present
        pve_list = []
        if isinstance(parsed, dict):
            if "pveDeaths" in parsed and isinstance(parsed["pveDeaths"], dict):
                pve_list.extend(parsed["pveDeaths"].values())
            elif "WoWKillboardDB" in parsed and isinstance(parsed["WoWKillboardDB"], dict) and "pveDeaths" in parsed["WoWKillboardDB"]:
                pve_list.extend(parsed["WoWKillboardDB"]["pveDeaths"].values())
        for pd in pve_list:
            if isinstance(pd, dict) and "deathId" in pd:
                try:
                    conn.execute("""
                        INSERT OR REPLACE INTO pve_deaths (
                            death_id, timestamp, npc_name, npc_id, npc_guid, npc_spell, npc_damage,
                            victim_name, victim_guid, victim_level, victim_class, victim_guild, victim_faction,
                            map_id, zone, subzone, coord_x, coord_y, raw_json
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        pd["deathId"], pd.get("timestamp", int(time.time())),
                        pd.get("npc", {}).get("name") or pd.get("creature", {}).get("name", "Unknown"),
                        pd.get("npc", {}).get("id") or pd.get("creature", {}).get("id", 0),
                        pd.get("npc", {}).get("guid") or pd.get("creature", {}).get("guid", "Creature-0"),
                        pd.get("npc", {}).get("spell", "Physical Strike"),
                        pd.get("npc", {}).get("damage", 0),
                        pd.get("player", {}).get("name") or pd.get("victim", {}).get("name", "Unknown"),
                        pd.get("player", {}).get("guid") or pd.get("victim", {}).get("guid", "Player-0"),
                        int(pd.get("player", {}).get("level") or pd.get("victim", {}).get("level") or 0),
                        pd.get("player", {}).get("class") or pd.get("victim", {}).get("class", "WARRIOR"),
                        pd.get("player", {}).get("guild") or pd.get("victim", {}).get("guild", "None"),
                        pd.get("player", {}).get("faction") or pd.get("victim", {}).get("faction", "Alliance"),
                        pd.get("location", {}).get("mapId", 0), pd.get("location", {}).get("zone", "Unknown"),
                        pd.get("location", {}).get("subZone", ""), pd.get("location", {}).get("x", 0.0),
                        pd.get("location", {}).get("y", 0.0), json.dumps(pd)
                    ))
                except Exception:
                    pass

        # Also extract characters directory if present
        char_list = []
        if isinstance(parsed, dict):
            if "characters" in parsed and isinstance(parsed["characters"], dict):
                char_list.extend(parsed["characters"].values())
            elif "WoWKillboardDB" in parsed and isinstance(parsed["WoWKillboardDB"], dict) and "characters" in parsed["WoWKillboardDB"]:
                chars_obj = parsed["WoWKillboardDB"]["characters"]
                if isinstance(chars_obj, dict):
                    char_list.extend(chars_obj.values())
        for c in char_list:
            if isinstance(c, dict) and c.get("name"):
                c_name = c.get("name")
                if c_name and c_name != "Unknown":
                    try:
                        conn.execute("""
                            INSERT INTO characters (name, realm, guid, class, race, level, faction, guild, last_seen)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ON CONFLICT(name) DO UPDATE SET
                                realm = COALESCE(excluded.realm, characters.realm),
                                guid = COALESCE(excluded.guid, characters.guid),
                                class = CASE WHEN excluded.class != 'UNKNOWN' THEN excluded.class ELSE characters.class END,
                                race = CASE WHEN excluded.race != 'Unknown' THEN excluded.race ELSE characters.race END,
                                level = CASE WHEN excluded.level > 0 AND excluded.level <= 85 THEN excluded.level ELSE characters.level END,
                                faction = CASE WHEN excluded.faction != 'Unknown' THEN excluded.faction ELSE characters.faction END,
                                guild = CASE WHEN excluded.guild != 'None' THEN excluded.guild ELSE characters.guild END,
                                last_seen = MAX(characters.last_seen, excluded.last_seen)
                        """, (
                            c_name, c.get("realm"), c.get("guid"), c.get("class", "UNKNOWN"),
                            c.get("race", "Unknown"), c.get("level", 0), c.get("faction", "Unknown"),
                            c.get("guild", "None"), c.get("lastSeen", int(time.time()))
                        ))
                    except Exception:
                        pass

        conn.commit()

    return jsonify({
        "success": True,
        "kills_processed": processed_count,
        "message": f"Successfully parsed and synchronized {processed_count} combat records into Master Ledger."
    }), 200

@app.route("/api/admin/reset", methods=["POST"])
def admin_reset():
    """
    Administrative Endpoint: Complete reset of combat ledger, bounties, and leaderboards.
    Requires ADMIN_SECRET_KEY.
    """
    req_secret = None
    if request.is_json:
        req_secret = request.json.get("secret")
    if not req_secret:
        req_secret = request.args.get("secret") or request.form.get("secret")

    if req_secret != ADMIN_SECRET_KEY:
        return jsonify({"error": "Unauthorized: Invalid administrative secret key."}), 403

    wipe_database()
    return jsonify({
        "success": True,
        "message": "All combat tables, leaderboards, and telemetry ledgers have been completely reset."
    }), 200

# ----------------- Stats & Telemetry API -----------------

@app.route("/api/stats", methods=["GET", "POST"])
def stats_endpoint():
    if request.method == "POST":
        data = request.json or {}
        with get_db() as conn:
            for category, val in data.items():
                conn.execute("INSERT OR REPLACE INTO platform_stats (key, value) VALUES (?, ?)", (category, json.dumps(val)))
            conn.commit()
        return jsonify({"success": True}), 200
    else:
        with get_db() as conn:
            rows = conn.execute("SELECT key, value FROM platform_stats").fetchall()
            stats = {r["key"]: json.loads(r["value"]) for r in rows}
            total_kills = conn.execute("SELECT COUNT(*) FROM kills").fetchone()[0]
            world_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE is_battleground = 0 AND is_arena = 0 AND (is_duel = 0 OR is_duel IS NULL)").fetchone()[0]
            bg_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE is_battleground = 1").fetchone()[0]
            arena_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE is_arena = 1").fetchone()[0]
            duel_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE is_duel = 1").fetchone()[0]
            solo_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE is_solo = 1").fetchone()[0]
            alliance_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE killer_faction = 'Alliance'").fetchone()[0]
            horde_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE killer_faction = 'Horde'").fetchone()[0]
            active_bounties = conn.execute("SELECT COUNT(*) FROM bounties WHERE status = 'ACTIVE'").fetchone()[0]
            bounty_gold = conn.execute("SELECT COALESCE(SUM(amount_gold), 0) FROM bounties WHERE status = 'ACTIVE'").fetchone()[0]
            top_zone_row = conn.execute("SELECT zone, COUNT(*) as cnt FROM kills WHERE zone IS NOT NULL AND (is_duel = 0 OR is_duel IS NULL) GROUP BY zone ORDER BY cnt DESC LIMIT 1").fetchone()
            top_zone = top_zone_row["zone"] if top_zone_row else "Hillsbrad Foothills"

            stats["counts"] = {
                "total": total_kills,
                "world": world_kills,
                "bg": bg_kills,
                "arena": arena_kills,
                "duel": duel_kills,
                "solo": solo_kills,
                "alliance": alliance_kills,
                "horde": horde_kills,
                "active_bounties": active_bounties,
                "bounty_gold": bounty_gold,
                "top_zone": top_zone
            }
        return jsonify(stats)

# ----------------- Leaderboard API -----------------

@app.route("/api/leaderboard", methods=["GET"])
def get_leaderboard():
    mode = request.args.get("mode", "WORLD").upper()
    where = "WHERE 1=1"
    if mode == "WORLD":
        where += " AND is_battleground = 0 AND is_arena = 0 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "BG":
        where += " AND is_battleground = 1 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "ARENA":
        where += " AND is_arena = 1 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "DUEL":
        where += " AND is_duel = 1"
    else:
        where += " AND (is_duel = 0 OR is_duel IS NULL)"

    with get_db() as conn:
        # Top Killers
        top_killers_query = f"""
            SELECT killer_name AS name, killer_class AS class, killer_guild AS guild, killer_faction AS faction,
                   COUNT(*) AS kills, SUM(is_solo) AS solo_kills
            FROM kills {where}
            GROUP BY killer_name
            ORDER BY kills DESC, solo_kills DESC
            LIMIT 15
        """
        top_killers = [dict(r) for r in conn.execute(top_killers_query).fetchall()]
        for p in top_killers:
            k_stat = p.get("kills") or 0
            d_stat = conn.execute("SELECT COUNT(*) FROM kills WHERE victim_name = ?", (p["name"],)).fetchone()
            victim_count = d_stat[0] if d_stat else 0
            kd = round(k_stat / victim_count, 2) if victim_count > 0 else float(k_stat)
            spec_row = conn.execute("SELECT killer_spec, killer_level FROM kills WHERE killer_name = ? AND killer_spec IS NOT NULL ORDER BY timestamp DESC LIMIT 1", (p["name"],)).fetchone()
            p_spec = spec_row[0] if spec_row else None
            p_lvl = spec_row[1] if spec_row and spec_row[1] else 60
            p["percentile"] = compute_character_percentile(conn, p["name"], p["class"], p_spec, p_lvl, k_stat, kd)

        # Top Solo Hunters
        top_solo_query = f"""
            SELECT killer_name AS name, killer_class AS class, killer_guild AS guild, killer_faction AS faction,
                   SUM(is_solo) AS solo_kills, COUNT(*) AS total_kills
            FROM kills {where}
            GROUP BY killer_name
            HAVING solo_kills > 0
            ORDER BY solo_kills DESC
            LIMIT 10
        """
        top_solo = [dict(r) for r in conn.execute(top_solo_query).fetchall()]

        # Top Guilds
        top_guilds_query = f"""
            SELECT killer_guild AS guild, killer_faction AS faction, COUNT(*) AS kills
            FROM kills {where} AND killer_guild != 'None' AND killer_guild != ''
            GROUP BY killer_guild
            ORDER BY kills DESC
            LIMIT 10
        """
        top_guilds = [dict(r) for r in conn.execute(top_guilds_query).fetchall()]

        # Top Zones
        top_zones_query = f"""
            SELECT zone, COUNT(*) AS kills
            FROM kills {where}
            GROUP BY zone
            ORDER BY kills DESC
            LIMIT 10
        """
        top_zones = [dict(r) for r in conn.execute(top_zones_query).fetchall()]

    return jsonify({
        "mode": mode,
        "topKillers": top_killers,
        "topSolo": top_solo,
        "topGuilds": top_guilds,
        "topZones": top_zones,
    })

# ----------------- PvE Combat & Deadly NPCs API -----------------

@app.route("/api/pve/deaths", methods=["GET", "POST"])
def pve_deaths_endpoint():
    if request.method == "POST":
        data = request.json or {}
        death_id = data.get("deathId")
        if not death_id:
            return jsonify({"error": "Missing deathId"}), 400

        npc = data.get("npc", {})
        victim = data.get("victim", {})
        loc = data.get("location", {})

        with get_db() as conn:
            conn.execute("""
                INSERT OR IGNORE INTO pve_deaths (
                    death_id, timestamp, npc_name, npc_id, npc_guid, npc_spell, npc_damage,
                    victim_name, victim_guid, victim_level, victim_class, victim_guild, victim_faction,
                    map_id, zone, subzone, coord_x, coord_y, raw_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                death_id,
                data.get("timestamp", int(time.time())),
                npc.get("name", "Unknown Monster"),
                int(npc.get("id") or 0),
                npc.get("guid", ""),
                npc.get("spell", "Combat Strike"),
                int(npc.get("damage") or 0),
                victim.get("name", "Unknown"),
                victim.get("guid", ""),
                int(victim.get("level") or 0),
                victim.get("class", "UNKNOWN"),
                victim.get("guild", "None"),
                victim.get("faction", "Unknown"),
                int(loc.get("mapId") or 0),
                loc.get("zone", "Unknown"),
                loc.get("subZone", ""),
                float(loc.get("x") or 0.0),
                float(loc.get("y") or 0.0),
                json.dumps(data)
            ))
            conn.commit()

        return jsonify({"success": True, "deathId": death_id}), 201

    else:
        limit = int(request.args.get("limit", 50))
        npc_name = request.args.get("npc")
        victim_name = request.args.get("player")
        with get_db() as conn:
            query = "SELECT * FROM pve_deaths"
            params = []
            conds = []
            if npc_name:
                conds.append("npc_name LIKE ?")
                params.append(f"%{npc_name}%")
            if victim_name:
                conds.append("victim_name LIKE ?")
                params.append(f"%{victim_name}%")
            if conds:
                query += " WHERE " + " AND ".join(conds)
            query += " ORDER BY timestamp DESC LIMIT ?"
            params.append(limit)

            rows = conn.execute(query, tuple(params)).fetchall()
            deaths = [dict(r) for r in rows]
        return jsonify({"deaths": deaths, "count": len(deaths)})

@app.route("/api/pve/leaderboard", methods=["GET"])
def get_pve_leaderboard():
    limit = int(request.args.get("limit", 20))
    with get_db() as conn:
        top_npcs_rows = conn.execute("""
            SELECT npc_name, npc_id, COUNT(*) AS kills,
                   COUNT(DISTINCT victim_name) AS unique_victims,
                   MAX(timestamp) AS last_kill,
                   zone,
                   npc_spell
            FROM pve_deaths
            GROUP BY npc_name
            ORDER BY kills DESC
            LIMIT ?
        """, (limit,)).fetchall()
        top_npcs = [dict(r) for r in top_npcs_rows]

        top_victims_rows = conn.execute("""
            SELECT victim_name, victim_class, victim_faction, victim_guild,
                   COUNT(*) AS deaths,
                   MAX(timestamp) AS last_death
            FROM pve_deaths
            GROUP BY victim_name
            ORDER BY deaths DESC
            LIMIT 10
        """, ()).fetchall()
        top_victims = [dict(r) for r in top_victims_rows]

        total_pve = conn.execute("SELECT COUNT(*) FROM pve_deaths").fetchone()[0]
        unique_npcs = conn.execute("SELECT COUNT(DISTINCT npc_name) FROM pve_deaths").fetchone()[0]
        most_dangerous_zone_row = conn.execute("""
            SELECT zone, COUNT(*) as deaths
            FROM pve_deaths
            GROUP BY zone
            ORDER BY deaths DESC
            LIMIT 1
        """).fetchone()
        most_dangerous_zone = dict(most_dangerous_zone_row) if most_dangerous_zone_row else {"zone": "None", "deaths": 0}

    return jsonify({
        "summary": {
            "totalDeaths": total_pve,
            "uniqueDeadlyNpcs": unique_npcs,
            "mostDangerousZone": most_dangerous_zone
        },
        "topDeadlyNpcs": top_npcs,
        "topFallenPlayers": top_victims
    })

# ----------------- Client Flavor System API -----------------

@app.route("/api/system/flavor", methods=["GET", "POST"])
def client_flavor_endpoint():
    valid_flavors = ["CLASSIC_ERA", "ANNIVERSARY", "FOREVER", "TBC", "WOTLK", "RETAIL"]
    valid_servers = ["PVP", "PVE", "RP", "HARDCORE"]
    if request.method == "POST":
        data = request.json or {}
        flavor = (data.get("flavor") or "").upper()
        server = (data.get("server") or "").upper()
        if flavor not in valid_flavors:
            return jsonify({"error": f"Invalid flavor. Supported: {valid_flavors}"}), 400
        if server and server not in valid_servers:
            server = "PVP"
        with get_db() as conn:
            conn.execute("INSERT OR REPLACE INTO platform_stats (key, value) VALUES ('client_flavor', ?)", (json.dumps(flavor),))
            if server:
                conn.execute("INSERT OR REPLACE INTO platform_stats (key, value) VALUES ('forever_server', ?)", (json.dumps(server),))
            conn.commit()
        resp = {"success": True, "flavor": flavor}
        if server:
            resp["server"] = server
        return jsonify(resp), 200
    else:
        with get_db() as conn:
            row = conn.execute("SELECT value FROM platform_stats WHERE key = 'client_flavor'").fetchone()
            flavor = json.loads(row[0]) if row else "CLASSIC_ERA"
            srow = conn.execute("SELECT value FROM platform_stats WHERE key = 'forever_server'").fetchone()
            server = json.loads(srow[0]) if srow else "PVP"
        return jsonify({
            "flavor": flavor,
            "server": server,
            "supportedFlavors": valid_flavors,
            "supportedServers": valid_servers
        })

# ----------------- Battleground Stats API -----------------

@app.route("/api/bg/stats", methods=["GET"])
def get_bg_stats():
    with get_db() as conn:
        top_damage = [dict(r) for r in conn.execute("""
            SELECT killer_name AS name, killer_class AS class, killer_guild AS guild,
                   SUM(killer_damage_done) AS total_damage, COUNT(*) AS kills
            FROM kills WHERE is_battleground = 1
            GROUP BY killer_name
            ORDER BY total_damage DESC
            LIMIT 10
        """).fetchall()]

        top_healing = [dict(r) for r in conn.execute("""
            SELECT killer_name AS name, killer_class AS class, killer_guild AS guild,
                   SUM(killer_healing_done) AS total_healing, COUNT(*) AS kills
            FROM kills WHERE is_battleground = 1
            GROUP BY killer_name
            HAVING total_healing > 0
            ORDER BY total_healing DESC
            LIMIT 10
        """).fetchall()]

        top_kd = [dict(r) for r in conn.execute("""
            SELECT killer_name AS name, killer_class AS class, killer_guild AS guild,
                   COUNT(*) AS kills,
                   (SELECT COUNT(*) FROM kills k2 WHERE k2.victim_name = kills.killer_name AND k2.is_battleground = 1) AS deaths
            FROM kills WHERE is_battleground = 1
            GROUP BY killer_name
            ORDER BY kills DESC
            LIMIT 10
        """).fetchall()]

        for item in top_kd:
            d = item["deaths"]
            item["kdRatio"] = round(item["kills"] / d, 2) if d > 0 else float(item["kills"])

    return jsonify({
        "topDamage": top_damage,
        "topHealing": top_healing,
        "topKd": top_kd,
    })

# ----------------- Character & Player Armory API -----------------

def calculate_pvp_rank_title(kills: int, kd: float, faction: str) -> str:
    """Calculates authentic World of Warcraft PvP Military Honor Title based on combat rating."""
    is_alliance = (faction or "").lower() == "alliance"
    score = kills * (1.0 + min(kd, 3.0) * 0.2)
    if is_alliance:
        if score >= 500: return "Grand Marshal"
        elif score >= 350: return "Field Marshal"
        elif score >= 250: return "Marshal"
        elif score >= 175: return "Commander"
        elif score >= 120: return "Lieutenant Commander"
        elif score >= 80:  return "Knight-Champion"
        elif score >= 50:  return "Knight-Captain"
        elif score >= 30:  return "Knight-Lieutenant"
        elif score >= 15:  return "Knight"
        elif score >= 8:   return "Sergeant Major"
        elif score >= 4:   return "Master Sergeant"
        elif score >= 2:   return "Corporal"
        else:              return "Private"
    else:
        if score >= 500: return "High Warlord"
        elif score >= 350: return "Warlord"
        elif score >= 250: return "General"
        elif score >= 175: return "Lieutenant General"
        elif score >= 120: return "Champion"
        elif score >= 80:  return "Centurion"
        elif score >= 50:  return "Legionnaire"
        elif score >= 30:  return "Blood Guard"
        elif score >= 15:  return "Stone Guard"
        elif score >= 8:   return "First Sergeant"
        elif score >= 4:   return "Senior Sergeant"
        elif score >= 2:   return "Grunt"
        else:              return "Scout"

@app.route("/api/armory", methods=["GET"])
def get_armory_directory():
    """Returns the realm combat directory for all known players with PvP honors and stats."""
    search = request.args.get("search", "").strip().lower()
    faction = request.args.get("faction", "").strip()
    char_class = request.args.get("class", "").strip()
    sort_by = request.args.get("sort", "kills")
    limit = min(int(request.args.get("limit", 60)), 150)

    with get_db() as conn:
        names_query = """
            SELECT DISTINCT killer_name AS name FROM kills WHERE killer_name IS NOT NULL AND killer_name != 'Unknown' AND killer_name != ''
            UNION
            SELECT DISTINCT victim_name AS name FROM kills WHERE victim_name IS NOT NULL AND victim_name != 'Unknown' AND victim_name != ''
            UNION
            SELECT DISTINCT character_name AS name FROM character_guild_history WHERE character_name IS NOT NULL AND character_name != ''
        """
        all_names = [r[0] for r in conn.execute(names_query).fetchall()]
        
        characters = []
        now_ts = int(time.time())

        # Preload active bounties map
        bounties_map = {}
        b_rows = conn.execute("SELECT target_name, amount_gold FROM bounties WHERE status = 'ACTIVE'").fetchall()
        for b in b_rows:
            bounties_map[b["target_name"]] = b["amount_gold"]

        # Preload KOS and Deserter sets
        kos_set = {r[0] for r in conn.execute("SELECT entity_name FROM kos_blacklist WHERE status = 'KOS'").fetchall()}
        deserter_map = {}
        d_rows = conn.execute("SELECT player_name, former_guild, expires_at FROM kos_deserters WHERE expires_at > ?", (now_ts,)).fetchall()
        for d in d_rows:
            deserter_map[d["player_name"]] = {
                "former_guild": d["former_guild"],
                "days_remaining": max(1, (d["expires_at"] - now_ts) // 86400)
            }

        for name in all_names:
            char_row = conn.execute("""
                SELECT killer_name AS name, killer_class AS class, killer_level AS level, killer_guild AS guild, killer_faction AS faction
                FROM kills WHERE killer_name = ?
                UNION
                SELECT victim_name AS name, victim_class AS class, victim_level AS level, victim_guild AS guild, victim_faction AS faction
                FROM kills WHERE victim_name = ?
                LIMIT 1
            """, (name, name)).fetchone()

            if not char_row:
                continue

            c_data = dict(char_row)
            c_class = c_data.get("class", "UNKNOWN")
            c_faction = c_data.get("faction", "Unknown")
            c_level = c_data.get("level", 60)
            c_guild = c_data.get("guild", "None")

            # Check guild history for latest guild
            latest_gh = conn.execute("SELECT guild_name, faction FROM character_guild_history WHERE character_name = ? ORDER BY last_seen DESC LIMIT 1", (name,)).fetchone()
            if latest_gh:
                if latest_gh["guild_name"]: c_guild = latest_gh["guild_name"]
                if latest_gh["faction"] and latest_gh["faction"] != "Unknown": c_faction = latest_gh["faction"]

            if faction and faction.lower() != "all" and c_faction.lower() != faction.lower():
                continue
            if char_class and char_class.upper() != "ALL" and c_class.upper() != char_class.upper():
                continue

            if search and (search not in name.lower() and search not in (c_guild or "").lower()):
                continue

            # Stats
            k_stat = conn.execute("""
                SELECT COUNT(*) AS total_kills,
                       COALESCE(SUM(is_solo), 0) AS solo_kills,
                       COALESCE(SUM(is_duel), 0) AS duel_kills,
                       COALESCE(SUM(is_battleground), 0) AS bg_kills,
                       COALESCE(SUM(killer_damage_done), 0) AS total_damage,
                       COALESCE(SUM(killer_healing_done), 0) AS total_healing
                FROM kills WHERE killer_name = ?
            """, (name,)).fetchone()

            d_stat = conn.execute("SELECT COUNT(*) FROM kills WHERE victim_name = ?", (name,)).fetchone()

            # Last seen
            ls_row = conn.execute("""
                SELECT zone, subzone, timestamp FROM kills
                WHERE killer_name = ? OR victim_name = ?
                ORDER BY timestamp DESC LIMIT 1
            """, (name, name)).fetchone()

            kills = k_stat["total_kills"] or 0
            deaths = d_stat[0] or 0
            kd = round(kills / deaths, 2) if deaths > 0 else float(kills)

            rank_title = calculate_pvp_rank_title(kills, kd, c_faction)

            char_obj = {
                "name": name,
                "class": c_class,
                "level": c_level,
                "faction": c_faction,
                "guild": c_guild,
                "kills": kills,
                "deaths": deaths,
                "kd": kd,
                "soloKills": k_stat["solo_kills"] or 0,
                "duelKills": k_stat["duel_kills"] or 0,
                "bgKills": k_stat["bg_kills"] or 0,
                "totalDamage": k_stat["total_damage"] or 0,
                "totalHealing": k_stat["total_healing"] or 0,
                "rankTitle": rank_title,
                "activeBountyGold": bounties_map.get(name, 0),
                "isKos": (name in kos_set) or (c_guild in kos_set),
                "deserter": deserter_map.get(name),
                "lastSeen": {
                    "zone": ls_row["zone"] if ls_row else "Azeroth",
                    "subzone": ls_row["subzone"] if ls_row else "",
                    "timestamp": ls_row["timestamp"] if ls_row else 0
                } if ls_row else None
            }
            characters.append(char_obj)

        # Compute cohort percentiles based on (class, spec, level)
        cohort_groups = {}
        for c in characters:
            c["spec"] = resolve_character_spec(c["class"])
            key = (c["class"].upper(), c["spec"].lower(), c["level"])
            if key not in cohort_groups:
                cohort_groups[key] = []
            cohort_groups[key].append(c)

        for key, cohort_list in cohort_groups.items():
            cohort_list.sort(key=lambda x: (x["kills"] * 1000) + x["kd"], reverse=True)
            total_n = len(cohort_list)
            for idx, c in enumerate(cohort_list):
                rank = idx + 1
                if total_n <= 1:
                    pct = 99.0
                    top = 1.0
                else:
                    pct = round(min(99.9, max(1.0, ((total_n - rank + 1) / total_n) * 100.0)), 1)
                    top = round(max(0.1, 100.0 - pct), 1)
                c["percentile"] = {
                    "percentile": pct,
                    "topPct": top,
                    "rank": rank,
                    "totalInCohort": total_n,
                    "cohortLabel": f"Level {c['level']} {c['spec']} {c['class'].capitalize()}",
                    "spec": c["spec"]
                }

        # Sorting
        if sort_by == "kd":
            characters.sort(key=lambda x: (x["kd"], x["kills"]), reverse=True)
        elif sort_by == "solo":
            characters.sort(key=lambda x: (x["soloKills"], x["kills"]), reverse=True)
        elif sort_by == "level":
            characters.sort(key=lambda x: (x["level"], x["kills"]), reverse=True)
        elif sort_by == "recent":
            characters.sort(key=lambda x: (x["lastSeen"]["timestamp"] if x["lastSeen"] else 0), reverse=True)
        else: # "kills" default
            characters.sort(key=lambda x: (x["kills"], x["kd"]), reverse=True)

        total_count = len(characters)
        paged_characters = characters[:limit]

    return jsonify({
        "total": total_count,
        "characters": paged_characters
    })

@app.route("/api/characters", methods=["GET"])
def get_characters_directory():
    """Returns a list of indexed characters known to the platform for character selection/linking."""
    search = request.args.get("search", "").strip().lower()
    faction = request.args.get("faction", "").strip().lower()
    limit = min(int(request.args.get("limit", 100)), 200)
    owner_token = request.headers.get("X-Owner-Token", "").strip() or request.args.get("owner_token", "").strip()

    with get_db() as conn:
        query = """
            SELECT c.name, c.realm, c.class, c.race, c.level, c.faction, c.guild, c.last_seen,
                   cc.owner_token, cc.claim_code, cc.verified
            FROM characters c
            LEFT JOIN character_claims cc ON LOWER(cc.character_name) = LOWER(c.name)
            WHERE c.name IS NOT NULL AND c.name != 'Unknown' AND c.name != ''
        """
        params = []
        if search:
            query += " AND LOWER(c.name) LIKE ?"
            params.append(f"%{search}%")
        if faction and faction in ("alliance", "horde"):
            query += " AND LOWER(c.faction) = ?"
            params.append(faction)

        query += " ORDER BY c.last_seen DESC, c.level DESC LIMIT ?"
        params.append(limit)

        rows = conn.execute(query, params).fetchall()
        result = []
        for r in rows:
            claimed_token = r["owner_token"]
            is_claimed = bool(claimed_token)
            is_verified = bool(r["verified"] and r["verified"] == 1)
            is_owner = bool(is_claimed and owner_token and claimed_token == owner_token)
            result.append({
                "name": r["name"],
                "realm": r["realm"] or "WoW Forever",
                "class": r["class"] or "UNKNOWN",
                "race": r["race"] or "Unknown",
                "level": r["level"] or 0,
                "faction": r["faction"] or "Unknown",
                "guild": r["guild"] or "None",
                "last_seen": r["last_seen"] or 0,
                "is_claimed": is_claimed,
                "is_verified": is_verified,
                "is_owner": is_owner,
                "claim_code": r["claim_code"] if is_owner else None,
            })
        return jsonify(result)

@app.route("/api/auth/claim-character", methods=["POST"])
def claim_character():
    """Allows a user to claim or register a character with cryptographic ownership protection."""
    data = request.json or {}
    name = (data.get("name") or data.get("characterName") or "").strip()
    if not name or name.lower() == "unknown":
        return jsonify({"error": "Valid character name required"}), 400

    owner_token = (data.get("owner_token") or request.headers.get("X-Owner-Token") or "").strip()
    if not owner_token:
        import uuid
        owner_token = f"tok_{uuid.uuid4().hex[:16]}"

    realm = (data.get("realm") or "WoW Forever").strip()
    char_class = (data.get("class") or "UNKNOWN").strip().upper()
    faction = (data.get("faction") or "Alliance").strip().capitalize()
    level = int(data.get("level") or 60)
    guild = (data.get("guild") or "None").strip()
    now_ts = int(time.time())

    with get_db() as conn:
        # Check if already claimed by someone else
        existing_claim = conn.execute(
            "SELECT owner_token, verified, claim_code FROM character_claims WHERE LOWER(character_name) = LOWER(?)",
            (name,)
        ).fetchone()
        if existing_claim:
            if existing_claim["owner_token"] != owner_token:
                return jsonify({
                    "error": f"Character '{name}' is already claimed and locked by its owner. Only the verified owner can claim or select this character.",
                    "is_claimed": True,
                    "is_owner": False
                }), 403
            else:
                claim_code = existing_claim["claim_code"]
                verified = bool(existing_claim["verified"])
        else:
            # Generate deterministic in-game verification code e.g. KB-XXXX
            import hashlib
            claim_hash = hashlib.md5(f"{name}_{now_ts}_{owner_token}".encode()).hexdigest()[:4].upper()
            claim_code = f"KB-{claim_hash}"
            verified = False
            conn.execute("""
                INSERT INTO character_claims (character_name, owner_token, claim_code, claimed_at, verified)
                VALUES (?, ?, ?, ?, ?)
            """, (name, owner_token, claim_code, now_ts, 0))

        conn.execute("""
            INSERT INTO characters (name, realm, guid, class, race, level, faction, guild, last_seen)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(name) DO UPDATE SET
                realm = excluded.realm,
                class = CASE WHEN excluded.class != 'UNKNOWN' THEN excluded.class ELSE characters.class END,
                faction = excluded.faction,
                level = CASE WHEN excluded.level > 0 THEN excluded.level ELSE characters.level END,
                guild = CASE WHEN excluded.guild != 'None' THEN excluded.guild ELSE characters.guild END,
                last_seen = excluded.last_seen
        """, (name, realm, f"Player-CLAIM-{name}", char_class, "Unknown", level, faction, guild, now_ts))
        conn.commit()

    return jsonify({
        "success": True,
        "owner_token": owner_token,
        "claim_code": claim_code,
        "verified": verified,
        "character": {
            "name": name,
            "realm": realm,
            "class": char_class,
            "faction": faction,
            "level": level,
            "guild": guild
        }
    })

@app.route("/api/auth/verify-claim", methods=["POST"])
def verify_claim():
    """Verifies in-game claim code from SavedVariables sync or user submission."""
    data = request.json or {}
    name = (data.get("name") or data.get("character_name") or "").strip()
    code = (data.get("code") or data.get("claim_code") or "").strip().upper()
    if not name or not code:
        return jsonify({"error": "Character name and claim code required"}), 400

    with get_db() as conn:
        claim = conn.execute(
            "SELECT * FROM character_claims WHERE LOWER(character_name) = LOWER(?)",
            (name,)
        ).fetchone()
        if not claim:
            return jsonify({"error": "No pending claim found for this character"}), 404
        if claim["claim_code"] == code:
            conn.execute("UPDATE character_claims SET verified = 1 WHERE LOWER(character_name) = LOWER(?)", (name,))
            conn.commit()
            return jsonify({"success": True, "message": f"Character '{name}' ownership verified and locked to owner."})
        else:
            return jsonify({"error": "Invalid verification code"}), 400

@app.route("/api/auth/release-claim", methods=["POST"])
def release_claim():
    """Allows an owner or claimant to release/cancel a pending or owned claim."""
    data = request.json or {}
    name = (data.get("name") or data.get("character_name") or data.get("characterName") or "").strip()
    owner_token = (data.get("owner_token") or request.headers.get("X-Owner-Token") or "").strip()
    if not name:
        return jsonify({"error": "Character name required"}), 400

    with get_db() as conn:
        existing = conn.execute(
            "SELECT owner_token, verified FROM character_claims WHERE LOWER(character_name) = LOWER(?)",
            (name,)
        ).fetchone()
        if not existing:
            return jsonify({"success": True, "message": "No claim found for this character"})

        # If owner_token provided and matches or if unverified, allow releasing
        if existing["owner_token"] and owner_token and existing["owner_token"] != owner_token:
            return jsonify({"error": "Unauthorized: Owner token does not match"}), 403

        conn.execute("DELETE FROM character_claims WHERE LOWER(character_name) = LOWER(?)", (name,))
        conn.commit()

    return jsonify({"success": True, "message": f"Claim on '{name}' released successfully"})

@app.route("/api/auth/bnet", methods=["GET"])
def auth_bnet():
    """Redirects user to Blizzard Battle.net OAuth authorize endpoint."""
    client_id = os.environ.get("BLIZZARD_CLIENT_ID", "").strip()
    client_secret = os.environ.get("BLIZZARD_CLIENT_SECRET", "").strip()
    region = os.environ.get("BLIZZARD_REGION", "us").strip()

    if not client_id or not client_secret:
        return jsonify({
            "status": "config_needed",
            "message": "Battle.net OAuth requires BLIZZARD_CLIENT_ID and BLIZZARD_CLIENT_SECRET environment variables. You can claim or select any character immediately in the War Room character selector modal!",
            "instructions": "Register an application at https://develop.battle.net to obtain credentials, or select your character from the active Killboard directory."
        }), 200

    import urllib.parse
    from flask import redirect
    redirect_uri = request.host_url.rstrip("/") + "/api/auth/bnet/callback"
    state = f"bnet_{int(time.time())}"
    bnet_auth_url = (
        f"https://oauth.battle.net/authorize?"
        f"client_id={urllib.parse.quote(client_id)}&"
        f"scope=wow.profile&"
        f"response_type=code&"
        f"redirect_uri={urllib.parse.quote(redirect_uri)}&"
        f"state={state}"
    )
    return redirect(bnet_auth_url)

@app.route("/api/auth/bnet/callback", methods=["GET"])
def auth_bnet_callback():
    """Handles OAuth 2.0 callback from Blizzard Battle.net, extracts characters, and persists."""
    code = request.args.get("code")
    client_id = os.environ.get("BLIZZARD_CLIENT_ID", "").strip()
    client_secret = os.environ.get("BLIZZARD_CLIENT_SECRET", "").strip()
    region = os.environ.get("BLIZZARD_REGION", "us").strip()

    if not code or not client_id or not client_secret:
        from flask import redirect
        return redirect("/?bnet_error=missing_code_or_credentials")

    import urllib.parse
    import requests
    from flask import redirect
    redirect_uri = request.host_url.rstrip("/") + "/api/auth/bnet/callback"

    try:
        token_resp = requests.post(
            "https://oauth.battle.net/oauth/token",
            data={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirect_uri
            },
            auth=(client_id, client_secret),
            timeout=10
        )
        if token_resp.status_code != 200:
            return redirect(f"/?bnet_error=token_failed&detail={urllib.parse.quote(token_resp.text[:100])}")

        token_data = token_resp.json()
        access_token = token_data.get("access_token")

        user_resp = requests.get(
            "https://oauth.battle.net/oauth/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10
        )
        battletag = user_resp.json().get("battletag", "Player") if user_resp.status_code == 200 else "Player"

        chars_resp = requests.get(
            f"https://{region}.battle.net/profile/user/wow?namespace=profile-{region}&locale=en_US",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10
        )

        discovered = []
        now_ts = int(time.time())
        if chars_resp.status_code == 200:
            profile_data = chars_resp.json()
            with get_db() as conn:
                for acct in profile_data.get("wow_accounts", []):
                    for ch in acct.get("characters", []):
                        ch_name = ch.get("name")
                        ch_realm = ch.get("realm", {}).get("name", "WoW Forever")
                        ch_class = ch.get("playable_class", {}).get("name", "WARRIOR").upper()
                        ch_faction = ch.get("faction", {}).get("name", "Alliance")
                        ch_lvl = ch.get("level", 60)
                        if ch_name:
                            discovered.append(ch_name)
                            conn.execute("""
                                INSERT INTO characters (name, realm, guid, class, race, level, faction, guild, last_seen)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                                ON CONFLICT(name) DO UPDATE SET
                                    realm = excluded.realm,
                                    class = excluded.class,
                                    level = excluded.level,
                                    faction = excluded.faction,
                                    last_seen = excluded.last_seen
                            """, (ch_name, ch_realm, f"Player-BNET-{ch_name}", ch_class, "Unknown", ch_lvl, ch_faction, "None", now_ts))
                conn.commit()

        return redirect(f"/?bnet_user={urllib.parse.quote(battletag)}&bnet_chars={urllib.parse.quote(','.join(discovered[:10]))}")
    except Exception as e:
        return redirect(f"/?bnet_error=exception&detail={urllib.parse.quote(str(e)[:100])}")

@app.route("/api/character/<name>", methods=["GET"])

def get_character_profile(name):
    with get_db() as conn:
        char_row = conn.execute("""
            SELECT killer_name AS name, killer_class AS class, killer_level AS level, killer_guild AS guild, killer_faction AS faction
            FROM kills WHERE killer_name = ?
            UNION
            SELECT victim_name AS name, victim_class AS class, victim_level AS level, victim_guild AS guild, victim_faction AS faction
            FROM kills WHERE victim_name = ?
            LIMIT 1
        """, (name, name)).fetchone()

        if not char_row:
            # Check if character exists in characters directory table
            dir_row = conn.execute("SELECT name, class, level, guild, faction FROM characters WHERE name = ?", (name,)).fetchone()
            if dir_row:
                char_data = dict(dir_row)
            else:
                # Check if character exists in debt_ledger, bounties, or kos_blacklist
                debt_fallback = conn.execute("SELECT * FROM debt_ledger WHERE player_name = ?", (name,)).fetchone()
                bnt_fallback = conn.execute("SELECT * FROM bounties WHERE target_name = ?", (name,)).fetchone()
                kos_fallback = conn.execute("SELECT * FROM kos_blacklist WHERE entity_name = ?", (name,)).fetchone()
            if debt_fallback:
                char_data = {"name": name, "class": "WARRIOR", "level": 60, "guild": "None", "faction": "Unknown"}
            elif bnt_fallback:
                char_data = {"name": name, "class": bnt_fallback["target_class"] or "UNKNOWN", "level": 60, "guild": "None", "faction": bnt_fallback["target_faction"] or "Unknown"}
            elif kos_fallback:
                char_data = {"name": name, "class": "UNKNOWN", "level": 60, "guild": "None", "faction": "Unknown"}
            else:
                char_data = {"name": name, "class": "WARRIOR", "level": 60, "guild": "Vanguard Frontier", "faction": "Alliance"}
        else:
            char_data = dict(char_row)

        # Total Kills & breakdown
        kills_stat = conn.execute("""
            SELECT COUNT(*) AS total_kills,
                   COALESCE(SUM(is_solo), 0) AS solo_kills,
                   COALESCE(SUM(is_duel), 0) AS duel_kills,
                   COALESCE(SUM(is_battleground), 0) AS bg_kills,
                   COALESCE(SUM(killer_damage_done), 0) AS total_damage,
                   COALESCE(SUM(killer_healing_done), 0) AS total_healing
            FROM kills WHERE killer_name = ?
        """, (name,)).fetchone()

        # Total Deaths
        deaths_stat = conn.execute("""
            SELECT COUNT(*) AS total_deaths
            FROM kills WHERE victim_name = ?
        """, (name,)).fetchone()

        total_kills = kills_stat["total_kills"] or 0
        total_deaths = deaths_stat["total_deaths"] or 0
        kd = round(total_kills / total_deaths, 2) if total_deaths > 0 else float(total_kills)

        # Guild History
        guild_history_rows = conn.execute("""
            SELECT guild_name, faction, first_seen, last_seen
            FROM character_guild_history
            WHERE character_name = ?
            ORDER BY last_seen DESC
        """, (name,)).fetchall()
        guild_history = [dict(r) for r in guild_history_rows]

        # Recent Kills (last 10)
        recent_kills_rows = conn.execute("""
            SELECT kill_id, timestamp, is_duel, is_battleground, is_solo, zone, subzone,
                   victim_name, victim_level, victim_class, victim_guild, total_damage
            FROM kills WHERE killer_name = ?
            ORDER BY timestamp DESC
            LIMIT 10
        """, (name,)).fetchall()
        recent_kills = [dict(r) for r in recent_kills_rows]

        # Recent Deaths (last 10)
        recent_deaths_rows = conn.execute("""
            SELECT kill_id, timestamp, is_duel, is_battleground, is_solo, zone, subzone,
                   killer_name, killer_level, killer_class, killer_guild, total_damage
            FROM kills WHERE victim_name = ?
            ORDER BY timestamp DESC
            LIMIT 10
        """, (name,)).fetchall()
        recent_deaths = [dict(r) for r in recent_deaths_rows]

        current_guild = guild_history[0]["guild_name"] if guild_history else (char_data.get("guild") or "None")
        faction = char_data.get("faction", "Unknown")

        # Honor Rank Title
        rank_title = calculate_pvp_rank_title(total_kills, kd, faction)

        # Active Bounty Check
        bounty_row = conn.execute("SELECT amount_gold FROM bounties WHERE target_name = ? AND status = 'ACTIVE' LIMIT 1", (name,)).fetchone()
        active_bounty_gold = bounty_row[0] if bounty_row else 0

        # KOS & Deserter Check
        now_ts = int(time.time())
        is_kos = bool(conn.execute("SELECT 1 FROM kos_blacklist WHERE entity_name = ? OR entity_name = ?", (name, current_guild)).fetchone())
        deserter_row = conn.execute("SELECT former_guild, expires_at FROM kos_deserters WHERE (player_name = ? OR former_guild = ?) AND expires_at > ? LIMIT 1", (name, current_guild, now_ts)).fetchone()
        deserter_data = None
        if deserter_row:
            deserter_data = {
                "former_guild": deserter_row[0],
                "days_remaining": max(1, (deserter_row[1] - now_ts) // 86400)
            }

        # Blood Debtor Check (Immutable GUID & Name Tracking)
        char_guid = None
        g_row = conn.execute("SELECT raw_json FROM kills WHERE killer_name = ? OR victim_name = ? LIMIT 1", (name, name)).fetchone()
        if g_row and g_row[0]:
            try:
                rj = json.loads(g_row[0])
                if rj.get("killer", {}).get("name") == name:
                    char_guid = rj.get("killer", {}).get("guid")
                elif rj.get("victim", {}).get("name") == name:
                    char_guid = rj.get("victim", {}).get("guid")
            except Exception:
                pass

        debt_query = "SELECT * FROM debt_ledger WHERE (player_name = ?"
        params = [name]
        if char_guid:
            debt_query += " OR player_guid = ?"
            params.append(char_guid)
        debt_query += ") AND status IN ('BLOOD_DEBTOR', 'OATHBREAKER') LIMIT 1"

        debt_row = conn.execute(debt_query, params).fetchone()
        blood_debt_data = None
        if debt_row:
            is_kos = True
            blood_debt_data = {
                "creditor": debt_row["creditor"],
                "amountOwedCopper": debt_row["amount_owed_copper"],
                "amountOwedGold": debt_row["amount_owed_copper"] // 10000,
                "daysInDefault": debt_row["days_in_default"],
                "status": "BLOOD_DEBTOR"
            }

        reputation = "HONORABLE COMBATANT"
        if blood_debt_data:
            reputation = "BLOOD DEBTOR — KILL ON SIGHT"
        elif is_kos:
            reputation = "KOS BLACKLISTED"

        realm = "classic"
        armory_urls = {
            "official": f"https://worldofwarcraft.blizzard.com/en-us/character/us/{realm}/{name.lower()}",
            "ironforge": f"https://ironforge.pro/pvp/player/{realm}/{name.lower()}/",
            "warcraftlogs": f"https://classic.warcraftlogs.com/character/us/{realm}/{name.lower()}"
        }

        # Check if killer_spec or victim_spec was logged
        spec_row = conn.execute("""
            SELECT killer_spec FROM kills WHERE killer_name = ? AND killer_spec IS NOT NULL AND killer_spec != ''
            UNION
            SELECT victim_spec FROM kills WHERE victim_name = ? AND victim_spec IS NOT NULL AND victim_spec != ''
            LIMIT 1
        """, (name, name)).fetchone()
        raw_spec = spec_row[0] if spec_row else None
        char_spec = resolve_character_spec(char_data.get("class", "WARRIOR"), raw_spec)

        percentile_data = compute_character_percentile(
            conn, name, char_data.get("class", "WARRIOR"), char_spec, char_data.get("level", 60), total_kills, kd
        )

        return jsonify({
            "name": name,
            "guid": char_guid,
            "class": char_data.get("class", "UNKNOWN"),
            "spec": char_spec,
            "level": char_data.get("level", 60),
            "faction": faction,
            "currentGuild": current_guild,
            "rankTitle": rank_title,
            "percentile": percentile_data,
            "activeBountyGold": active_bounty_gold,
            "isKos": is_kos,
            "bloodDebtor": blood_debt_data,
            "reputation": reputation,
            "deserter": deserter_data,
            "stats": {
                "kills": total_kills,
                "deaths": total_deaths,
                "kd": kd,
                "soloKills": kills_stat["solo_kills"] or 0,
                "duelKills": kills_stat["duel_kills"] or 0,
                "bgKills": kills_stat["bg_kills"] or 0,
                "totalDamage": kills_stat["total_damage"] or 0,
                "totalHealing": kills_stat["total_healing"] or 0,
            },
            "guildHistory": guild_history,
            "recentKills": recent_kills,
            "recentDeaths": recent_deaths,
            "armoryUrls": armory_urls
        })

@app.route("/api/guilds", methods=["GET"])
def get_guilds_leaderboard():
    mode = request.args.get("mode", "ALL").upper()
    where = "WHERE k.killer_guild IS NOT NULL AND k.killer_guild != 'None' AND k.killer_guild != ''"
    victim_where = "WHERE victim_guild = ?"
    member_where = "WHERE killer_guild = ?"

    if mode == "WORLD":
        where += " AND k.is_battleground = 0 AND k.is_arena = 0 AND (k.is_duel = 0 OR k.is_duel IS NULL)"
        victim_where += " AND is_battleground = 0 AND is_arena = 0 AND (is_duel = 0 OR is_duel IS NULL)"
        member_where += " AND is_battleground = 0 AND is_arena = 0 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "BG":
        where += " AND k.is_battleground = 1"
        victim_where += " AND is_battleground = 1"
        member_where += " AND is_battleground = 1"
    elif mode == "ARENA":
        where += " AND k.is_arena = 1"
        victim_where += " AND is_arena = 1"
        member_where += " AND is_arena = 1"
    elif mode == "DUEL":
        where += " AND k.is_duel = 1"
        victim_where += " AND is_duel = 1"
        member_where += " AND is_duel = 1"

    with get_db() as conn:
        guilds_query = f"""
            SELECT 
                k.killer_guild AS guild,
                k.killer_faction AS faction,
                COUNT(k.kill_id) AS kills,
                COALESCE(SUM(k.is_solo), 0) AS solo_kills,
                COUNT(DISTINCT k.killer_name) AS members_count
            FROM kills k
            {where}
            GROUP BY k.killer_guild
            ORDER BY kills DESC
            LIMIT 50
        """
        guilds = [dict(r) for r in conn.execute(guilds_query).fetchall()]

        for g in guilds:
            g_name = g["guild"]
            death_count = conn.execute(f"""
                SELECT COUNT(*) FROM kills {victim_where}
            """, (g_name,)).fetchone()[0]
            g["deaths"] = death_count
            g["kd"] = round(g["kills"] / death_count, 2) if death_count > 0 else float(g["kills"])

            top_member = conn.execute(f"""
                SELECT killer_name AS name, killer_class AS class, COUNT(*) as kills
                FROM kills {member_where}
                GROUP BY killer_name
                ORDER BY kills DESC LIMIT 1
            """, (g_name,)).fetchone()
            g["topMember"] = dict(top_member) if top_member else None

        return jsonify({"guilds": guilds})

@app.route("/api/guild/<guild_name>", methods=["GET"])
def get_guild_profile(guild_name):
    with get_db() as conn:
        kills_stat = conn.execute("""
            SELECT COUNT(*) AS total_kills, killer_faction AS faction,
                   COALESCE(SUM(is_solo), 0) AS solo_kills,
                   COUNT(DISTINCT killer_name) AS member_count
            FROM kills
            WHERE killer_guild = ?
        """, (guild_name,)).fetchone()

        if not kills_stat or kills_stat["total_kills"] == 0:
            victim_stat = conn.execute("""
                SELECT COUNT(*) AS total_deaths, victim_faction AS faction
                FROM kills WHERE victim_guild = ?
            """, (guild_name,)).fetchone()
            if not victim_stat or victim_stat["total_deaths"] == 0:
                return jsonify({"error": "Guild not found"}), 404
            total_kills = 0
            total_deaths = victim_stat["total_deaths"]
            faction = victim_stat["faction"] or "Unknown"
            solo_kills = 0
            member_count = 0
        else:
            total_kills = kills_stat["total_kills"]
            faction = kills_stat["faction"] or "Unknown"
            solo_kills = kills_stat["solo_kills"]
            member_count = kills_stat["member_count"]
            total_deaths = conn.execute("SELECT COUNT(*) FROM kills WHERE victim_guild = ?", (guild_name,)).fetchone()[0]

        kd = round(total_kills / total_deaths, 2) if total_deaths > 0 else float(total_kills)

        members = [dict(r) for r in conn.execute("""
            SELECT killer_name AS name, killer_class AS class, killer_level AS level,
                   COUNT(*) AS kills, SUM(is_solo) AS solo_kills, MAX(timestamp) AS last_seen
            FROM kills WHERE killer_guild = ?
            GROUP BY killer_name
            ORDER BY kills DESC
        """, (guild_name,)).fetchall()]

        recent_kills = [dict(r) for r in conn.execute("""
            SELECT kill_id, timestamp, is_duel, is_battleground, is_solo, zone, subzone,
                   killer_name, killer_class, victim_name, victim_class, victim_guild, total_damage
            FROM kills WHERE killer_guild = ?
            ORDER BY timestamp DESC
            LIMIT 15
        """, (guild_name,)).fetchall()]

        return jsonify({
            "guild": guild_name,
            "faction": faction,
            "kills": total_kills,
            "deaths": total_deaths,
            "kd": kd,
            "soloKills": solo_kills,
            "memberCount": member_count,
            "members": members,
            "recentKills": recent_kills
        })

# ----------------- Bounties & Debt Ledger API -----------------

@app.route("/api/bounties", methods=["GET"])
def get_bounties():
    is_supporter = request.args.get("supporter") == "1"
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM bounties ORDER BY timestamp DESC").fetchall()
        bounties = [dict(r) for r in rows]
        now = int(time.time())

        for b in bounties:
            target = b["target_name"]
            last_kill = conn.execute("""
                SELECT timestamp, zone, subzone
                FROM kills
                WHERE killer_name = ? OR victim_name = ?
                ORDER BY timestamp DESC
                LIMIT 1
            """, (target, target)).fetchone()

            if last_kill:
                kill_time = last_kill["timestamp"]
                elapsed = max(0, now - kill_time)
                zone_name = last_kill["zone"] or "Unknown"
                subzone_name = last_kill["subzone"] or ""

                b["lastSeen"] = {
                    "hasTelemetry": True,
                    "zone": zone_name,
                    "subzone": subzone_name if is_supporter else None,
                    "hasSubzoneAccess": is_supporter,
                    "timestamp": kill_time,
                    "elapsedSeconds": elapsed,
                    "minutesAgo": max(1, elapsed // 60),
                    "displayText": f"{zone_name} ({subzone_name})" if (is_supporter and subzone_name) else zone_name
                }
            else:
                b["lastSeen"] = {
                    "hasTelemetry": False,
                    "displayText": "Unknown (No combat logged)"
                }

    return jsonify(bounties)

@app.route("/api/bounties/leaderboards", methods=["GET"])
def get_bounties_leaderboards():
    now = int(time.time())
    with get_db() as conn:
        # 1. Top Bounty Hunters
        top_hunters_rows = conn.execute("""
            SELECT hunter_name, COUNT(*) AS claimed_count, SUM(amount_gold) AS total_gold
            FROM bounties
            WHERE status = 'CLAIMED' AND hunter_name IS NOT NULL AND hunter_name != ''
            GROUP BY hunter_name
            ORDER BY claimed_count DESC, total_gold DESC
            LIMIT 10
        """).fetchall()
        top_hunters = [dict(r) for r in top_hunters_rows]

        # 2. Highest Bounty Contracts
        highest_rows = conn.execute("""
            SELECT id, target_name, target_class, target_faction, placer_name, amount_gold, status, hunter_name, timestamp
            FROM bounties
            ORDER BY amount_gold DESC
            LIMIT 10
        """).fetchall()
        highest_bounties = [dict(r) for r in highest_rows]

        # 3. Longest Outstanding Bounties (Most Elusive Outlaws)
        longest_rows = conn.execute("""
            SELECT id, target_name, target_class, target_faction, placer_name, amount_gold, timestamp,
                   (? - timestamp) AS elapsed_seconds
            FROM bounties
            WHERE status = 'ACTIVE'
            ORDER BY timestamp ASC
            LIMIT 10
        """, (now,)).fetchall()
        longest_outstanding = [dict(r) for r in longest_rows]

        # 4. Fastest Collected Bounties
        fastest_rows = conn.execute("""
            SELECT id, target_name, target_class, placer_name, hunter_name, amount_gold, timestamp, payment_deadline,
                   (payment_deadline - timestamp) AS duration_seconds
            FROM bounties
            WHERE status = 'CLAIMED' AND payment_deadline IS NOT NULL AND payment_deadline >= timestamp
            ORDER BY duration_seconds ASC
            LIMIT 10
        """).fetchall()
        fastest_collected = [dict(r) for r in fastest_rows]

    return jsonify({
        "topHunters": top_hunters,
        "highestBounties": highest_bounties,
        "longestOutstanding": longest_outstanding,
        "fastestCollected": fastest_collected
    })

@app.route("/api/bounties", methods=["POST"])
def create_bounty():
    data = request.json or {}
    if data.get("is_instance") or data.get("isBattleground") or data.get("isArena"):
        return jsonify({"error": "Blood bounties can only be placed upon the open battlefields of Azeroth (Open World PvP only)."}), 400

    b_id = data.get("id") or f"BNT-{int(time.time()*1000)}"
    target = data.get("targetName", "Unknown")
    target_guid = data.get("targetGuid", "UNKNOWN")
    gold = int(data.get("amountGold", 100))
    copper = int(data.get("amountCopper", gold * 10000))
    placer = data.get("placerName", "Anonymous")

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO bounties (
                id, target_name, target_guid, target_class, target_faction, placer_name,
                amount_copper, amount_gold, status, timestamp, expiry
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'ACTIVE', ?, ?)
        """, (
            b_id, target, target_guid, data.get("targetClass", "UNKNOWN"), data.get("targetFaction", "Unknown"),
            placer, copper, gold, int(time.time()), int(time.time() + 86400 * 7)
        ))
        conn.commit()

    return jsonify({"success": True, "bountyId": b_id}), 201

@app.route("/api/bounties/most-wanted", methods=["GET"])
def get_most_wanted():
    is_supporter = request.args.get("supporter") == "1"
    now = int(time.time())
    with get_db() as conn:
        rows = conn.execute("""
            SELECT id, target_name, target_guid, target_class, target_faction, placer_name,
                   amount_gold, amount_copper, timestamp
            FROM bounties
            WHERE status = 'ACTIVE'
            ORDER BY amount_gold DESC
            LIMIT 10
        """).fetchall()
        most_wanted = []
        for r in rows:
            b = dict(r)
            target = b["target_name"]
            last_kill = conn.execute("""
                SELECT timestamp, zone, subzone
                FROM kills
                WHERE killer_name = ? OR victim_name = ?
                ORDER BY timestamp DESC
                LIMIT 1
            """, (target, target)).fetchone()

            if last_kill:
                kill_time = last_kill["timestamp"]
                elapsed = max(0, now - kill_time)
                zone_name = last_kill["zone"] or "Unknown"
                subzone_name = last_kill["subzone"] or ""
                b["lastSeen"] = {
                    "hasTelemetry": True,
                    "zone": zone_name,
                    "subzone": subzone_name if is_supporter else None,
                    "hasSubzoneAccess": is_supporter,
                    "displayText": f"{zone_name} ({subzone_name})" if (is_supporter and subzone_name) else zone_name,
                    "elapsedSeconds": elapsed,
                    "minutesAgo": max(1, elapsed // 60)
                }
            else:
                b["lastSeen"] = {
                    "hasTelemetry": False,
                    "displayText": "Unknown (No combat logged)"
                }

            acc_row = conn.execute("SELECT COUNT(*) FROM bounty_acceptances WHERE bounty_id = ?", (b["id"],)).fetchone()
            b["acceptedCount"] = acc_row[0] if acc_row else 0
            most_wanted.append(b)

    return jsonify(most_wanted)

@app.route("/api/bounties/accept", methods=["POST"])
def accept_bounty():
    data = request.json
    if not data or "bountyId" not in data or "hunterName" not in data:
        return jsonify({"error": "Missing bountyId or hunterName"}), 400
    b_id = data["bountyId"]
    hunter = data["hunterName"]
    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO bounty_acceptances (bounty_id, hunter_name, accepted_at)
            VALUES (?, ?, ?)
        """, (b_id, hunter, int(time.time())))
        conn.commit()
    return jsonify({"success": True, "bountyId": b_id, "hunterName": hunter})

@app.route("/api/bounties/archive", methods=["GET"])
def get_bounties_archive():
    now = int(time.time())
    thirty_days_ago = now - (30 * 86400)
    with get_db() as conn:
        # Move bounties older than 30 days to COLD_CASE
        conn.execute("""
            UPDATE bounties
            SET status = 'COLD_CASE'
            WHERE status = 'ACTIVE' AND timestamp < ?
        """, (thirty_days_ago,))
        conn.commit()

        rows = conn.execute("""
            SELECT * FROM bounties
            WHERE status = 'COLD_CASE'
            ORDER BY timestamp DESC
        """).fetchall()
        cold_cases = [dict(r) for r in rows]
    return jsonify(cold_cases)

@app.route("/api/stats/activity-7d", methods=["GET"])
@app.route("/api/stats/sidebar", methods=["GET"])
def get_activity_7d():
    now = int(time.time())
    one_day_ago = now - 86400
    with get_db() as conn:
        # Lifetime total kills (Open World & BGs, Duels isolated)
        total_kills = conn.execute("SELECT COUNT(*) FROM kills WHERE (is_duel = 0 OR is_duel IS NULL)").fetchone()[0]

        # Lifetime active characters (includes combatants and scanner-indexed characters)
        char_count = conn.execute("""
            SELECT COUNT(DISTINCT name) FROM (
                SELECT killer_name AS name FROM kills WHERE killer_name != 'Unknown'
                UNION
                SELECT victim_name AS name FROM kills WHERE victim_name != 'Unknown'
                UNION
                SELECT name FROM characters WHERE name IS NOT NULL AND name != 'Unknown'
            )
        """).fetchone()[0]

        # Lifetime active guilds
        guild_count = conn.execute("""
            SELECT COUNT(DISTINCT guild) FROM (
                SELECT killer_guild AS guild FROM kills WHERE killer_guild IS NOT NULL AND killer_guild != 'None' AND killer_guild != ''
                UNION
                SELECT victim_guild AS guild FROM kills WHERE victim_guild IS NOT NULL AND victim_guild != 'None' AND victim_guild != ''
            )
        """).fetchone()[0]

        # Lifetime faction breakdown (excluding duels)
        alliance_kills = conn.execute(
            "SELECT COUNT(*) FROM kills WHERE killer_faction = 'Alliance' AND (is_duel = 0 OR is_duel IS NULL)"
        ).fetchone()[0]
        horde_kills = conn.execute(
            "SELECT COUNT(*) FROM kills WHERE killer_faction = 'Horde' AND (is_duel = 0 OR is_duel IS NULL)"
        ).fetchone()[0]

        # 1. Deadliest Zones (Last 24 Hours - Open World / Battlegrounds, Duels Excluded)
        deadliest_zones_rows = conn.execute("""
            SELECT zone, COUNT(*) AS kills
            FROM kills
            WHERE timestamp >= ? AND zone IS NOT NULL AND zone != '' AND zone != 'Unknown' AND (is_duel = 0 OR is_duel IS NULL)
            GROUP BY zone
            ORDER BY kills DESC
            LIMIT 5
        """, (one_day_ago,)).fetchall()
        if not deadliest_zones_rows:
            deadliest_zones_rows = conn.execute("""
                SELECT zone, COUNT(*) AS kills
                FROM kills
                WHERE zone IS NOT NULL AND zone != '' AND zone != 'Unknown' AND (is_duel = 0 OR is_duel IS NULL)
                GROUP BY zone
                ORDER BY kills DESC
                LIMIT 5
            """).fetchall()
        top_zones_24h = [dict(r) for r in deadliest_zones_rows]

        # 2. Top Active Gankers (Last 24 Hours - Duels Excluded from Ganks)
        top_gankers_rows = conn.execute("""
            SELECT killer_name AS name, killer_class AS class, killer_spec AS spec, killer_faction AS faction, killer_guild AS guild, COUNT(*) AS kills
            FROM kills
            WHERE timestamp >= ? AND killer_name != 'Unknown' AND (is_duel = 0 OR is_duel IS NULL)
            GROUP BY killer_name
            ORDER BY kills DESC
            LIMIT 5
        """, (one_day_ago,)).fetchall()
        if not top_gankers_rows:
            top_gankers_rows = conn.execute("""
                SELECT killer_name AS name, killer_class AS class, killer_spec AS spec, killer_faction AS faction, killer_guild AS guild, COUNT(*) AS kills
                FROM kills
                WHERE killer_name != 'Unknown' AND (is_duel = 0 OR is_duel IS NULL)
                GROUP BY killer_name
                ORDER BY kills DESC
                LIMIT 5
            """).fetchall()
        top_chars_24h = [dict(r) for r in top_gankers_rows]

        # 3. Top Active Guilds (Last 24 Hours - Duels Excluded)
        top_guilds_rows = conn.execute("""
            SELECT killer_guild AS guild, killer_faction AS faction, COUNT(*) AS kills
            FROM kills
            WHERE timestamp >= ? AND killer_guild IS NOT NULL AND killer_guild != 'None' AND killer_guild != '' AND (is_duel = 0 OR is_duel IS NULL)
            GROUP BY killer_guild
            ORDER BY kills DESC
            LIMIT 5
        """, (one_day_ago,)).fetchall()
        if not top_guilds_rows:
            top_guilds_rows = conn.execute("""
                SELECT killer_guild AS guild, killer_faction AS faction, COUNT(*) AS kills
                FROM kills
                WHERE killer_guild IS NOT NULL AND killer_guild != 'None' AND killer_guild != '' AND (is_duel = 0 OR is_duel IS NULL)
                GROUP BY killer_guild
                ORDER BY kills DESC
                LIMIT 5
            """).fetchall()
        top_guilds_24h = [dict(r) for r in top_guilds_rows]

        # 4. Top Classes (Lifetime) - All Classes for Realm
        CLASSIC_CLASSES = ["WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"]
        RETAIL_CLASSES = CLASSIC_CLASSES + ["DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"]

        flavor_str = "CLASSIC_ERA"
        flavor_row = conn.execute("SELECT value FROM platform_stats WHERE key='client_flavor'").fetchone()
        if flavor_row and flavor_row[0]:
            try:
                flavor_str = json.loads(flavor_row[0])
            except Exception:
                flavor_str = flavor_row[0]

        base_classes = RETAIL_CLASSES if flavor_str == "RETAIL" else (CLASSIC_CLASSES + ["DEATHKNIGHT"] if flavor_str == "WOTLK" else CLASSIC_CLASSES)

        raw_classes = conn.execute("""
            SELECT UPPER(killer_class) AS class, COUNT(*) AS kills
            FROM kills
            WHERE killer_class IS NOT NULL AND killer_class != ''
            GROUP BY UPPER(killer_class)
        """).fetchall()
        class_dict = {r["class"]: r["kills"] for r in raw_classes}

        # Include all flavor base classes, plus any logged class with recorded kills
        all_class_keys = list(base_classes)
        for k in class_dict.keys():
            if k not in all_class_keys:
                all_class_keys.append(k)

        top_classes = []
        for cls in all_class_keys:
            top_classes.append({
                "class": cls,
                "kills": class_dict.get(cls, 0)
            })
        top_classes.sort(key=lambda x: x["class"])

        # 5. Top Specs (Lifetime) - All Specializations
        CLASSIC_SPECS = [
            ("Affliction", "WARLOCK"), ("Arcane", "MAGE"), ("Arms", "WARRIOR"),
            ("Assassination", "ROGUE"), ("Balance", "DRUID"), ("Beast Mastery", "HUNTER"),
            ("Combat", "ROGUE"), ("Demonology", "WARLOCK"), ("Destruction", "WARLOCK"),
            ("Discipline", "PRIEST"), ("Elemental", "SHAMAN"), ("Enhancement", "SHAMAN"),
            ("Feral Combat", "DRUID"), ("Fire", "MAGE"), ("Frost", "MAGE"),
            ("Fury", "WARRIOR"), ("Holy", "PALADIN"), ("Holy", "PRIEST"),
            ("Marksmanship", "HUNTER"), ("Protection", "PALADIN"), ("Protection", "WARRIOR"),
            ("Restoration", "DRUID"), ("Restoration", "SHAMAN"), ("Retribution", "PALADIN"),
            ("Shadow", "PRIEST"), ("Subtlety", "ROGUE"), ("Survival", "HUNTER")
        ]

        raw_specs = conn.execute("""
            SELECT killer_spec AS spec, killer_class AS class, COUNT(*) AS kills
            FROM kills
            WHERE killer_spec IS NOT NULL AND killer_spec != '' AND killer_spec != 'Unknown'
            GROUP BY killer_spec, killer_class
        """).fetchall()
        spec_dict = {(r["spec"].strip().lower(), (r["class"] or "").strip().upper()): r["kills"] for r in raw_specs}

        all_specs_dict = {}
        for sp_name, sp_cls in CLASSIC_SPECS:
            kills_val = spec_dict.get((sp_name.lower(), sp_cls), 0)
            all_specs_dict[(sp_name, sp_cls)] = kills_val

        for r in raw_specs:
            sp_name = r["spec"].strip()
            sp_cls = (r["class"] or "").strip().upper()
            key = (sp_name, sp_cls)
            if key not in all_specs_dict:
                all_specs_dict[key] = r["kills"]

        top_specs = [
            {"spec": k[0], "class": k[1], "kills": v}
            for k, v in all_specs_dict.items()
        ]
        top_specs.sort(key=lambda x: (x["spec"].lower(), x["class"]))

    return jsonify({
        "kills": total_kills,
        "characters": char_count,
        "guilds": guild_count,
        "allianceKills": alliance_kills,
        "hordeKills": horde_kills,
        "deadliestZones24h": top_zones_24h,
        "topGankers24h": top_chars_24h,
        "topGuilds24h": top_guilds_24h,
        "topClasses": top_classes,
        "topSpecs": top_specs,
        "topCharacters": top_chars_24h,
        "topGuilds": top_guilds_24h,
        "topZones": top_zones_24h
    })

@app.route("/api/bounties/debt-ledger", methods=["GET"])
def get_debt_ledger():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM debt_ledger WHERE status IN ('BLOOD_DEBTOR', 'OATHBREAKER') ORDER BY days_in_default DESC").fetchall()
        debts = [dict(r) for r in rows]
    return jsonify(debts)

@app.route("/api/bounties/debt-ledger", methods=["POST"])
def post_debt_ledger():
    data = request.json
    player_name = data.get("playerName")
    if not player_name:
        return jsonify({"error": "Missing playerName"}), 400

    player_guid = data.get("playerGuid") or data.get("player_guid")
    status = data.get("status", "BLOOD_DEBTOR")
    amount_owed = int(data.get("amountOwedCopper", 0))
    amount_gold = amount_owed // 10000

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO debt_ledger (
                player_name, creditor, amount_owed_copper, principal_copper,
                surcharge_copper, status, default_date, days_in_default, bounty_id, player_guid
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            player_name, data.get("creditor", "BountyPool"), amount_owed,
            data.get("principalCopper", 0), data.get("surchargeCopper", 0), status,
            int(time.time()), data.get("daysInDefault", 1), data.get("bountyId", ""),
            player_guid
        ))

        # Platform Guardrail: Any Blood Debtor in default is placed onto the Realm KOS Blacklist
        if status in ("BLOOD_DEBTOR", "OATHBREAKER"):
            conn.execute("""
                INSERT OR REPLACE INTO kos_blacklist (entity_name, entity_type, reason, branded_at, status)
                VALUES (?, 'PLAYER', ?, ?, 'KOS')
            """, (player_name, f"Blood Debtor: Unpaid bounty debt ({amount_gold}g)", int(time.time())))

        conn.commit()

    return jsonify({"success": True}), 201

@app.route("/api/debt/pay", methods=["POST"])
def pay_debt():
    data = request.json
    player_name = data.get("playerName")
    player_guid = data.get("playerGuid") or data.get("player_guid")
    if not player_name and not player_guid:
        return jsonify({"error": "Missing playerName or playerGuid"}), 400

    with get_db() as conn:
        if player_name:
            conn.execute("UPDATE debt_ledger SET status = 'REDEEMED' WHERE player_name = ?", (player_name,))
            conn.execute("DELETE FROM kos_blacklist WHERE entity_name = ? AND reason LIKE 'Blood Debtor%'", (player_name,))
        if player_guid:
            conn.execute("UPDATE debt_ledger SET status = 'REDEEMED' WHERE player_guid = ?", (player_guid,))
            row = conn.execute("SELECT player_name FROM debt_ledger WHERE player_guid = ?", (player_guid,)).fetchone()
            if row:
                conn.execute("DELETE FROM kos_blacklist WHERE entity_name = ? AND reason LIKE 'Blood Debtor%'", (row[0],))
        conn.commit()

    return jsonify({"success": True, "message": f"Debt cleared for {player_name or player_guid}"})

# ----------------- Discord Webhook & Guild Operations Engine -----------------

def send_discord_webhook(webhook_url: str, payload: dict) -> bool:
    """Dispatches rich embed notifications to a configured Discord channel webhook."""
    if not webhook_url or not webhook_url.startswith("http"):
        return False
    try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            webhook_url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "WoWKillboard/1.0 (Discord Webhook Engine)"
            },
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status in (200, 204)
    except Exception as e:
        print(f"[Discord Webhook Error]: {e}")
        return False

def get_discord_config_for_guild(guild_name: str = None) -> dict:
    """Fetches discord webhook settings for a guild, falling back to 'default'."""
    with get_db() as conn:
        if guild_name and guild_name != "None" and guild_name != "":
            row = conn.execute("SELECT * FROM guild_discord_configs WHERE guild_name = ?", (guild_name,)).fetchone()
            if row:
                return dict(row)
        # Fallback to default
        row_def = conn.execute("SELECT * FROM guild_discord_configs WHERE guild_name = 'default'").fetchone()
        if row_def:
            return dict(row_def)
    return {}

@app.route("/api/backup/distress", methods=["POST"])
def post_distress_beacon():
    """Receives in-game Call for Backup (SOS / War Horn / Vanguard Rally) distress beacons and broadcasts to Discord."""
    data = request.json or {}
    if data.get("is_instance") or data.get("isArena"):
        return jsonify({"error": "The War Horn cannot be sounded inside PvE dungeons, raids, or competitive arenas."}), 400

    beacon_id = data.get("id") or f"SOS-{int(time.time())}-{data.get('character_name', 'Unknown')}"
    char_name = data.get("character_name")
    if not char_name:
        return jsonify({"error": "Missing character_name"}), 400

    char_class = data.get("character_class", "WARRIOR")
    char_level = int(data.get("character_level") or 60)
    guild_name = data.get("guild_name", "None")
    faction = data.get("faction", "Unknown")
    zone = data.get("zone", "Wilderness")
    subzone = data.get("subzone", "")
    coord_x = float(data.get("coord_x", 0.0))
    coord_y = float(data.get("coord_y", 0.0))
    hostile_count = int(data.get("hostile_count", 1))
    hostile_names = data.get("hostile_names", "Hostiles")
    ts = int(data.get("timestamp") or time.time())
    status = data.get("status", "ACTIVE")

    # Rich Rally metadata
    group_type = (data.get("group_type") or data.get("groupType") or "PARTY").upper()
    content_type = (data.get("content_type") or data.get("contentType") or ("BG" if data.get("isBattleground") else "WORLD")).upper()
    min_level = int(data.get("min_level") or data.get("minLevel") or 1)
    max_level = int(data.get("max_level") or data.get("maxLevel") or 60)
    
    # Format roles
    raw_roles = data.get("roles")
    if isinstance(raw_roles, dict):
        r_list = []
        if raw_roles.get("tank"): r_list.append("TANK")
        if raw_roles.get("heal"): r_list.append("HEAL")
        if raw_roles.get("dps"): r_list.append("DPS")
        roles_str = ",".join(r_list) if r_list else "ALL"
    elif isinstance(raw_roles, list):
        roles_str = ",".join(str(r).upper() for r in raw_roles)
    elif isinstance(raw_roles, str) and raw_roles.strip():
        roles_str = raw_roles.strip().upper()
    else:
        roles_str = "TANK,HEAL,DPS"

    message = (data.get("message") or data.get("notes") or "").strip()

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO distress_beacons (
                id, character_name, character_class, character_level,
                guild_name, faction, zone, subzone, coord_x, coord_y,
                hostile_count, hostile_names, timestamp, status,
                group_type, content_type, min_level, max_level, roles, message
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            beacon_id, char_name, char_class, char_level,
            guild_name, faction, zone, subzone, coord_x, coord_y,
            hostile_count, hostile_names, ts, status,
            group_type, content_type, min_level, max_level, roles_str, message
        ))
        conn.commit()

    # Discord Webhook Notification
    discord_notified = False
    cfg = get_discord_config_for_guild(guild_name)
    if cfg and cfg.get("webhook_url") and cfg.get("alerts_enabled", 1):
        content_label = "Battleground Operations" if content_type == "BG" else "Open World PvP Frontline"
        group_label = "40-Man Strike Team (Raid)" if group_type == "RAID" else "5-Man Squad (Party)"
        fields = [
            {"name": "Commander", "value": f"**{char_name}** (Lvl {char_level} {char_class})", "inline": True},
            {"name": "Guild", "value": f"<{guild_name}>" if guild_name and guild_name != "None" else "Unaligned", "inline": True},
            {"name": "Faction", "value": f"{faction}", "inline": True},
            {"name": "Objective / Theatre", "value": f"**{content_label}** in **{zone}** {f'({subzone})' if subzone else ''}", "inline": True},
            {"name": "Squad Capacity", "value": f"{group_label}", "inline": True},
            {"name": "Level Bracket", "value": f"Levels **{min_level} – {max_level}**", "inline": True},
            {"name": "Roles Requested", "value": f"`{roles_str}`", "inline": True},
        ]
        if coord_x > 0 or coord_y > 0:
            fields.append({"name": "GPS Coordinates", "value": f"`({coord_x:.1f}, {coord_y:.1f})`", "inline": True})
        if message:
            fields.append({"name": "Battle Cry / Directive", "value": f"💬 *\"{message}\"*", "inline": False})
        fields.append({"name": "Join Vanguard Squad", "value": f"Whisper `/w {char_name} rally` in-game for **instant auto-invite** into the group!", "inline": False})

        discord_payload = {
            "content": f"📯 **THE WAR HORN HAS BEEN SOUNDED — VANGUARD CALL TO ARMS!**",
            "embeds": [{
                "title": f"📯 {faction.upper()} RALLY: {char_name} Mustering Troops for {zone}!",
                "description": f"Blood calls to blood! **{char_name}** has sounded the War Horn for **{content_label}**.",
                "color": 0x00A8FF if faction.lower() == "alliance" else 0xDD2E44,
                "fields": fields,
                "footer": {"text": "WoW Killboard Frontline War Room"},
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts))
            }]
        }
        discord_notified = send_discord_webhook(cfg["webhook_url"], discord_payload)

    return jsonify({"status": "ok", "beacon_id": beacon_id, "discord_notified": discord_notified}), 201

@app.route("/api/backup/distress", methods=["GET"])
def get_distress_beacons():
    """Returns active distress beacons from the last 2 hours."""
    cutoff = int(time.time()) - 7200  # 2 hours
    with get_db() as conn:
        rows = conn.execute("""
            SELECT * FROM distress_beacons
            WHERE timestamp >= ? AND status = 'ACTIVE'
            ORDER BY timestamp DESC
        """, (cutoff,)).fetchall()
        beacons = [dict(r) for r in rows]
    return jsonify(beacons)

@app.route("/api/backup/resolve/<beacon_id>", methods=["POST"])
def resolve_distress_beacon(beacon_id):
    """Marks a distress beacon as resolved."""
    with get_db() as conn:
        row = conn.execute("SELECT * FROM distress_beacons WHERE id = ?", (beacon_id,)).fetchone()
        if not row:
            return jsonify({"error": "Beacon not found"}), 404
        conn.execute("UPDATE distress_beacons SET status = 'RESOLVED' WHERE id = ?", (beacon_id,))
        conn.commit()

    beacon = dict(row)
    cfg = get_discord_config_for_guild(beacon.get("guild_name"))
    if cfg and cfg.get("webhook_url") and cfg.get("alerts_enabled", 1):
        discord_payload = {
            "content": f"⚔️ **FRONT SECURED**: Reinforcements arrived for **{beacon.get('character_name')}** in **{beacon.get('zone')}**. The enemy has fallen or retreated. Blood and Honor!",
        }
        send_discord_webhook(cfg["webhook_url"], discord_payload)

    return jsonify({"status": "ok", "message": f"Beacon {beacon_id} marked as RESOLVED"})

@app.route("/api/events", methods=["POST"])
def create_guild_event():
    """Creates a guild event/rally and announces it to Discord."""
    data = request.json or {}
    title = data.get("title")
    if not title:
        return jsonify({"error": "Missing title"}), 400

    evt_id = data.get("id") or f"EVT-{int(time.time())}-{data.get('creator_name', 'Player')}"
    desc = data.get("description", "Guild PvP Rally and Frontline Operations")
    guild_name = data.get("guild_name", "Vanguard Brigade")
    creator = data.get("creator_name", "Officer")
    zone = data.get("zone", "World PvP Zone")
    time_str = data.get("time_str", "NOW")
    created_at = int(time.time())

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO guild_events (
                id, title, description, guild_name, creator_name, zone, time_str, created_at, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'SCHEDULED')
        """, (evt_id, title, desc, guild_name, creator, zone, time_str, created_at))
        conn.commit()

    discord_notified = False
    cfg = get_discord_config_for_guild(guild_name)
    if cfg and cfg.get("webhook_url") and cfg.get("events_enabled", 1):
        discord_payload = {
            "content": f"⚔️ **WAR COUNCIL BATTLE ORDER: {title}**",
            "embeds": [{
                "title": f"⚔️ {guild_name} War Council: {title}",
                "description": desc,
                "color": 0x00CCFF,  # Cyan
                "fields": [
                    {"name": "War Guild", "value": f"<{guild_name}>", "inline": True},
                    {"name": "Commander", "value": f"{creator}", "inline": True},
                    {"name": "Rally Location", "value": f"**{zone}**", "inline": True},
                    {"name": "Battle Hour", "value": f"**{time_str}**", "inline": True},
                    {"name": "Join Frontline Unit", "value": f"Whisper `/w {creator} invite` in-game to join the raid/party!", "inline": False}
                ],
                "footer": {"text": "WoW Killboard Frontline War Room"},
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(created_at))
            }]
        }
        discord_notified = send_discord_webhook(cfg["webhook_url"], discord_payload)

    return jsonify({"status": "ok", "event_id": evt_id, "discord_notified": discord_notified}), 201

@app.route("/api/events", methods=["GET"])
def get_guild_events():
    """Returns scheduled and active guild events."""
    with get_db() as conn:
        rows = conn.execute("""
            SELECT * FROM guild_events
            WHERE status != 'CANCELLED'
            ORDER BY created_at DESC
            LIMIT 50
        """).fetchall()
        events = [dict(r) for r in rows]
    return jsonify(events)

@app.route("/api/events/<event_id>/cancel", methods=["POST"])
def cancel_guild_event(event_id):
    """Cancels a guild event."""
    with get_db() as conn:
        conn.execute("UPDATE guild_events SET status = 'CANCELLED' WHERE id = ?", (event_id,))
        conn.commit()
    return jsonify({"status": "ok", "message": f"Event {event_id} cancelled"})

@app.route("/api/discord/config", methods=["POST"])
def set_discord_config():
    """Configures Discord webhook URL for a guild or global default."""
    data = request.json or {}
    guild_name = data.get("guild_name") or "default"
    webhook_url = data.get("webhook_url", "").strip()
    alerts_enabled = 1 if data.get("alerts_enabled", True) else 0
    events_enabled = 1 if data.get("events_enabled", True) else 0

    if not webhook_url:
        return jsonify({"error": "Missing webhook_url"}), 400

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO guild_discord_configs (
                guild_name, webhook_url, alerts_enabled, events_enabled
            ) VALUES (?, ?, ?, ?)
        """, (guild_name, webhook_url, alerts_enabled, events_enabled))
        conn.commit()

    return jsonify({"status": "ok", "message": f"Discord configuration saved for {guild_name}"})

@app.route("/api/discord/config", methods=["GET"])
def get_discord_config():
    """Fetches Discord webhook config with masked URL token."""
    guild_name = request.args.get("guild", "default")
    with get_db() as conn:
        row = conn.execute("SELECT * FROM guild_discord_configs WHERE guild_name = ?", (guild_name,)).fetchone()
        if not row and guild_name != "default":
            row = conn.execute("SELECT * FROM guild_discord_configs WHERE guild_name = 'default'").fetchone()

    if not row:
        return jsonify({"configured": False})

    d = dict(row)
    url = d.get("webhook_url", "")
    # Mask URL token for security
    if len(url) > 20:
        masked_url = url[:len(url)-8] + "****" + url[-4:]
    else:
        masked_url = "****"

    return jsonify({
        "configured": True,
        "guild_name": d["guild_name"],
        "masked_url": masked_url,
        "alerts_enabled": bool(d["alerts_enabled"]),
        "events_enabled": bool(d["events_enabled"])
    })

@app.route("/api/discord/test", methods=["POST"])
def test_discord_webhook():
    """Sends an immediate test ping embed to the Discord webhook."""
    data = request.json or {}
    webhook_url = data.get("webhook_url")
    if not webhook_url:
        guild_name = data.get("guild_name", "default")
        cfg = get_discord_config_for_guild(guild_name)
        webhook_url = cfg.get("webhook_url")

    if not webhook_url:
        return jsonify({"error": "No webhook URL provided or configured"}), 400

    payload = {
        "content": "🔔 **WoW Killboard Tactical Defense — Discord Webhook Test Connection**",
        "embeds": [{
            "title": "🛡️ Connection Verified: Discord Defense Gateway Active",
            "description": "Your Discord channel is now connected to the WoW Killboard intelligence network. You will receive live **War Horn** alerts and **Guild Rally Announcements** here.",
            "color": 0x00FF66,  # Green
            "fields": [
                {"name": "Status", "value": "ONLINE & READY", "inline": True},
                {"name": "Platform", "value": "WoW Killboard v1.0.0", "inline": True},
                {"name": "Network", "value": "Frontline War Room", "inline": True}
            ],
            "footer": {"text": "WoW Killboard | Frontline War Room"},
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        }]
    }
    success = send_discord_webhook(webhook_url, payload)
# ----------------- Tactical Intel & Gank Sighting Wire API -----------------

@app.route("/api/intel/sighting", methods=["POST"])
def post_intel_sighting():
    """Receives tactical scout/gank sightings from the field and broadcasts to the war network."""
    data = request.json or {}
    if data.get("is_instance") or data.get("isBattleground") or data.get("isArena"):
        return jsonify({"error": "Intel sightings can only be recorded in the Open World."}), 400

    s_id = data.get("id") or f"SPT-{int(time.time()*1000)}"
    reporter_name = data.get("reporter_name", "Scout")
    reporter_guild = data.get("reporter_guild", "")
    target_name = data.get("target_name")
    if not target_name:
        return jsonify({"error": "Missing target_name"}), 400

    target_class = data.get("target_class", "WARRIOR")
    target_level = int(data.get("target_level", 60))
    target_guild = data.get("target_guild", "")
    target_faction = data.get("target_faction", "Unknown")
    zone = data.get("zone", "Azeroth")
    subzone = data.get("subzone", "")
    coord_x = float(data.get("coord_x", 0.0))
    coord_y = float(data.get("coord_y", 0.0))
    notes = data.get("notes", "Hostile spotted")
    ts = int(data.get("timestamp") or time.time())

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO intel_sightings (
                id, reporter_name, reporter_guild, target_name, target_class, target_level,
                target_guild, target_faction, zone, subzone, coord_x, coord_y, notes, timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            s_id, reporter_name, reporter_guild, target_name, target_class, target_level,
            target_guild, target_faction, zone, subzone, coord_x, coord_y, notes, ts
        ))
        conn.commit()

    # Optional Discord Webhook Broadcast
    cfg = get_discord_config_for_guild(reporter_guild)
    if cfg and cfg.get("webhook_url") and cfg.get("alerts_enabled", 1):
        discord_payload = {
            "content": f"👁️ **TACTICAL INTEL SPOT: Hostile {target_name} Spotted in {zone}!**",
            "embeds": [{
                "title": f"👁️ SCOUT REPORT: {target_name} ({target_faction})",
                "description": f"Scout **{reporter_name}** has flagged enemy presence: *\"{notes}\"*",
                "color": 0xFFA500,  # Orange
                "fields": [
                    {"name": "Hostile Target", "value": f"**{target_name}** (Lvl {target_level} {target_class})", "inline": True},
                    {"name": "Guild", "value": f"<{target_guild}>" if target_guild else "Unaligned", "inline": True},
                    {"name": "Sector / GPS", "value": f"**{zone}** {f'({subzone})' if subzone else ''}\n`({coord_x:.1f}, {coord_y:.1f})`", "inline": True},
                    {"name": "Reported By", "value": f"{reporter_name} <{reporter_guild}>" if reporter_guild else reporter_name, "inline": True}
                ],
                "footer": {"text": "WoW Killboard Tactical Intel Wire"},
                "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts))
            }]
        }
        send_discord_webhook(cfg["webhook_url"], discord_payload)

    return jsonify({"status": "ok", "sighting_id": s_id}), 201

@app.route("/api/intel/sightings", methods=["GET"])
def get_intel_sightings():
    """Returns tactical sightings from the last 30 minutes."""
    cutoff = int(time.time()) - 1800  # 30 minutes
    with get_db() as conn:
        rows = conn.execute("""
            SELECT * FROM intel_sightings
            WHERE timestamp >= ?
            ORDER BY timestamp DESC
            LIMIT 50
        """, (cutoff,)).fetchall()
        sightings = [dict(r) for r in rows]
    return jsonify(sightings)

# ----------------- Head-to-Head Blood Feuds & ROE API -----------------

@app.route("/api/feuds/challenge", methods=["POST"])
def create_blood_feud():
    """Declares a Head-to-Head Blood Feud between two guilds or characters."""
    data = request.json or {}
    feud_id = data.get("id") or f"FEUD-{int(time.time()*1000)}"
    feud_type = data.get("feud_type", "GUILD")
    c_name = data.get("challenger_name", "Challenger")
    c_guild = data.get("challenger_guild", "")
    c_faction = data.get("challenger_faction", "Unknown")
    t_name = data.get("target_name", "Target")
    t_guild = data.get("target_guild", "")
    t_faction = data.get("target_faction", "Unknown")
    target_score = int(data.get("target_score", 100))
    roe_min_lvl = int(data.get("roe_min_level", 55))
    roe_underdog = 1 if data.get("roe_underdog_bonus", True) else 0
    roe_zone = data.get("roe_zone", "").strip()
    status = data.get("status", "ACTIVE")
    now_ts = int(time.time())
    expires_at = now_ts + (86400 * 30)  # 30 day contest window

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO blood_feuds (
                id, feud_type, challenger_name, challenger_guild, challenger_faction,
                target_name, target_guild, target_faction, target_score, challenger_score,
                target_score_current, roe_min_level, roe_underdog_bonus, roe_zone,
                status, created_at, expires_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?)
        """, (
            feud_id, feud_type, c_name, c_guild, c_faction,
            t_name, t_guild, t_faction, target_score,
            roe_min_lvl, roe_underdog, roe_zone,
            status, now_ts, expires_at
        ))
        conn.commit()

    return jsonify({"status": "ok", "feud_id": feud_id, "message": f"Blood Feud declared: {c_guild or c_name} vs {t_guild or t_name}"}), 201

@app.route("/api/feuds", methods=["GET"])
def get_blood_feuds():
    """Returns active, pending, and completed Blood Feuds."""
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM blood_feuds ORDER BY created_at DESC LIMIT 50").fetchall()
        feuds = [dict(r) for r in rows]
    return jsonify(feuds)

@app.route("/api/feuds/<feud_id>/accept", methods=["POST"])
def accept_blood_feud(feud_id):
    """Accepts a pending Blood Feud challenge."""
    with get_db() as conn:
        row = conn.execute("SELECT * FROM blood_feuds WHERE id = ?", (feud_id,)).fetchone()
        if not row:
            return jsonify({"error": "Feud not found"}), 404
        conn.execute("UPDATE blood_feuds SET status = 'ACTIVE' WHERE id = ?", (feud_id,))
        conn.commit()
    return jsonify({"status": "ok", "feud_id": feud_id, "message": "Blood Feud challenge accepted!"})

# ----------------- Realm KOS Blacklist & 30-Day Deserters API -----------------

@app.route("/api/kos/blacklist", methods=["GET"])
def get_kos_blacklist():
    """Returns current KOS Blacklist entities and marked Deserters."""
    now_ts = int(time.time())
    with get_db() as conn:
        # Guild / Entity blacklist
        guild_rows = conn.execute("SELECT * FROM kos_blacklist WHERE status = 'KOS' ORDER BY branded_at DESC").fetchall()
        guilds = [dict(r) for r in guild_rows]

        # Deserters with active penalty
        deserter_rows = conn.execute("""
            SELECT player_guid, player_name, former_guild, branded_at, expires_at
            FROM kos_deserters
            WHERE expires_at > ?
            ORDER BY expires_at DESC
        """, (now_ts,)).fetchall()

        deserters = []
        for r in deserter_rows:
            d = dict(r)
            remaining_seconds = max(0, d["expires_at"] - now_ts)
            d["days_remaining"] = max(1, remaining_seconds // 86400)
            deserters.append(d)

    return jsonify({
        "guilds": guilds,
        "deserters": deserters
    })

@app.route("/api/kos/blacklist", methods=["POST"])
def add_kos_blacklist():
    """Brands a guild or player onto the KOS Blacklist."""
    data = request.json or {}
    entity_name = data.get("entity_name")
    if not entity_name:
        return jsonify({"error": "Missing entity_name"}), 400

    entity_type = data.get("entity_type", "GUILD")
    reason = data.get("reason", "Branded KOS by Realm War Council")
    now_ts = int(time.time())

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO kos_blacklist (entity_name, entity_type, reason, branded_at, status)
            VALUES (?, ?, ?, ?, 'KOS')
        """, (entity_name, entity_type, reason, now_ts))

        # If blacklisting a guild, mark current known members as deserters for 30 days
        if entity_type == "GUILD":
            exp_ts = now_ts + (30 * 86400)
            roster = conn.execute("SELECT DISTINCT character_name FROM character_guild_history WHERE guild_name = ?", (entity_name,)).fetchall()
            for m in roster:
                m_name = m["character_name"]
                conn.execute("""
                    INSERT OR REPLACE INTO kos_deserters (player_guid, player_name, former_guild, branded_at, expires_at)
                    VALUES (?, ?, ?, ?, ?)
                """, (f"Player-KOS-{m_name}", m_name, entity_name, now_ts, exp_ts))

        conn.commit()

    return jsonify({"status": "ok", "message": f"{entity_name} consigned to the KOS Blacklist."}), 201

@app.route("/api/kos/pardon", methods=["POST"])
def pardon_kos_entity():
    """Pardons an entity or deserter from the KOS Blacklist."""
    data = request.json or {}
    entity_name = data.get("entity_name")
    if not entity_name:
        return jsonify({"error": "Missing entity_name"}), 400

    with get_db() as conn:
        conn.execute("DELETE FROM kos_blacklist WHERE entity_name = ?", (entity_name,))
        conn.execute("DELETE FROM kos_deserters WHERE player_name = ? OR former_guild = ?", (entity_name, entity_name))
        conn.commit()

    return jsonify({"status": "ok", "message": f"{entity_name} pardoned from KOS Blacklist."})

# ----------------- The War Archivist & Combat Oracle API -----------------

SCRIBE_SYSTEM_PROMPT = """You are the Grand War Archivist of Azeroth, chronicler of the bloodstained ledger for the WoW Killboard.
Your voice reflects the dark, grounded, unforgiving aesthetic of original Vanilla World of Warcraft (2004–2006). Azeroth is a scarred, volatile frontier recovering from the Third War—not a polished theme park.

Core Voice Principles:
1. Grounded & Rugged: Treat game mechanics like dangerous field craft, martial discipline, or forbidden arcane study. The tone is utilitarian, ominous, and battle-hardened.
2. No Modern SaaS/Tech Jargon: Never use startup or corporate phrasing (e.g., "streamline your workflow," "optimize performance," "user-friendly dashboard," "seamless integration"). Replace them with terms like forged, martial efficiency, field kit, armory, reconnaissance, dispatches, pacts, ledger.
3. Diegetic & Immersive: Speak as an Ironforge armorer, an Undercity apothecary, or a veteran scout at a bloodstained Southshore tavern table.
4. Austere, Not Overly Flowery: Avoid excessive high-fantasy purple prose or quips. Speak plainly, bluntly, and with weight.
5. Factual Grounding: Answer the soldier's query directly using the battlefield telemetry and ledger dispatches provided. Keep answers concise (2 to 4 paragraphs max)."""

@app.route("/api/oracle/chat", methods=["POST"])
def oracle_chat():
    """AI Combat Oracle & Scribe endpoint querying live telemetry and generating in-character intelligence."""
    data = request.json or {}
    query = (data.get("query") or "").strip()
    character = (data.get("character") or "Unmarked Scout").strip()
    flavor = (data.get("flavor") or "CLASSIC_ERA").strip()
    user_api_key = (data.get("api_key") or "").strip() or os.environ.get("GEMINI_API_KEY", "").strip()

    if not query:
        return jsonify({"error": "Empty query"}), 400

    now_ts = int(time.time())

    # 1. Gather live database facts
    telemetry_facts = {}
    sources = []
    with get_db() as conn:
        # Total kills & split
        tot = conn.execute("SELECT count(*) as c, sum(is_solo) as s FROM kills").fetchone()
        a_kills = conn.execute("SELECT count(*) as c FROM kills WHERE killer_faction = 'Alliance'").fetchone()["c"]
        h_kills = conn.execute("SELECT count(*) as c FROM kills WHERE killer_faction = 'Horde'").fetchone()["c"]
        telemetry_facts["total_kills"] = tot["c"] if tot else 0
        telemetry_facts["solo_kills"] = tot["s"] if tot and tot["s"] else 0
        telemetry_facts["alliance_kills"] = a_kills
        telemetry_facts["horde_kills"] = h_kills

        # Top killers
        top_k = conn.execute("""
            SELECT killer_name, killer_guild, killer_class, count(*) as kills
            FROM kills GROUP BY killer_name ORDER BY kills DESC LIMIT 5
        """).fetchall()
        telemetry_facts["top_killers"] = [dict(r) for r in top_k]

        # Top open bounties
        top_b = conn.execute("""
            SELECT target_name, target_class, amount_gold, placer_name, status
            FROM bounties WHERE status = 'OPEN' ORDER BY amount_gold DESC LIMIT 5
        """).fetchall()
        telemetry_facts["top_bounties"] = [dict(r) for r in top_b]

        # Top deadly NPCs
        top_n = conn.execute("""
            SELECT npc_name, zone, count(*) as deaths
            FROM pve_deaths GROUP BY npc_name ORDER BY deaths DESC LIMIT 5
        """).fetchall()
        telemetry_facts["deadly_npcs"] = [dict(r) for r in top_n]

        # Top slaughter zones
        top_z = conn.execute("""
            SELECT zone, count(*) as kills
            FROM kills WHERE zone IS NOT NULL AND zone != ''
            GROUP BY zone ORDER BY kills DESC LIMIT 5
        """).fetchall()
        telemetry_facts["top_zones"] = [dict(r) for r in top_z]

        # Check for specific character or player lookup
        target_player = None
        for word in query.replace("?", "").replace("!", "").split():
            clean_word = word.strip()
            if len(clean_word) >= 3 and clean_word.lower() not in ["who", "what", "where", "when", "how", "the", "and", "bounty", "kill", "player", "guild", "zone", "addon", "sync"]:
                p_match = conn.execute("""
                    SELECT killer_name, count(*) as kills FROM kills WHERE killer_name LIKE ? GROUP BY killer_name LIMIT 1
                """, (f"%{clean_word}%",)).fetchone()
                if p_match:
                    p_name = p_match["killer_name"]
                    p_deaths = conn.execute("SELECT count(*) as deaths FROM kills WHERE victim_name = ?", (p_name,)).fetchone()["deaths"]
                    p_victims = conn.execute("SELECT victim_name, victim_class, zone FROM kills WHERE killer_name = ? ORDER BY timestamp DESC LIMIT 3", (p_name,)).fetchall()
                    target_player = {
                        "name": p_name,
                        "kills": p_match["kills"],
                        "deaths": p_deaths,
                        "recent_victims": [dict(v) for v in p_victims]
                    }
                    sources.append(f"Player Ledger: {p_name}")
                    break

    # 2. Try Gemini API generation if key is supplied
    if user_api_key:
        try:
            from google import genai
            client = genai.Client(api_key=user_api_key)
            prompt_context = f"""Soldier Call-Sign: {character}
Active War Front: {flavor}
Field Telemetry Context:
- Total Slaughter Recorded: {telemetry_facts['total_kills']} kills ({telemetry_facts['solo_kills']} certified solo 1v1)
- Faction Split: Alliance {telemetry_facts['alliance_kills']} vs Horde {telemetry_facts['horde_kills']}
- Top Five Killers on Ledger: {json.dumps(telemetry_facts['top_killers'])}
- Top Open Blood Bounties: {json.dumps(telemetry_facts['top_bounties'])}
- Deadliest Wilderness Threats (NPCs): {json.dumps(telemetry_facts['deadly_npcs'])}
- Bloodiest Zones: {json.dumps(telemetry_facts['top_zones'])}
{f"- Subject Dossier: {json.dumps(target_player)}" if target_player else ""}

Soldier Inquiry: "{query}"

Answer strictly in your role as the Classic Azeroth Scribe. Grounded, utilitarian, rugged."""

            try:
                response = client.models.generate_content(
                    model="gemini-2.5-flash",
                    contents=[prompt_context],
                    config={"system_instruction": SCRIBE_SYSTEM_PROMPT}
                )
                if response and response.text:
                    sources.append("Gemini Arcane Oracle (gemini-2.5-flash)")
                    return jsonify({
                        "reply": response.text,
                        "sources": sources,
                        "status": "ok"
                    })
            except Exception as e:
                # Fallback to direct heuristic if API call fails
                print(f"[Oracle Gemini Error]: {e}")
        except Exception as e:
            print(f"[Oracle GenAI Import Error]: {e}")

    # 3. Built-in Diegetic Scribe Intelligence Engine (Offline / Local Fallback)
    q_lower = query.lower()
    reply = ""

    if target_player:
        p = target_player
        reply = (
            f"**Dispatches on {p['name']}:**\n\n"
            f"The ledger bears witness to **{p['kills']}** confirmed kills and **{p['deaths']}** documented falls upon the field of combat. "
        )
        if p["recent_victims"]:
            v_list = ", ".join([f"{v['victim_name']} ({v.get('victim_class', 'Unknown')}) in {v.get('zone', 'the frontier')}" for v in p["recent_victims"]])
            reply += f"Recent fallen foes claimed by their steel: {v_list}.\n\n"
        reply += "Keep your guard high; reputations in Azeroth are earned in blood and paid in steel."
        sources.append("Frontline Kill Ledger")

    elif any(k in q_lower for k in ["bounty", "bounties", "contract", "gibbet", "most wanted", "wanted", "gold"]):
        b_list = telemetry_facts["top_bounties"]
        if b_list:
            b_text = "\n".join([f"- **{b['target_name']}** ({b.get('target_class', 'Target')}): **{b['amount_gold']} Gold** pledged by {b.get('placer_name', 'High Command')}" for b in b_list])
            reply = (
                f"**The Blood Bounty Ledger & Gibbet:**\n\n"
                f"Coin is pledged; retribution is sworn. High Command has approved the following execution contracts:\n\n"
                f"{b_text}\n\n"
                f"Fell the marked target in certified combat and your dispatches will automatically deliver the gold. Default on a pledged bounty debt, and your name shall be branded upon the server KOS rolls."
            )
        else:
            reply = (
                "**The Bounty Board is Quiet:**\n\n"
                "No open blood contracts currently stain the ledger for this front. Any veteran with coin may issue a contract through the Blood Bounties hub. Once pledged, the hunter who logs the killmail collects the prize."
            )
        sources.append("Bounty Board & Debt Ledger")

    elif any(k in q_lower for k in ["npc", "boss", "pve", "creature", "stitches", "arugal", "beast", "threat"]):
        n_list = telemetry_facts["deadly_npcs"]
        if n_list:
            n_text = "\n".join([f"- **{n['npc_name']}** in *{n.get('zone', 'Wilderness')}*: **{n['deaths']}** fallen scouts" for n in n_list])
            reply = (
                f"**Wilderness Casualties & Lethal Denizens:**\n\n"
                f"The wilds of Azeroth show no mercy to reckless patrols. Field scouts report the heaviest casualties claimed by:\n\n"
                f"{n_text}\n\n"
                f"Travel under armed escort. Even the most seasoned warrior is but meat to the horrors stalking outside garrison walls."
            )
        else:
            reply = (
                "**Wilderness Intelligence:**\n\n"
                "Our scouts have logged no major denizen massacres in the immediate vicinity. Keep your weapons drawn and your senses sharp; the frontier gives no second warnings."
            )
        sources.append("PvE Casualty Records")

    elif any(k in q_lower for k in ["zone", "where", "battleground", "hillsbrad", "barrens", "stranglethorn", "blackrock", "territory", "front"]):
        z_list = telemetry_facts["top_zones"]
        if z_list:
            z_text = "\n".join([f"- **{z['zone']}**: {z['kills']} skirmishes recorded" for z in z_list])
            reply = (
                f"**Frontline Theater Intelligence:**\n\n"
                f"The highest concentration of violence and reported skirmishes lies in:\n\n"
                f"{z_text}\n\n"
                f"Reinforcements in these sectors are scarce. If you venture into these killing grounds, travel in tight formation or prepare to inscribe your own death dispatch."
            )
        else:
            reply = (
                "**Field Reconnaissance:**\n\n"
                "Skirmishes are dispersed along the frontier. The contested roads of Hillsbrad Foothills, Stranglethorn Vale, and the Searing Gorge remain volatile flashpoints."
            )
        sources.append("Territorial Telemetry")

    elif any(k in q_lower for k in ["addon", "how", "work", "sync", "download", "taint", "lua", "deduplication", "fnv", "cluster"]):
        reply = (
            "**The War Archivist's Architecture & Addon Guide:**\n\n"
            "Our combat logging apparatus is forged under strict martial discipline:\n\n"
            "1. **Zero Blizzard UI Taint**: Compiled purely in Lua with `BackdropTemplate` and anonymous widgets. It never inherits Blizzard XML button templates or touches `UISpecialFrames`. Runs silently with zero 'Action Blocked' errors during combat lockdown.\n"
            "2. **Cryptographic 32-Bit FNV-1a Blood Stamp**: Every clash generates a deterministic hash from timestamp, combatant GUIDs, and map coordinates (`C_Map`). When a 40-man raid logs the same fight, our ledger merges all dispatches into a single verified killmail.\n"
            "3. **Sliding 15-Second Temporal Clustering**: Separates honorable 1v1 duels from multi-attacker gank squads based on localized damage windows.\n"
            "4. **Automated Courier (`WoWKillboardSync.exe`)**: A solitary Windows executable that scans `C:`, `D:`, and `E:` drives automatically with zero Python runes or manual terminal commands."
        )
        sources.append("Addon Architecture & Field Manual")

    elif any(k in q_lower for k in ["who", "killer", "top", "leader", "hero", "warlord"]):
        k_list = telemetry_facts["top_killers"]
        if k_list:
            k_text = "\n".join([f"- **{k['killer_name']}** ({k.get('killer_class', 'Fighter')}) of <{k.get('killer_guild', 'No Guild')}>: **{k['kills']}** confirmed kills" for k in k_list])
            reply = (
                f"**Hall of Heroes & Grim Slayers:**\n\n"
                f"The following combatants hold the highest tally of fallen enemies upon the ledger:\n\n"
                f"{k_text}\n\n"
                f"Their steel is tested; their names are feared across the faction divide."
            )
        else:
            reply = "The muster rolls are being tallied. New champions are forged in every clash."
        sources.append("Hall of Heroes Roster")

    else:
        tot = telemetry_facts["total_kills"]
        solo = telemetry_facts["solo_kills"]
        a = telemetry_facts["alliance_kills"]
        h = telemetry_facts["horde_kills"]
        reply = (
            f"**State of the War Front:**\n\n"
            f"The ledger currently records **{tot}** fallen combatants across all tracked fronts, with **{solo}** certified 1v1 honorable solo kills.\n\n"
            f"- **Alliance Casualties Claimed**: {a} kills\n"
            f"- **Horde Casualties Claimed**: {h} kills\n\n"
            f"Inquire regarding a specific soldier's call-sign, an active blood bounty, the deadliest wilderness creatures, or the inner workings of our addon field kit. The War Archivist answers all who seek the records of conflict."
        )
        sources.append("Master Ledger Telemetry")

    return jsonify({
        "reply": reply,
        "sources": sources,
        "status": "ok"
    })

if __name__ == "__main__":
    if "--reset-db" in sys.argv:
        print("[*] Admin flag --reset-db detected. Wiping all database tables...")
        wipe_database()
        print("[*] Database successfully re-initialized with fresh schema.")
    else:
        init_db()
    port = int(os.environ.get("PORT", 8080))
    print(f"[*] WoW Killboard Web Server running at http://127.0.0.1:{port}")
    app.run(host="0.0.0.0", port=port, debug=True)

