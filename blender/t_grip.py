"""Check Makoto's grip on the reflector (dusk) without exporting: python3 t_grip.py <out_dir> [t]
Workbench close-ups of both hands from the front of the board, from her eye, from each side."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import export_dusk as X, chars as C
out = sys.argv[1]; t = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
X.build(); X.at(t)
m = X.S['m']; RM = X.S['rf_M']; R = RM.to_3x3().normalized()
Mi = RM.inverted()
for side in 'lr':
    for b in (f'hand_{side}', f'middle_03_{side}', f'thumb_03_{side}'):
        p = C.bone_tail(m, b) if '03' in b else C.bone_head(m, b)
        q = Mi @ p
        print('GRIP', b, 'board local x %.2f y(mm) %.1f z %.2f' % (q.x, q.y * 6, q.z))
s = bpy.context.scene
s.render.engine = 'CYCLES'; s.cycles.samples = 16; s.cycles.device = 'CPU'
sun = bpy.data.lights.new('gs', 'SUN'); sun.energy = 3; so = bpy.data.objects.new('gs', sun); s.collection.objects.link(so); so.rotation_euler = (0.6, 0.2, 0.5)
s.render.resolution_x, s.render.resolution_y = 600, 460
ctr = RM @ Vector((0, 0, -.25))
f = -(R @ Vector((0, 1, 0))); bx = R @ Vector((1, 0, 0)); up = R @ Vector((0, 0, 1))
cam_d = bpy.data.cameras.new('gc'); cam_d.lens = 35; cam = bpy.data.objects.new('gc', cam_d); s.collection.objects.link(cam); s.camera = cam
views = {'front': f * .55 + up * .1, 'her_eye': -f * .35 + up * .45, 'side_l': bx * .45 + f * .2, 'side_r': -bx * .45 + f * .2, 'below': -up * .4 + f * .25}
for name, off in views.items():
    cam.location = ctr + off
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    s.render.filepath = f'{out}/{name}.png'; bpy.ops.render.render(write_still=True)
print('GRIP_DONE')
