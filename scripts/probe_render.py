import urllib.request

endpoints = ['/', '/api/health', '/api/kills', '/api/leaderboard', '/api/bounties', '/api/stats']
for ep in endpoints:
    url = 'https://wow-killboard.onrender.com' + ep
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        res = urllib.request.urlopen(req)
        print(f'{ep} -> HTTP {res.status} ({len(res.read())} bytes)')
    except Exception as e:
        print(f'{ep} -> {e}')
