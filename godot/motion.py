"""Motion check sheets: python3 motion.py <night|dusk> [person,...]
For each person, two close.py sheets over the same 6 loop times (before / during / after the reactions):
  <scene>_mv_<person>_neck : the neck and collar from the rear-side (120 deg off the face)
  <scene>_mv_<person>_hand : the arms and hands from the front-side (35 deg off the face)
Shapes are judged here (no halftone, check light); the print look is judged on the usual sheets.
PCK / PRINT / PEXP pass through to close.py. ~4 min a person."""
import sys, os, subprocess
scene = sys.argv[1]
TIMES = {'night': '2.0,6.3,8.5,11.3,14.0,19.0',   # knocks 6.0-6.56 and 11.0-11.6, Kiryu looks 7.3-10, Taiga up 5.6-12.2
         'dusk': '1.0,3.6,6.8,9.0,12.5,16.0'}      # Makoto glances 3.2-5.0 / 12-13.6, Kiryu looks up 6.5-8.6 / 15.2-17, Taiga turns 11-13.5
LIGHT = {'night': .2, 'dusk': .12}
ZG = -.18
# person: (x, y, floor z, front azimuth in close.py terms (0 = from -y), neck z, hand z[, neck view offset])
# the camera is the player, so walls push it: pick a neck view with room behind it (Taiga at dusk stands in the doorway)
P = {'night': {'kiryu': (-.32, 4.02, 0, -14, 1.48, 1.15),
               'taiga': (.82, 5.27, ZG, 176, 1.30, 1.25),
               'natsuki': (.435, 6.56, ZG, 0, 1.38, 1.05)},
     'dusk': {'natsuki': (.36, 3.84, 0, 0, 1.38, .85),
              'kiryu': (-.32, 4.43, 0, 33, 1.48, 1.45),
              'taiga': (.82, 6.47, ZG, -10, 1.70, 1.05, 50),   # the player stands lower outside the doorway: aim higher
              'makoto': (1.08, 2.52, 0, -151, 1.38, 1.15)}}
who = sys.argv[2].split(',') if len(sys.argv) > 2 else list(P[scene])
C = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'close.py')
env = dict(os.environ); env.setdefault('PRINT', '0')
for k in who:
    x, y, z0, f, zn, zh, *o = P[scene][k]
    for part, z, d, az, dh in (('neck', zn, .7, f + (o[0] if o else 120), .05), ('hand', zh, 1.1, f + 35, .15)):
        r = subprocess.run(['python3', C, scene, f'{scene}_mv_{k}_{part}', f'{x},{y},{z0 + z:.2f}', str(d), str(az % 360),
                            TIMES[scene], str(dh), str(LIGHT[scene])], env=env, capture_output=True, text=True)
        print(k, part, r.stdout.strip().splitlines()[-1] if r.stdout.strip() else 'NO_OUTPUT ' + r.stderr[-300:], flush=True)
print('MOTION_DONE')
