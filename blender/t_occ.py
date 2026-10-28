import sys; sys.path.insert(0,'/home/claude/kf')
import bpy, shot, lib
shot.build(); bpy.context.scene.view_settings.exposure=.8; bpy.context.scene.view_settings.look='AgX - Medium High Contrast'
for f in (38, 119):
    shot.at(f/12); lib.render(f'/home/claude/kf/out/occ_{f}.png', samples=12, pct=35)
