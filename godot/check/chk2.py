"""All-characters sheet from an exported pck: python3 chk2.py <pck> <tag>. Each character from 4 sides (the camera
1.0 m out at head height looking at the chest), night and dusk, halftone on. Sheet: rows = characters, cols = sides."""
import sys, math, subprocess, os
from PIL import Image, ImageDraw
pck, tag = sys.argv[1], sys.argv[2]
G = '/home/claude/godot/Godot_v4.4.1-stable_linux.x86_64'
S = '/tmp/claude-0/-home-claude/6407adc7-bdf3-5700-ba20-4629ee47fbe1/scratchpad'; R = f'{S}/chk2_{tag}'; os.makedirs(R, exist_ok=True)
CH = {'night': [('kiryu', -.32, 3.85, 1.3), ('taiga', .82, 5.6, 1.3)],
      'dusk': [('natsuki', .36, 3.84, 1.25), ('kiryu', -.32, 4.43, 1.3), ('makoto', 1.08, 2.52, 1.2), ('taiga', .82, 6.47, 1.25)]}
AZ = (0, 90, 180, 270)
for sc, chars in CH.items():
    poses = []
    for nm, bx, by, bz in chars:
        tx, tz = bx, -by
        for az in AZ:
            a = math.radians(az); cx = tx + math.sin(a) * 1.0; cz = tz + math.cos(a) * 1.0
            yaw = math.degrees(math.atan2(-(tx - cx), -(tz - cz))); pitch = -math.degrees(math.atan2(.2, 1.0))
            poses.append(f'{cx:.3f},{cz:.3f},{yaw:.1f},{pitch:.1f},{bz + .2:.3f}')
    for f in os.listdir(R):
        if f.startswith(sc): os.remove(f'{R}/{f}')
    subprocess.run(f'cd /tmp && timeout 900 xvfb-run -a -s "-screen 0 960x540x24" {G} --main-pack {pck} --windowed --resolution 960x540 --write-movie {R}/{sc}_.png --fixed-fps 24 -- --record=poses --nocard --scene={sc} --gi=baked --pexp=3.0 --print=1 --at=8.0 "--poses={";".join(poses)}"', shell=True, capture_output=True)
    frames = sorted(f for f in os.listdir(R) if f.startswith(sc + '_') and f.endswith('.png'))
    print(sc, 'frames', len(frames))
    # poses mode: each pose is held for a fixed number of frames; take the last frame of each block
    n = len(poses); per = len(frames) // n if n else 0
    W, H = 480, 270; o = Image.new('RGB', (W * len(AZ), H * len(chars)))
    for i in range(n):
        if per == 0: break
        im = Image.open(f'{R}/{frames[i * per + per - 1]}').convert('RGB').resize((W, H))
        ImageDraw.Draw(im).text((6, 6), f'{chars[i // len(AZ)][0]} az{AZ[i % len(AZ)]}', fill=(255, 255, 0))
        o.paste(im, ((i % len(AZ)) * W, (i // len(AZ)) * H))
    o.save(f'/home/claude/kf/sheet_{tag}_{sc}.png'); print('sheet', f'/home/claude/kf/sheet_{tag}_{sc}.png')
