# the four views a player gets: front, looking up from below at an angle, side, coming round from behind
import bpy, sys, math
sys.path.insert(0,'/home/claude/kf')
import lib
key=sys.argv[-2]; hz=float(sys.argv[-1])
bpy.ops.wm.open_mainfile(filepath=f'/home/claude/tripo/{key}_prep.blend')
s=bpy.context.scene
for o in list(bpy.data.objects):
    if o.type in ('CAMERA','LIGHT'): bpy.data.objects.remove(o)
if s.world is None: s.world=bpy.data.worlds.new('w')
s.world.use_nodes=True; s.world.node_tree.nodes['Background'].inputs[1].default_value=.25
s.view_settings.view_transform='AgX'
lib.area('key',(-1.2,-2.2,2.2),(0,0,hz),260,k=5000,size=(1.5,1.5)); lib.area('fill',(1.5,-1.5,1.5),(0,0,hz),90,k=5000,size=(2,2)); lib.area('back',(0,2.5,2),(0,0,hz),120,k=5000,size=(2,2))
views={'front':((0,-.7,hz),(0,0,hz)),'up':((.3,-.45,hz-.35),(0,0,hz-.05)),'side':((.7,-.05,hz+.02),(0,0,hz-.02)),'back':((.45,.5,hz+.1),(0,0,hz-.02))}
for n,(c,t) in views.items():
    lib.camera(c,t,lens=70)
    lib.render(f'/home/claude/tripo/v4_{key}_{n}.png',samples=16,res=(450,450))
