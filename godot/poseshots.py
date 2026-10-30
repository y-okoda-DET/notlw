"""Stills from explicit camera poses: python3 poseshots.py <scene> <name> "<x,z,yaw,pitch,h>;..." <t1,t2,..> [light]"""
import sys, subprocess, os
from PIL import Image, ImageDraw
scene, name = sys.argv[1], sys.argv[2]; poses = sys.argv[3].split(';'); ts = [float(t) for t in sys.argv[4].split(',')]
light = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0
G = '/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64'; src = os.environ.get('PCK'); base = f'--main-pack {src}' if src else '--path /home/claude/rules'
S = '/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad/close'; os.makedirs(S, exist_ok=True)
tiles = []
for pi, pose in enumerate(poses):
    for t in ts:
        out = f'{S}/{name}_{pi}_{t}_'
        for f in os.listdir(S):
            if f.startswith(f'{name}_{pi}_{t}_'): os.remove(f'{S}/{f}')
        subprocess.run(f'cd /tmp && timeout 300 xvfb-run -a -s "-screen 0 960x540x24" {G} {base} --windowed --resolution 960x540 --write-movie {out}.png --fixed-fps 24 --quit-after 12 -- --record=poses --nocard --scene={scene} --gi=baked --pexp={3.0 if light == 0 else 1.0} --print=0 --hold=99 --at={t} --chklight={light} "--poses={pose}"', shell=True, capture_output=True)
        p = f'{out}00000010.png'
        im = Image.open(p).convert('RGB') if os.path.exists(p) else Image.new('RGB', (960, 540))
        ImageDraw.Draw(im).text((8, 8), f'{name} view{pi} t{t}', fill=(255, 255, 0)); tiles.append(im)
cols = len(ts); rows = len(poses)
o = Image.new('RGB', (960 * cols, 540 * rows))
for i, im in enumerate(tiles): o.paste(im, ((i % cols) * 960, (i // cols) * 540))
o.save(f'/home/claude/kf/close_{name}.png'); print('OK')
