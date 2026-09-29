import urllib.request

endpoints = ['/', '/api/health', '/api/kills', '/api/leaderboard', '/api/bounties', '/api/stats']
for ep in endpoints:
    url = 'http://13.216.102.148' + ep
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        res = urllib.request.urlopen(req)
        print(f'{ep} -> HTTP {res.status} ({len(res.read())} bytes)')
    except Exception as e:
        print(f'{ep} -> {e}')
