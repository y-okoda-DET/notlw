"""Look at the dusk rooms without exporting: python3 t_rooms.py <out_dir> [samples]
Cycles stills from a standing eye in the living room, the dining room and the kitchen, with the scene's own lights."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import export_dusk as XD, house4 as H4
out = sys.argv[1]; spp = int(sys.argv[2]) if len(sys.argv) > 2 else 24
XD.build()
s = bpy.context.scene
s.render.engine = 'CYCLES'; s.cycles.samples = spp; s.cycles.device = 'CPU'; s.cycles.use_denoising = True
s.render.resolution_x, s.render.resolution_y = 800, 450
cam_d = bpy.data.cameras.new('tc'); cam_d.lens = 20; cam = bpy.data.objects.new('tc', cam_d); s.collection.objects.link(cam); s.camera = cam
X, Y = H4.X, H4.Y
views = {   # plan eye (x, y), plan target (x, y, z)
    'living_door': ((3.8, 3.5), (.5, 2.0, 1.0)),
    'living_sofa': ((3.3, .4), (.6, 3.6, .9)),
    'living_deer': ((2.2, 3.3), (2.1, 0, 1.7)),
    'dining': ((3.5, 4.3), (1.0, 7.2, .8)),
    'kitchen_door': ((6.3, 6.4), (9.0, 4.5, .9)),
    'kitchen_back': ((9.3, 5.5), (6.5, 7.0, .9)),
    'hall_doors': ((5.3, 4.6), (4.0, 3.5, 1.2)),
}
only = sys.argv[3].split(',') if len(sys.argv) > 3 else None
for name, ((ex, ey), (tx, ty, tz)) in views.items():
    if only and name not in only: continue
    cam.location = Vector((X(ex), Y(ey), 1.52))
    cam.rotation_euler = (Vector((X(tx), Y(ty), tz)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    s.render.filepath = f'{out}/{name}.png'; bpy.ops.render.render(write_still=True)
    print('ROOM', name, flush=True)
print('ROOMS_DONE')
