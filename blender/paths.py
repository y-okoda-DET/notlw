"""All paths in one place. The repo-internal ones follow from where this file is; the ones that change per machine
(WORK, BUILD, GODOT) come from paths.env at the repo root, then paths.local.env (not in git), then the environment.
Use:  import paths as P  ->  P.KF, P.RULES, P.TRIPO, P.ASSETS, P.PLAN, P.WORK, P.BUILD, P.GODOT
From tripo/ or godot/:  sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'blender'))"""
import os
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KF = f'{REPO}/blender'; RULES = f'{REPO}/godot'; TRIPO = f'{REPO}/tripo'; ASSETS = f'{REPO}/assets'; PLAN = f'{REPO}/plan'
_v = {}
for _f in ('paths.env', 'paths.local.env'):
    _p = os.path.join(REPO, _f)
    if os.path.exists(_p):
        for _l in open(_p, encoding='utf-8'):
            _l = _l.strip()
            if _l and not _l.startswith('#') and '=' in _l:
                k, v = _l.split('=', 1); _v[k.strip()] = v.strip()
for k in ('WORK', 'BUILD', 'GODOT'):
    if os.environ.get(k): _v[k] = os.environ[k]
WORK = _v['WORK']; BUILD = _v['BUILD']; GODOT = _v['GODOT']
if __name__ == '__main__':   # python3 blender/paths.py : print them (bash reads this too)
    for k in ('REPO', 'KF', 'RULES', 'TRIPO', 'ASSETS', 'PLAN', 'WORK', 'BUILD', 'GODOT'): print(f'{k}={globals()[k]}')
