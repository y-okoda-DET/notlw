import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, shot, lib
from mathutils import Vector
shot.build(); shot.at(3.0)
c=shot.S['cam']; c.location=(shot.S['slit_x']-.1, 5.4, 1.35); c.rotation_euler=(Vector((shot.S['slit_x'],6.3,1.25))-c.location).to_track_quat('-Z','Y').to_euler(); c.data.lens=35
bpy.context.scene.view_settings.exposure=.8
lib.render('/home/claude/kf/out/t_door_close.png', samples=16, pct=40)
