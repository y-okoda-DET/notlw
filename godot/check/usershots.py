"""ユーザーの F12 の画を、その名前から同じ位置・向き・時刻で撮り直す（直す前と後を並べるため）。
    python3 godot/check/usershots.py <pck> <出力フォルダ> <F12 の画の名前> [<名前> ...]
名前の例：shot_house-t20_x0.69_z-0.27_yaw718_pitch-43_t388.4_y-0.00(.png)
場面と時刻は名前から（house-t20 → --scene=house --time=t20、第2章の20時なら人もいる：--ch2）。GARGS= でゲームの引数を足す。
OV=1 で、pck の上にいまのリポジトリのスクリプトを重ねる（書き出す前の確認。godot/check/overlay.sh）。
pck の横に RULES_house.pck があれば読む。出力：<出力フォルダ>/<名前>.png（刷りあり、1920x1080 の半分）"""
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..', 'blender')); import paths as P
import sys, re, os, subprocess, glob

pck, out = sys.argv[1], sys.argv[2]; names = [os.path.basename(n).replace('.png', '') for n in sys.argv[3:]]
os.makedirs(out, exist_ok=True)
RES = os.environ.get('RES', '960x540')
hp = os.path.join(os.path.dirname(pck), 'RULES_house.pck')
hp = f'--housepack={hp}' if os.path.exists(hp) else ''
if os.environ.get('OV'):
    subprocess.run(['bash', f'{P.RULES}/check/overlay.sh'], capture_output=True)
    base, ua = f'--path {P.WORK}/overlay', f'--basepack={pck}'
else:
    base, ua = f'--main-pack {pck}', ''
groups = {}
for n in names:
    m = re.match(r'shot_([a-z]+)(?:-([a-z0-9]+))?_x(-?[\d.]+)_z(-?[\d.]+)_yaw(-?[\d.]+)_pitch(-?[\d.]+)_t([\d.]+)(?:_y(-?[\d.]+))?', n)
    if not m: print('名前が読めない', n); continue
    sc, tm, x, z, yaw, pitch, t, y = m.groups()
    groups.setdefault((sc, tm), []).append((n, f'{x},{z},{float(yaw) % 360:.1f},{pitch},1.52,{t},{y or 0}'))
for (sc, tm), shots in groups.items():
    o = f'{P.WORK}/usershots/{sc}_{tm}_'; os.makedirs(os.path.dirname(o), exist_ok=True)
    for f in glob.glob(o + '*'): os.remove(f)
    extra = f'--scene={sc}' + (f' --time={tm} --ch2' if tm else '')
    cmd = (f'cd /tmp && timeout 1500 xvfb-run -a -s "-screen 0 {RES}x24" {P.GODOT} {base} --windowed --resolution {RES} '
           f'--write-movie {o}.png --fixed-fps 24 --quit-after {12 * len(shots) + 40} -- {ua} {hp} --record=poses --nocard '
           f'--gi=baked --print=1 {extra} {os.environ.get("GARGS", "")} "--shots={";".join(s for _, s in shots)}"')
    r = subprocess.run(cmd, shell=True, capture_output=True)
    so = r.stdout.decode(errors='replace')
    if 'SHOTS ' not in so: print('撮れなかった', sc, tm, so[-800:], r.stderr.decode(errors='replace')[-800:])
    for i, (n, _) in enumerate(shots):
        f = f'{o}{i * 12 + 10:08d}.png'
        if os.path.exists(f): os.replace(f, f'{out}/{n}.png'); print('OK', f'{out}/{n}.png')
        else: print('なし', n)
