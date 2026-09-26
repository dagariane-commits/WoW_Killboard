import urllib.request
import json

req = urllib.request.Request('http://127.0.0.1:8080/api/leaderboard?mode=ALL')
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    print('topKillers count:', len(data.get('topKillers', [])))
    print('Keys in data:', list(data.keys()))
    if data.get('topKillers'):
        print('First killer:', data['topKillers'][0])

bnt_req = urllib.request.Request('http://127.0.0.1:8080/api/bounties')
with urllib.request.urlopen(bnt_req) as resp:
    bnts = json.loads(resp.read().decode())
    print('Bounties count:', len(bnts))
