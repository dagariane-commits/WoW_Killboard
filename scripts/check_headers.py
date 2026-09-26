import urllib.request

req = urllib.request.Request('https://wow-killboard.onrender.com/', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as resp:
    print('HEADERS:')
    for k, v in resp.headers.items():
        print(f'  {k}: {v}')
