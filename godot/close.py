"""Close-up check stills: python3 close.py <scene> <name> <bx,by,bz> <dist> <az1,az2,..> <t1,t2,t3> [dh] [light]
target in Blender coords; camera `dist` away at each azimuth (deg; 0 = from the south / -y side), `dh` above the
target looking at it. Each (view, moment) is 12 frames started at that loop time; the whole sheet is one start of
the game (ONESHOT=1: one start per still, the old way). RES=480x270 for the fast check.
`light` > 0 adds a check light at the camera (pexp stays 3.0) so hands can be read in the dark scene."""
import os as _os, sys as _sys; _sys.path.insert(0, _os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', 'blender')); import paths as P   # all paths: paths.env
import sys, math, subprocess, os
from PIL import Image, ImageDraw
scene, name = sys.argv[1], sys.argv[2]
bx, by, bz = map(float, sys.argv[3].split(',')); dist = float(sys.argv[4])
azs = [float(a) for a in sys.argv[5].split(',')]; ts = [float(t) for t in sys.argv[6].split(',')]
dh = float(sys.argv[7]) if len(sys.argv) > 7 else 0.0
light = float(sys.argv[8]) if len(sys.argv) > 8 else 0.0
G = P.GODOT
src = os.environ.get('PCK')
base = f"--main-pack {src}" if src else f"--path {P.RULES}"
S = f'{P.WORK}/close'; os.makedirs(S, exist_ok=True)
tx, tz = bx, -by
shots = []
for ai, az in enumerate(azs):
    a = math.radians(az); cx = tx + math.sin(a) * dist; cz = tz + math.cos(a) * dist
    yaw = math.degrees(math.atan2(-(tx - cx), -(tz - cz))); pitch = -math.degrees(math.atan2(dh, dist))
    for t in ts: shots.append((ai, az, t, f'{cx:.3f},{cz:.3f},{yaw:.1f},{pitch:.1f},{bz + dh:.3f}'))
args = (f'--scene={scene} --gi=baked --pexp={os.environ.get("PEXP", 3.0 if light == 0 else 1.0)} '
        f'--print={os.environ.get("PRINT", "0")} --chklight={light} {os.environ.get("GARGS", "")}')   # GARGS: more game options
RES = os.environ.get('RES', '960x540'); RW, RH = map(int, RES.split('x'))   # RES=480x270: the fast check (shape only)
def godot(out, frames, user):
    return subprocess.run(f'cd /tmp && timeout {120 + 30 * frames // 12} xvfb-run -a -s "-screen 0 {RES}x24" {G} {base} --windowed --resolution {RES} '
                   f'--write-movie {out}.png --fixed-fps 24 --quit-after {frames} -- --record=poses --nocard {args} {user}', shell=True, capture_output=True)
def frame(p):
    return Image.open(p).convert('RGB') if os.path.exists(p) else Image.new('RGB', (RW, RH))
# The same pck (same file, size and time) shot from the same place with the same settings gives the same sheet: reuse
# it (the "before" sheets of check.sh are the same on every round). CLOSE_CACHE=0 to always shoot.
import hashlib, shutil
key = None
if src and os.path.exists(src) and os.environ.get('CLOSE_CACHE', '1') != '0':
    st_ = os.stat(src)
    key = hashlib.sha256(repr((os.path.abspath(src), st_.st_size, st_.st_mtime_ns, sys.argv[1:], args, RES, bool(os.environ.get('ONESHOT')))).encode()).hexdigest()[:24]
    hit = f'{P.WORK}/cache/close/{key}.png'
    if os.path.exists(hit):
        shutil.copyfile(hit, f'{P.WORK}/close_{name}.png'); print('OK', f'{P.WORK}/close_{name}.png', '(cache)'); sys.exit(0)
for f in os.listdir(S):
    if f.startswith(f'{name}_'): os.remove(f'{S}/{f}')
if not os.environ.get('ONESHOT'):   # one start for the whole sheet (main.gd _shot_tick gives each still the frames a fresh start would)
    out = f'{S}/{name}_all_'
    r = godot(out, 12 * len(shots), '"--shots=' + ';'.join(f'{pose},{t}' for _, _, t, pose in shots) + '"')
    so = r.stdout.decode(errors='replace')
    if 'SHOTS ' in so:
        ims = [frame(f'{out}{i * 12 + 10:08d}.png') for i in range(len(shots))]
        # A wall pushed the camera (the player) and it is still moving (falling back) on the kept frame: that motion
        # depends on how the physics steps fall between frames, which differs from a fresh start. Those stills are
        # shot the old way, one start each. Once it has come to rest the still is the same however the steps fell.
        pos = {int(l.split()[1]): tuple(map(float, l.split()[2:7])) for l in so.splitlines() if l.startswith('SHOTPOS ')}
        for i in range(len(shots)):
            p = pos.get(i)
            if p is None or p[3] < .5 or p[4] > .0005: ims[i] = None
        if any(im is None for im in ims): print('pushed by a wall, shot one by one:', [i for i, im in enumerate(ims) if im is None], flush=True)
    else:
        print('older pck (no --shots): one start per still', flush=True); ims = [None] * len(shots)
else: ims = [None] * len(shots)   # ONESHOT=1, or a pck from before 2026-10-31: one start of the game per still
for i, (ai, az, t, pose) in enumerate(shots):
    if ims[i] is None:
        out = f'{S}/{name}_{ai}_{t}_'
        godot(out, 12, f'--hold=99 --at={t} "--poses={pose}"'); ims[i] = frame(f'{out}00000010.png')
tiles = []
for (ai, az, t, pose), im in zip(shots, ims):
    ImageDraw.Draw(im).text((8, 8), f'{name} az{az:.0f} t{t}', fill=(255, 255, 0)); tiles.append(im)
cols = len(ts); rows = len(azs)
o = Image.new('RGB', (RW * cols, RH * rows))
for i, im in enumerate(tiles): o.paste(im, ((i % cols) * RW, (i // cols) * RH))
o.save(f'{P.WORK}/close_{name}.png'); print('OK', f'{P.WORK}/close_{name}.png')
if key:
    os.makedirs(f'{P.WORK}/cache/close', exist_ok=True); shutil.copyfile(f'{P.WORK}/close_{name}.png', f'{P.WORK}/cache/close/{key}.png')
