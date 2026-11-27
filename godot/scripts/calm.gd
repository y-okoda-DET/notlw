## 試作297（赤字 #23「体をくねらせているのはいいんだけど、不自然にぐにゃっとなりすぎ」）: over a talk clip, the back and
## the neck go part of the way back to their rest, so the clip's sway stays but smaller. A SkeletonModifier3D, as headrest.gd.
extends SkeletonModifier3D
var k := 0.5            # how far back to rest (0: the clip as it is, 1: upright at rest)
var bones := ["spine_01", "spine_02", "spine_03", "neck_01"]

func _process_modification():
	var sk := get_skeleton()
	if sk == null: return
	for n in bones:
		var i := sk.find_bone(n)
		if i < 0: continue
		var rest: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(rest, k))
