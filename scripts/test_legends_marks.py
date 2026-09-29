import urllib.request
import urllib.error
import json

targets = [
    "http://127.0.0.1:8080",
    "http://13.216.102.148"
]

routes = [
    "/api/leaderboard?mode=ALL",
    "/api/guilds?mode=ALL",
    "/api/bounties",
    "/api/bounties/debt-ledger",
    "/api/bounties/leaderboards",
    "/api/stats"
]

for base in targets:
    print(f"\n=== Testing {base} ===")
    for route in routes:
        url = f"{base}{route}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "WoWKillboardTest/1.0"})
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = resp.read()
                print(f"  [PASS] {route}: HTTP {resp.status} (Length: {len(data)})")
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="ignore")[:100]
            print(f"  [FAIL] {route}: HTTP {e.code} -> {body}")
        except Exception as ex:
            print(f"  [ERROR] {route}: {ex}")
