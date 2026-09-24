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

# ----------------- Bounties & Debt Ledger API -----------------

@app.route("/api/bounties", methods=["GET"])
def get_bounties():
    with get_db() as conn:
        rows = conn.execute("SELECT * FROM bounties ORDER BY timestamp DESC").fetchall()
        bounties = [dict(r) for r in rows]
    return jsonify(bounties)

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
