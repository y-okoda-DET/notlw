import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, lib, chars as C, numpy as np
lib.reset()
r,b=C.make_tripo('natsuki')
gi={g.index:g.name for g in b.vertex_groups}
armn=lambda n: n.split('_')[0] in C.ARM_CHAIN
P=np.array([tuple(b.matrix_world@v.co) for v in b.data.vertices])
aw=np.array([sum(g.weight for g in v.groups if armn(gi[g.group])) for v in b.data.vertices])
tot=np.array([sum(g.weight for g in v.groups) for v in b.data.vertices])
print('no weights', (tot<1e-6).sum())
bad=(aw>.3)&(np.abs(P[:,0])<.15)&(P[:,2]<1.0)
print('jeans with arm weight', bad.sum())
if bad.sum(): print(P[bad][:10], P[bad][:,2].min(), P[bad][:,2].max())
for n in ['thigh_l','pelvis','spine_01','upperarm_l','hand_l']:
    print(n, r.data.bones[n].head_local[:], (r.matrix_world@r.data.bones[n].head_local)[:])
print('body mw', b.matrix_world.translation[:], b.parent)
# components sizes
