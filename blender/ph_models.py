"""Poly Haven models (CC0, ユーザー許可 2026-11-04) into assets/phm/<id>/ as 1k glTF.
python3 blender/ph_models.py rubber_boots hatchet ...   (already there: skipped)"""
import sys, os, json, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import paths as P
OUT = f'{P.ASSETS}/phm'

def get(url, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'rules-build'}), timeout=60) as r: open(path, 'wb').write(r.read())

def fetch(a, res='1k'):
    d = f'{OUT}/{a}'
    if os.path.exists(f'{d}/{a}.gltf'): return
    with urllib.request.urlopen(urllib.request.Request(f'https://api.polyhaven.com/files/{a}', headers={'User-Agent': 'rules-build'}), timeout=60) as r: j = json.load(r)
    g = j['gltf'][res]['gltf']
    get(g['url'], f'{d}/{a}.gltf')
    for rel, inc in g['include'].items():
        if 'dirty' in rel: continue   # the alternative dirty set: not used
        get(inc['url'], f'{d}/{rel}')
    print('PHM', a, flush=True)

if __name__ == '__main__':
    for a in sys.argv[1:]: fetch(a)
