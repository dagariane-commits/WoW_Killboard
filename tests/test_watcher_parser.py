#!/usr/bin/env python3
"""
Test LuaTableParser with realistic SavedVariables file syntax.
"""
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(BASE_DIR, "sync"))

from watcher import LuaTableParser

sample_lua = """
WoWKillboardDB = {
    ["kills"] = {
        ["KB-a1b2c3d4"] = {
            ["killId"] = "KB-a1b2c3d4",
            ["timestamp"] = 1774384000,
            ["isSolo"] = true,
            ["isBattleground"] = false,
            ["attackersCount"] = 1,
            ["totalDamage"] = 3850,
            ["name"] = "Viper",
            ["level"] = 60,
            ["class"] = "ROGUE",
            ["guild"] = "Shadowstep",
            ["faction"] = "Horde",
            ["victim_name"] = "Lightbringer",
            ["victim_level"] = 60,
            ["victim_class"] = "PALADIN",
            ["victim_guild"] = "Crusaders",
            ["victim_faction"] = "Alliance",
            ["zone"] = "Stranglethorn Vale",
            ["x"] = 42.5,
            ["y"] = 18.2,
        },
    },
    ["stats"] = {
        ["duels"] = { ["wins"] = 5, ["losses"] = 2 },
        ["bgs"] = { ["wins"] = 10, ["losses"] = 3 },
        ["arenas"] = { ["wins"] = 4, ["losses"] = 1 },
    },
}

WoWKillboardBounties = {
    ["BNT-998877"] = {
        ["id"] = "BNT-998877",
        ["targetName"] = "Lightbringer",
        ["targetClass"] = "PALADIN",
        ["amountCopper"] = 10000000,
        ["amountGold"] = 1000,
        ["placerName"] = "Viper",
        ["status"] = "ACTIVE",
    },
}

WoWKillboardDebtLedger = {
    ["DeadbeatJoe"] = {
        ["playerName"] = "DeadbeatJoe",
        ["creditor"] = "Viper",
        ["amountOwedCopper"] = 11000000,
        ["status"] = "OATHBREAKER",
        ["daysInDefault"] = 3,
    },
}
"""

def test_parser():
    parsed = LuaTableParser.parse_string(sample_lua)
    assert "WoWKillboardDB" in parsed
    kills = parsed["WoWKillboardDB"]
    assert "KB-a1b2c3d4" in kills
    k = kills["KB-a1b2c3d4"]
    assert k["name"] == "Viper"
    assert k["level"] == 60
    assert k["isSolo"] is True
    assert k["x"] == 42.5

    bounties = parsed.get("WoWKillboardBounties", {})
    assert "BNT-998877" in bounties
    assert bounties["BNT-998877"]["amountGold"] == 1000

    debts = parsed.get("WoWKillboardDebtLedger", {})
    assert "DeadbeatJoe" in debts
    assert debts["DeadbeatJoe"]["daysInDefault"] == 3

    stats = parsed.get("stats", {})
    assert stats.get("duels", {}).get("wins") == 5
    assert stats.get("bgs", {}).get("losses") == 3
    assert stats.get("arenas", {}).get("wins") == 4

    print("[PASS] LuaTableParser correctly parsed realistic WoW SavedVariables syntax.")

if __name__ == "__main__":
    test_parser()
