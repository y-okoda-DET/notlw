"""Close-up check stills: python3 close.py <scene> <name> <bx,by,bz> <dist> <az1,az2,..> <t1,t2,t3> [dh] [light]
target in Blender coords; camera `dist` away at each azimuth (deg; 0 = from the south / -y side), `dh` above the
target looking at it. Each (view, moment) is a 12-frame run started at that loop time, so a sheet takes ~1 min.
`light` > 0 adds a check light at the camera (pexp stays 3.0) so hands can be read in the dark scene."""
import sys, math, subprocess, os
from PIL import Image, ImageDraw
scene, name = sys.argv[1], sys.argv[2]
bx, by, bz = map(float, sys.argv[3].split(',')); dist = float(sys.argv[4])
azs = [float(a) for a in sys.argv[5].split(',')]; ts = [float(t) for t in sys.argv[6].split(',')]
dh = float(sys.argv[7]) if len(sys.argv) > 7 else 0.0
light = float(sys.argv[8]) if len(sys.argv) > 8 else 0.0
G = '/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64'
src = os.environ.get('PCK')
base = f'--main-pack {src}' if src else '--path /home/claude/rules'
S = '/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad/close'; os.makedirs(S, exist_ok=True)
tx, tz = bx, -by
tiles = []
for ai, az in enumerate(azs):
    a = math.radians(az); cx = tx + math.sin(a) * dist; cz = tz + math.cos(a) * dist
    yaw = math.degrees(math.atan2(-(tx - cx), -(tz - cz))); pitch = -math.degrees(math.atan2(dh, dist))
    pose = f'{cx:.3f},{cz:.3f},{yaw:.1f},{pitch:.1f},{bz + dh:.3f}'
    for t in ts:
        out = f'{S}/{name}_{ai}_{t}_'
        for f in os.listdir(S):
            if f.startswith(f'{name}_{ai}_{t}_'): os.remove(f'{S}/{f}')
        subprocess.run(f'cd /tmp && timeout 300 xvfb-run -a -s "-screen 0 960x540x24" {G} {base} --windowed --resolution 960x540 --write-movie {out}.png --fixed-fps 24 --quit-after 12 -- --record=poses --nocard --scene={scene} --gi=baked --pexp={3.0 if light == 0 else 1.0} --print=0 --hold=99 --at={t} --chklight={light} "--poses={pose}"', shell=True, capture_output=True)
        p = f'{out}00000010.png'
        im = Image.open(p).convert('RGB') if os.path.exists(p) else Image.new('RGB', (960, 540))
        ImageDraw.Draw(im).text((8, 8), f'{name} az{az:.0f} t{t}', fill=(255, 255, 0)); tiles.append(im)
cols = len(ts); rows = len(azs)
o = Image.new('RGB', (960 * cols, 540 * rows))
for i, im in enumerate(tiles): o.paste(im, ((i % cols) * 960, (i // cols) * 540))
o.save(f'/home/claude/kf/close_{name}.png'); print('OK', f'/home/claude/kf/close_{name}.png')
