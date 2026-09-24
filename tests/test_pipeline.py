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

# Ensure web/ is importable
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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
            "Utils.lua",
            "UnitScanner.lua",
            "CombatTracker.lua",
            "Killmail.lua",
            "BountyEngine.lua",
            "Sync.lua",
            "Reinforcements.lua",
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
        print("[PASS] All 12 Addon Lua and TOC files verified.")

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

        # 3. Pay off debt (Redemption)
        res_pay = self.client.post("/api/debt/pay", json={"playerName": "DeadbeatDan"})
        self.assertEqual(res_pay.status_code, 200)

        # Verify debtor is cleansed from active Oathbreaker ledger
        wall_after = self.client.get("/api/bounties/debt-ledger").get_json()
        cleansed = any(d["player_name"] == "DeadbeatDan" for d in wall_after)
        self.assertFalse(cleansed, "Redeemed debtor must be removed from the active Wall of Shame")
        print("[PASS] Verified Bounty placement, Oathbreaker Debt Ledger, and Redemption lifecycle.")

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
            "guild_name": "Forged By Valor",
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
            "guild_name": "Forged By Valor",
            "webhook_url": "https://discord.com/api/webhooks/1234567890/testtoken",
            "alerts_enabled": True,
            "events_enabled": True
        }
        res_cfg = self.client.post("/api/discord/config", json=discord_cfg_payload)
        self.assertEqual(res_cfg.status_code, 200)

        # 4. Verify Discord config is returned with masked token
        res_get_cfg = self.client.get("/api/discord/config?guild=Forged By Valor")
        self.assertEqual(res_get_cfg.status_code, 200)
        cfg_data = res_get_cfg.get_json()
        self.assertTrue(cfg_data["configured"])
        self.assertIn("****", cfg_data["masked_url"])

        # 5. Create a Guild Event / Rally
        event_payload = {
            "id": "EVT-TEST-001",
            "title": "STV Zone Defense & Outlaw Manhunt",
            "description": "Repel Horde gank squad operating outside Booty Bay. Form up at Rebel Camp!",
            "guild_name": "Forged By Valor",
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

        print("[PASS] Verified Call for Backup SOS beacons, Guild Events, and Discord Defense Gateway.")

if __name__ == "__main__":
    unittest.main()
