## A hand that goes to a thing and stays on it (a door's knob as it swings, a candle held up): a two-bone arm over
## whatever the clip is doing, as a SkeletonModifier3D. 2026-11-17 夜（ユーザー「扉に手をかけて扉を開けるアニメーション」）.
## target: a Node3D (followed every frame) or a fixed Vector3 in world space. w: 0..1 (blend with the clip's own arm).
extends SkeletonModifier3D
var side := "r"                 # "r" | "l"
var target_node: Node3D = null
var target := Vector3.ZERO
var offset := Vector3.ZERO      # added to the target (world), e.g. the palm a little off the knob
var w := 0.0
var pole := Vector3(0.0, -1.0, -0.4)   # where the elbow hangs (world): down and a little back

func _process_modification():
	var sk := get_skeleton()
	if sk == null or w <= 0.001: return
	var ua := sk.find_bone("upperarm_" + side); var la := sk.find_bone("lowerarm_" + side); var ha := sk.find_bone("hand_" + side)
	if ua < 0 or la < 0 or ha < 0: return
	var to_w: Vector3 = target
	if is_instance_valid(target_node):
		to_w = ((target_node as MeshInstance3D).global_transform * (target_node as MeshInstance3D).get_aabb()).get_center() if target_node is MeshInstance3D else target_node.global_position
	to_w += offset
	var inv := sk.global_transform.affine_inverse()
	var t: Vector3 = inv * to_w
	var pl: Vector3 = (inv.basis * pole).normalized()
	var sp := sk.get_bone_global_pose(ua).origin
	var ep := sk.get_bone_global_pose(la).origin
	var hp := sk.get_bone_global_pose(ha).origin
	var l1 := sp.distance_to(ep); var l2 := ep.distance_to(hp)
	var n := t - sp; var d := clampf(n.length(), 0.05, l1 + l2 - 0.005); n = n.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var pp := (pl - n * pl.dot(n))
	if pp.length() < 0.01: pp = Vector3(0, -1, 0) - n * n.y
	pp = pp.normalized()
	var elbow := sp + n * a + pp * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var g1 := sk.get_bone_global_pose(ua)
	var q1 := Quaternion((ep - sp).normalized(), (elbow - sp).normalized())
	sk.set_bone_global_pose(ua, Transform3D(Basis(Quaternion().slerp(q1, w)) * g1.basis, g1.origin))
	var g2 := sk.get_bone_global_pose(la)
	var hp2 := sk.get_bone_global_pose(ha).origin
	var q2 := Quaternion((hp2 - g2.origin).normalized(), (sp + n * d - g2.origin).normalized())
	sk.set_bone_global_pose(la, Transform3D(Basis(Quaternion().slerp(q2, w)) * g2.basis, g2.origin))
