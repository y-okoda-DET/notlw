"""段階2: check stills of the whole house at its six times, from fixed places (the same places at every time, so the
sheets show the one house changing). python3 house_shots.py [times] [views] — e.g. `t23,t0330 hall,cellar`.
PCK=... shoots the exported pack (what the user gets); PRINT=0 for the print off; RES=960x540.
Writes $WORK/house/<time>_<view>.png, a sheet per time ($WORK/house/sheet_<time>.png) and one per view across the
times ($WORK/house/times_<view>.png)."""
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', 'blender')); import paths as P
import sys, math, subprocess, os
from PIL import Image, ImageDraw, ImageFont

TIMES = ['dusk', 't20', 't23', 't02', 't0330', 't0430']
LABEL = {'dusk': '17:30 夕方', 't20': '20:00 停電', 't23': '23:00', 't02': '2:00', 't0330': '3:30', 't0430': '4:30 夜明け'}
OX, YF = 4.8, 6.3
def B(x, y): return (x - OX, YF - y)        # plan -> Blender
F2, ZB = 2.75, -2.45
# name: (camera plan x, y, eye z (absolute), look-at plan x, y, z, label)
VIEWS = {
    'hall':    (4.25, 2.0, 1.55, 5.9, 4.6, 1.3, '廊下（玄関側から階段と奥へ斜めに）'),
    'genkan':  (5.2, 2.2, 1.45, 4.4, 0.1, 1.1, '上がり框から玄関と細い窓'),
    'living':  (3.75, 3.45, 1.5, .4, .6, 1.0, '居間（戸口から窓へ）'),
    'kitchen': (6.3, 4.6, 1.5, 9.6, 7.6, 1.0, '台所（勝手口と流し）'),
    'study':   (7.25, 1.65, 1.4, 7.2, .3, .7, '書斎のガラス棚（キツネとキジ）'),
    'lwall':   (1.0, 2.3, 1.5, 4.0, 2.3, 1.35, '居間の東の壁（外した額の跡と新聞の束）'),
    'counter': (7.6, 5.6, 1.5, 7.6, 3.8, 1.0, '台所の調理台（やかん、湯のみ、酒）'),
    'kwall':   (7.6, 5.4, 1.5, 6.0, 5.6, 1.45, '台所の西の壁（カレンダーと止まった時計）'),
    'desk':    (8.9, 1.8, 1.25, 9.55, 1.7, .38, '書斎の机（帳面、老眼鏡、灰皿）'),
    'kcal':    (6.75, 5.75, 1.5, 6.0, 5.78, 1.42, '台所のカレンダー（近くから）'),
    'vest':    (5.1, 1.75, 1.5, 4.0, 1.62, 1.3, '廊下の西の壁のフック（ベストと帽子）'),
    'photo':   (5.0, 5.15, 1.55, 4.0, 5.275, 1.5, '廊下の額（猟仲間の写真）'),
    'hide':    (3.3, 2.5, 1.6, 1.6, 3.6, .1, '居間のストーブの前の毛皮'),
    'blanket': (7.6, 2.4, 1.4, 6.4, 3.2, .2, '書斎の隅の毛布と、机の前の座布団'),
    'zabuton': (8.2, .9, 1.35, 9.0, 1.85, .05, '書斎の机の前の座布団'),
    'stair':   (4.45, 7.6, F2 + 1.5, 5.2, .2, F2 + .9, '二階の踊り場から南の窓と吹抜け'),
    'bedroom': (6.35, 2.9, F2 + 1.5, 9.8, .3, F2 + .6, '寝室3（真琴）'),
    'cellar':  (6.0, 2.0, ZB + 1.5, 9.3, 6.3, ZB + .5, '地下（階段の下から発電機へ）'),
    'bed1':    (3.55, 2.7, F2 + 1.5, .6, 1.2, F2 + .5, '寝室1（澪と夏希。夏希のベッドとバッグ）'),
    'bed1w':   (3.0, 1.0, F2 + 1.5, .3, 3.0, F2 + .7, '寝室1（西の窓のカーテンと、澪のベッド）'),
    'bed2':    (3.55, 7.2, F2 + 1.5, .8, 5.6, F2 + .5, '寝室2（桐生と大河）'),
    'supply':  (3.5, 5.6, F2 + 1.45, 2.6, 6.4, F2 + .25, '寝室2のロケ隊の備品（コンロ、カップ麺、水）'),
    'bed3b':   (7.0, 1.0, F2 + 1.5, 9.6, 3.4, F2 + .5, '寝室3（真琴の上着と椅子、レフ板）'),
    'landing2':(4.6, 6.1, F2 + 1.55, 5.5, 7.9, F2 + .3, '二階の踊り場（飲み水とごみ袋）'),
    'csleep':  (5.75, 1.3, ZB + 1.55, 4.55, 2.5, ZB + .1, '地下の閂の扉のそば（大河が寝かされる寝袋）'),
    'cshelf':  (7.4, 3.3, ZB + 1.5, 7.4, 1.3, ZB + .8, '地下の南の棚（持ち主の物）'),
    'gen':     (8.3, 5.4, ZB + 1.35, 9.5, 6.3, ZB + .35, '地下の発電機（近く。持ち主のテープ）'),
    'cnw':     (8.6, 6.75, ZB + 1.55, 4.3, 6.2, ZB + .4, '地下の北西（冬タイヤ、脚立）'),
}

def pose(v):
    cx, cy, cz, lx, ly, lz, _ = VIEWS[v]
    bx, by = B(cx, cy); tx, ty = B(lx, ly)
    gx, gz = bx, -by; tgx, tgz = tx, -ty
    yaw = math.degrees(math.atan2(-(tgx - gx), -(tgz - gz)))
    pitch = math.degrees(math.atan2(lz - cz, math.hypot(tgx - gx, tgz - gz)))
    return f'{gx:.3f},{gz:.3f},{yaw:.1f},{pitch:.1f},{cz:.3f},2.0'

def main():
    ts = sys.argv[1].split(',') if len(sys.argv) > 1 and sys.argv[1] != 'all' else TIMES
    vs = sys.argv[2].split(',') if len(sys.argv) > 2 else list(VIEWS)
    G = P.GODOT; src = os.environ.get('PCK')
    base = f"--main-pack {src}" if src else f"--path {P.RULES}"
    RES = os.environ.get('RES', '960x540'); RW, RH = map(int, RES.split('x'))
    OUT = f'{P.WORK}/house'; os.makedirs(OUT, exist_ok=True)
    pr = os.environ.get('PRINT', '1')
    for t in ts:
        tmp = f'{OUT}/tmp_{t}_'
        for f in os.listdir(OUT):
            if f.startswith(f'tmp_{t}_'): os.remove(f'{OUT}/{f}')
        shots = ';'.join(pose(v) for v in vs)
        n = 12 * len(vs)
        cmd = (f'cd /tmp && timeout {240 + 40 * len(vs)} xvfb-run -a -s "-screen 0 {RES}x24" {G} {base} --windowed --resolution {RES} '
               f'--write-movie {tmp}.png --fixed-fps 24 --quit-after {n} -- --record=poses --nocard --scene=house --time={t} '
               f'--gi={os.environ.get("GI", "baked")} --print={pr} {os.environ.get("GARGS", "")} "--shots={shots}"')
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if 'SHOTS' not in r.stdout: print(r.stdout[-3000:], r.stderr[-3000:])
        for i, v in enumerate(vs):
            p = f'{tmp}{i * 12 + 10:08d}.png'
            if os.path.exists(p): Image.open(p).convert('RGB').save(f'{OUT}/{t}_{v}.png')
            else: print('MISSING', t, v)
        for f in os.listdir(OUT):
            if f.startswith(f'tmp_{t}_'): os.remove(f'{OUT}/{f}')
        print('shot', t, flush=True)
    font = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc', 22)
    def sheet(cells, cols, path):
        w, h = RW // 2, RH // 2
        rows = (len(cells) + cols - 1) // cols
        S = Image.new('RGB', (cols * w, rows * (h + 30)), (240, 236, 226)); d = ImageDraw.Draw(S)
        for k, (f, cap) in enumerate(cells):
            x, y = (k % cols) * w, (k // cols) * (h + 30)
            if os.path.exists(f): S.paste(Image.open(f).resize((w, h)), (x, y + 30))
            d.text((x + 8, y + 3), cap, fill=(0, 40, 90), font=font)
        S.save(path)
    for t in ts:
        sheet([(f'{OUT}/{t}_{v}.png', VIEWS[v][6]) for v in vs], 2, f'{OUT}/sheet_{t}.png')
    for v in vs:
        sheet([(f'{OUT}/{t}_{v}.png', LABEL[t]) for t in ts], 3 if len(ts) > 2 else len(ts), f'{OUT}/times_{v}.png')
    print('HOUSE_SHOTS_DONE')

if __name__ == '__main__':
    main()
