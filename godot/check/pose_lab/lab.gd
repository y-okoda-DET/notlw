extends SceneTree
# pose lab: the hands before the eye as ch6.gd holds them (rig = the camera's frame), with stand-ins for what they hold
var frame := 0
var scenes := []
var cur: Node3D
var cam: Camera3D
var todo := []
func v3(a) -> Vector3: return Vector3(a[0], a[1], a[2])
func q_of(d) -> Basis: return Basis.from_euler(Vector3(deg_to_rad(d[0]), deg_to_rad(d[1]), deg_to_rad(d[2])), EULER_ORDER_YXZ)
func arm(left: bool, curl: float, thumb: float) -> Node3D:
	var h := Node3D.new()
	var inst: Node3D = (load("res://props/mio_arm_%s.glb" % ("l" if left else "r")) as PackedScene).instantiate(); h.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var to_h := Transform3D(); var nd: Node3D = sk
	while nd != h: to_h = nd.transform * to_h; nd = nd.get_parent()
	for f in ["index", "middle", "ring", "pinky", "thumb"]:
		for j in 3:
			var bi := sk.find_bone("%s_0%d_%s" % [f, j + 1, "l" if left else "r"])
			if bi < 0: continue
			var gb: Basis = (to_h * sk.get_bone_global_rest(bi)).basis.orthonormalized()
			var ax: Vector3 = gb.y.cross(Vector3.DOWN).normalized()
			if f == "thumb":
				var o: Vector3 = (to_h * sk.get_bone_global_rest(bi)).origin
				ax = gb.y.cross((Vector3(0.0, -0.035, -0.075) - o).normalized()).normalized()
			ax = (gb.inverse() * ax).normalized()
			var ang: float = (thumb * [0.30, 0.55, 0.40][j]) if f == "thumb" else (curl * [0.80, 1.05, 0.70][j])
			todo.append([sk, bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion(ax, ang)])
	return h
func build(sc: Dictionary) -> Node3D:
	var r := Node3D.new(); var hands := {}
	for k in ["l", "r"]:
		if not sc.has(k): continue
		var d: Array = sc[k]
		var h := arm(k == "l", d[2], d[3] if d.size() > 3 else d[2] * 0.6); r.add_child(h)
		h.position = v3(d[0]); h.basis = q_of(d[1]); hands[k] = h
	for o in sc.get("objs", []):
		var mi := MeshInstance3D.new()
		if o.has("cyl"):
			var c := CylinderMesh.new(); c.top_radius = o.cyl[0]; c.bottom_radius = o.cyl[0]; c.height = o.cyl[1]; mi.mesh = c
		else:
			var b := BoxMesh.new(); b.size = v3(o.box); mi.mesh = b
		var m := StandardMaterial3D.new(); m.albedo_color = Color(o.get("col", "666666")); mi.material_override = m
		var par: Node3D = hands.get(o.get("on", ""), r)
		par.add_child(mi); mi.position = v3(o.get("pos", [0, 0, 0]))
		if o.has("deg"): mi.basis = q_of(o.deg)
		if o.has("axis"):   # a cylinder from pos along axis
			var a := v3(o.axis).normalized(); var x := a.cross(Vector3.BACK).normalized()
			mi.basis = Basis(x, a, x.cross(a)); mi.position = v3(o.pos) + a * o.cyl[1] * 0.5
	return r
func _init():
	var w := Node3D.new(); root.add_child(w)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.16, 0.2, 0.26)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.45; env.environment = e; w.add_child(env)
	var l := OmniLight3D.new(); l.position = Vector3(-0.2, 0.15, -0.1); l.omni_range = 3.0; l.light_energy = 1.2; w.add_child(l)
	cam = Camera3D.new(); cam.fov = 62; cam.near = 0.05; w.add_child(cam)
	scenes = JSON.parse_string(FileAccess.get_file_as_string("res://poses.json"))
	var only := OS.get_environment("ONLY")
	if only != "": scenes = scenes.filter(func(s): return String(s.name).begins_with(only))
func _process(_d):
	frame += 1
	var k := (frame - 1) / 6; var ph := (frame - 1) % 6
	if k >= scenes.size(): quit(); return false
	if ph == 0:
		if cur: cur.queue_free()
		todo = []; cur = build(scenes[k]); cam.add_child(cur)
	if ph == 2:
		for t in todo: (t[0] as Skeleton3D).set_bone_pose_rotation(t[1], t[2])
	if ph == 5: root.get_viewport().get_texture().get_image().save_png("res://out/L_%s.png" % scenes[k].name)
	return false
