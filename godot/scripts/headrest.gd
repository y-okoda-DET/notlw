## Makoto asleep in the car (2026-11-21 8時、ユーザー「真琴、まだ顔が歪んでいる」): the sitting clip rolls her head hard to one
## side and her face reads crooked. Over the clip, the neck and the head go back to their rest, the chin a little down:
## asleep, upright against the headrest. A SkeletonModifier3D, as reach.gd.
extends SkeletonModifier3D
var chin := 0.10        # radians the head drops forward (asleep)
var lean := 0.06        # and a little to her window
var follow: Node3D = null   # the earphone: put on her ear after the head is set (a BoneAttachment3D still sees the clip's head)
var follow_at := Vector3.ZERO

func _process_modification():
	var sk := get_skeleton()
	if sk == null: return
	for b in [["neck_01", chin * 0.4, lean * 0.5], ["head", chin * 0.6, lean * 0.5]]:
		var i := sk.find_bone(b[0])
		if i < 0: continue
		var r: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
		sk.set_bone_pose_rotation(i, r * Quaternion(Vector3.RIGHT, b[1]) * Quaternion(Vector3.FORWARD, b[2]))
	if follow != null:
		var hi := sk.find_bone("head")
		if hi >= 0:   # the ear: from the head's root, in her body's axes (the bone's own axes turn with the rest pose)
			var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(hi).origin
			follow.global_position = hp + sk.global_transform.basis.orthonormalized() * follow_at
