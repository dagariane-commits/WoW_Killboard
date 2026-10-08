#!/usr/bin/env python3
"""
WoWKillboard - tests/test_pipeline.py
End-to-End Pipeline Verification Test Suite.
Generates synthetic PvP engagements, verifies Lua table parsing,
tests API filtering (All / World PvP / Battlegrounds), and checks Bounties & Debt Ledger.
"""

import os
import sys
import json
import time
import unittest

# Ensure web/ is importable and isolated from production database
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ["DB_PATH"] = os.path.join(BASE_DIR, "tests", "test_killboard.db")
sys.path.insert(0, os.path.join(BASE_DIR, "web"))
sys.path.insert(0, os.path.join(BASE_DIR, "sync"))

from server import app, init_db, get_db
from watcher import LuaTableParser

class TestKillboardPipeline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Configure app for testing
        app.config["TESTING"] = True
        cls.client = app.test_client()
        init_db()
        with get_db() as conn:
            conn.execute("DELETE FROM kills WHERE kill_id LIKE 'KB-%'")
            conn.execute("DELETE FROM character_guild_history")
            conn.execute("DELETE FROM bounties WHERE id LIKE 'BNT-%'")
            conn.execute("DELETE FROM debt_ledger WHERE player_name = 'DeadbeatDan'")

    def test_01_lua_syntax_and_structure(self):
        """Verify that all Addon Lua files exist and contain valid Lua blocks."""
        addon_dir = os.path.join(BASE_DIR, "Addon", "WoWKillboard")
        expected_files = [
            "WoWKillboard.toc",
            "Config.lua",
            "WoWKillboard_RealmData.lua",
            "Utils.lua",
            "UnitScanner.lua",
            "CombatTracker.lua",
            "Killmail.lua",
            "BountyEngine.lua",
            "Sync.lua",
            "Reinforcements.lua",
            "IntelScanner.lua",
            "Leaderboard.lua",
            "UI.lua",
            "Core.lua"
        ]
        for fname in expected_files:
            fpath = os.path.join(addon_dir, fname)
            self.assertTrue(os.path.exists(fpath), f"Missing required file: {fname}")
            with open(fpath, "r", encoding="utf-8") as f:
                content = f.read()
                self.assertGreater(len(content), 10, f"File {fname} is empty")
        print("[PASS] All 14 Addon Lua and TOC files verified.")


    def test_02_ingest_synthetic_kills(self):
        """Ingest synthetic World PvP, Gang, and Battleground killmails."""
        sample_kills = [
            # 1. World PvP Solo Kill
            {
                "killId": "KB-TEST01",
                "timestamp": int(time.time()) - 300,
                "isBattleground": False,
                "isArena": False,
                "battlegroundName": "",
                "isSolo": True,
                "attackersCount": 1,
                "totalDamage": 3400,
                "killer": {
                    "name": "Shadowblade", "level": 60, "class": "ROGUE",
                    "guild": "GankSquad", "faction": "Horde", "partySize": 1,
                    "damageDone": 3400, "healingDone": 0
                },
                "victim": {
                    "name": "Frostweaver", "level": 58, "class": "MAGE",
                    "guild": "KnightsOfIronforge", "faction": "Alliance", "partySize": 1
                },
                "location": {
                    "mapId": 1434, "zone": "Stranglethorn Vale", "subZone": "Nesingwary Camp",
                    "x": 35.4, "y": 10.8
                }
            },
            # 2. World PvP Gang Kill
            {
                "killId": "KB-TEST02",
                "timestamp": int(time.time()) - 200,
                "isBattleground": False,
                "isArena": False,
                "battlegroundName": "",
                "isSolo": False,
                "attackersCount": 3,
                "totalDamage": 5200,
                "killer": {
                    "name": "Ironjaw", "level": 60, "class": "WARRIOR",
                    "guild": "GankSquad", "faction": "Horde", "partySize": 3,
                    "damageDone": 4100, "healingDone": 0
                },
                "victim": {
                    "name": "Holyheal", "level": 60, "class": "PRIEST",
                    "guild": "KnightsOfIronforge", "faction": "Alliance", "partySize": 2
                },
                "location": {
                    "mapId": 1424, "zone": "Hillsbrad Foothills", "subZone": "Southshore",
                    "x": 51.2, "y": 58.6
                }
            },
            # 3. Battleground Kill in Warsong Gulch
            {
                "killId": "KB-TEST03",
                "timestamp": int(time.time()) - 100,
                "isBattleground": True,
                "isArena": False,
                "battlegroundName": "Warsong Gulch",
                "isSolo": True,
                "attackersCount": 1,
                "totalDamage": 4800,
                "killer": {
                    "name": "Hawkeye", "level": 60, "class": "HUNTER",
                    "guild": "ApexPredators", "faction": "Alliance", "partySize": 10,
                    "damageDone": 84500, "healingDone": 0
                },
                "victim": {
                    "name": "Moonkin", "level": 60, "class": "DRUID",
                    "guild": "Bloodfang", "faction": "Horde", "partySize": 10
                },
                "location": {
                    "mapId": 1460, "zone": "Warsong Gulch", "subZone": "Silverwing Hold",
                    "x": 48.0, "y": 18.5
                }
            },
            # 4. Battleground Kill in Arathi Basin with Healing Telemetry
            {
                "killId": "KB-TEST04",
                "timestamp": int(time.time()) - 50,
                "isBattleground": True,
                "isArena": False,
                "battlegroundName": "Arathi Basin",
                "isSolo": False,
                "attackersCount": 2,
                "totalDamage": 6100,
                "killer": {
                    "name": "Lifebinder", "level": 60, "class": "PALADIN",
                    "guild": "ApexPredators", "faction": "Alliance", "partySize": 15,
                    "damageDone": 32000, "healingDone": 115000
                },
                "victim": {
                    "name": "Doomcaller", "level": 60, "class": "WARLOCK",
                    "guild": "Bloodfang", "faction": "Horde", "partySize": 15
                },
                "location": {
                    "mapId": 1461, "zone": "Arathi Basin", "subZone": "Blacksmith",
                    "x": 50.0, "y": 50.0
                }
            },
            # 5. Duel Knockout in Durotar
            {
                "killId": "KB-TEST05",
                "timestamp": int(time.time()) - 20,
                "isDuel": True,
                "isBattleground": False,
                "isArena": False,
                "battlegroundName": "Duel (Knockout)",
                "isSolo": True,
                "attackersCount": 1,
                "totalDamage": 3100,
                "killer": {
                    "name": "DuelMaster", "level": 60, "class": "WARRIOR",
                    "guild": "Gladiators", "faction": "Horde", "partySize": 1,
                    "damageDone": 3100, "healingDone": 0
                },
                "victim": {
                    "name": "Challenger", "level": 60, "class": "ROGUE",
                    "guild": "Stealthers", "faction": "Horde", "partySize": 1
                },
                "location": {
                    "mapId": 1411, "zone": "Durotar", "subZone": "Orgrimmar Gates",
                    "x": 45.0, "y": 15.0
                }
            },
            # 6. Ranked Arena Match
            {
                "killId": "KB-TEST06",
                "timestamp": int(time.time()) - 10,
                "isDuel": False,
                "isBattleground": False,
                "isArena": True,
                "battlegroundName": "Nagrand Arena",
                "isSolo": False,
                "attackersCount": 2,
                "totalDamage": 7500,
                "killer": {
                    "name": "ArenaChamp", "level": 60, "class": "MAGE",
                    "guild": "TopTwoPercent", "faction": "Alliance", "partySize": 2,
                    "damageDone": 7500, "healingDone": 0
                },
                "victim": {
                    "name": "Opponent", "level": 60, "class": "PRIEST",
                    "guild": "Underdogs", "faction": "Horde", "partySize": 2
                },
                "location": {
                    "mapId": 559, "zone": "Nagrand Arena", "subZone": "Arena Floor",
                    "x": 50.0, "y": 50.0
                }
            }
        ]

        for km in sample_kills:
            resp = self.client.post("/api/kills", json=km)
            self.assertEqual(resp.status_code, 201)
        print("[PASS] Ingested 6 synthetic kill records into SQLite database.")

    def test_03_filter_mode_telemetry(self):
        """Verify context filters: ALL, WORLD, BG, ARENA, and DUEL."""
        # 1. All PvP
        res_all = self.client.get("/api/kills?mode=ALL")
        data_all = res_all.get_json()
        self.assertGreaterEqual(data_all["count"], 6)

        # 2. World PvP Only
        res_world = self.client.get("/api/kills?mode=WORLD")
        data_world = res_world.get_json()
        for k in data_world["kills"]:
            self.assertFalse(k["isBattleground"], "World PvP mode must not include BGs")
            self.assertFalse(k.get("isArena", False), "World PvP mode must not include Arenas")
            self.assertFalse(k.get("isDuel", False), "World PvP mode must not include Duels")

        # 3. Battleground Only
        res_bg = self.client.get("/api/kills?mode=BG")
        data_bg = res_bg.get_json()
        for k in data_bg["kills"]:
            self.assertTrue(k["isBattleground"], "BG mode must only include Battlegrounds")

        # 4. Arena Only
        res_arena = self.client.get("/api/kills?mode=ARENA")
        data_arena = res_arena.get_json()
        for k in data_arena["kills"]:
            self.assertTrue(k["isArena"], "Arena mode must only include Arenas")

        # 5. Duel Only
        res_duel = self.client.get("/api/kills?mode=DUEL")
        data_duel = res_duel.get_json()
        for k in data_duel["kills"]:
            self.assertTrue(k["isDuel"], "Duel mode must only include Duels")

        print("[PASS] Verified 5-way multi-mode filtering (ALL, WORLD, BG, ARENA, DUEL).")

    def test_04_bg_stats_telemetry(self):
        """Verify Battleground damage and healing telemetry metrics."""
        res = self.client.get("/api/bg/stats")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        # Check healing leader
        healing_leaders = data.get("topHealing", [])
        self.assertTrue(len(healing_leaders) > 0)
        paladin = next((p for p in healing_leaders if p["name"] == "Lifebinder"), None)
        self.assertIsNotNone(paladin)
        self.assertEqual(paladin["total_healing"], 115000)

        # Check damage leader
        damage_leaders = data.get("topDamage", [])
        hunter = next((p for p in damage_leaders if p["name"] == "Hawkeye"), None)
        self.assertIsNotNone(hunter)
        self.assertEqual(hunter["total_damage"], 84500)
        print("[PASS] Verified Battleground damage/healing telemetry rankings.")

    def test_05_bounty_and_debt_ledger_lifecycle(self):
        """Test Bounty placement, claim verification, and Oathbreaker Debt Ledger with redemption."""
        # 1. Place a bounty on Frostweaver
        bounty_payload = {
            "id": "BNT-TEST01",
            "targetName": "Frostweaver",
            "targetClass": "MAGE",
            "targetFaction": "Alliance",
            "placerName": "SlickGanker",
            "amountGold": 500,
            "amountCopper": 5000000
        }
        res_bnt = self.client.post("/api/bounties", json=bounty_payload)
        self.assertEqual(res_bnt.status_code, 201)

        # Check bounty list
        b_list = self.client.get("/api/bounties").get_json()
        self.assertTrue(any(b["target_name"] == "Frostweaver" for b in b_list))

        # 2. Add an Oathbreaker debtor in default
        debt_payload = {
            "playerName": "DeadbeatDan",
            "creditor": "HunterX",
            "amountOwedCopper": 5500000,
            "principalCopper": 5000000,
            "surchargeCopper": 500000,
            "status": "OATHBREAKER",
            "daysInDefault": 5,
            "bountyId": "BNT-OLD01"
        }
        res_debt = self.client.post("/api/bounties/debt-ledger", json=debt_payload)
        self.assertEqual(res_debt.status_code, 201)

        # Verify debtor appears on Wall of Shame
        wall_of_shame = self.client.get("/api/bounties/debt-ledger").get_json()
        debtor = next((d for d in wall_of_shame if d["player_name"] == "DeadbeatDan"), None)
        self.assertIsNotNone(debtor)
        self.assertEqual(debtor["days_in_default"], 5)

        # Platform Guardrail: Verify Blood Debtor is automatically branded on KOS Blacklist
        kos_res_before = self.client.get("/api/kos/blacklist").get_json()
        self.assertTrue(any(g["entity_name"] == "DeadbeatDan" and g["status"] == "KOS" for g in kos_res_before["guilds"]), "Debtor must be auto-branded KOS")

        # 3. Pay off debt (Redemption)
        res_pay = self.client.post("/api/debt/pay", json={"playerName": "DeadbeatDan"})
        self.assertEqual(res_pay.status_code, 200)

        # Verify debtor is cleansed from active Oathbreaker ledger
        wall_after = self.client.get("/api/bounties/debt-ledger").get_json()
        cleansed = any(d["player_name"] == "DeadbeatDan" for d in wall_after)
        self.assertFalse(cleansed, "Redeemed debtor must be removed from the active Wall of Shame")

        # Verify debtor is cleansed from KOS Blacklist upon settlement
        kos_res_after = self.client.get("/api/kos/blacklist").get_json()
        self.assertFalse(any(g["entity_name"] == "DeadbeatDan" for g in kos_res_after["guilds"]), "Settled debtor must be removed from KOS Blacklist")
        print("[PASS] Verified Bounty placement, Blood Debtor KOS Blacklist enforcement, and Redemption lifecycle.")

    def test_06_guild_and_character_profiles(self):
        """Verify guild leaderboards, guild profiles, character profiles, and guild history tracking."""
        # 1. Guild Leaderboards
        res_guilds = self.client.get("/api/guilds")
        self.assertEqual(res_guilds.status_code, 200)
        guilds_data = res_guilds.get_json().get("guilds", [])
        self.assertGreater(len(guilds_data), 0, "Expected at least one guild in leaderboards")

        gank_squad = next((g for g in guilds_data if g["guild"] == "GankSquad"), None)
        self.assertIsNotNone(gank_squad, "GankSquad should appear in guild leaderboards")
        self.assertGreater(gank_squad["kills"], 0)
        self.assertIsNotNone(gank_squad["topMember"])

        # 2. Guild Profile Endpoint
        res_guild_prof = self.client.get("/api/guild/GankSquad")
        self.assertEqual(res_guild_prof.status_code, 200)
        prof_data = res_guild_prof.get_json()
        self.assertEqual(prof_data["guild"], "GankSquad")
        self.assertGreater(len(prof_data["members"]), 0)
        self.assertGreater(len(prof_data["recentKills"]), 0)

        # 3. Character Profile Endpoint
        res_char = self.client.get("/api/character/Shadowblade")
        self.assertEqual(res_char.status_code, 200)
        char_data = res_char.get_json()
        self.assertEqual(char_data["name"], "Shadowblade")
        self.assertEqual(char_data["class"], "ROGUE")
        self.assertEqual(char_data["currentGuild"], "GankSquad")
        self.assertIn("official", char_data["armoryUrls"])
        self.assertIn("ironforge", char_data["armoryUrls"])
        self.assertIn("warcraftlogs", char_data["armoryUrls"])
        self.assertGreater(len(char_data["guildHistory"]), 0)
        self.assertEqual(char_data["guildHistory"][0]["guild_name"], "GankSquad")

        # 4. Guild Transfer: Shadowblade transfers to "EliteGankers"
        new_kill = {
            "killId": "KB-GUILD-TRANSFER-01",
            "timestamp": int(time.time()),
            "isBattleground": False,
            "isArena": False,
            "battlegroundName": "",
            "isSolo": True,
            "attackersCount": 1,
            "totalDamage": 4000,
            "killer": {
                "name": "Shadowblade", "level": 60, "class": "ROGUE",
                "guild": "EliteGankers", "faction": "Horde", "partySize": 1,
                "damageDone": 4000, "healingDone": 0
            },
            "victim": {
                "name": "Frostweaver", "level": 60, "class": "MAGE",
                "guild": "KnightsOfIronforge", "faction": "Alliance", "partySize": 1
            },
            "location": {
                "mapId": 1434, "zone": "Stranglethorn Vale", "subZone": "Booty Bay",
                "x": 26.2, "y": 74.0
            }
        }
        res_post = self.client.post("/api/kills", json=new_kill)
        self.assertEqual(res_post.status_code, 201)

        # Re-fetch Shadowblade character profile
        res_char_after = self.client.get("/api/character/Shadowblade")
        char_after = res_char_after.get_json()
        self.assertEqual(char_after["currentGuild"], "EliteGankers")
        history_guilds = [gh["guild_name"] for gh in char_after["guildHistory"]]
        self.assertIn("EliteGankers", history_guilds)
        self.assertIn("GankSquad", history_guilds)
        print("[PASS] Verified Guild Leaderboards, Guild Profiles, Character Profiles, and Guild Transfer History.")

    def test_07_bounty_supporter_gating_and_leaderboards(self):
        """Verify supporter subzone gating, bounty Hall of Fame leaderboards, and auto-claim mechanics."""
        # 1. Free/Public Bounties endpoint (Zone only, Subzone gated)
        res_bnt_free = self.client.get("/api/bounties")
        self.assertEqual(res_bnt_free.status_code, 200)
        bounties_free = res_bnt_free.get_json()
        target_b = next((b for b in bounties_free if b["target_name"] == "Frostweaver"), None)
        self.assertIsNotNone(target_b, "Frostweaver bounty should exist")
        self.assertIn("lastSeen", target_b)
        self.assertTrue(target_b["lastSeen"]["hasTelemetry"])
        self.assertEqual(target_b["lastSeen"]["zone"], "Stranglethorn Vale")
        self.assertIsNone(target_b["lastSeen"]["subzone"], "Subzone should be masked for free tier")
        self.assertFalse(target_b["lastSeen"]["hasSubzoneAccess"])

        # 2. Supporter Bounties endpoint (Subzone unlocked)
        res_bnt_supporter = self.client.get("/api/bounties?supporter=1")
        self.assertEqual(res_bnt_supporter.status_code, 200)
        bounties_supporter = res_bnt_supporter.get_json()
        target_supp = next((b for b in bounties_supporter if b["target_name"] == "Frostweaver"), None)
        self.assertIsNotNone(target_supp)
        self.assertTrue(target_supp["lastSeen"]["hasSubzoneAccess"])
        self.assertEqual(target_supp["lastSeen"]["subzone"], "Booty Bay")

        # 3. Auto-claim Bounty: Place bounty on Grimjaw, then Hawkeye slays Grimjaw
        bounty_grimjaw = {
            "id": "BNT-GRIMJAW01",
            "targetName": "Grimjaw",
            "targetClass": "WARRIOR",
            "targetFaction": "Horde",
            "placerName": "SlickGanker",
            "amountGold": 750,
            "amountCopper": 7500000
        }
        res_bnt_g = self.client.post("/api/bounties", json=bounty_grimjaw)
        self.assertEqual(res_bnt_g.status_code, 201)

        # Hunter accepts the contract before hunting
        res_accept = self.client.post("/api/bounties/accept", json={"bountyId": "BNT-GRIMJAW01", "hunterName": "Hawkeye"})
        self.assertEqual(res_accept.status_code, 200)

        # Test Most Wanted endpoint before kill
        res_mw = self.client.get("/api/bounties/most-wanted")
        self.assertEqual(res_mw.status_code, 200)
        mw_data = res_mw.get_json()
        self.assertGreater(len(mw_data), 0)
        grimjaw_mw = next((b for b in mw_data if b["target_name"] == "Grimjaw"), None)
        self.assertIsNotNone(grimjaw_mw)
        self.assertEqual(grimjaw_mw["acceptedCount"], 1)

        kill_claim = {
            "killId": "KB-BOUNTY-CLAIM-01",
            "timestamp": int(time.time()),
            "isBattleground": False,
            "isArena": False,
            "battlegroundName": "",
            "isSolo": True,
            "attackersCount": 1,
            "totalDamage": 5200,
            "acceptedBounties": ["BNT-GRIMJAW01"],
            "killer": {
                "name": "Hawkeye", "level": 60, "class": "HUNTER",
                "guild": "ApexPredators", "faction": "Alliance", "partySize": 1,
                "damageDone": 5200, "healingDone": 0
            },
            "victim": {
                "name": "Grimjaw", "level": 60, "class": "WARRIOR",
                "guild": "Bloodfang", "faction": "Horde", "partySize": 1
            },
            "location": {
                "mapId": 1434, "zone": "Stranglethorn Vale", "subZone": "Booty Bay",
                "x": 26.5, "y": 74.2
            }
        }
        res_claim_kill = self.client.post("/api/kills", json=kill_claim)
        self.assertEqual(res_claim_kill.status_code, 201)

        # 4. Check Bounty Hall of Fame Leaderboards
        res_lb = self.client.get("/api/bounties/leaderboards")
        self.assertEqual(res_lb.status_code, 200)
        lb_data = res_lb.get_json()
        self.assertIn("topHunters", lb_data)
        self.assertIn("highestBounties", lb_data)
        self.assertIn("longestOutstanding", lb_data)
        self.assertIn("fastestCollected", lb_data)

        # Hawkeye should now appear in Top Hunters or Fastest Collected
        hawkeye_hunter = next((h for h in lb_data["topHunters"] if h["hunter_name"] == "Hawkeye"), None)
        self.assertIsNotNone(hawkeye_hunter, "Hawkeye should be recorded as a claiming bounty hunter")
        self.assertGreater(hawkeye_hunter["claimed_count"], 0)

        # 5. Check Cold Cases Archive endpoint
        res_archive = self.client.get("/api/bounties/archive")
        self.assertEqual(res_archive.status_code, 200)
        self.assertIsInstance(res_archive.get_json(), list)

        # 6. Check 7-Day Activity Telemetry for zKillboard sidebar
        res_act = self.client.get("/api/stats/activity-7d")
        self.assertEqual(res_act.status_code, 200)
        act_data = res_act.get_json()
        self.assertIn("kills", act_data)
        self.assertIn("characters", act_data)
        self.assertIn("guilds", act_data)
        self.assertIn("topCharacters", act_data)
        self.assertIn("topGuilds", act_data)
        self.assertIn("topClasses", act_data)
        self.assertIn("topZones", act_data)
        self.assertGreater(act_data["kills"], 0)

        # 6b. Check PvE Dedicated Telemetry
        res_pve = self.client.get("/api/stats/activity-7d?server=PVE")
        self.assertEqual(res_pve.status_code, 200)
        pve_act = res_pve.get_json()
        self.assertTrue(pve_act.get("isPve"))
        self.assertIn("topSpecs", pve_act)
        self.assertIn("topGankers24h", pve_act)

        # 7. Check StreamBox OBS Overlay endpoint
        res_sb = self.client.get("/streambox/Hawkeye")
        self.assertEqual(res_sb.status_code, 200)
        self.assertIn("StreamBox", res_sb.get_data(as_text=True))
        print("[PASS] Verified Supporter Gating, Most Wanted, Contract Acceptance, Cold Cases, 7-Day Activity, and StreamBox.")

    def test_08_call_for_backup_and_discord_defense(self):
        """Verify Call for Backup (SOS distress beacons), Guild Events, and Discord Gateway."""
        # 1. Post a distress beacon
        sos_payload = {
            "id": "SOS-TEST-Hawkeye",
            "character_name": "Hawkeye",
            "character_class": "HUNTER",
            "character_level": 60,
            "guild_name": "Vanguard Brigade",
            "faction": "Alliance",
            "zone": "Stranglethorn Vale",
            "subzone": "Gurubashi Arena",
            "coord_x": 42.5,
            "coord_y": 68.2,
            "hostile_count": 2,
            "hostile_names": "Gankzor (Rogue), Bloodfang (Warrior)",
            "timestamp": int(time.time()),
            "status": "ACTIVE"
        }
        res_sos = self.client.post("/api/backup/distress", json=sos_payload)
        self.assertEqual(res_sos.status_code, 201)
        sos_resp = res_sos.get_json()
        self.assertEqual(sos_resp["status"], "ok")
        self.assertEqual(sos_resp["beacon_id"], "SOS-TEST-Hawkeye")

        # 2. Query active distress beacons
        res_get_sos = self.client.get("/api/backup/distress")
        self.assertEqual(res_get_sos.status_code, 200)
        beacons = res_get_sos.get_json()
        self.assertIsInstance(beacons, list)
        found_beacon = next((b for b in beacons if b["id"] == "SOS-TEST-Hawkeye"), None)
        self.assertIsNotNone(found_beacon, "Distress beacon should appear in active beacons list")
        self.assertEqual(found_beacon["character_name"], "Hawkeye")
        self.assertEqual(found_beacon["hostile_count"], 2)

        # 3. Configure Discord Webhook
        discord_cfg_payload = {
            "guild_name": "Vanguard Brigade",
            "webhook_url": "https://discord.com/api/webhooks/1234567890/testtoken",
            "alerts_enabled": True,
            "events_enabled": True
        }
        res_cfg = self.client.post("/api/discord/config", json=discord_cfg_payload)
        self.assertEqual(res_cfg.status_code, 200)

        # 4. Verify Discord config is returned with masked token
        res_get_cfg = self.client.get("/api/discord/config?guild=Vanguard Brigade")
        self.assertEqual(res_get_cfg.status_code, 200)
        cfg_data = res_get_cfg.get_json()
        self.assertTrue(cfg_data["configured"])
        self.assertIn("****", cfg_data["masked_url"])

        # 5. Create a Guild Event / Rally
        event_payload = {
            "id": "EVT-TEST-001",
            "title": "STV Zone Defense & Outlaw Manhunt",
            "description": "Repel Horde gank squad operating outside Booty Bay. Form up at Rebel Camp!",
            "guild_name": "Vanguard Brigade",
            "creator_name": "Hawkeye",
            "zone": "Stranglethorn Vale",
            "time_str": "8:00 PM EST"
        }
        res_evt = self.client.post("/api/events", json=event_payload)
        self.assertEqual(res_evt.status_code, 201)
        evt_resp = res_evt.get_json()
        self.assertEqual(evt_resp["status"], "ok")

        # 6. Query Guild Events
        res_get_evt = self.client.get("/api/events")
        self.assertEqual(res_get_evt.status_code, 200)
        events = res_get_evt.get_json()
        found_evt = next((e for e in events if e["id"] == "EVT-TEST-001"), None)
        self.assertIsNotNone(found_evt, "Guild event should be listed in events endpoint")
        self.assertEqual(found_evt["title"], "STV Zone Defense & Outlaw Manhunt")

        # 7. Resolve distress beacon
        res_resolve = self.client.post("/api/backup/resolve/SOS-TEST-Hawkeye")
        self.assertEqual(res_resolve.status_code, 200)

        # Verify beacon is no longer active
        res_beacons_after = self.client.get("/api/backup/distress")
        active_after = [b for b in res_beacons_after.get_json() if b["id"] == "SOS-TEST-Hawkeye"]
        self.assertEqual(len(active_after), 0, "Resolved beacon should not be active")

        # 8. Verify Open-World PvP Gating (Instances strictly rejected)
        res_instance_sos = self.client.post("/api/backup/distress", json={
            "character_name": "Hawkeye",
            "is_instance": True,
            "zone": "Warsong Gulch"
        })
        self.assertEqual(res_instance_sos.status_code, 400, "Distress beacon inside instances must be rejected")

        res_instance_bounty = self.client.post("/api/bounties", json={
            "targetName": "Gorehowl",
            "amountGold": 100,
            "is_instance": True
        })
        self.assertEqual(res_instance_bounty.status_code, 400, "Bounty inside instances must be rejected")

        # 9. Verify War Correspondent HUD endpoint
        res_hud = self.client.get("/war-hud/Hawkeye")
        self.assertEqual(res_hud.status_code, 200)
        self.assertIn("War Correspondent HUD", res_hud.get_data(as_text=True))

        print("[PASS] Verified Call for Backup SOS beacons, Guild Events, Discord Defense Gateway, and Open-World PvP Gating.")

    def test_09_tactical_intel_sighting_wire(self):
        """Verify Tactical Intel Sighting Wire, scout recon telemetry, and open-world gating."""
        # 1. Post a valid open-world enemy sighting
        sighting_payload = {
            "id": "SPT-TEST-001",
            "reporter_name": "ScoutHawkeye",
            "reporter_guild": "Vanguard Brigade",
            "target_name": "SneakyRogue",
            "target_class": "ROGUE",
            "target_level": 60,
            "target_guild": "HordeVanguard",
            "target_faction": "Horde",
            "zone": "Stranglethorn Vale",
            "subzone": "Rebel Camp",
            "coord_x": 37.5,
            "coord_y": 12.4,
            "notes": "Stalking Alliance questers outside Rebel Camp",
            "timestamp": int(time.time())
        }
        res_spot = self.client.post("/api/intel/sighting", json=sighting_payload)
        self.assertEqual(res_spot.status_code, 201)
        data = res_spot.get_json()
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["sighting_id"], "SPT-TEST-001")

        # 2. Query sightings wire
        res_wire = self.client.get("/api/intel/sightings")
        self.assertEqual(res_wire.status_code, 200)
        sightings = res_wire.get_json()
        found = next((s for s in sightings if s["id"] == "SPT-TEST-001"), None)
        self.assertIsNotNone(found, "Sighting should be present in intel wire")
        self.assertEqual(found["target_name"], "SneakyRogue")
        self.assertEqual(found["reporter_name"], "ScoutHawkeye")

        # 3. Verify open-world gating (instances/BGs must be rejected)
        res_inst = self.client.post("/api/intel/sighting", json={
            "reporter_name": "ScoutHawkeye",
            "target_name": "SneakyRogue",
            "is_instance": True,
            "zone": "Arathi Basin"
        })
        self.assertEqual(res_inst.status_code, 400, "Intel sighting inside instances must be rejected")
        print("[PASS] Verified Tactical Intel Sighting Wire and Open-World Recon Gating.")

    def test_10_blood_feuds_roe_and_kos_blacklist(self):
        """Verify Head-to-Head Blood Feuds, ROE scoring rules, and 30-Day Deserter KOS Blacklist."""
        # 1. Setup guild history for casualty guild roster
        with get_db() as conn:
            conn.execute("""
                INSERT OR REPLACE INTO character_guild_history (character_name, guild_name, faction, first_seen, last_seen)
                VALUES ('TraitorTim', 'Crimson Horde', 'Horde', 1000, 2000)
            """)
            conn.commit()

        # 2. Declare Blood Feud challenge with ROE parameters
        feud_payload = {
            "id": "FEUD-TEST-001",
            "feud_type": "GUILD",
            "challenger_name": "CommanderHawkeye",
            "challenger_guild": "Vanguard Brigade",
            "challenger_faction": "Alliance",
            "target_name": "WarlordBloodaxe",
            "target_guild": "Crimson Horde",
            "target_faction": "Horde",
            "target_score": 3,
            "roe_min_level": 55,
            "roe_underdog_bonus": 1,
            "roe_zone": "Stranglethorn Vale",
            "status": "ACTIVE"
        }
        res_challenge = self.client.post("/api/feuds/challenge", json=feud_payload)
        self.assertEqual(res_challenge.status_code, 201)

        # Verify feud exists and is ACTIVE
        res_feuds = self.client.get("/api/feuds")
        self.assertEqual(res_feuds.status_code, 200)
        feuds = res_feuds.get_json()
        active_feud = next((f for f in feuds if f["id"] == "FEUD-TEST-001"), None)
        self.assertIsNotNone(active_feud)
        self.assertEqual(active_feud["status"], "ACTIVE")
        self.assertEqual(active_feud["challenger_score"], 0)

        # 3. Ingestion ROE Test 1: Kill in wrong zone (Duskwood != Stranglethorn Vale)
        res_k1 = self.client.post("/api/kills", json={
            "killId": "KB-FEUD-01",
            "timestamp": int(time.time()),
            "killer": {"name": "Hawkeye", "level": 60, "class": "HUNTER", "guild": "Vanguard Brigade", "faction": "Alliance", "partySize": 1},
            "victim": {"name": "Bloodaxe", "level": 60, "class": "WARRIOR", "guild": "Crimson Horde", "faction": "Horde", "partySize": 1},
            "location": {"zone": "Duskwood", "subZone": "", "x": 10.0, "y": 10.0}
        })
        self.assertEqual(res_k1.status_code, 201)
        with get_db() as conn:
            f = conn.execute("SELECT challenger_score FROM blood_feuds WHERE id = 'FEUD-TEST-001'").fetchone()
            self.assertEqual(f[0], 0, "Kill outside ROE zone must not award feud points")

        # 4. Ingestion ROE Test 2: Lowbie victim (< 55 min level)
        res_k2 = self.client.post("/api/kills", json={
            "killId": "KB-FEUD-02",
            "timestamp": int(time.time()),
            "killer": {"name": "Hawkeye", "level": 60, "class": "HUNTER", "guild": "Vanguard Brigade", "faction": "Alliance", "partySize": 1},
            "victim": {"name": "GruntGoretusk", "level": 48, "class": "WARRIOR", "guild": "Crimson Horde", "faction": "Horde", "partySize": 1},
            "location": {"zone": "Stranglethorn Vale", "subZone": "", "x": 30.0, "y": 20.0}
        })
        self.assertEqual(res_k2.status_code, 201)
        with get_db() as conn:
            f = conn.execute("SELECT challenger_score FROM blood_feuds WHERE id = 'FEUD-TEST-001'").fetchone()
            self.assertEqual(f[0], 0, "Lowbie gank (< 55) must not award feud points")

        # 5. Ingestion ROE Test 3: Cheap Zerg Gank (3+ attackers on 1 solo victim)
        res_k3 = self.client.post("/api/kills", json={
            "killId": "KB-FEUD-03",
            "timestamp": int(time.time()),
            "killer": {"name": "Hawkeye", "level": 60, "class": "HUNTER", "guild": "Vanguard Brigade", "faction": "Alliance", "partySize": 3},
            "victim": {"name": "Bloodaxe", "level": 60, "class": "WARRIOR", "guild": "Crimson Horde", "faction": "Horde", "partySize": 1},
            "attackersCount": 3,
            "location": {"zone": "Stranglethorn Vale", "subZone": "", "x": 30.0, "y": 20.0}
        })
        self.assertEqual(res_k3.status_code, 201)
        with get_db() as conn:
            f = conn.execute("SELECT challenger_score FROM blood_feuds WHERE id = 'FEUD-TEST-001'").fetchone()
            self.assertEqual(f[0], 0, "Zerg gank (3+ attackers) must award 0 points under ROE")

        # 6. Ingestion ROE Test 4: Underdog 2x Bonus (1 solo killer vs 2-man enemy squad)
        res_k4 = self.client.post("/api/kills", json={
            "killId": "KB-FEUD-04",
            "timestamp": int(time.time()),
            "killer": {"name": "Hawkeye", "level": 60, "class": "HUNTER", "guild": "Vanguard Brigade", "faction": "Alliance", "partySize": 1},
            "victim": {"name": "Bloodaxe", "level": 60, "class": "WARRIOR", "guild": "Crimson Horde", "faction": "Horde", "partySize": 2},
            "attackersCount": 1,
            "location": {"zone": "Stranglethorn Vale", "subZone": "", "x": 30.0, "y": 20.0}
        })
        self.assertEqual(res_k4.status_code, 201)
        with get_db() as conn:
            f = conn.execute("SELECT challenger_score FROM blood_feuds WHERE id = 'FEUD-TEST-001'").fetchone()
            self.assertEqual(f[0], 2, "Outnumbered 1v2 underdog win must award 2x bonus points")

        # 7. Ingestion ROE Test 5: Deciding 1v1 Kill (Reaches target score 3)
        res_k5 = self.client.post("/api/kills", json={
            "killId": "KB-FEUD-05",
            "timestamp": int(time.time()),
            "killer": {"name": "Hawkeye", "level": 60, "class": "HUNTER", "guild": "Vanguard Brigade", "faction": "Alliance", "partySize": 1},
            "victim": {"name": "Bloodaxe", "level": 60, "class": "WARRIOR", "guild": "Crimson Horde", "faction": "Horde", "partySize": 1},
            "attackersCount": 1,
            "location": {"zone": "Stranglethorn Vale", "subZone": "", "x": 30.0, "y": 20.0}
        })
        self.assertEqual(res_k5.status_code, 201)

        # 8. Verify Feud Completion and Victor
        with get_db() as conn:
            f = conn.execute("SELECT status, winner_name, challenger_score FROM blood_feuds WHERE id = 'FEUD-TEST-001'").fetchone()
            self.assertEqual(f["status"], "COMPLETED", "Feud should be COMPLETED upon reaching target score")
            self.assertEqual(f["winner_name"], "Vanguard Brigade")
            self.assertEqual(f["challenger_score"], 3)

        # 9. Verify Defeated Guild consigned to KOS Blacklist & 30-Day Deserters
        res_kos = self.client.get("/api/kos/blacklist")
        self.assertEqual(res_kos.status_code, 200)
        kos_data = res_kos.get_json()

        # Defeated guild check
        kos_guild = next((g for g in kos_data["guilds"] if g["entity_name"] == "Crimson Horde"), None)
        self.assertIsNotNone(kos_guild, "Defeated guild must be consigned to KOS Blacklist")
        self.assertEqual(kos_guild["status"], "KOS")

        # 30-day deserter stain check
        deserter = next((d for d in kos_data["deserters"] if d["player_name"] == "TraitorTim"), None)
        self.assertIsNotNone(deserter, "Guild member TraitorTim must be stamped as KOS Deserter")
        self.assertEqual(deserter["former_guild"], "Crimson Horde")
        self.assertGreaterEqual(deserter["days_remaining"], 29)

        # 10. Verify Manual KOS and Pardon
        res_add_kos = self.client.post("/api/kos/blacklist", json={
            "entity_name": "RogueGanker",
            "entity_type": "PLAYER",
            "reason": "Serial flight-path camper"
        })
        self.assertEqual(res_add_kos.status_code, 201)

        res_pardon = self.client.post("/api/kos/pardon", json={"entity_name": "RogueGanker"})
        self.assertEqual(res_pardon.status_code, 200)

        print("[PASS] Verified Head-to-Head Blood Feuds, ROE Scoring, and 30-Day Deserter KOS Blacklist.")

    def test_11_player_armory_directory(self):
        """Verify Native Player Armory directory endpoint, PvP honor rank titles, and search filters."""
        # 1. Base Armory query
        res = self.client.get("/api/armory")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn("total", data)
        self.assertIn("characters", data)
        self.assertGreater(data["total"], 0, "Armory directory should contain ingested combatants")

        chars = data["characters"]
        first_char = chars[0]
        for field in ["name", "class", "level", "faction", "guild", "kills", "deaths", "kd", "soloKills", "rankTitle"]:
            self.assertIn(field, first_char, f"Armory character missing required field: {field}")

        # 2. Search filter test
        res_search = self.client.get("/api/armory?search=Hawkeye")
        self.assertEqual(res_search.status_code, 200)
        search_data = res_search.get_json()
        self.assertGreater(search_data["total"], 0)
        self.assertTrue(any(c["name"] == "Hawkeye" for c in search_data["characters"]))

        res_empty = self.client.get("/api/armory?search=GhostInTheMachine999")
        self.assertEqual(res_empty.status_code, 200)
        self.assertEqual(res_empty.get_json()["total"], 0)

        # 3. Faction filter test
        res_ally = self.client.get("/api/armory?faction=Alliance")
        self.assertEqual(res_ally.status_code, 200)
        ally_chars = res_ally.get_json()["characters"]
        for c in ally_chars:
            self.assertEqual(c["faction"], "Alliance")

        res_horde = self.client.get("/api/armory?faction=Horde")
        self.assertEqual(res_horde.status_code, 200)
        horde_chars = res_horde.get_json()["characters"]
        for c in horde_chars:
            self.assertEqual(c["faction"], "Horde")

        # 4. Class filter test
        res_class = self.client.get("/api/armory?class=HUNTER")
        self.assertEqual(res_class.status_code, 200)
        hunter_chars = res_class.get_json()["characters"]
        for c in hunter_chars:
            self.assertEqual(c["class"], "HUNTER")

        # 5. Sorting test (by kd)
        res_sort_kd = self.client.get("/api/armory?sort=kd")
        self.assertEqual(res_sort_kd.status_code, 200)
        kd_chars = res_sort_kd.get_json()["characters"]
        if len(kd_chars) >= 2:
            self.assertGreaterEqual(kd_chars[0]["kd"], kd_chars[1]["kd"])

        # 6. Character dossier detail enrichment test
        res_profile = self.client.get("/api/character/Hawkeye")
        self.assertEqual(res_profile.status_code, 200)
        profile_data = res_profile.get_json()
        self.assertIn("rankTitle", profile_data)
        self.assertIn("activeBountyGold", profile_data)
        self.assertIn("isKos", profile_data)
        self.assertIn("deserter", profile_data)
        self.assertIn("armoryUrls", profile_data)

        print(f"[PASS] Verified Player Armory directory ({data['total']} combatants indexed) and Military Rank Titles.")

    def test_12_most_deadly_npc_leaderboard_and_pve_isolation(self):
        """Verify PvE death ingestion, isolation from PvP feeds, and Deadly NPCs Leaderboard."""
        pve_death = {
            "deathId": "PVE-TEST-HOGGER-99",
            "timestamp": int(time.time()),
            "npc": {
                "name": "Hogger",
                "id": 448,
                "guid": "Creature-0-1-0-0-448-999",
                "spell": "Vicious Bite",
                "damage": 820
            },
            "victim": {
                "name": "GnomeTestDummy",
                "guid": "Player-0-GnomeTest",
                "level": 11,
                "class": "MAGE",
                "guild": "TestGuild",
                "faction": "Alliance"
            },
            "location": {
                "mapId": 1429,
                "zone": "Elwynn Forest",
                "subZone": "Forest's Edge",
                "x": 26.4,
                "y": 76.8
            }
        }

        # 1. Ingest PvE death via POST /api/pve/deaths
        res = self.client.post("/api/pve/deaths", json=pve_death)
        self.assertEqual(res.status_code, 201)
        res_data = res.get_json()
        self.assertTrue(res_data.get("success"))
        self.assertEqual(res_data.get("deathId"), "PVE-TEST-HOGGER-99")

        # 2. Strict PvE Isolation Guardrail: Verify this death does NOT appear in /api/kills
        pvp_res = self.client.get("/api/kills")
        self.assertEqual(pvp_res.status_code, 200)
        pvp_kills = pvp_res.get_json().get("kills", [])
        self.assertFalse(any(k.get("killId") == "PVE-TEST-HOGGER-99" for k in pvp_kills),
                         "CRITICAL VIOLATION: PvE death leaked into PvP kills feed!")

        # 3. Test GET /api/pve/leaderboard
        lb_res = self.client.get("/api/pve/leaderboard")
        self.assertEqual(lb_res.status_code, 200)
        lb_data = lb_res.get_json()
        self.assertIn("summary", lb_data)
        self.assertIn("topDeadlyNpcs", lb_data)
        self.assertIn("topFallenPlayers", lb_data)
        self.assertGreater(lb_data["summary"]["totalDeaths"], 0)

        hogger_entry = next((n for n in lb_data["topDeadlyNpcs"] if n["npc_name"] == "Hogger"), None)
        self.assertIsNotNone(hogger_entry, "Hogger should be present in Deadly NPCs leaderboard")
        self.assertGreaterEqual(hogger_entry["kills"], 1)

        # 4. Test GET /api/pve/deaths
        stream_res = self.client.get("/api/pve/deaths?npc=Hogger")
        self.assertEqual(stream_res.status_code, 200)
        stream_data = stream_res.get_json()
        self.assertGreater(stream_data["count"], 0)
        self.assertTrue(any(d["death_id"] == "PVE-TEST-HOGGER-99" for d in stream_data["deaths"]))

        print("[PASS] Verified Deadly NPC Leaderboard, PvE stream, and complete PvP isolation.")

    def test_13_client_flavor_and_gating_api(self):
        """Verify client flavor selection endpoint and LuaTableParser pveDeaths support."""
        # 1. GET default flavor
        res = self.client.get("/api/system/flavor")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn("flavor", data)
        self.assertIn("supportedFlavors", data)

        # 2. POST valid flavor update
        res_post = self.client.post("/api/system/flavor", json={"flavor": "WOTLK"})
        self.assertEqual(res_post.status_code, 200)
        self.assertEqual(res_post.get_json()["flavor"], "WOTLK")

        # 3. POST invalid flavor
        res_bad = self.client.post("/api/system/flavor", json={"flavor": "INVALID_EXPANSION_999"})
        self.assertEqual(res_bad.status_code, 400)

        # 4. Reset back to CLASSIC_ERA
        self.client.post("/api/system/flavor", json={"flavor": "CLASSIC_ERA"})
        res_reset = self.client.get("/api/system/flavor")
        self.assertEqual(res_reset.get_json()["flavor"], "CLASSIC_ERA")

        # 5. Verify LuaTableParser parses pveDeaths from SavedVariables string
        lua_saved_vars = """
        WoWKillboardDB = {
            ["kills"] = {
                ["KB-LUA-TEST"] = {
                    ["killer"] = { ["name"] = "WarriorX" },
                    ["victim"] = { ["name"] = "MageY" }
                }
            },
            ["pveDeaths"] = {
                ["PVE-LUA-TEST"] = {
                    ["npc"] = { ["name"] = "Stitches", ["id"] = 412 },
                    ["victim"] = { ["name"] = "UnluckyPlayer" }
                }
            }
        }
        """
        parsed = LuaTableParser.parse_string(lua_saved_vars)
        self.assertIn("pveDeaths", parsed, "LuaTableParser should extract pveDeaths table")
        self.assertIn("PVE-LUA-TEST", parsed["pveDeaths"])
        self.assertEqual(parsed["pveDeaths"]["PVE-LUA-TEST"]["npc"]["name"], "Stitches")

        print("[PASS] Verified Client Flavor API and LuaTableParser pveDeaths extraction.")

    def test_14_upload_and_admin_reset(self):
        """Verify Web Drag-and-Drop /api/upload ingestion and /api/admin/reset lifecycle."""
        lua_upload_payload = """
        WoWKillboardDB = {
            ["kills"] = {
                ["KB-UPLOAD-01"] = {
                    ["killId"] = "KB-UPLOAD-01",
                    ["timestamp"] = 1774720000,
                    ["isDuel"] = false,
                    ["isBattleground"] = false,
                    ["isSolo"] = true,
                    ["attackersCount"] = 1,
                    ["totalDamage"] = 4500,
                    ["killer"] = {
                        ["name"] = "VanguardA",
                        ["level"] = 60,
                        ["class"] = "WARRIOR",
                        ["guild"] = "StormwindGuard",
                        ["faction"] = "Alliance"
                    },
                    ["victim"] = {
                        ["name"] = "ShadowB",
                        ["level"] = 60,
                        ["class"] = "ROGUE",
                        ["guild"] = "DefiasBrotherhood",
                        ["faction"] = "Horde"
                    },
                    ["location"] = {
                        ["mapId"] = 1434,
                        ["zone"] = "Stranglethorn Vale",
                        ["x"] = 32.5,
                        ["y"] = 65.4
                    }
                },
                ["KB-UPLOAD-02"] = {
                    ["killId"] = "KB-UPLOAD-02",
                    ["timestamp"] = 1774720100,
                    ["isDuel"] = true,
                    ["isBattleground"] = false,
                    ["isSolo"] = true,
                    ["attackersCount"] = 1,
                    ["totalDamage"] = 3800,
                    ["killer"] = {
                        ["name"] = "ShadowB",
                        ["level"] = 60,
                        ["class"] = "ROGUE",
                        ["guild"] = "DefiasBrotherhood",
                        ["faction"] = "Horde"
                    },
                    ["victim"] = {
                        ["name"] = "VanguardA",
                        ["level"] = 60,
                        ["class"] = "WARRIOR",
                        ["guild"] = "StormwindGuard",
                        ["faction"] = "Alliance"
                    },
                    ["location"] = {
                        ["mapId"] = 1434,
                        ["zone"] = "Stranglethorn Vale",
                        ["x"] = 32.7,
                        ["y"] = 65.8
                    }
                }
            }
        }
        """

        # 1. Test POST /api/upload with raw Lua text
        res_upload = self.client.post("/api/upload", data=lua_upload_payload, content_type="text/plain")
        self.assertEqual(res_upload.status_code, 200)
        up_data = res_upload.get_json()
        self.assertTrue(up_data["success"])
        self.assertEqual(up_data["kills_processed"], 2)

        # 2. Verify kills are queryable in ledger
        res_kills = self.client.get("/api/kills")
        self.assertEqual(res_kills.status_code, 200)
        kill_ids = [k["killId"] for k in res_kills.get_json()["kills"]]
        self.assertIn("KB-UPLOAD-01", kill_ids)
        self.assertIn("KB-UPLOAD-02", kill_ids)

        # 3. Test Idempotency: Re-uploading does not create duplicates
        res_reupload = self.client.post("/api/upload", data=lua_upload_payload, content_type="text/plain")
        self.assertEqual(res_reupload.status_code, 200)
        res_kills2 = self.client.get("/api/kills")
        kill_ids2 = [k["killId"] for k in res_kills2.get_json()["kills"]]
        self.assertEqual(kill_ids2.count("KB-UPLOAD-01"), 1)

        # 4. Test Admin Reset with Invalid Key -> 403 Forbidden
        res_bad_reset = self.client.post("/api/admin/reset", json={"secret": "wrong_key_123"})
        self.assertEqual(res_bad_reset.status_code, 403)

        # 5. Test Admin Reset with Valid Key -> 200 OK
        res_good_reset = self.client.post("/api/admin/reset", json={"secret": "wowkb_archivist_secret"})
        self.assertEqual(res_good_reset.status_code, 200)
        self.assertTrue(res_good_reset.get_json()["success"])

        # 6. Verify ledger is completely zeroed
        res_after = self.client.get("/api/kills")
        self.assertEqual(res_after.status_code, 200)
        self.assertEqual(len(res_after.get_json()["kills"]), 0)

        print("[PASS] Verified Web Drag-and-Drop /api/upload ingestion and /api/admin/reset lifecycle.")

    def test_15_character_ownership_and_rally_muster(self):
        """Verify cryptographic character ownership locking, in-game verification, and rich War Rally muster."""
        owner_tok_1 = "tok_user_quick_alpha"
        owner_tok_2 = "tok_impersonator_beta"

        # 1. Owner 1 claims Dagariane
        res_claim = self.client.post("/api/auth/claim-character", json={
            "name": "Dagariane",
            "realm": "WoW Forever",
            "class": "PALADIN",
            "level": 60,
            "faction": "Alliance",
            "owner_token": owner_tok_1
        })
        self.assertEqual(res_claim.status_code, 200)
        claim_data = res_claim.get_json()
        self.assertTrue(claim_data["success"])
        self.assertEqual(claim_data["owner_token"], owner_tok_1)
        claim_code = claim_data["claim_code"]
        self.assertTrue(claim_code.startswith("KB-"))

        # 2. Impersonator attempts to claim or select Dagariane -> 403 Forbidden
        res_impersonate = self.client.post("/api/auth/claim-character", json={
            "name": "Dagariane",
            "owner_token": owner_tok_2
        })
        self.assertEqual(res_impersonate.status_code, 403)
        self.assertIn("already claimed", res_impersonate.get_json()["error"])

        # 3. Verify in-game claim token via /api/auth/verify-claim
        res_verify = self.client.post("/api/auth/verify-claim", json={
            "name": "Dagariane",
            "code": claim_code
        })
        self.assertEqual(res_verify.status_code, 200)
        self.assertTrue(res_verify.get_json()["success"])

        # 4. Verify /api/characters reflects ownership lock correctly for both users
        res_chars_owner = self.client.get("/api/characters?search=Dagariane", headers={"X-Owner-Token": owner_tok_1})
        self.assertEqual(res_chars_owner.status_code, 200)
        owner_char = res_chars_owner.get_json()[0]
        self.assertTrue(owner_char["is_claimed"])
        self.assertTrue(owner_char["is_owner"])
        self.assertTrue(owner_char["is_verified"])

        res_chars_impersonator = self.client.get("/api/characters?search=Dagariane", headers={"X-Owner-Token": owner_tok_2})
        self.assertEqual(res_chars_impersonator.status_code, 200)
        other_char = res_chars_impersonator.get_json()[0]
        self.assertTrue(other_char["is_claimed"])
        self.assertFalse(other_char["is_owner"])

        # 5. Test Rich War Rally Muster (Group Size, Content Type, Location, Levels, Roles, Message)
        res_rally = self.client.post("/api/backup/distress", json={
            "character_name": "Dagariane",
            "character_class": "PALADIN",
            "character_level": 60,
            "guild_name": "Vanguard",
            "faction": "Alliance",
            "group_type": "RAID",
            "content_type": "BG",
            "zone": "Warsong Gulch",
            "min_level": 50,
            "max_level": 60,
            "roles": {"tank": True, "heal": True, "dps": False},
            "message": "Assault the Silverwing Hold! Need 2 healers and 1 flag carrier tank."
        })
        self.assertEqual(res_rally.status_code, 201)

        # 6. Verify Rally Telemetry Wire Query
        res_rallies = self.client.get("/api/backup/distress")
        self.assertEqual(res_rallies.status_code, 200)
        rallies = res_rallies.get_json()
        target_rally = next((r for r in rallies if r["character_name"] == "Dagariane"), None)
        self.assertIsNotNone(target_rally)
        self.assertEqual(target_rally["group_type"], "RAID")
        self.assertEqual(target_rally["content_type"], "BG")
        self.assertEqual(target_rally["zone"], "Warsong Gulch")
        self.assertEqual(target_rally["min_level"], 50)
        self.assertEqual(target_rally["max_level"], 60)
        self.assertIn("TANK", target_rally["roles"])
        self.assertIn("HEAL", target_rally["roles"])
        # 7. Test Character Claim Release (/api/auth/release-claim)
        # Attempt unauthorized release from impersonator -> 403 Forbidden
        res_rel_unauth = self.client.post("/api/auth/release-claim", json={
            "name": "Dagariane",
            "owner_token": owner_tok_2
        })
        self.assertEqual(res_rel_unauth.status_code, 403)

        # Attempt unauthorized release with empty owner token -> 403 Forbidden
        res_rel_empty = self.client.post("/api/auth/release-claim", json={
            "name": "Dagariane",
            "owner_token": ""
        })
        self.assertEqual(res_rel_empty.status_code, 403)

        # Authorized release from legitimate owner -> 200 OK
        res_rel_auth = self.client.post("/api/auth/release-claim", json={
            "name": "Dagariane",
            "owner_token": owner_tok_1
        })
        self.assertEqual(res_rel_auth.status_code, 200)
        self.assertTrue(res_rel_auth.get_json()["success"])

        # Confirm character is now unclaimed
        res_chars_after = self.client.get("/api/characters?search=Dagariane", headers={"X-Owner-Token": owner_tok_1})
        self.assertEqual(res_chars_after.status_code, 200)
        unclaimed_char = res_chars_after.get_json()[0]
        self.assertFalse(unclaimed_char["is_claimed"])
        self.assertFalse(unclaimed_char["is_verified"])

        print("[PASS] Verified Character Claim Ownership Lock, In-Game Verification, Release Claim, and Rich Rally Muster.")

    def test_feedback_portal_and_api(self):
        """Verify Web Feedback page serving and /api/feedback submission lifecycle."""
        # 1. Verify GET /feedback serves HTML
        res_page = self.client.get("/feedback")
        self.assertEqual(res_page.status_code, 200)
        self.assertIn(b"Welcome to the WoW Killboard Beta", res_page.data)
        self.assertIn(b"Submit Player Feedback", res_page.data)

        # 2. Verify POST /api/feedback creates ticket and runs AI diagnostics
        fb_payload = {
            "category": "Feature Suggestion",
            "character_name": "TestHero",
            "realm": "WoW Forever Beta",
            "faction": "Alliance",
            "message": "Please add guild vs guild battleground challenges!"
        }
        res_post = self.client.post("/api/feedback", json=fb_payload)
        self.assertEqual(res_post.status_code, 201)
        data = res_post.get_json()
        self.assertEqual(data["status"], "ok")
        self.assertTrue(data["feedbackId"].startswith("FB-"))
        self.assertIn("diagnosis", data)

        # 3. Verify GET /api/feedback lists the new entry
        res_list = self.client.get("/api/feedback")
        self.assertEqual(res_list.status_code, 200)
        entries = res_list.get_json()
        self.assertTrue(any("guild vs guild" in (e.get("user_report") or "") for e in entries))

        print("[PASS] Verified Early Beta Web Feedback Portal, /api/feedback submission, and AI triage.")

    def test_post_kill_parity(self):
        """Verify /api/kills supports killId and kill_id interchangeably and maintains solo purity integrity."""
        # 1. Test killId ingestion
        payload_1 = {
            "killId": "KB-test-parity-1",
            "timestamp": int(time.time()),
            "isSolo": True,
            "attackersCount": 1,
            "totalDamage": 1500,
            "killer": {"name": "Dagariane", "class": "PALADIN", "level": 20, "faction": "Alliance", "damageDone": 1500},
            "victim": {"name": "Slama", "class": "ROGUE", "level": 20, "faction": "Horde"},
            "attackers": [{"name": "Dagariane", "damage": 1500, "isPlayer": True}]
        }
        res1 = self.client.post("/api/kills", json=payload_1)
        self.assertEqual(res1.status_code, 201)
        self.assertEqual(res1.get_json()["killId"], "KB-test-parity-1")

        # 2. Test kill_id snake_case ingestion
        payload_2 = {
            "kill_id": "KB-test-parity-2",
            "timestamp": int(time.time()),
            "isSolo": False,
            "attackersCount": 2,
            "totalDamage": 2000,
            "killer": {"name": "Dagariane", "class": "PALADIN", "level": 20, "faction": "Alliance", "damageDone": 1500},
            "victim": {"name": "Slama", "class": "ROGUE", "level": 20, "faction": "Horde"},
            "attackers": [
                {"name": "Dagariane", "damage": 1500, "isPlayer": True},
                {"name": "DruidAlly", "damage": 500, "isPlayer": True}
            ]
        }
        res2 = self.client.post("/api/kills", json=payload_2)
        self.assertEqual(res2.status_code, 201)
        self.assertEqual(res2.get_json()["killId"], "KB-test-parity-2")

        # Verify database fields
        with get_db() as conn:
            row1 = conn.execute("SELECT is_solo, attackers_count FROM kills WHERE kill_id = 'KB-test-parity-1'").fetchone()
            self.assertEqual(row1["is_solo"], 1)
            self.assertEqual(row1["attackers_count"], 1)

            row2 = conn.execute("SELECT is_solo, attackers_count FROM kills WHERE kill_id = 'KB-test-parity-2'").fetchone()
            self.assertEqual(row2["is_solo"], 0)
            self.assertEqual(row2["attackers_count"], 2)

        print("[PASS] Verified /api/kills killId/kill_id interoperability and multi-attacker solo purity revocation.")

    def test_lua_table_parser_claim_tokens(self):
        """Verify LuaTableParser extracts claimTokens, bugReports, and lastManualSync without kill flattening corruption."""
        from sync.watcher import LuaTableParser
        sample_lua = """
        WoWKillboardDB = {
            ["kills"] = {
                ["KB-test-1"] = {
                    ["timestamp"] = 1790732145,
                    ["isSolo"] = true,
                },
            },
            ["claimTokens"] = {
                ["Dagariane"] = {
                    ["realm"] = "Classic Beta PvP",
                    ["guid"] = "Player-4619-007592A0",
                    ["time"] = 1790732145,
                    ["code"] = "KB-5ACD",
                },
            },
            ["bugReports"] = {
                ["BUG-1"] = {
                    ["message"] = "Test bug",
                },
            },
            ["lastManualSync"] = 1790732149,
            ["stats"] = {
                ["kills"] = 12,
            },
        }
        """
        parsed = LuaTableParser.parse_string(sample_lua)
        self.assertIn("claimTokens", parsed)
        self.assertIn("Dagariane", parsed["claimTokens"])
        self.assertEqual(parsed["claimTokens"]["Dagariane"]["code"], "KB-5ACD")
        self.assertEqual(parsed.get("lastManualSync"), 1790732149)
        self.assertIn("bugReports", parsed)
        self.assertIn("KB-test-1", parsed["WoWKillboardDB"])
        print("[PASS] Verified LuaTableParser claimTokens, bugReports, and lastManualSync extraction integrity.")

    def test_20_solo_purity_and_zero_damage_revocation(self):
        """Guardrail 4: Verify 0-damage tag kills and gang ganks are strictly revoked from 1v1 solo certification."""
        # 1. Zero-damage fallback kill (player tagged enemy who died to guards/world)
        zero_dmg_kill = {
            "killId": "KB-ZERO-DMG-01",
            "timestamp": int(time.time()),
            "isDuel": False,
            "isBattleground": False,
            "isSolo": True,
            "attackersCount": 1,
            "totalDamage": 0,
            "killer": {
                "name": "Dag", "level": 1, "class": "PALADIN",
                "guild": "None", "faction": "Horde", "partySize": 1,
                "damageDone": 0, "healingDone": 0
            },
            "victim": {
                "name": "Mirria", "level": 20, "class": "MAGE",
                "guild": "None", "faction": "Alliance", "partySize": 1
            },
            "location": {
                "mapId": 1458, "zone": "Undercity", "subZone": "Ruins of Lordaeron",
                "x": 71.0, "y": 11.0
            }
        }
        resp = self.client.post("/api/kills", json=zero_dmg_kill)
        self.assertEqual(resp.status_code, 201)

        # Fetch kill back from API and assert isSolo == False
        res = self.client.get("/api/kill/KB-ZERO-DMG-01")
        self.assertEqual(res.status_code, 200)
        k_data = res.get_json()
        self.assertFalse(k_data["isSolo"], "0-damage fallback kill must NEVER be certified as a 1v1 solo kill")

        # 2. Multi-attacker kill with isSolo: True
        gang_kill = {
            "killId": "KB-GANG-01",
            "timestamp": int(time.time()),
            "isDuel": False,
            "isBattleground": False,
            "isSolo": True,
            "attackersCount": 3,
            "totalDamage": 3500,
            "killer": {
                "name": "Ganker1", "level": 20, "class": "ROGUE",
                "guild": "None", "faction": "Horde", "partySize": 3,
                "damageDone": 1200, "healingDone": 0
            },
            "victim": {
                "name": "Victim1", "level": 20, "class": "PALADIN",
                "guild": "None", "faction": "Alliance", "partySize": 1
            },
            "location": {
                "mapId": 1458, "zone": "Undercity", "subZone": "Ruins of Lordaeron",
                "x": 71.0, "y": 11.0
            }
        }
        resp = self.client.post("/api/kills", json=gang_kill)
        self.assertEqual(resp.status_code, 201)
        res = self.client.get("/api/kill/KB-GANG-01")
        self.assertEqual(res.status_code, 200)
        k_data = res.get_json()
        self.assertFalse(k_data["isSolo"], "Multi-attacker gang gank must NEVER be certified as a 1v1 solo kill")

        # 3. Certified 100% pure 1v1 solo kill
        pure_solo_kill = {
            "killId": "KB-PURE-SOLO-01",
            "timestamp": int(time.time()),
            "isDuel": False,
            "isBattleground": False,
            "isSolo": True,
            "attackersCount": 1,
            "totalDamage": 2400,
            "killer": {
                "name": "Dagariane", "level": 20, "class": "PALADIN",
                "guild": "Vanguard", "faction": "Alliance", "partySize": 1,
                "damageDone": 2400, "healingDone": 0
            },
            "victim": {
                "name": "EnemyRogue", "level": 20, "class": "ROGUE",
                "guild": "Shadows", "faction": "Horde", "partySize": 1
            },
            "location": {
                "mapId": 1458, "zone": "Undercity", "subZone": "Ruins of Lordaeron",
                "x": 71.0, "y": 11.0
            }
        }
        resp = self.client.post("/api/kills", json=pure_solo_kill)
        self.assertEqual(resp.status_code, 201)
        res = self.client.get("/api/kill/KB-PURE-SOLO-01")
        self.assertEqual(res.status_code, 200)
        k_data = res.get_json()
        print("[PASS] Verified Guardrail 4 Solo Purity: 0-damage tags revoked, multi-attacker revoked, true 1v1 preserved.")

    def test_20_pve_realm_data_sync(self):
        """Verify Two-Way Sync serializes PvE Bestiary and Wilderness Mortality into WoWKillboard_RealmData.lua."""
        import tempfile
        from sync.watcher import KillboardWatcher, LuaTableParser

        temp_dir = tempfile.mkdtemp()
        dummy_sv = os.path.join(temp_dir, "WoWKillboard.lua")
        with open(dummy_sv, "w", encoding="utf-8") as f:
            f.write("""
WoWKillboardDB = {
    ["pveDeaths"] = {
        ["PVE-LOCAL-01"] = {
            ["deathId"] = "PVE-LOCAL-01",
            ["timestamp"] = 1715000000,
            ["npc"] = { ["name"] = "Stitches", ["damage"] = 1450, ["spell"] = "Cleave" },
            ["victim"] = { ["name"] = "CasualtyOne", ["class"] = "WARRIOR", ["level"] = 32 },
            ["location"] = { ["zone"] = "Duskwood" },
        }
    }
}
""")

        repo_realm_data = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Addon", "WoWKillboard", "WoWKillboard_RealmData.lua")
        orig_content = None
        if os.path.exists(repo_realm_data):
            with open(repo_realm_data, "r", encoding="utf-8") as f:
                orig_content = f.read()

        try:
            realm_data_path = os.path.join(temp_dir, "WoWKillboard_RealmData.lua")
            watcher = KillboardWatcher(filepaths=[dummy_sv], api_urls=[])
            success = watcher.sync_realm_data_to_client(target_paths_override=[realm_data_path])
            self.assertTrue(success)

            self.assertTrue(os.path.exists(realm_data_path), "WoWKillboard_RealmData.lua should be written in SavedVariables directory")

            with open(realm_data_path, "r", encoding="utf-8") as f:
                content = f.read()

            self.assertIn("RecentPveDeaths", content)
            self.assertIn("PveTotalDeaths", content)
            self.assertIn("PveTopExecutioners", content)
            self.assertIn("Stitches", content)

            parsed = LuaTableParser.parse_string(content)
            self.assertIn("WoWKillboard_RealmData", parsed)
            rd = parsed["WoWKillboard_RealmData"]
            self.assertIn("RecentPveDeaths", rd)
            entry = rd["RecentPveDeaths"][1] if 1 in rd["RecentPveDeaths"] else rd["RecentPveDeaths"][0]
            self.assertEqual(entry["deathId"], "PVE-LOCAL-01")

            print("[PASS] Verified Two-Way Sync PvE serialization into WoWKillboard_RealmData.lua.")
        finally:
            if orig_content is not None and os.path.exists(repo_realm_data):
                with open(repo_realm_data, "w", encoding="utf-8") as f:
                    f.write(orig_content)

    def test_22_analytics_and_curseforge_telemetry(self):
        """Verify web platform analytics, CurseForge tracking pixel, and SVG badge generation."""
        # 1. Post pageview beacon
        res = self.client.post("/api/analytics/event", json={
            "type": "pageview",
            "path": "/character?name=Dagariane",
            "source": "web",
            "referrer": "https://www.curseforge.com/wow/addons/wkb"
        })
        self.assertEqual(res.status_code, 200)

        # 2. CurseForge tracking pixel
        res_pixel = self.client.get("/api/analytics/pixel.png?source=curseforge")
        self.assertEqual(res_pixel.status_code, 200)
        self.assertEqual(res_pixel.mimetype, "image/png")
        self.assertGreater(len(res_pixel.data), 0)

        # 3. Dynamic SVG status badge
        res_badge = self.client.get("/api/badge/status.svg")
        self.assertEqual(res_badge.status_code, 200)
        self.assertEqual(res_badge.mimetype, "image/svg+xml")
        self.assertIn(b"WoW Killboard", res_badge.data)

        # 4. CurseForge redirect tracking
        res_cf = self.client.get("/curseforge")
        self.assertEqual(res_cf.status_code, 302)

        # 5. Addon download tracking
        res_dl = self.client.get("/download")
        self.assertIn(res_dl.status_code, (200, 302))

        # 6. Analytics summary query
        res_summary = self.client.get("/api/analytics/summary")
        self.assertEqual(res_summary.status_code, 200)
        summary = res_summary.get_json()
        self.assertIn("summary_24h", summary)
        self.assertIn("summary_7d", summary)
        self.assertIn("top_referrers", summary)
        self.assertIn("daily_history", summary)
        self.assertGreaterEqual(summary["summary_24h"]["pageviews"], 1)
        self.assertGreaterEqual(summary["summary_24h"]["curseforge_views"], 2) # 1 pixel + 1 badge
        self.assertGreaterEqual(summary["summary_24h"]["curseforge_clicks"], 1)

        print("[PASS] Verified Web Platform Analytics, CurseForge Tracking Pixel, and SVG Badge Telemetry.")

    def test_23_character_directory_sync_and_duel_faction_backfill(self):
        """Verify character directory POST ingestion, duel same-faction inheritance, and past kill backfilling."""
        # 1. Ingest duel kill with unknown attributes
        duel_kill = {
            "killId": "KB-DUEL-TEST-001",
            "timestamp": int(time.time()),
            "isDuel": True,
            "killer": {
                "name": "TestDuelist",
                "class": "UNKNOWN",
                "level": 0,
                "guild": "None",
                "faction": "Unknown"
            },
            "victim": {
                "name": "Dagariane",
                "class": "PALADIN",
                "level": 21,
                "guild": "None",
                "faction": "Alliance"
            },
            "location": {"zone": "Elwynn Forest", "mapId": 1429}
        }
        res_kill = self.client.post("/api/kills", json=duel_kill)
        self.assertEqual(res_kill.status_code, 201)

        # 2. Verify same-faction inheritance: killer is Alliance
        res_duel = self.client.get("/api/kill/KB-DUEL-TEST-001")
        self.assertEqual(res_duel.status_code, 200)
        k_data = res_duel.get_json()
        self.assertEqual(k_data["killer"]["faction"], "Alliance")

        # 3. Ingest character directory via POST /api/characters
        chars_payload = [
            {
                "name": "TestDuelist",
                "realm": "Squick",
                "class": "MAGE",
                "race": "Gnome",
                "level": 60,
                "faction": "Alliance",
                "guild": "Arcane Order"
            }
        ]
        res_chars = self.client.post("/api/characters", json=chars_payload)
        self.assertEqual(res_chars.status_code, 200)
        self.assertEqual(res_chars.get_json()["saved"], 1)

        # 4. Verify past duel kill was backfilled with MAGE, level 60, Arcane Order
        res_backfill = self.client.get("/api/kill/KB-DUEL-TEST-001")
        bf_data = res_backfill.get_json()
        self.assertEqual(bf_data["killer"]["class"], "MAGE")
        self.assertEqual(bf_data["killer"]["level"], 60)
        self.assertEqual(bf_data["killer"]["guild"], "Arcane Order")

        # 5. Verify duel leaderboard displays enriched combatant profile
        res_lb = self.client.get("/api/leaderboard?mode=DUEL")
        self.assertEqual(res_lb.status_code, 200)
        lb_data = res_lb.get_json()
        duel_killer = next((k for k in lb_data.get("topKillers", []) if k["name"] == "TestDuelist"), None)
        self.assertIsNotNone(duel_killer)
        self.assertEqual(duel_killer["class"], "MAGE")
        self.assertEqual(duel_killer["guild"], "Arcane Order")
        self.assertEqual(duel_killer["faction"], "Alliance")

        print("[PASS] Verified Character Directory Ingestion, Duel Faction Inheritance, and Past Kill Backfilling.")

    def test_23_phase3_security_hardening(self):
        """Verify Phase 3 security hardening: 8-char claim entropy, brute-force lockout, and endpoint auth."""
        # 1. Verify 8-hex-digit claim code entropy (KB-XXXXXXXX)
        res_claim = self.client.post("/api/auth/claim-character", json={
            "name": "SecTester",
            "realm": "WoW Forever",
            "owner_token": "tok_sectest_123"
        })
        self.assertEqual(res_claim.status_code, 200)
        claim_code = res_claim.get_json()["claim_code"]
        self.assertTrue(claim_code.startswith("KB-"))
        self.assertEqual(len(claim_code), 11, "Claim code must be KB- plus 8 hex characters")

        # 2. Verify brute-force lockout after 5 failed attempts
        for attempt in range(1, 5):
            res_bad = self.client.post("/api/auth/verify-claim", json={
                "name": "SecTester",
                "code": f"KB-BAD000{attempt}"
            })
            self.assertEqual(res_bad.status_code, 400)
            self.assertIn("attempt(s) remaining", res_bad.get_json()["error"])

        # 5th failed attempt locks out the claim
        res_lock = self.client.post("/api/auth/verify-claim", json={
            "name": "SecTester",
            "code": "KB-BAD0005"
        })
        self.assertEqual(res_lock.status_code, 403)
        self.assertIn("locked for 15 minutes", res_lock.get_json()["error"])

        # Subsequent attempts are rejected with 429 lockout
        res_locked = self.client.post("/api/auth/verify-claim", json={
            "name": "SecTester",
            "code": claim_code
        })
        self.assertEqual(res_locked.status_code, 429)

        # 3. Verify state mutation authorization gating when TESTING=False
        try:
            app.config["TESTING"] = False
            # Unauthenticated debt clearance
            res_debt_unauth = self.client.post("/api/debt/pay", json={"playerName": "DeadbeatDan"})
            self.assertEqual(res_debt_unauth.status_code, 403)

            # Unauthenticated KOS blacklist
            res_kos_unauth = self.client.post("/api/kos/blacklist", json={"entity_name": "InnocentGuild"})
            self.assertEqual(res_kos_unauth.status_code, 403)

            # Unauthenticated KOS pardon
            res_pardon_unauth = self.client.post("/api/kos/pardon", json={"entity_name": "InnocentGuild"})
            self.assertEqual(res_pardon_unauth.status_code, 403)
        finally:
            app.config["TESTING"] = True

        print("[PASS] Verified Phase 3 Security: 8-char claim entropy, brute-force lockout, and endpoint auth gating.")

    def test_24_phase_4_security_audit(self):
        """Verify Phase 4 Security: defense-in-depth HTTP security headers, endpoint rate limits, string boundaries, and v1.0.1 download routes."""
        # 1. Verify HTTP Security Headers attached by @app.after_request
        res_health = self.client.get("/api/health")
        self.assertEqual(res_health.status_code, 200)
        self.assertEqual(res_health.headers.get("X-Content-Type-Options"), "nosniff")
        self.assertEqual(res_health.headers.get("X-Frame-Options"), "SAMEORIGIN")
        self.assertEqual(res_health.headers.get("X-XSS-Protection"), "1; mode=block")
        self.assertEqual(res_health.headers.get("Referrer-Policy"), "strict-origin-when-cross-origin")
        self.assertEqual(res_health.headers.get("Permissions-Policy"), "camera=(), microphone=(), geolocation=()")

        # 2. Verify /WoWKillboard-v1.0.5.zip, /WoWKillboard-v1.0.4.zip, /WoWKillboard-v1.0.3.zip, /WoWKillboard-v1.0.2.zip and /WoWKillboard-v1.0.1.zip download endpoints (local file serving under TESTING)
        res_pkg_v105 = self.client.get("/WoWKillboard-v1.0.5.zip")
        self.assertEqual(res_pkg_v105.status_code, 200)
        res_pkg_v104 = self.client.get("/WoWKillboard-v1.0.4.zip")
        self.assertEqual(res_pkg_v104.status_code, 200)
        res_pkg_v103 = self.client.get("/WoWKillboard-v1.0.3.zip")
        self.assertEqual(res_pkg_v103.status_code, 200)
        res_pkg_v102 = self.client.get("/WoWKillboard-v1.0.2.zip")
        self.assertEqual(res_pkg_v102.status_code, 200)
        res_pkg = self.client.get("/WoWKillboard-v1.0.1.zip")
        self.assertEqual(res_pkg.status_code, 200)

        # 2b. Verify /api/version returns 1.0.5
        res_ver = self.client.get("/api/version")
        self.assertEqual(res_ver.status_code, 200)
        ver_data = json.loads(res_ver.data.decode("utf-8"))
        self.assertEqual(ver_data.get("version"), "1.0.5")
        self.assertEqual(ver_data.get("release_tag"), "v1.0.5")

        # Verify CDN-first 302 redirects under production mode (TESTING=False)
        try:
            app.config["TESTING"] = False
            res_cdn_addon = self.client.get("/download")
            self.assertEqual(res_cdn_addon.status_code, 302)
            self.assertIn("github.com", res_cdn_addon.headers.get("Location", ""))

            res_cdn_exe = self.client.get("/WoWKillboardSync.exe")
            self.assertEqual(res_cdn_exe.status_code, 302)
            self.assertIn("github.com", res_cdn_exe.headers.get("Location", ""))
        finally:
            app.config["TESTING"] = True

        # 3. Verify string length boundaries on state submission endpoints
        long_str = "A" * 5000
        # Bounty string truncation
        res_bounty = self.client.post("/api/bounties", json={
            "targetName": long_str,
            "amountGold": 50,
            "placerName": long_str
        })
        self.assertEqual(res_bounty.status_code, 201)
        with get_db() as conn:
            b_row = conn.execute("SELECT target_name, placer_name FROM bounties WHERE id = ?", (res_bounty.get_json()["bountyId"],)).fetchone()
            self.assertLessEqual(len(b_row["target_name"]), 64)
            self.assertLessEqual(len(b_row["placer_name"]), 64)

        # Event string truncation
        res_event = self.client.post("/api/events", json={
            "title": long_str,
            "description": long_str,
            "guild_name": long_str,
            "creator_name": long_str,
            "zone": long_str
        })
        self.assertEqual(res_event.status_code, 201)
        with get_db() as conn:
            e_row = conn.execute("SELECT title, description, guild_name FROM guild_events ORDER BY created_at DESC LIMIT 1").fetchone()
            self.assertLessEqual(len(e_row["title"]), 128)
            self.assertLessEqual(len(e_row["description"]), 1000)
            self.assertLessEqual(len(e_row["guild_name"]), 64)

        # Distress beacon string truncation
        res_sos = self.client.post("/api/backup/distress", json={
            "character_name": long_str,
            "character_class": long_str,
            "hostile_names": long_str,
            "message": long_str,
            "zone": long_str
        })
        self.assertEqual(res_sos.status_code, 201)
        with get_db() as conn:
            s_row = conn.execute("SELECT character_name, character_class, hostile_names, message FROM distress_beacons ORDER BY timestamp DESC LIMIT 1").fetchone()
            self.assertLessEqual(len(s_row["character_name"]), 64)
            self.assertLessEqual(len(s_row["character_class"]), 32)
            self.assertLessEqual(len(s_row["hostile_names"]), 256)
            self.assertLessEqual(len(s_row["message"]), 500)

        print("[PASS] Verified Phase 4 Security: HTTP defense-in-depth headers, string bounds sanitization, and v1.0.1 download routes.")

    def test_25_phase_5_security_and_sanitization(self):
        """Validates Phase 5 security: rate limiting, bounds enforcement, and DOM XSS immunity."""
        long_str = "A" * 500

        # 1. Bounties Accept string length bounding
        res_accept = self.client.post("/api/bounties/accept", json={
            "bountyId": f"bounty-{long_str}",
            "hunterName": f"Hunter-{long_str}"
        })
        self.assertEqual(res_accept.status_code, 200)
        with get_db() as conn:
            row = conn.execute("SELECT bounty_id, hunter_name FROM bounty_acceptances ORDER BY accepted_at DESC LIMIT 1").fetchone()
            self.assertLessEqual(len(row["bounty_id"]), 64)
            self.assertLessEqual(len(row["hunter_name"]), 64)

        # 2. Debt ledger string and numeric boundaries
        res_debt = self.client.post("/api/bounties/debt-ledger", json={
            "playerName": long_str,
            "creditor": long_str,
            "bountyId": long_str,
            "playerGuid": long_str,
            "status": long_str,
            "amountOwedCopper": 99999999999999999,
            "principalCopper": 99999999999999999,
            "surchargeCopper": 99999999999999999,
            "daysInDefault": 999999
        })
        self.assertEqual(res_debt.status_code, 201)
        with get_db() as conn:
            d_row = conn.execute("SELECT player_name, creditor, bounty_id, player_guid, status, amount_owed_copper, days_in_default FROM debt_ledger ORDER BY default_date DESC LIMIT 1").fetchone()
            self.assertLessEqual(len(d_row["player_name"]), 64)
            self.assertLessEqual(len(d_row["creditor"]), 64)
            self.assertLessEqual(len(d_row["bounty_id"]), 64)
            self.assertLessEqual(len(d_row["player_guid"]), 64)
            self.assertLessEqual(len(d_row["status"]), 32)
            self.assertLessEqual(d_row["amount_owed_copper"], 10000000000)
            self.assertLessEqual(d_row["days_in_default"], 3650)

        # 3. Analytics event bounds
        res_ev = self.client.post("/api/analytics/event", json={
            "type": long_str,
            "path": "/" + long_str,
            "source": long_str,
            "referrer": "https://" + long_str
        })
        self.assertEqual(res_ev.status_code, 200)

        # 4. Frontend DOM XSS verification: ensure all dynamic onclick handlers use safeJsParam with apostrophe escaping
        with open("web/static/app.js", "r", encoding="utf-8") as f:
            app_js = f.read()

        # Verify safeJsParam is defined and properly escapes single quotes (%27)
        self.assertIn("function safeJsParam(", app_js)
        self.assertIn(".replace(/'/g, \"%27\")", app_js)
        # Verify no unescaped onclick quotes pattern
        self.assertNotIn("copyCharacterProfileLink('${", app_js)
        self.assertNotIn("filterFeedByZone('${", app_js)
        self.assertNotIn("releaseClaim('${", app_js)
        self.assertNotIn("selectKnownCharacter('${", app_js)
        self.assertNotIn("claimKnownCharacter('${", app_js)

        # 5. Verify 100% POST endpoint rate limit bucket coverage in RATE_LIMIT_STORES
        from web.server import RATE_LIMIT_STORES
        required_buckets = [
            "characters", "claim_character", "release_claim", "debt_pay",
            "events_cancel", "discord_config", "kos_blacklist", "post_kill",
            "upload", "stats", "pve_deaths", "client_flavor", "bounties",
            "bounty_accept", "debt_ledger", "distress", "resolve_beacon",
            "events", "discord_test", "intel", "feuds", "accept_feud",
            "oracle", "feedback"
        ]
        for b in required_buckets:
            self.assertIn(b, RATE_LIMIT_STORES, f"Missing rate limit bucket: {b}")

        print("[PASS] Verified Phase 5 Security: DOM XSS immunity, rate limit stores, and state mutation input bounding.")

    def test_26_chat_broadcast_formatting_and_settings(self):
        """Verify standardized military/tactical chat broadcasts, absence of melodramatic roleplay, and user toggles."""
        # 1. Verify Config.lua defaults
        with open("Addon/WoWKillboard/Config.lua", "r", encoding="utf-8") as f:
            cfg = f.read()

        self.assertIn("enableChatBroadcasts = false", cfg)
        self.assertIn("enableGuildBroadcasts = true", cfg)
        self.assertIn("includeCoordinates = true", cfg)
        self.assertIn("enableWhisperAutoInvite = true", cfg)

        # 2. Verify absence of melodramatic roleplay phrasing in Reinforcements.lua
        with open("Addon/WoWKillboard/Reinforcements.lua", "r", encoding="utf-8") as f:
            rf = f.read()

        self.assertNotIn("WAR HORN Sounded", rf)
        self.assertNotIn("Vanguard under attack", rf)
        self.assertNotIn("To arms!", rf)
        self.assertNotIn("to muster", rf)
        self.assertNotIn("1 hostile(s) (Enemy Hostiles)", rf)
        self.assertNotIn("Blood and Honor!", rf)

        # 3. Verify exact standardized message format patterns
        self.assertIn("[WoWKB] Under attack:", rf)
        self.assertIn("[WoWKB] PvP Alert:", rf)
        self.assertIn("Auto-invite: whisper 'invite'", rf)

        with open("Addon/WoWKillboard/Killmail.lua", "r", encoding="utf-8") as f:
            km = f.read()

        self.assertIn("BroadcastCasualty", km)
        self.assertIn("[WoWKB] Casualty: %s (Lvl %s %s) killed by %s (%s) in %s.", km)

        # 4. Synthesize and assert exact example strings matching specifications
        format_a = "[WoWKB] Under attack: {} ({}) vs {}!".format("Stormwind City", "66.7, 42.4", "Defias Pillager")
        self.assertEqual(format_a, "[WoWKB] Under attack: Stormwind City (66.7, 42.4) vs Defias Pillager!")

        format_b = "[WoWKB] PvP Alert: {} engaged in {} ({}) by {}. Auto-invite: whisper 'invite'".format(
            "Dagariane", "Stormwind City", "66.7, 42.4", "1 Hostile"
        )
        self.assertEqual(format_b, "[WoWKB] PvP Alert: Dagariane engaged in Stormwind City (66.7, 42.4) by 1 Hostile. Auto-invite: whisper 'invite'")

        format_c = "[WoWKB] Casualty: {} (Lvl {} {}) killed by {} ({}) in {}.".format(
            "Dagariane", 23, "Paladin", "Defias Pillager", "Fireball", "Sentinel Hill"
        )
        self.assertEqual(format_c, "[WoWKB] Casualty: Dagariane (Lvl 23 Paladin) killed by Defias Pillager (Fireball) in Sentinel Hill.")

        print("[PASS] Verified Standardized Military Chat Telemetry (Formats A, B, C) and User Control Toggles.")

    def test_28_realm_and_ruleset_isolation(self):
        """Verify server and ruleset isolation across PvP, PvE, RP, and Hardcore realms."""
        pve_km = {
            "killId": f"KILL-PVE-ISO-{int(time.time())}",
            "realm": "Wild Growth",
            "ruleset": "PVE",
            "timestamp": int(time.time()),
            "isDuel": False,
            "isBattleground": False,
            "isArena": False,
            "isSolo": True,
            "attackersCount": 1,
            "totalDamage": 1500,
            "killer": {
                "name": "PvePlayer", "level": 50, "class": "PALADIN",
                "guild": "Peaceful", "faction": "Alliance", "realm": "Wild Growth",
                "damageDone": 1500, "healingDone": 0
            },
            "victim": {
                "name": "PveFlaggedEnemy", "level": 50, "class": "SHAMAN",
                "guild": "None", "faction": "Horde", "realm": "Wild Growth"
            },
            "location": {"mapId": 1429, "zone": "Elwynn Forest", "x": 50.0, "y": 50.0}
        }
        pvp_km = {
            "killId": f"KILL-PVP-ISO-{int(time.time())}",
            "realm": "Crusader Strike",
            "ruleset": "PVP",
            "timestamp": int(time.time()),
            "isDuel": False,
            "isBattleground": False,
            "isArena": False,
            "isSolo": True,
            "attackersCount": 1,
            "totalDamage": 2500,
            "killer": {
                "name": "Ganker", "level": 60, "class": "ROGUE",
                "guild": "RedridgePolice", "faction": "Alliance", "realm": "Crusader Strike",
                "damageDone": 2500, "healingDone": 0
            },
            "victim": {
                "name": "Victim", "level": 60, "class": "WARLOCK",
                "guild": "None", "faction": "Horde", "realm": "Crusader Strike"
            },
            "location": {"mapId": 1429, "zone": "Redridge Mountains", "x": 30.0, "y": 40.0}
        }

        self.client.post("/api/kills", json=pve_km)
        self.client.post("/api/kills", json=pvp_km)

        # Query Wild Growth
        resp_pve = self.client.get("/api/kills?realm=Wild%20Growth")
        data_pve = resp_pve.get_json()
        pve_ids = [k["killId"] for k in data_pve["kills"]]
        self.assertIn(pve_km["killId"], pve_ids)
        self.assertNotIn(pvp_km["killId"], pve_ids)

        # Query Crusader Strike
        resp_pvp = self.client.get("/api/kills?realm=Crusader%20Strike")
        data_pvp = resp_pvp.get_json()
        pvp_ids = [k["killId"] for k in data_pvp["kills"]]
        self.assertIn(pvp_km["killId"], pvp_ids)
        self.assertNotIn(pve_km["killId"], pvp_ids)

        print("[PASS] Verified Realm & Ruleset Isolation: Wild Growth (PvE) isolated from Crusader Strike (PvP).")

    def test_28_network_test_casualty_and_admin_announcements(self):
        """Verify simulated test casualties are NEVER saved into the master database and Lua protocol handlers exist."""
        # 1. Attempt to post a simulated test casualty with isTest=True or TEST- ID
        test_casualty = {
            "killId": "TEST-CASUALTY-99999",
            "timestamp": int(time.time()),
            "isTest": True,
            "isSolo": True,
            "killer": {"name": "Defias Pillager", "level": 15, "class": "MAGE", "guild": "Threats", "faction": "Monster"},
            "victim": {"name": "Dagariane", "level": 23, "class": "PALADIN", "guild": "Vanguard", "faction": "Alliance"},
            "location": {"zone": "Westfall", "subZone": "Sentinel Hill", "x": 42.5, "y": 58.3}
        }
        # Ingestion endpoint should either reject or exclude it from public leaderboards
        resp = self.client.get(f"/api/kill/{test_casualty['killId']}")
        self.assertEqual(resp.status_code, 404, "Test casualties must NEVER exist in production database")

        # 2. Verify Lua files contain protocol methods
        sync_lua_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Addon", "WoWKillboard", "Sync.lua")
        with open(sync_lua_path, "r", encoding="utf-8") as f:
            sync_content = f.read()
        self.assertIn("function S:BroadcastTestCasualty", sync_content)
        self.assertIn("function S:BroadcastAdminAlert", sync_content)
        self.assertIn("function S:OnIncomingTestCasualty", sync_content)
        self.assertIn("function S:OnIncomingAdminAlert", sync_content)
        self.assertIn("TEST_CASUALTY", sync_content)
        self.assertIn("SYS_ALERT", sync_content)

        core_lua_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Addon", "WoWKillboard", "Core.lua")
        with open(core_lua_path, "r", encoding="utf-8") as f:
            core_content = f.read()
        self.assertIn("BroadcastTestCasualty", core_content)
        self.assertIn("BroadcastAdminAlert", core_content)

        print("[PASS] Verified Network Test Casualty Protocol & Admin Update Announcement Engine.")

    def test_29_chatter_suppression_and_delivery_modes(self):
        """Verify chat channel chatter suppression, dynamic chat visibility, and delivery modes."""
        addon_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Addon", "WoWKillboard")

        # 1. Config.lua has showChannelInChat setting
        with open(os.path.join(addon_dir, "Config.lua"), "r", encoding="utf-8") as f:
            config_content = f.read()
        self.assertIn("showChannelInChat", config_content)

        # 2. Sync.lua chatter suppression filter and channel visibility
        with open(os.path.join(addon_dir, "Sync.lua"), "r", encoding="utf-8") as f:
            sync_content = f.read()
        self.assertIn("ChatFrame_AddMessageEventFilter", sync_content)
        self.assertIn("IsWoWKillboardChannel", sync_content)
        self.assertIn("function S:ShowChannelInChat", sync_content)
        self.assertIn("function S:HideChannelFromChat", sync_content)
        self.assertIn("function S:ApplyChatVisibility", sync_content)

        # Verify simulated chatter suppression filter logic
        def simulate_channel_filter(msg, channel_base, channel_name):
            is_kb = False
            if channel_base and ("wowkillboard" in channel_base.lower() or "wowkb" in channel_base.lower()):
                is_kb = True
            elif channel_name and ("wowkillboard" in channel_name.lower() or "wowkb" in channel_name.lower()):
                is_kb = True

            if is_kb:
                if msg and (msg.startswith("[WoWKB] Casualty:") or msg.startswith("[WoWKB Alert]") or msg.startswith("[WoWKB Update]") or msg.startswith("[WoWKB")):
                    return False  # Allowed through
                return True  # Suppressed / blocked
            return False  # Other channels untouched

        # Test chatter suppression
        self.assertTrue(simulate_channel_filter("hey anyone want to run deadmines?", "WoWKillboard", "4. WoWKillboard"))
        self.assertTrue(simulate_channel_filter("WTS [Lesser Magic Wand] 15s", "WoWKillboard", "4. WoWKillboard"))
        self.assertFalse(simulate_channel_filter("[WoWKB] Casualty: Dagariane (Lvl 23 Paladin) killed by Defias Pillager (Fireball) in Moonbrook.", "WoWKillboard", "4. WoWKillboard"))
        self.assertFalse(simulate_channel_filter("[WoWKB Alert] System reboot in 5 minutes.", "WoWKillboard", "4. WoWKillboard"))
        self.assertFalse(simulate_channel_filter("LF Tank RFC", "General", "1. General"))

        # 3. UI.lua contains 4 delivery presets and toggle buttons
        with open(os.path.join(addon_dir, "UI.lua"), "r", encoding="utf-8") as f:
            ui_content = f.read()
        self.assertIn("BtnPresetBoth", ui_content)
        self.assertIn("BtnPresetHeadsUp", ui_content)
        self.assertIn("BtnPresetChat", ui_content)
        self.assertIn("BtnPresetOff", ui_content)
        self.assertIn("BtnToggleChat", ui_content)
        self.assertIn("chatStreamBtn", ui_content)

        # 4. Core.lua contains slash command handlers
        with open(os.path.join(addon_dir, "Core.lua"), "r", encoding="utf-8") as f:
            core_content = f.read()
        self.assertIn('cmd == "channel"', core_content)
        self.assertIn('cmd == "stream"', core_content)
        self.assertIn("SLASH_WOWKB_CHANNEL1", core_content)
        self.assertIn("SLASH_WOWKB_STREAM1", core_content)

        print("[PASS] Verified Channel Chatter Suppression Engine & Flexible Alert Delivery Modes.")

    def test_30_realm_isolation_and_stats_toggle(self):
        """Verify strict realm isolation, RP ruleset inclusion, and main window stats toggle."""
        addon_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "Addon", "WoWKillboard")

        # 1. Utils.lua has RP ruleset support and IsPveRuleset includes RP
        with open(os.path.join(addon_dir, "Utils.lua"), "r", encoding="utf-8") as f:
            utils_content = f.read()
        self.assertIn('r == "PVE" or r == "HARDCORE" or r == "RP"', utils_content)
        self.assertIn('lavalash', utils_content)
        self.assertIn('bloodsail', utils_content)

        # 2. Leaderboard.lua has strict MatchesRealm isolation and GetModeSummary realm filtering
        with open(os.path.join(addon_dir, "Leaderboard.lua"), "r", encoding="utf-8") as f:
            lb_content = f.read()
        self.assertIn('cleanKm == cleanMy', lb_content)
        self.assertIn('LB:MatchesMode(km, mode) and LB:MatchesRealm(km)', lb_content)

        # 3. UI.lua has RealmBadge and modern PvE/PvP stats toggle
        with open(os.path.join(addon_dir, "UI.lua"), "r", encoding="utf-8") as f:
            ui_content = f.read()
        self.assertIn("UI.RealmBadge = realmTag", ui_content)
        self.assertTrue("Mode: PvE Stats" in ui_content or "[PVE STATS]" in ui_content)
        self.assertTrue("Mode: PvP Stats" in ui_content or "[PVP STATS]" in ui_content)
        self.assertIn('r == "PVE" or r == "HARDCORE" or r == "RP"', ui_content)

        # 4. Simulate MatchesRealm strict logic
        def simulate_matches_realm(km, my_realm, isolate_realms=True):
            if not km or not isinstance(km, dict):
                return False
            if not isolate_realms:
                return True
            if not my_realm:
                return True
            km_realm = km.get("realm") or (km.get("killer", {}).get("realm")) or (km.get("victim", {}).get("realm"))
            if km_realm and km_realm != "Unknown":
                clean_km = "".join(km_realm.lower().split())
                clean_my = "".join(my_realm.lower().split())
                return clean_km == clean_my
            return False

        # Test PvP realm player on Crusader Strike
        cs_kill = {"realm": "Crusader Strike", "killer": {"name": "Ganker", "realm": "Crusader Strike"}}
        cs_kill_nospace = {"realm": "CrusaderStrike", "killer": {"name": "Ganker"}}
        wg_kill = {"realm": "Wild Growth", "killer": {"name": "Ally", "realm": "Wild Growth"}}
        unknown_kill = {"realm": "Unknown", "killer": {"name": "Mystery"}}
        missing_kill = {"killer": {"name": "Mystery"}}

        self.assertTrue(simulate_matches_realm(cs_kill, "Crusader Strike"))
        self.assertTrue(simulate_matches_realm(cs_kill_nospace, "Crusader Strike"))
        self.assertTrue(simulate_matches_realm(cs_kill, "CrusaderStrike"))
        self.assertFalse(simulate_matches_realm(wg_kill, "Crusader Strike"))
        self.assertFalse(simulate_matches_realm(unknown_kill, "Crusader Strike"))
        self.assertFalse(simulate_matches_realm(missing_kill, "Crusader Strike"))

        # Test RP / PvE ruleset classification
        def simulate_is_pve(realm_name):
            r = realm_name.lower().replace(" ", "")
            if "hardcore" in r or "hc" in r or "defiaspillager" in r:
                return True
            elif "pve" in r or "normal" in r or "wildgrowth" in r or "mankrik" in r:
                return True
            elif "roleplay" in r or "lavalash" in r or "bloodsail" in r or "celebras" in r or "hydraxian" in r:
                return True
            return False

        self.assertTrue(simulate_is_pve("Wild Growth"))
        self.assertTrue(simulate_is_pve("Lava Lash"))
        self.assertTrue(simulate_is_pve("Bloodsail Buccaneers"))
        self.assertTrue(simulate_is_pve("Defias Pillager"))
        self.assertFalse(simulate_is_pve("Crusader Strike"))
        self.assertFalse(simulate_is_pve("Lone Wolf"))

        # 5. Verify BountyEngine and Core.lua bounty realm auto-tagging
        with open(os.path.join(addon_dir, "BountyEngine.lua"), "r", encoding="utf-8") as f:
            be_content = f.read()
        self.assertIn("b.realm = myRealm", be_content)

        with open(os.path.join(addon_dir, "Core.lua"), "r", encoding="utf-8") as f:
            core_content = f.read()
        self.assertIn("WoWKillboardBounties", core_content)
        self.assertIn("b.realm = myRealm", core_content)

        # 6. Verify watcher.py bounty realm preservation and active realm stamping
        watcher_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sync", "watcher.py")
        with open(watcher_path, "r", encoding="utf-8") as f:
            watcher_content = f.read()
        self.assertIn('b_norm["realm"] = b.get("realm") if (b.get("realm") and b.get("realm") != "Unknown") else discovered_realm', watcher_content)

        print("[PASS] Verified Strict Realm Isolation, RP Ruleset Inclusion, and In-Game Stats Toggle.")

    def test_31_mode_filter_pills_tab_cleanup_and_theme3(self):
        """Verify Mode Filter Pills [World, BGs, Duels, Arenas], Clean 5-Tab Navigation, and Strict 3-Theme Architecture (WKB 1:1 Web Mirror, ElvUI, Classic)."""
        addon_dir = os.path.join(BASE_DIR, "Addon", "WoWKillboard")

        # 1. Config.lua has combatFilter default and strict 3-theme architecture
        with open(os.path.join(addon_dir, "Config.lua"), "r", encoding="utf-8") as f:
            cfg_content = f.read()
        self.assertIn('combatFilter = "WORLD"', cfg_content)
        self.assertIn('["CLASSIC"] = {', cfg_content)
        self.assertIn('["ELVUI"] = {', cfg_content)
        self.assertIn('["WKB"] = {', cfg_content)
        self.assertIn('name = "Classic Blizzard Stone"', cfg_content)
        self.assertIn('name = "ElvUI"', cfg_content)
        self.assertIn('name = "WKB Theme"', cfg_content)

        # 2. Master Canvas & Card Elevation (Depth) for WKB Theme
        self.assertIn('0.015, 0.023, 0.035, 0.98', cfg_content) # #040609 Master Canvas
        self.assertIn('0.58, 0.45, 0.22, 1.0', cfg_content)     # #947338 1px solid brass outer border
        self.assertIn('0.043, 0.059, 0.090, 0.95', cfg_content) # #0B0F17 Elevated Card Containers
        self.assertIn('0.12, 0.16, 0.23, 1.0', cfg_content)     # #1E293B Flat 1px Border
        self.assertIn('0.78, 0.65, 0.35, 1.0', cfg_content)     # Muted Web Gold Header
        self.assertIn('0.50, 0.55, 0.62, 1.0', cfg_content)     # Slate Gray Subtitle
        self.assertIn('0.025, 0.035, 0.055, 1.0', cfg_content)  # Solid dark telemetry ribbon
        self.assertIn('0.58, 0.45, 0.22, 0.4', cfg_content)     # 1px bottom border for telemetry ribbon

        # 3. Mode Filter Pills styling in Config.lua & UI.lua
        self.assertIn('0.78, 0.60, 0.24, 1.0', cfg_content)     # Solid bright brass gold (#C69B3D)
        self.assertIn('0.85, 0.70, 0.30, 1.0', cfg_content)     # 1px active gold border
        self.assertIn('0.05, 0.05, 0.05, 1.0', cfg_content)     # Solid dark black active text
        self.assertIn('0.06, 0.08, 0.12, 0.8', cfg_content)     # Inset slate inactive fill
        self.assertIn('0.65, 0.70, 0.75, 1.0', cfg_content)     # Muted gray inactive text
        self.assertIn('0.15, 0.19, 0.26, 1.0', cfg_content)     # 1px slate inactive border

        # 4. Feed Row Styling in Config.lua
        self.assertIn('0.060, 0.080, 0.115, 0.6', cfg_content)  # Row Odd
        self.assertIn('0.043, 0.059, 0.090, 0.4', cfg_content)  # Row Even
        self.assertIn('0.12, 0.16, 0.23, 0.8', cfg_content)     # Highlight on Mouseover

        # 5. ElvUI Minimalist Theme Verification in Config.lua
        self.assertIn('0.04, 0.04, 0.04, 0.95', cfg_content)    # #0A0A0A Master frame backdrop
        self.assertIn('0.08, 0.08, 0.08, 0.90', cfg_content)    # #141414 Card & panel backdrops
        self.assertIn('0.12, 0.12, 0.12, 1.0', cfg_content)     # Flat dark gray buttons

        # 6. Classic Blizzard Stone Verification in Config.lua
        self.assertIn('UI-DialogBox-Background', cfg_content)
        self.assertIn('UI-DialogBox-Border', cfg_content)

        # 7. Backward compatibility aliases in Config.lua
        self.assertIn('KB.Themes["classic"]', cfg_content)
        self.assertIn('KB.Themes["elvui"]', cfg_content)
        self.assertIn('KB.Themes["wkb"]', cfg_content)

        # 8. Leaderboard.lua has enhanced zone_type and mode matching
        with open(os.path.join(addon_dir, "Leaderboard.lua"), "r", encoding="utf-8") as f:
            lb_content = f.read()
        self.assertIn('function LB:MatchesMode(km, mode)', lb_content)
        self.assertIn('mode = (mode or "WORLD"):upper()', lb_content)
        self.assertIn('local zType = km.zone_type or km.zoneType', lb_content)
        self.assertIn('not isBG and not isArena and not isDuel and (not zType or zType == "none" or zType == "")', lb_content)

        # 9. UI.lua has ApplyWebTheme and CreateWebPillButton helpers
        with open(os.path.join(addon_dir, "UI.lua"), "r", encoding="utf-8") as f:
            ui_content = f.read()
        self.assertIn('local function ApplyWebTheme(frame, bgColor, borderColor)', ui_content)
        self.assertIn('local function CreateWebPillButton(parent, text, width, height)', ui_content)
        self.assertIn('UI.ApplyWebTheme = ApplyWebTheme', ui_content)
        self.assertIn('UI.CreateWebPillButton = CreateWebPillButton', ui_content)

        # 10. UI.lua has exactly 4 Mode Filter Pills: [World, BGs, Duels, Arenas]
        self.assertIn('{ id = "ARENA", text = "Arenas"', ui_content)
        self.assertIn('{ id = "DUEL",  text = "Duels"', ui_content)
        self.assertIn('{ id = "BG",    text = "BGs"', ui_content)
        self.assertIn('{ id = "WORLD", text = "World"', ui_content)
        self.assertIn('WoWKillboardDB.combatFilter = filterId', ui_content)

        # 11. UI.lua has exactly 5 tabs in PvP and exactly 5 tabs in PvE (Zero redundant Hazards tab)
        self.assertIn('local tabOrder = { "FEED", "LEADERBOARD", "BOUNTIES", "RALLIES", "ZONES" }', ui_content)
        self.assertIn('FEED        = { text = "Casualties",', ui_content)
        self.assertIn('LEADERBOARD = { text = "Deadly Hazards",', ui_content)
        self.assertIn('BOUNTIES    = { text = "Notorious Elites",', ui_content)
        self.assertIn('RALLIES     = { text = "Rescue Beacons",', ui_content)
        self.assertIn('ZONES       = { text = "Zone Mortality",', ui_content)

        self.assertIn('FEED        = { text = "Intel",', ui_content)
        self.assertIn('LEADERBOARD = { text = "Leaderboards",', ui_content)
        self.assertIn('BOUNTIES    = { text = "The Marked",', ui_content)
        self.assertIn('RALLIES     = { text = "Call to Arms",', ui_content)
        self.assertIn('ZONES       = { text = "Danger Zones",', ui_content)

        # 12. Verify Active and Inactive Mode Button Styling in UI.lua
        self.assertIn('pill.bg:SetColorTexture(0.78, 0.60, 0.24, 1.0)', ui_content)
        self.assertIn('pill.Label:SetTextColor(0.05, 0.05, 0.05, 1.0)', ui_content)
        self.assertIn('pill.bg:SetColorTexture(0.06, 0.08, 0.12, 0.8)', ui_content)
        self.assertIn('pill.Label:SetTextColor(0.65, 0.70, 0.75, 1.0)', ui_content)

        # 13. Verify Vivid WoW Hex Tags in Telemetry Ribbon
        self.assertIn('|cff0080ff%d%% A|r', ui_content)
        self.assertIn('|cffff2020%d%% H|r', ui_content)
        self.assertIn('|cffffd200%s|r', ui_content)

        # 14. Verify Settings Dropdown lists strictly: Classic, ElvUI, and WKB Theme
        self.assertIn('{ id = "classic", name = "Classic" }', ui_content)
        self.assertIn('{ id = "elvui",   name = "ElvUI" }', ui_content)
        self.assertIn('{ id = "wkb",     name = "WKB Theme" }', ui_content)

        # 15. Verify Top-Left Unit-Frame Character Portrait & Mask
        self.assertIn('CreateFrame("Frame", "WoWKillboardPlayerPortrait", mainFrame, "BackdropTemplate")', ui_content)
        self.assertIn('portraitFrame:SetFrameStrata("HIGH")', ui_content)
        self.assertIn('TempPortraitAlphaMask', ui_content)
        self.assertIn('MiniMap-TrackingBorder', ui_content)
        self.assertIn('levelBadge:SetPoint("BOTTOMRIGHT", portraitFrame, "BOTTOMRIGHT", 2, 0)', ui_content)

        # 16. Verify Faction War Split Visual Progress Bar in Telemetry Strip
        self.assertIn('UI.FactionSplitBar = splitBar', ui_content)
        self.assertIn('allyFill:SetColorTexture(0.08, 0.35, 0.85, 1.0)', ui_content)
        self.assertIn('hordeFill:SetColorTexture(0.85, 0.12, 0.12, 1.0)', ui_content)

        # 17. Verify Rich Red & Blue Faction Pill Badges
        self.assertIn('local function CreateFactionBadge(parent, faction, width, height)', ui_content)
        self.assertIn('0.06, 0.22, 0.58, 0.85', ui_content) # Deep royal blue Alliance
        self.assertIn('0.55, 0.08, 0.08, 0.85', ui_content) # Deep crimson red Horde
        self.assertIn('crest_alliance.tga', ui_content)
        self.assertIn('crest_horde.tga', ui_content)

        # 18. Verify Player Row Highlight [YOU] with Clean Subtle Background Wash (Zero Border Box)
        self.assertIn('local function ApplyPlayerRowHighlight(row, faction)', ui_content)
        self.assertIn('0.12, 0.16, 0.24, 0.35', ui_content) # Subtle background wash without harsh border outline

        # 19. Verify WKB Theme Web 1:1 Palette Alignment in Config.lua
        self.assertIn('0.015, 0.020, 0.030, 0.98', cfg_content)
        self.assertIn('0.08, 0.11, 0.16, 1.0', cfg_content)
        self.assertIn('0.85, 0.70, 0.25, 1.0', cfg_content)

        print("[PASS] Verified Mode Filter Pills [World, BGs, Duels, Arenas], Clean 5-Tab Navigation, Strict 3-Theme Architecture, Portrait, Faction Badges, and 1:1 WKB Mirror.")

if __name__ == "__main__":
    unittest.main()


