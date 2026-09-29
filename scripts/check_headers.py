import urllib.request

req = urllib.request.Request('http://13.216.102.148/', headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as resp:
    print('HEADERS:')
    for k, v in resp.headers.items():
        print(f'  {k}: {v}')
