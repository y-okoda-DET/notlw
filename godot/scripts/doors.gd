## 段階2 家まるごと: the doors open and close (試作90, ユーザー「扉、開くと嬉しいけど、難しいかな？（開けられないところは
## 開けられないと出ればOK」). Each hinged leaf (door_*, door2_*: kept out of the joined, lightmapped mesh) gets its own
## collision that turns with it; E on a door within reach swings it shut or open. Doors that will not open say so, in
## the same small serif line at the bottom left that names what you look at in the story scenes.
extends Node
const Type = preload("res://scripts/type.gd")
const Sound = preload("res://scripts/sound.gd")

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
	# 2026-11-14（ユーザー「この光源はなに？」、地下の階段から見上げた地下の扉のノブ）：黒い丸いノブが、刷りで小さな灯りに見えた。
	# ノブは真鍮の色に（どの扉も同じ）
	var brass := StandardMaterial3D.new(); brass.albedo_color = Color(0.62, 0.50, 0.30); brass.metallic = 0.7; brass.roughness = 0.4
	for k in main.S.env_node.find_children("door_*knob*", "MeshInstance3D", true, false): (k as MeshInstance3D).material_override = brass
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
		if key == "door_front" and ST.get("boards", false): locked = "開かない。"   # 試作281（ユーザー「開かない、外から誰かが押さえているは変。トル」）
		elif key == "door_back" and ST.get("boards", false): locked = "開かない。"   # 2026-11-16（docs/資料/夏希をゾンビに見せる証拠_2026-11-16.md）: 3:30 she comes in by this door
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
				doors[mi].open = _hall_side(mi, doors[mi])   # (rest - the plans' way still left it over the stair: 試作121)
				if main.TIME == "dusk": doors[mi].is_open = false
			piv.rotation.y = doors[mi].open if doors[mi].is_open else rest
	# a shut door opens to the side where the swept leaf meets the least (walls, furniture): the plans give no side
	await get_tree().physics_frame
	for mi in doors:
		var d: Dictionary = doors[mi]
		if d.is_open: continue
		if d.pivot == main.door_pivot: d.open = d.rest + deg_to_rad(105.0); continue   # as it stands at dusk
		# 2026-11-14（ユーザー「1階から地下を見下ろすと、下りの階段が見えない。謎の板」）: shut at 20:00, the cellar door chose the
		# stairwell's side (nothing there for the leaf to meet) and hung over the stair when Taiga opened it. It opens into the hall
		# (plan +y of its wall at 5.6, Godot +z)
		if d.key == "door_cellar": d.open = _hall_side(mi, d); continue
		var best := 0.0; var fewest := 1 << 30
		for a in [deg_to_rad(92.0), deg_to_rad(-92.0)]:
			var hits := 0
			for f in [0.35, 0.7, 1.0]:
				hits += _hits_at(mi, d, d.rest + a * f)
			if hits < fewest: fewest = hits; best = a
		d.open = d.rest + best

# the cellar door's open angle on the hall's side of its wall (plan +y of 5.6, Godot +z): its leaf's middle there
func _hall_side(mi: MeshInstance3D, d: Dictionary) -> float:
	var piv: Node3D = d.pivot; var keep := piv.rotation.y; var pick: float = d.rest + deg_to_rad(92.0)
	var wall_z: float = piv.global_position.z
	for a2 in [deg_to_rad(92.0), deg_to_rad(-92.0)]:
		piv.rotation.y = d.rest + a2
		var c: Vector3 = mi.global_transform * mi.get_aabb().get_center()
		if c.z > wall_z + 0.2: pick = d.rest + a2
	piv.rotation.y = keep
	# 試作232（ユーザー「柱が扉を突き抜けている」、20時）: at 92° the leaf lay along the kitchen wall and the kitchen door's
	# jamb came through it. It stops at 68°, clear of the wall
	return d.rest + (pick - d.rest) * 68.0 / 92.0

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

# 試作281: the ray from the eye, looking down, met the top of her own body first (ch8.gd _cel_look, the same)
func _me() -> Array:
	var pl = main.player if main else null
	return [(pl as CollisionObject3D).get_rid()] if pl is CollisionObject3D else []

func _looked() -> MeshInstance3D:
	var from := cam.global_position
	var to := from - cam.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to); q.exclude = _me()
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not hit.collider.has_meta("door"): return null
	# 試作127（ユーザー「扉を選択するとnullとだけ出る」、第3章の玄関）: a chapter that takes a door for itself (ch3: the front
	# door) drops it from the list, but its body still carried the meta: E on it read a missing entry
	var m = hit.collider.get_meta("door")
	return m if doors.has(m) else null

# 試作277（ユーザー「扉一回選択したら、左下、消す」）：一度動かした扉には、もう案内を出さない
var used := {}
# 試作277（ユーザー「ここの扉、選択できるように。開かない。みたいなテキストを出す」）：書斎のふすま（開かない）
func _fusuma() -> bool:
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * REACH); q.exclude = _me()
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return false
	var c: Node = hit.collider
	return String(c.name).to_lower().contains("fusuma") or (c.get_parent() != null and String(c.get_parent().name).to_lower().contains("fusuma"))

func _process(dt):
	t += dt
	cam = main.player.get_node_or_null("Head/Camera") if main.player else null
	if cam == null: return
	var d := _looked()
	if t < say_until: return
	# 試作282（ユーザー「扉は選択できるけど、開かないという具合に」、4時の地下の扉）: a door that will not open keeps its prompt
	label.text = "［扉｜Ｅ］" if d and (not used.has(d) or String(doors[d].locked) != "") else ("［ふすま｜Ｅ］" if d == null and _fusuma() else "")

func _unhandled_input(e):
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E)
	if not press: return
	if cam == null: return
	var d := _looked()
	if d == null:
		if _fusuma():
			get_viewport().set_input_as_handled()
			Sound.one(self, "ch3_rattle", -16.0, cam.global_position - cam.global_basis.z * 0.8)
			label.text = "［開かない］"; say_until = t + 2.2
		return
	get_viewport().set_input_as_handled()
	used[d] = true
	toggle(d)

func toggle(d: MeshInstance3D):
	if not doors.has(d): return
	var s: Dictionary = doors[d]
	# 試作125: at 22:00 Taiga asks Mio to lock the front door (ch2_21.gd); E on it is her locking it
	if s.key == "door_front" and main.has_meta("front_lock") and (main.get_meta("front_lock") as Callable).is_valid():
		var cb: Callable = main.get_meta("front_lock"); main.remove_meta("front_lock"); cb.call(); return
	if s.key == "door_front" and main.has_meta("front_locked"): Sound.one(self, "ch3_rattle", -12.0, (d as Node3D).global_position); return   # locked at 22時 (ch2_21.gd)
	if s.locked != "":
		# 2026-11-17 夜（ユーザー「左下の開かない、トル」）: the back door says nothing; it only rattles in its frame (it is not locked: 3:30)
		if s.key == "door_back": Sound.one(self, "ch3_rattle", -12.0, (d as Node3D).global_position); return
		Sound.one(self, "ch3_rattle", -14.0, (d as Node3D).global_position)
		label.text = s.locked; say_until = t + 2.2; return
	s.is_open = not s.is_open
	var to: float = s.open if s.is_open else s.rest
	# 試作127（新しい音）: a wooden door opening, and shutting with its latch
	if s.is_open: Sound.one(self, "door_open", -12.0, (d as Node3D).global_position)
	else: get_tree().create_timer(SWING * 0.75).timeout.connect(func(): Sound.one(self, "door_close", -10.0, (d as Node3D).global_position))
	create_tween().tween_property(s.pivot, "rotation:y", to, SWING).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if s.pivot == main.door_pivot: main.S["door_rot"] = to

# 試作92: someone else opens a door on their way (Taiga to the cellar): open it if it is shut, never say "locked"
func open_key(key: String):
	for d in doors:
		var s: Dictionary = doors[d]
		if s.key == key and not s.is_open and s.locked == "": toggle(d)

# 2026-11-17（第4章は勝手口から）: the story opens a door whatever it says to the player (the back door is "locked" for her
# once the boards are up: at 3:30 someone comes in by it). secs: how long it takes to swing
func open_force(key: String, secs := SWING):
	for d in doors:
		var s: Dictionary = doors[d]
		if s.key != key or s.is_open: continue
		s.locked = ""; s.is_open = true
		if secs <= 0.05: s.pivot.rotation.y = s.open
		else: create_tween().tween_property(s.pivot, "rotation:y", s.open, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
