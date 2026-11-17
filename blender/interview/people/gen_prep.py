import re
src = open('/home/user/notlw/tripo/prep_natsuki.py').read()
src = re.sub(r'\nA\.data\.transform\([^\n]*# NIGHT_BODY[^\n]*', '', src)
a = src.index("A_HEIGHT = "); b = src.index("def imp(f):")
s = src[:a] + """A_HEIGHT = 0.98
H_BODY = 1.57 / A_HEIGHT
S_HEAD = 0.36
A_CHIN = 0.843
B_CHIN = 0.352
B_EYE_Z = 0.6625; B_EYE_X = -0.0015; B_EYED = 0.165
B_CUT = 0.0
NECK_K = 1.0
A_CUT = 0.835
from mathutils import Matrix as _Mx
NORM = _Mx.Translation((0, 0, 0.49)) @ _Mx.Rotation(-math.pi / 2, 4, 'Z')   # these two came out centred and facing +X

""" + src[b:]
s = s.replace("A.rotation_euler.z += math.pi; ", "")
s = s.replace("    o.parent = None\n", "    o.parent = None\n    o.matrix_world = NORM @ o.matrix_world\n")
assert 'NORM @' in s
s = s.replace("n2_body.glb", "kikite_body.glb").replace("n2_head.glb", "kikite_head.glb")
s = s.replace("natsuki_talk_open", "natsuki_talk").replace("natsuki", "kikite")
s = re.sub(r"_ck = np.array\(\[[^\]]*\]\)", "_ck = np.array([0.878, 0.716, 0.603])", s)
s = s.replace('CUT_UP = .003', 'CUT_UP = .012').replace('NECK_GEOM = True', 'NECK_GEOM = False')
s = s.replace("T = P.TRIPO", "T = '/home/claude/work/kikite'")
assert "T = '/home/claude/work/kikite'" in s
# the generated bust wears a white cloth below the neck: above the collar line it would stand out of the collar
k = "cut(B, lambda c: c.z > collar_z - .022)"
assert k in s
s = s.replace(k, k + """
_sb = albedo_sampler(B); _uvb = B.data.uv_layers[0]
_wh = [p.index for p in B.data.polygons if p.center.z < zA_chin - .01 and min(_sb(sum((_uvb.data[li].uv for li in p.loop_indices), Vector((0, 0))) / len(p.loop_indices))) > .55]
bm = bmesh.new(); bm.from_mesh(B.data); bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in _wh], context='FACES'); bm.to_mesh(B.data); bm.free(); del _sb
print('white cloth faces removed from the head', len(_wh))""", 1)
cutp = s.index("# ---- the drawn face")
s = s[:cutp] + """# no drawn face for the interviewer (her face is never seen in 3D): the generated head as it is
B.name = 'kikite_head'
for o in (A, B):
    for p in o.data.polygons: p.use_smooth = True
bpy.ops.wm.save_as_mainfile(filepath=f'{T}/kikite_prep.blend')
print('SAVED')
"""
open('prep_kikite.py', 'w').write(s)
