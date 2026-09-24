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
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

APP_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(APP_DIR, "static")
DB_PATH = os.path.join(APP_DIR, "killboard.db")

app = Flask(__name__, static_folder=STATIC_DIR)
CORS(app)

def get_db():
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
                raw_json TEXT
            )
        """)
        # Safe migration if table exists without is_duel
        try:
            conn.execute("ALTER TABLE kills ADD COLUMN is_duel INTEGER DEFAULT 0")
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

@app.route("/")
def index():
    return send_from_directory(STATIC_DIR, "index.html")

@app.route("/static/<path:path>")
def static_files(path):
    return send_from_directory(STATIC_DIR, path)

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
        query += " AND is_battleground = 1"
    elif mode == "ARENA":
        query += " AND is_arena = 1"
    elif mode == "DUEL":
        query += " AND is_duel = 1"

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
            kills.append({
                "killId": r["kill_id"],
                "timestamp": r["timestamp"],
                "isDuel": bool(r["is_duel"]) if "is_duel" in r.keys() else False,
                "isBattleground": bool(r["is_battleground"]),
                "isArena": bool(r["is_arena"]),
                "battlegroundName": r["bg_name"],
                "isSolo": bool(r["is_solo"]),
                "attackersCount": r["attackers_count"],
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

@app.route("/api/kills", methods=["POST"])
def post_kill():
    data = request.json
    if not data or "killId" not in data:
        return jsonify({"error": "Invalid payload"}), 400

    kill_id = data["killId"]
    timestamp = data.get("timestamp", int(time.time()))
    is_duel = 1 if data.get("isDuel") else 0
    is_bg = 1 if data.get("isBattleground") else 0
    is_arena = 1 if data.get("isArena") else 0
    bg_name = data.get("battlegroundName", "")
    is_solo = 1 if data.get("isSolo") else 0
    attackers_count = data.get("attackersCount", 1)
    total_damage = data.get("totalDamage", 0)

    k = data.get("killer", {})
    v = data.get("victim", {})
    loc = data.get("location", {})

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO kills (
                kill_id, timestamp, is_duel, is_battleground, is_arena, bg_name,
                is_solo, attackers_count, total_damage,
                killer_name, killer_level, killer_class, killer_guild, killer_faction,
                killer_party_size, killer_damage_done, killer_healing_done,
                victim_name, victim_level, victim_class, victim_guild, victim_faction,
                victim_party_size, map_id, zone, subzone, coord_x, coord_y, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            kill_id, timestamp, is_duel, is_bg, is_arena, bg_name,
            is_solo, attackers_count, total_damage,
            k.get("name", "Unknown"), k.get("level", 60), k.get("class", "WARRIOR"), k.get("guild", "None"), k.get("faction", "Alliance"),
            k.get("partySize", 1), k.get("damageDone", 0), k.get("healingDone", 0),
            v.get("name", "Unknown"), v.get("level", 60), v.get("class", "ROGUE"), v.get("guild", "None"), v.get("faction", "Horde"),
            v.get("partySize", 1), loc.get("mapId", 0), loc.get("zone", "Unknown"), loc.get("subZone", ""),
            loc.get("x", 0.0), loc.get("y", 0.0), json.dumps(data)
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

        conn.commit()

    return jsonify({"success": True, "killId": kill_id}), 201

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
            stats["counts"] = {
                "total": total_kills,
                "world": world_kills,
                "bg": bg_kills,
                "arena": arena_kills,
                "duel": duel_kills
            }
        return jsonify(stats)

# ----------------- Leaderboard API -----------------

@app.route("/api/leaderboard", methods=["GET"])
def get_leaderboard():
    mode = request.args.get("mode", "ALL").upper()
    where = "WHERE 1=1"
    if mode == "WORLD":
        where += " AND is_battleground = 0 AND is_arena = 0 AND (is_duel = 0 OR is_duel IS NULL)"
    elif mode == "BG":
        where += " AND is_battleground = 1"
    elif mode == "ARENA":
        where += " AND is_arena = 1"
    elif mode == "DUEL":
        where += " AND is_duel = 1"

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

# ----------------- Character & Guild Profiles API -----------------

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
            return jsonify({"error": "Character not found"}), 404

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

        realm = "classic"
        armory_urls = {
            "official": f"https://worldofwarcraft.blizzard.com/en-us/character/us/{realm}/{name.lower()}",
            "ironforge": f"https://ironforge.pro/pvp/player/{realm}/{name.lower()}/",
            "warcraftlogs": f"https://classic.warcraftlogs.com/character/us/{realm}/{name.lower()}"
        }

        return jsonify({
            "name": name,
            "class": char_data.get("class", "UNKNOWN"),
            "level": char_data.get("level", 60),
            "faction": char_data.get("faction", "Unknown"),
            "currentGuild": current_guild,
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
    with get_db() as conn:
        guilds_query = """
            SELECT 
                k.killer_guild AS guild,
                k.killer_faction AS faction,
                COUNT(k.kill_id) AS kills,
                COALESCE(SUM(k.is_solo), 0) AS solo_kills,
                COUNT(DISTINCT k.killer_name) AS members_count
            FROM kills k
            WHERE k.killer_guild IS NOT NULL AND k.killer_guild != 'None' AND k.killer_guild != ''
            GROUP BY k.killer_guild
            ORDER BY kills DESC
            LIMIT 50
        """
        guilds = [dict(r) for r in conn.execute(guilds_query).fetchall()]

        for g in guilds:
            g_name = g["guild"]
            death_count = conn.execute("""
                SELECT COUNT(*) FROM kills WHERE victim_guild = ?
            """, (g_name,)).fetchone()[0]
            g["deaths"] = death_count
            g["kd"] = round(g["kills"] / death_count, 2) if death_count > 0 else float(g["kills"])

            top_member = conn.execute("""
                SELECT killer_name AS name, killer_class AS class, COUNT(*) as kills
                FROM kills WHERE killer_guild = ?
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
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM bounties ORDER BY timestamp DESC").fetchall()
        bounties = [dict(r) for r in rows]
        now = int(time.time())

        for b in bounties:
            target = b["target_name"]
            last_kill = conn.execute("""
                SELECT timestamp, zone, subzone, coord_x, coord_y
                FROM kills
                WHERE killer_name = ? OR victim_name = ?
                ORDER BY timestamp DESC
                LIMIT 1
            """, (target, target)).fetchone()

            if last_kill:
                kill_time = last_kill["timestamp"]
                elapsed = max(0, now - kill_time)
                # Fuzzy coordinate rounding to general sector grid (nearest 4%)
                fuzzy_x = round((last_kill["coord_x"] or 50.0) / 4.0) * 4.0
                fuzzy_y = round((last_kill["coord_y"] or 50.0) / 4.0) * 4.0
                b["lastSeen"] = {
                    "hasTelemetry": True,
                    "zone": last_kill["zone"] or "Unknown",
                    "subzone": last_kill["subzone"] or "Wilderness",
                    "coordX": fuzzy_x,
                    "coordY": fuzzy_y,
                    "timestamp": kill_time,
                    "elapsedSeconds": elapsed,
                    "minutesAgo": max(1, elapsed // 60),
                    "displayText": f"{last_kill['zone']}{(' (' + last_kill['subzone'] + ')') if last_kill['subzone'] else ''}"
                }
            else:
                b["lastSeen"] = {
                    "hasTelemetry": False,
                    "displayText": "Unknown (No recent combat logged)"
                }

    return jsonify(bounties)

@app.route("/api/bounty/intel/<target_name>", methods=["GET"])
def get_bounty_intel(target_name):
    with get_db() as conn:
        last_kill = conn.execute("""
            SELECT timestamp, zone, subzone, coord_x, coord_y, killer_name, victim_name
            FROM kills
            WHERE killer_name = ? OR victim_name = ?
            ORDER BY timestamp DESC
            LIMIT 1
        """, (target_name, target_name)).fetchone()

        if not last_kill:
            return jsonify({
                "targetName": target_name,
                "hasTelemetry": False,
                "message": "No combat telemetry on record for this target."
            })

        zone = last_kill["zone"]
        kill_time = last_kill["timestamp"]
        now = int(time.time())
        elapsed = max(0, now - kill_time)
        fuzzy_x = round((last_kill["coord_x"] or 50.0) / 4.0) * 4.0
        fuzzy_y = round((last_kill["coord_y"] or 50.0) / 4.0) * 4.0

        # Query up to 30 recent kills in the same zone to form the combat heatmap
        zone_kills_rows = conn.execute("""
            SELECT kill_id, timestamp, coord_x, coord_y, total_damage, is_solo
            FROM kills
            WHERE zone = ?
            ORDER BY timestamp DESC
            LIMIT 30
        """, (zone,)).fetchall()
        zone_heat = [dict(r) for r in zone_kills_rows]

        return jsonify({
            "targetName": target_name,
            "hasTelemetry": True,
            "zone": zone,
            "subzone": last_kill["subzone"] or "Wilderness",
            "coordX": fuzzy_x,
            "coordY": fuzzy_y,
            "timestamp": kill_time,
            "elapsedSeconds": elapsed,
            "minutesAgo": max(1, elapsed // 60),
            "tacticalDelayMinutes": 10,
            "zoneHeat": zone_heat
        })

@app.route("/api/bounties", methods=["POST"])
def create_bounty():
    data = request.json
    b_id = data.get("id") or f"BNT-{int(time.time()*1000)}"
    target = data.get("targetName", "Unknown")
    gold = int(data.get("amountGold", 100))
    copper = int(data.get("amountCopper", gold * 10000))
    placer = data.get("placerName", "Anonymous")

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO bounties (
                id, target_name, target_class, target_faction, placer_name,
                amount_copper, amount_gold, status, timestamp, expiry
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'ACTIVE', ?, ?)
        """, (
            b_id, target, data.get("targetClass", "UNKNOWN"), data.get("targetFaction", "Unknown"),
            placer, copper, gold, int(time.time()), int(time.time() + 86400 * 7)
        ))
        conn.commit()

    return jsonify({"success": True, "bountyId": b_id}), 201

@app.route("/api/bounties/debt-ledger", methods=["GET"])
def get_debt_ledger():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM debt_ledger WHERE status = 'OATHBREAKER' ORDER BY days_in_default DESC").fetchall()
        debts = [dict(r) for r in rows]
    return jsonify(debts)

@app.route("/api/bounties/debt-ledger", methods=["POST"])
def post_debt_ledger():
    data = request.json
    player_name = data.get("playerName")
    if not player_name:
        return jsonify({"error": "Missing playerName"}), 400

    with get_db() as conn:
        conn.execute("""
            INSERT OR REPLACE INTO debt_ledger (
                player_name, creditor, amount_owed_copper, principal_copper,
                surcharge_copper, status, default_date, days_in_default, bounty_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            player_name, data.get("creditor", "BountyPool"), data.get("amountOwedCopper", 0),
            data.get("principalCopper", 0), data.get("surchargeCopper", 0), data.get("status", "OATHBREAKER"),
            int(time.time()), data.get("daysInDefault", 1), data.get("bountyId", "")
        ))
        conn.commit()

    return jsonify({"success": True}), 201

@app.route("/api/debt/pay", methods=["POST"])
def pay_debt():
    data = request.json
    player_name = data.get("playerName")
    if not player_name:
        return jsonify({"error": "Missing playerName"}), 400

    with get_db() as conn:
        conn.execute("UPDATE debt_ledger SET status = 'REDEEMED' WHERE player_name = ?", (player_name,))
        conn.commit()

    return jsonify({"success": True, "message": f"Debt cleared for {player_name}"})

if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("PORT", 8080))
    print(f"[*] WoW Killboard Web Server running at http://127.0.0.1:{port}")
    app.run(host="0.0.0.0", port=port, debug=True)
