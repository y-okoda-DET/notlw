import sys, bpy
sys.path.insert(0,'/home/claude/kf')
import chars as C
from mathutils import Vector
key=sys.argv[-1]
rig, body = C.make_tripo(key)
bpy.context.view_layer.update()
V=[body.matrix_world@v.co for v in body.data.vertices]
H=max(p.z for p in V)
s='r'
e=C.bone_head(rig,'lowerarm_r'); w=C.bone_head(rig,'hand_r'); d=(w-e).normalized()
lat=lambda p:((p-e)-d*(p-e).dot(d))
pts=[p for p in V if lat(p).length<.07 and (p-e).dot(d)>0]
tipd=max((p-e).dot(d) for p in pts)
print('ROOTS',[round((C.bone_head(rig,f+'_01_r')-e).dot(d)*100,1) for f in ('index','middle','pinky','thumb')],'tip',round((C.bone_tail(rig,'middle_03_r')-e).dot(d)*100,1)); print('KEY',key,'H',round(H,3),'forearm',round((w-e).length*100,1),'elbow->tip',round(tipd*100,1),'rig wrist at',round((w-e).length*100,1))
for a in range(0,int(tipd*100)+1):
    sl=[lat(p) for p in pts if a<=(p-e).dot(d)*100<a+1]
    if not sl: continue
    import itertools
    # width across: extent of lateral vectors projected on the two lateral axes
    ax1=d.orthogonal().normalized(); ax2=d.cross(ax1)
    w1=max(v.dot(ax1) for v in sl)-min(v.dot(ax1) for v in sl); w2=max(v.dot(ax2) for v in sl)-min(v.dot(ax2) for v in sl)
    print('PROF',a,len(sl),round(w1*100,1),round(w2*100,1))
