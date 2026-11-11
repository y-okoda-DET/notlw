## 段階2 家まるごと: the doors open and close (試作90, ユーザー「扉、開くと嬉しいけど、難しいかな？（開けられないところは
## 開けられないと出ればOK」). Each hinged leaf (door_*, door2_*: kept out of the joined, lightmapped mesh) gets its own
## collision that turns with it; E on a door within reach swings it shut or open. Doors that will not open say so, in
## the same small serif line at the bottom left that names what you look at in the story scenes.
extends Node
const Type = preload("res://scripts/type.gd")

const REACH := 1.9
const SWING := 0.7          # seconds
var main
var cam: Camera3D           # the player's; looked up each frame (the body is made anew for shots)
var doors := {}             # leaf MeshInstance3D -> {pivot, open (rad), closed (rad), is_open, locked}
var label: Label
var say_until := 0.0
var t := 0.0

func setup(m):
	main = m
	var font: Font = Type.say()
	var layer := CanvasLayer.new(); layer.layer = 13; add_child(layer)
	label = Label.new(); label.add_theme_font_override("font", font)
	var u: float = main.get_viewport().get_visible_rect().size.y / 1080.0
	label.add_theme_font_size_override("font_size", int(26 * u))
	label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	Type.soft(label, u)
	label.position = Vector2(60 * u, main.get_viewport().get_visible_rect().size.y - 150 * u)
	layer.add_child(label)
	var ST: Dictionary = main.ST
	for mi in main.S.env_node.find_children("door*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.begins_with("door_") or nm.begins_with("door2_")) or nm.contains("knob") or nm.contains("glass"): continue
		var piv := mi.get_parent() as Node3D
		if piv == null or not String(piv.name).contains("pivot"): continue
		if doors.values().any(func(d): return d.pivot == piv): continue
		var key := nm.get_slice(".", 0)
		# the leaf's own collision, a child of the leaf so it turns with it
		var aabb: AABB = mi.get_aabb()
		var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
		bx.size = aabb.size; cs.shape = bx; cs.position = aabb.get_center(); sb.add_child(cs); mi.add_child(sb)
		sb.set_meta("door", mi)
		var cur := piv.rotation.y
		var locked := ""
		if key == "door_front" and ST.get("boards", false): locked = "開かない。外から、誰かが押さえている。" if main.TIME == "t23" else "開かない。"
		elif key == "door_back" and ST.get("boards", false): locked = "開かない。板が打ちつけてある。"
		elif key == "door_barred" and absf(cur) < 0.3: locked = "開かない。"   # shut from 0:00 (Taiga behind it); open before
		var rest := 0.0
		if piv == main.door_pivot: rest = float(main.S.get("door_rot", 0.0)) - deg_to_rad(float(ST.get("front", 0)))
		doors[mi] = {"pivot": piv, "rest": rest, "open": cur, "is_open": absf(cur - rest) > 0.3, "locked": locked, "key": key, "box": bx, "body": sb}
		# 試作97 (ユーザー「半開きみたいになっているのが変に感じた」): a door left ajar in the plans stood half open all night,
		# and the story's open_key left it so. An open door here is open all the way (the front door keeps its dusk angle)
		if doors[mi].is_open and piv != main.door_pivot and key != "door_barred":
			doors[mi].open = rest + signf(cur - rest) * deg_to_rad(92.0)
			# the cellar door: opened all the way the plans' way, its leaf lay over the stairwell (ユーザー「上るとき、ここに
			# 板があるのは変」) and turned its 発電機 notice to the wall. It opens into the hall, and at dusk it is shut
			if key == "door_cellar":
				doors[mi].open = rest - signf(cur - rest) * deg_to_rad(92.0)
				if main.TIME == "dusk": doors[mi].is_open = false
			piv.rotation.y = doors[mi].open if doors[mi].is_open else rest
	# a shut door opens to the side where the swept leaf meets the least (walls, furniture): the plans give no side
	await get_tree().physics_frame
	for mi in doors:
		var d: Dictionary = doors[mi]
		if d.is_open: continue
		if d.pivot == main.door_pivot: d.open = d.rest + deg_to_rad(105.0); continue   # as it stands at dusk
		var best := 0.0; var fewest := 1 << 30
		for a in [deg_to_rad(92.0), deg_to_rad(-92.0)]:
			var hits := 0
			for f in [0.35, 0.7, 1.0]:
				hits += _hits_at(mi, d, d.rest + a * f)
			if hits < fewest: fewest = hits; best = a
		d.open = d.rest + best

func _hits_at(mi: MeshInstance3D, d: Dictionary, ang: float) -> int:
	var piv: Node3D = d.pivot
	var keep := piv.rotation.y
	piv.rotation.y = ang
	var q := PhysicsShapeQueryParameters3D.new()
	var bx := BoxShape3D.new(); var sz: Vector3 = (d.box as BoxShape3D).size; bx.size = Vector3(maxf(sz.x - 0.12, 0.01), maxf(sz.y - 0.12, 0.01), maxf(sz.z - 0.12, 0.01))
	q.shape = bx
	q.transform = mi.global_transform * Transform3D(Basis(), mi.get_aabb().get_center())
	q.exclude = [(d.body as StaticBody3D).get_rid()]
	var n: int = main.get_world_3d().direct_space_state.intersect_shape(q, 8).size()
	piv.rotation.y = keep
	return n

func _looked() -> MeshInstance3D:
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.collider.has_meta("door"): return null
	return hit.collider.get_meta("door")

func _process(dt):
	t += dt
	cam = main.player.get_node_or_null("Head/Camera") if main.player else null
	if cam == null: return
	var d := _looked()
	if t < say_until: return
	label.text = "［扉｜Ｅ］" if d else ""

func _unhandled_input(e):
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E)
	if not press: return
	if cam == null: return
	var d := _looked()
	if d == null: return
	get_viewport().set_input_as_handled()
	toggle(d)

func toggle(d: MeshInstance3D):
	var s: Dictionary = doors[d]
	if s.locked != "":
		label.text = s.locked; say_until = t + 2.2; return
	s.is_open = not s.is_open
	var to: float = s.open if s.is_open else s.rest
	create_tween().tween_property(s.pivot, "rotation:y", to, SWING).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if s.pivot == main.door_pivot: main.S["door_rot"] = to

# 試作92: someone else opens a door on their way (Taiga to the cellar): open it if it is shut, never say "locked"
func open_key(key: String):
	for d in doors:
		var s: Dictionary = doors[d]
		if s.key == key and not s.is_open and s.locked == "": toggle(d)
