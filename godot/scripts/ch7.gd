## ステップ F：第7章「去年の夏」（docs/資料/第7章の設計_2026-11-19.md）。台詞は story/ch7.txt。
## 一年前の合宿を、陽太の目で。誰の証言でもない章：澪＊の行（ページの上の証言）は一つも無く、章のカードに問いも無い。
## main.gd が三つに分けて作る（光が三つあるので、場面を読み直す）：
##   play="ch7"  夕方（dusk の光）       車の窓の自分の顔 → 居間の窓を叩く → 玄関を叩く（澪が開ける）
##   play="ch7n" 21時半（y21 の光）      飲み会。4人と話す。大河と言い合い、外へ。私道を下りて、滑る
##   play="ch7b" 2時（y02 の光）         斜面の下で気がつく → 足を引きずって戻る → 玄関を叩く（開かない）→ 裏へ
## 押すキーはいつも Ｅ。夕方は押せば返ってくる。2時は、押しても音が鳴るだけ。
## 今夜（本編）の物は去年には無い：窓の板、撮影の機材、発電機のコード、ランタン、真琴。_last_year() で隠す。
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")

# ---------------------------------------------------------------- where things are (plan metres: x east, y north from the front wall)
const DOOR := [5.0, 0.0]
const PORCH_Z := -0.02                          # the porch's boards against the hall's floor
const CAR_STAND := [4.84, -8.14]                # beside the car, at its window
const CAR_LOOK := [5.6, -7.9, 0.13]            # the front door's window glass (z from the hall's floor)
const CAR_N := [-0.95, -0.32]                   # the glass's normal, out of the car (plan)
const CAR_EYE := 0.95                           # he stoops to the window
const WIN_X0 := 0.5                             # the living room's two south windows (from outside)
const WIN_X1 := 3.6
const WIN_AT := [2.95, -0.55]                    # where the unattended run stands to slap it
const WIN_Z := 1.25                             # where the palm lands (above the hall's floor)
const TABLE := [1.9, 1.85]                      # the living room's low table
const SEATS := {"kiryu": [3.1, 2.25], "taiga": [3.1, 1.3]}          # the sofa, facing west (ch2_21.gd)
const SIT := {"kiryu": "talk/sit_b", "taiga": "talk/sit_a"}
const STAND7 := {"natsuki": [1.95, 2.85], "mio": [0.95, 1.25]}
const HALL_NAT := [4.55, 2.35]                  # 夕方の扉: Natsuki in the hall behind Mio, the camera up
const HALL_MIO := [5.0, 0.85]                   # Mio, who opens it
const PARTY_ME := [2.2, 3.15]                   # Yota at the party, just inside the living room
const SIDE_AT := [5.8, -0.78]                  # beside the door on its latch side (seen from outside, the leaf swings out to the west: at 4.2 he stood behind it)
const OUT_AT := [5.0, -0.95]                    # on the porch, the door behind him
const DRIVE := [[5.0, -2.2], [6.4, -5.5], [8.6, -11.0], [10.6, -16.5], [12.4, -21.5]]   # down the drive (the unattended run)
const SLIP_Y := -19.5                           # past this on the drive, the edge gives
const WAKE_AT := [14.2, -20.4]                  # under the drive's shoulder
const BACK_ROUTE := [[12.6, -20.6], [10.6, -16.5], [8.6, -11.0], [6.4, -5.5], [5.0, -2.2], [5.0, -0.75]]
const EAST_ROUTE := [[6.9, -1.9], [10.9, -1.6], [11.6, 1.6]]
const CUT_AT := [11.4, 1.2]                     # round the east corner: the lit window at the back, the slope under his foot
const EYE := 1.6                                # Yota is taller than Mio (1.52)
const KNOCKS_TO_END := 6

var part := ""                 # ch7 | ch7n | ch7b
var stage := ""
var t_stage := 0.0
var card: Control
var card_t := 0.0
var black: ColorRect
var black_a := 0.0
var black_to := 0.0
var black_rate := 1.0
var demo7 := false
var start7 := ""
var dn                         # doors.gd
var door_closed := 0.0
var door_tw: Tween
var rig7: Node3D
var hand_l: Node3D
var hand_r: Node3D
var fill7: OmniLight3D
var door_sky7: Light3D
var mio_sky: OmniLight3D
var door_sky_e := 0.0
var door_sky_looked := false
var look_all := false
var talked7 := {}
var tgt7 := ""
var knocks := 0
var knock_idle := 0.0
var laugh_due := -1.0
var drunk := 0.0               # 0..1
var limp := 0.0                # 0..1
var watch: Node3D
var watch_up := false
var watch_k := 0.0
var watch_lit := false
var watch_said := false
var seg_mat: StandardMaterial3D
var seg_digits: Array = []
var conte_layer: CanvasLayer
var conte_rows: Array = []
var conte_done := [false, false, false]
var conte_up := false
var mirror: MeshInstance3D
var loops7 := {}
var said_light := false
var said_moon := false
var hour := 17
var minute := 40
var sec7 := 0.0
var page_clear_t := -1.0

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = []
	_load_story("ch7")
	_page()
	part = String(main.play)
	demo7 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	demo_on = demo7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch7at="): start7 = a.substr(8)
		if a == "--ch7probe": call_deferred("_probe")
	main.TALK = {}
	main.phones(false)
	_natsuki_cam()
	for e in main.torches:
		if is_instance_valid(e[0]): (e[0] as Node3D).visible = false
	_last_year()
	_load_mio()
	_lookers()
	if _has("mio"):
		var msk: Skeleton3D = main.S.mio_node.find_children("*", "Skeleton3D", true, false)[0]
		var lm := Look.new(); msk.add_child(lm)
		var fwd := msk.global_basis * Vector3(0, 0, 1); fwd.y = 0.0
		lm.setup(fwd.normalized()); looks["mio"] = lm
	_front_door()
	_black()
	_hands()
	_watch()
	_conte()
	player.eye_height = EYE; player.get_node("Head").position.y = EYE
	match part:
		"ch7": _ready_dusk()
		"ch7n": _ready_night()
		_: _ready_two()
	print("STORY ch7 part=%s start=%s" % [part, start7])

static func _load_story(file: String):
	D.load_all()
	if file in D.FILES or D.blocks.has("@" + file): return
	D.blocks["@" + file] = []
	var p := "res://story/%s.txt" % file
	if not FileAccess.file_exists(p): print("SCRIPT ERROR 台本: no file ", p); return
	var key := ""
	for raw in FileAccess.get_file_as_string(p).split("\n"):
		var ln := String(raw).strip_edges()
		if ln == "" or ln.begins_with("//"): continue
		if ln.begins_with("【") and ln.ends_with("】"): key = ln.substr(1, ln.length() - 2); D.blocks[key] = []
		elif key != "": D.blocks[key].append(String(raw).rstrip(" \t\r"))

# ---------------------------------------------------------------- last year's house
# what is tonight's and not last year's. The boards, the cord and the crew's lanterns are also off in the y times' own
# state (times.py); at dusk (tonight's light, borrowed) they are hidden here
const NOT_YET := ["board_", "gencord", "crew_", "lampshade_lantern_", "tpd_", "vcam_", "lcd", "recled", "fresnel", "fres_lens",
	"barndoor", "yoke", "cscol", "csleg", "tapebox", "cable", "furn_proj", "scan_tape_pack", "scan_stair_snacks", "scan_stair_mugs",
	"ext_slipok_cone", "ext_slipok_crack", "ext_slipok_mark", "reflector"]
func _last_year():
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		for pre in NOT_YET:
			if nm.begins_with(pre): (mi as Node3D).visible = false; break
	for k in ["makoto"]:
		if main.S.has(k + "_node"):
			(main.S[k + "_node"] as Node3D).visible = false
			if main.S.has(k + "_col"): (main.S[k + "_col"] as Node3D).global_position = Vector3(0, -50, 0)

# 澪の体（export_ch7.py）。4人（main.gd _t20_people）と同じ持ち方：体の glb、歩く、話す、当たり、顔の3枚
func _load_mio():
	if not ResourceLoader.exists("res://assets/dusk/mio.glb") or OS.get_cmdline_user_args().has("--nomio"): return
	main._load_scene("res://assets/dusk/mio.glb", "mio")
	var inst: Node3D = main.S.mio_node
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.extra_cull_margin = 1.0
		m3.layers = 8   # (see door_sky7)
		for i in range(m3.mesh.get_surface_count()):
			var mat := m3.get_active_material(i) as BaseMaterial3D
			if mat != null:
				var d := mat.duplicate() as BaseMaterial3D
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				m3.set_surface_override_material(i, d)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for ap in inst.find_children("*", "AnimationPlayer", true, false):
		var names: PackedStringArray = (ap as AnimationPlayer).get_animation_list()
		var lib := AnimationLibrary.new()
		if names.size() > 0:
			var an: Animation = (ap as AnimationPlayer).get_animation(names[0]).duplicate()
			an.loop_mode = Animation.LOOP_LINEAR; lib.add_animation("loop", an)
		(ap as AnimationPlayer).add_animation_library("t20", lib)
		if ResourceLoader.exists("res://assets/dusk/mio_talk.res"): (ap as AnimationPlayer).add_animation_library("talk", load("res://assets/dusk/mio_talk.res"))
	main._walk_anims("mio", inst)
	if FileAccess.file_exists("res://assets/dusk/ch7.json"):
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dusk/ch7.json"))
		if j is Dictionary and j.has("walk"): main.WALKJ["mio"] = j.walk
	var col := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new()
	cy.radius = 0.2; cy.height = 1.8; cs.shape = cy; cs.position.y = 0.9; col.add_child(cs); main.add_child(col)
	main.S["mio_col"] = col
	main.set_stand("mio", "talk/idle", 0.0)
	# her face: the surface named mio_face on the head, three pictures
	var head := inst.find_child("mio_head", true, false) as MeshInstance3D
	if head:
		var si := 0
		for i in range(head.get_surface_override_material_count()):
			var mm := head.get_active_material(i)
			if mm != null and String(mm.resource_name).ends_with("_face"): si = i
		var m := (head.get_active_material(si) as StandardMaterial3D).duplicate() as StandardMaterial3D
		head.set_surface_override_material(si, m)
		var tex := {}
		for st in ["open", "closed", "talk"]:
			for ext in ["jpg", "png"]:
				var pj := "res://assets/faces/mio_%s.%s" % [st, ext]
				if ResourceLoader.exists(pj): tex[st] = load(pj) as Texture2D
		if tex.size() == 3:
			m.albedo_texture = tex.open
			main.faces["mio"] = {"mat": m, "tex": tex, "next": randf_range(1.0, 4.0), "until": 0.0, "state": "open"}

func _has(k: String) -> bool:
	return main.S.has(k + "_node")

func _face(from: Array, to: Array) -> float:
	return atan2(to[0] - from[0], to[1] - from[1])

func _put(k: String, at: Array, yaw: float, z := 0.0):
	if _has(k): main.place_person(k, [at[0] - 4.8, 6.3 - at[1], z], yaw)

func _plan() -> Array:
	return [player.global_position.x + 4.8, player.global_position.z + 6.3]

func _cam() -> Camera3D:
	return player.get_node("Head/Camera")

func _after(sec: float, c: Callable):
	get_tree().create_timer(sec).timeout.connect(c)

# the ground under a plan point (Godot y), by a ray from above; the hall's floor where nothing is hit
func _ground(x: float, y: float) -> float:
	var from := gp(x, y, 6.0); var to := gp(x, y, -40.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else 0.0

func _stand_at(at: Array, look: Array, pitch_deg := -4.0):
	var gy := _ground(at[0], at[1])
	player.global_position = Vector3(at[0] - 4.8, gy + 0.02, at[1] - 6.3); player.velocity = Vector3.ZERO
	var to := Vector3(look[0] - at[0], 0.0, look[1] - at[1])
	player.yaw = atan2(-to.x, -to.z); player.pitch = deg_to_rad(pitch_deg)

func _probe():
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("C7ME ", _plan(), " y=", player.global_position.y, " eye=", player.eye_height)
	for l in main.find_children("*", "Light3D", true, false):
		var L := l as Light3D
		if L.visible and L.light_energy > 0.0: print("C7LIGHT ", L.name, " ", L.get_class(), " plan=(%.2f, %.2f, %.2f) e=%.2f" % [L.global_position.x + 4.8, L.global_position.z + 6.3, L.global_position.y, L.light_energy])
	for mi in main.find_children("*", "MeshInstance3D", true, false):
		var M := mi as MeshInstance3D
		if M.is_visible_in_tree() and absf(M.global_position.x + 4.8 - 5.0) < 0.8 and absf(M.global_position.z + 6.3) < 0.8: print("C7MESH ", M.name, " ", M.get_path(), " ", M.global_position)
	for yi in range(0, 17):
		var rowc := "C7CAR y=%.2f:" % (-6.0 - yi * 0.25)
		for xi in range(0, 21): rowc += " %5.2f" % _ground(3.5 + xi * 0.25, -6.0 - yi * 0.25)
		print(rowc)
	for y in range(2, -30, -2):
		var row := "C7GROUND y=%d:" % y
		for x in range(-2, 24, 2): row += " %5.2f" % _ground(float(x), float(y))
		print(row)

# ---------------------------------------------------------------- the front door (this chapter's, not doors.gd's)
func _front_door():
	dn = main.get_node_or_null("Doors")
	if dn:
		for k in dn.doors.keys():
			if dn.doors[k].pivot == main.door_pivot: dn.doors.erase(k)
	main.S.erase("knocks")   # main.gd shakes the door with the 23:00 knocks and holds it at the scene's angle: this chapter moves it itself
	if main.door_pivot:
		door_closed = float(main.S.get("door_rot", 0.0)) - deg_to_rad(float(main.ST.get("front", 0)))
		main.S["door_rot"] = door_closed
		main.door_pivot.rotation.y = door_closed
		main.door_pivot.position = main.S.get("door_rest", main.door_pivot.position)

# the porch's two steps are 11 cm each and square: coming up them from the drive the body stopped at the first (going down
# it only dropped). A ramp over them, unseen
func _porch_ramp():
	# (its plane clears each step's nose: flush with them, the body's round foot met the nose before the ramp lifted it)
	var y0 := -3.0; var y1 := -1.9; var z0 := _ground(5.0, -3.1); var z1 := -0.165
	if z0 > -0.3 or z0 < -0.9: z0 = -0.56
	var run := y1 - y0; var rise := z1 - z0
	var sb := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
	bx.size = Vector3(1.5, 0.06, Vector2(run, rise).length()); cs.shape = bx; sb.add_child(cs); main.add_child(sb)
	var ang := atan2(rise, run)
	sb.global_position = gp(5.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0) + Vector3(0, -0.03 * cos(ang), 0)
	sb.rotation.x = -ang
	var fl := StaticBody3D.new(); var cf := CollisionShape3D.new(); var bf := BoxShape3D.new()
	bf.size = Vector3(1.5, 0.06, 0.5); cf.shape = bf; fl.add_child(cf); main.add_child(fl)
	fl.global_position = gp(5.0, -1.67, z1 - 0.03)

func _door_to(deg: float, dur: float):
	if main.door_pivot == null: return
	if door_tw and door_tw.is_valid(): door_tw.kill()
	door_tw = create_tween()
	door_tw.tween_property(main.door_pivot, "rotation:y", door_closed + deg_to_rad(deg) * float(main.S.get("door_sign", 1.0)), dur).set_trans(Tween.TRANS_SINE)

func _near_door(r := 1.7) -> bool:
	var p := _plan()
	return p[1] < 0.2 and Vector2(p[0] - DOOR[0], p[1] - DOOR[1]).length() < r

# ---------------------------------------------------------------- black (the cuts between the hours)
func _black():
	var bl := CanvasLayer.new(); bl.layer = 22; add_child(bl)
	black = ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE; bl.add_child(black)

func _fade(to: float, sec: float):
	black_to = to
	if sec <= 0.0: black_a = to; black.color.a = to
	else: black_rate = 1.0 / sec

func _black_tick(dt: float):
	if black_a != black_to:
		black_a = move_toward(black_a, black_to, dt * black_rate); black.color.a = black_a

func _next_part(p: String):
	main.to_chapter(p)
	if main.COVER and is_instance_valid(main.COVER): (main.COVER.get_child(0) as ColorRect).color = Color(0, 0, 0)   # black to black: not the card's paper between

# ---------------------------------------------------------------- sound
func _loop7(name: String, db: float, at = null):
	if "--nosound" in OS.get_cmdline_user_args() or loops7.has(name): return
	var s := Sound.stream(name, true)
	if s == null: return
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new(); p3.stream = s; p3.unit_size = 4.0; p3.max_db = 0.0; add_child(p3); p3.global_position = at; p = p3
	else:
		var p2 := AudioStreamPlayer.new(); p2.stream = s; add_child(p2); p = p2
	p.set("volume_db", db); p.call("play")
	loops7[name] = p

func _loop_db(name: String, db: float, sec := 1.0):
	if not loops7.has(name): return
	create_tween().tween_property(loops7[name], "volume_db", db, sec)

func _one(name: String, db := 0.0, at = null):
	if "--nosound" in OS.get_cmdline_user_args(): return
	Sound.one(self, name, db, at)

# Natsuki shoots hand-held (七.夏希「手持ちで撮れてた」): the small camcorder (props/minicam.glb, story.gd _fixed_cam's model) where
# her phone is in 2026, in the hand that the 20:00 stand holds up. At the party it lies on the low table
var nat_cam: Node3D
func _natsuki_cam():
	if not _has("natsuki") or not ResourceLoader.exists("res://props/minicam.glb"): return
	var np := (main.S.natsuki_node as Node3D).find_child("nphone", true, false) as Node3D
	if np == null: return
	nat_cam = (load("res://props/minicam.glb") as PackedScene).instantiate()
	for mi in nat_cam.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	np.get_parent().add_child(nat_cam)
	nat_cam.transform = np.transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -0.02))
	nat_cam.visible = false

func _nat_cam_up(on: bool):
	if nat_cam: nat_cam.visible = on
	if _has("natsuki"): main.set_stand("natsuki", "t20/loop" if on else "talk/idle", 0.4)

# the party's table: cans, paper cups, a bag of snacks, a plate, the big bottle. Plain shapes in the print's three inks
func _party_props():
	var q := PhysicsRayQueryParameters3D.create(gp(TABLE[0], TABLE[1], 1.2), gp(TABLE[0], TABLE[1], -0.5))
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	var top: float = float(hit.position.y) if not hit.is_empty() else 0.38
	if top < 0.2 or top > 0.6: top = 0.38
	var root := Node3D.new(); root.name = "party7"; main.add_child(root); root.global_position = Vector3(TABLE[0] - 4.8, top, TABLE[1] - 6.3)
	var mat := func(c: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal; return m
	var put := func(mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = m; root.add_child(mi)
		mi.position = pos; mi.rotation_degrees = rot; mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC; return mi
	var can := CylinderMesh.new(); can.top_radius = 0.031; can.bottom_radius = 0.033; can.height = 0.122; can.radial_segments = 20
	var lid := CylinderMesh.new(); lid.top_radius = 0.026; lid.bottom_radius = 0.031; lid.height = 0.006; lid.radial_segments = 20
	var silver := mat.call(Color(0.78, 0.78, 0.76), 0.3, 0.7) as StandardMaterial3D
	var inks := [Color(0.82, 0.8, 0.74), Color(0.12, 0.3, 0.5), Color(0.8, 0.36, 0.2), Color(0.82, 0.8, 0.74), Color(0.1, 0.22, 0.2), Color(0.8, 0.36, 0.2), Color(0.12, 0.3, 0.5)]
	# (x east, z south) on the table's top, metres from its middle; the last two have fallen
	var cans := [[-0.16, -0.22, 0], [0.12, -0.3, 0], [0.17, 0.05, 0], [-0.05, 0.27, 0], [0.2, 0.34, 0], [-0.2, 0.1, 1], [0.02, -0.08, 1]]
	for i in cans.size():
		var c: Array = cans[i]; var m := mat.call(inks[i], 0.35, 0.3) as StandardMaterial3D
		if int(c[2]) == 0:
			put.call(can, m, Vector3(c[0], 0.061, c[1])); put.call(lid, silver, Vector3(c[0], 0.125, c[1]))
		else:
			put.call(can, m, Vector3(c[0], 0.033, c[1]), Vector3(90, 35.0 + 70.0 * i, 0))
	var cup := CylinderMesh.new(); cup.top_radius = 0.037; cup.bottom_radius = 0.026; cup.height = 0.088; cup.radial_segments = 18
	var paper := mat.call(Color(0.93, 0.91, 0.85), 0.8) as StandardMaterial3D
	for c in [[-0.08, -0.38], [0.24, -0.14], [-0.22, 0.36]]: put.call(cup, paper, Vector3(c[0], 0.044, c[1]))
	# the plate, what is left on it
	var plate := CylinderMesh.new(); plate.top_radius = 0.115; plate.bottom_radius = 0.09; plate.height = 0.014; plate.radial_segments = 28
	put.call(plate, paper, Vector3(0.0, 0.007, 0.12))
	var bean := CapsuleMesh.new(); bean.radius = 0.008; bean.height = 0.05
	var green := mat.call(Color(0.35, 0.5, 0.3), 0.7) as StandardMaterial3D
	for i in 7: put.call(bean, green, Vector3(0.05 * cos(i * 2.4) * (0.4 + 0.1 * i), 0.022, 0.12 + 0.05 * sin(i * 2.4) * (0.4 + 0.1 * i)), Vector3(90, i * 53.0, 0))
	# the snack bag, torn open and lying
	var bag := BoxMesh.new(); bag.size = Vector3(0.17, 0.035, 0.24)
	put.call(bag, mat.call(Color(0.8, 0.36, 0.2), 0.45), Vector3(-0.24, 0.02, -0.12), Vector3(0, 24, 4))
	var bag2 := BoxMesh.new(); bag2.size = Vector3(0.11, 0.004, 0.1)
	put.call(bag2, mat.call(Color(0.93, 0.91, 0.85), 0.6), Vector3(-0.24, 0.04, -0.12), Vector3(0, 24, 4))
	# the big bottle (a 4-litre plastic one, the kind a film crew buys), and its cap beside it
	var bot := CylinderMesh.new(); bot.top_radius = 0.07; bot.bottom_radius = 0.075; bot.height = 0.26; bot.radial_segments = 24
	var neck := CylinderMesh.new(); neck.top_radius = 0.02; neck.bottom_radius = 0.065; neck.height = 0.07; neck.radial_segments = 24
	var glass := mat.call(Color(0.5, 0.62, 0.66), 0.15) as StandardMaterial3D
	put.call(bot, glass, Vector3(0.22, 0.13, -0.42)); put.call(neck, glass, Vector3(0.22, 0.295, -0.42))
	var lab := CylinderMesh.new(); lab.top_radius = 0.0755; lab.bottom_radius = 0.0755; lab.height = 0.11; lab.radial_segments = 24
	put.call(lab, paper, Vector3(0.22, 0.14, -0.42))
	# Natsuki's camcorder, put down for the night
	if ResourceLoader.exists("res://props/minicam.glb"):
		var cam: Node3D = (load("res://props/minicam.glb") as PackedScene).instantiate(); root.add_child(cam)
		cam.position = Vector3(-0.02, 0.1, 0.42); cam.rotation_degrees = Vector3(0, 200, 0)

# ================================================================ 夕方
func _ready_dusk():
	hour = 17; minute = 40
	var c: Array = D.lines("七.カード")
	card = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], ["", 36, 0]], Type.card())   # the third row (the question) is left empty
	card_t = 2.75
	stage = "card"
	if start7 != "": card_t = 0.3
	for k in SEATS:
		_put(k, SEATS[k], _face(SEATS[k], [1.0, SEATS[k][1]])); main.set_stand(k, SIT[k], 0.0)
	_put("natsuki", STAND7.natsuki, _face(STAND7.natsuki, TABLE)); _nat_cam_up(true)
	_put("mio", STAND7.mio, _face(STAND7.mio, TABLE))
	_mirror()
	_loop7("c7_higurashi", -14.0)
	call_deferred("_place_dusk")

func _place_dusk():
	await get_tree().physics_frame
	await get_tree().physics_frame
	_porch_ramp()
	_stand_at(CAR_STAND, CAR_LOOK, 0.0)
	player.eye_height = CAR_EYE; player.get_node("Head").position.y = CAR_EYE
	var eye := Vector3(player.global_position.x, player.global_position.y + CAR_EYE, player.global_position.z)
	var to := gp(CAR_LOOK[0], CAR_LOOK[1], CAR_LOOK[2]) - eye
	player.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))
	if mirror: _mirror_place()
	if "--ch7trace" in OS.get_cmdline_user_args(): print("C7ME ", _plan(), " y=", player.global_position.y, " eye=", player.eye_height, " cam=", _cam().global_position)

# his own face in the car's window, the make-up on (画像 E). A reflection in a pane is half the size of what it shows
# and sits on the glass straight before the eye: a picture on the pane, moving as his head does
func _mirror():
	var p := "res://props/yota_mirror.png"
	if not ResourceLoader.exists(p): return
	mirror = MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.36, 0.36); mirror.mesh = q
	var m := StandardMaterial3D.new(); m.albedo_texture = load(p); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(0.74, 0.76, 0.78, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.no_depth_test = true; m.render_priority = 3
	mirror.material_override = m; mirror.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(mirror)
	# the pane behind his head is dark with his own shadow (he stands between it and the sky): without it the white make-up was
	# the print's bare paper on the lit seats, and nothing read
	var sh := MeshInstance3D.new(); var q2 := QuadMesh.new(); q2.size = Vector2(0.44, 0.44); sh.mesh = q2
	var m2 := StandardMaterial3D.new(); m2.albedo_texture = load(p); m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m2.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	m2.cull_mode = BaseMaterial3D.CULL_DISABLED; m2.no_depth_test = true; m2.render_priority = 2
	sh.material_override = m2; sh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; sh.name = "shade"; sh.position = Vector3(0, -0.02, -0.002)
	mirror.add_child(sh)

func _mirror_place():
	var eye: Vector3 = _cam().global_position
	var g0 := gp(CAR_LOOK[0], CAR_LOOK[1], CAR_LOOK[2])
	var n := Vector3(CAR_N[0], 0.0, CAR_N[1]).normalized()
	var d := (eye - g0).dot(n)
	var foot := eye - n * d
	foot.y = clampf(foot.y - 0.03, g0.y - 0.06, g0.y + 0.06)   # the pane is only so tall: the head keeps inside it
	mirror.global_position = foot + n * 0.02
	mirror.global_basis = Basis.looking_at(-n, Vector3.UP)

func _mirror_tick(dt: float):
	if mirror == null: return
	var m := mirror.material_override as StandardMaterial3D
	var want := 0.0
	if stage in ["mirror", "to_window"] or "--ch7mirror" in OS.get_cmdline_user_args():
		_mirror_place()
		var eye: Vector3 = _cam().global_position
		var d := (eye - mirror.global_position).length()
		var along := absf((eye - gp(CAR_LOOK[0], CAR_LOOK[1], CAR_LOOK[2])).dot(Vector3(-CAR_N[1], 0.0, CAR_N[0]).normalized()))
		want = clampf((1.7 - d) / 0.7, 0.0, 1.0) * clampf((0.42 - along) / 0.15, 0.0, 1.0) * 0.85
		if "--ch7mirror" in OS.get_cmdline_user_args(): want = 1.0
	m.albedo_color.a = move_toward(m.albedo_color.a, want, dt * 1.2)
	((mirror.get_node("shade") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(0.02, 0.06, 0.1, m.albedo_color.a * 0.75)
	mirror.visible = m.albedo_color.a > 0.005
	# he straightens up as he leaves the car
	if stage == "to_window" and player.eye_height < EYE - 0.01:
		var away := Vector2(_plan()[0] - CAR_STAND[0], _plan()[1] - CAR_STAND[1]).length()
		var h := lerpf(CAR_EYE, EYE, clampf(away / 0.8, 0.0, 1.0))
		if h > player.eye_height: player.eye_height = h; player.get_node("Head").position.y = h

func _begin(st: String):
	stage = st; t_stage = 0.0
	print("STORY ch7 %s t=%.1f" % [st, t_now])
	if "--ch7trace" in OS.get_cmdline_user_args():
		for l in main.find_children("*", "Light3D", true, false):
			var L := l as Light3D
			if L.visible and L.light_energy > 0.0 and absf(L.global_position.x + 4.8 - 5.0) < 1.5 and absf(L.global_position.z + 6.3) < 2.5: print("C7LIGHT ", L.name, " ", L.get_class(), " plan=(%.2f, %.2f, %.2f) e=%.2f mask=%d" % [L.global_position.x + 4.8, L.global_position.z + 6.3, L.global_position.y, L.light_energy, L.light_cull_mask], " doorsky=", main.lights.get("doorsky") == L)
		if main.door_pivot: print("C7DOOR rot=%.3f closed=%.3f" % [main.door_pivot.rotation.y, door_closed])
	match st:
		"mirror":
			_start(B("七.夕方"))
		"to_window":
			_set_mission(String(D.lines("七.夕方")[-1]).substr(1))
		"to_door":
			if _has("natsuki"): main.walk_to("natsuki", [[2.9, 3.2, 0.0], [3.55, 3.75, 0.0], [HALL_NAT[0], HALL_NAT[1], 0.0]], Callable(), _face(HALL_NAT, DOOR))
			if _has("mio"): main.walk_to("mio", [[2.9, 3.2, 0.0], [3.55, 3.75, 0.0], [4.9, 2.6, 0.0], [HALL_MIO[0], HALL_MIO[1], -0.18]], Callable(), _face(HALL_MIO, DOOR))
		"party":
			_start(B("七.夜"))
		"outside":
			_start(B("七.外"))
		"wake":
			_start(B("七.下"))
		"door2":
			pass
		"to_back":
			pass

# ================================================================ 21時半
func _ready_night():
	hour = 21; minute = 30
	for k in SEATS:
		_put(k, SEATS[k], _face(SEATS[k], [1.0, SEATS[k][1]])); main.set_stand(k, SIT[k], 0.0)
	_put("natsuki", STAND7.natsuki, _face(STAND7.natsuki, TABLE)); main.set_stand("natsuki", "talk/idle", 0.0)
	_put("mio", STAND7.mio, _face(STAND7.mio, TABLE))
	player.global_position = gp(PARTY_ME[0], PARTY_ME[1], 0.0)
	var to := Vector3(TABLE[0] - PARTY_ME[0], 0.0, TABLE[1] - PARTY_ME[1])
	player.yaw = atan2(-to.x, -to.z); player.pitch = deg_to_rad(-8.0)
	_fade(1.0, 0.0); _fade(0.0, 1.8)
	_loop7("c7_crickets", -18.0)
	call_deferred("_party_props")
	drunk = 0.35
	if start7 == "out": call_deferred("_go_out_now")
	else: _begin("party")

func _talk_target() -> String:
	if stage != "party" or mode != FREE: return ""
	var eye: Vector3 = _cam().global_position; var fwd: Vector3 = -_cam().global_basis.z
	var best := ""; var bd := 0.8
	for k in ["kiryu", "natsuki", "mio", "taiga"]:
		var at: Array = SEATS.get(k, STAND7.get(k, [0, 0]))
		var pos := gp(at[0], at[1], 1.2 if STAND7.has(k) else 0.95)
		if _has(k): pos = main._rig_of(k).global_position + Vector3(0, 1.2 if STAND7.has(k) else 0.95, 0)
		var to := pos - eye
		if to.length() > 2.6: continue
		var c := fwd.dot(to.normalized())
		if c > bd: bd = c; best = k
	return best

const NAME7 := {"kiryu": "桐生", "natsuki": "夏希", "mio": "澪", "taiga": "大河"}
func _talk_to(k: String):
	if k == "": return
	if talked7.has(k) and k != "taiga": return
	talked7[k] = true
	talk_with = k
	_start(B("七." + NAME7[k]))

func _go_out_now():
	stage = "going"; script_q.clear(); mode = FREE
	_fade(1.0, 0.9)
	_after(1.2, func():
		hour = 23; minute = 10
		look_all = false
		_stand_at(OUT_AT, [5.0, -8.0], -3.0)
		main.door_pivot.rotation.y = door_closed
		_one("door_close", -6.0)
		_loop_db("c7_crickets", -9.0, 0.5)
		_loop7("c7_party", -15.0, gp(2.0, 0.2, 1.2))
		drunk = 1.0
		_fade(0.0, 1.4)
		_begin("outside"))

func _slip_now():
	if stage != "outside": return
	stage = "slip"; t_stage = 0.0
	_start(B("七.滑る"))

# ================================================================ 2時
func _ready_two():
	hour = 1; minute = 50
	for k in ["kiryu", "taiga", "natsuki", "mio"]:
		if _has(k):
			main._rig_of(k).visible = false
			if main.S.has(k + "_col"): (main.S[k + "_col"] as Node3D).global_position = Vector3(0, -50, 0)
	_fade(1.0, 0.0)
	_loop7("c7_crickets", -9.0)
	limp = 1.0
	call_deferred("_place_two")

func _place_two():
	await get_tree().physics_frame
	await get_tree().physics_frame
	_porch_ramp()
	match start7:
		"door2":
			_stand_at([5.0, -2.4], DOOR, 0.0); _fade(0.0, 0.5); hour = 2; minute = 4; _begin("door2"); _set_mission("戻る")
		"back":
			_stand_at([5.0, -0.9], DOOR, 0.0); _fade(0.0, 0.5); hour = 2; minute = 7; knocks = KNOCKS_TO_END; _door_end()
		_:
			_stand_at(WAKE_AT, [WAKE_AT[0] - 3.0, WAKE_AT[1] + 2.0], 38.0)
			player.eye_height = 0.4; player.get_node("Head").position.y = 0.4
			_begin("wake")

func _eye_to(h: float, dur: float):
	create_tween().tween_method(func(v: float): player.eye_height = v; player.get_node("Head").position.y = v, player.eye_height, h, dur).set_trans(Tween.TRANS_SINE)

func _knock2():
	if mode != FREE or stage != "door2": return
	knocks += 1; knock_idle = 0.0
	if knocks <= 3:
		_start(B("七.扉二." + ["一", "二", "三"][knocks - 1]))
	else:
		_do("knock_real")
		if knocks >= KNOCKS_TO_END: _after(2.2, _door_end)

func _door_end():
	if stage == "door_end" or (stage != "door2" and start7 != "back"): return
	stage = "door_end"
	_start(B("七.扉二.終わり"))

# ================================================================ what the lines set off
func _do(what: String):
	print("STORY ch7 do %s t=%.1f" % [what, t_now])
	match what:
		"mirror":
			pass
		"window_slap":
			_slap()
			look_all = true
			if _has("taiga"):
				var rig: Node3D = main._rig_of("taiga"); var p0 := rig.global_position
				var tw := create_tween()
				tw.tween_property(rig, "global_position", p0 + Vector3(0.22, 0, 0), 0.18)
				tw.parallel().tween_property(rig, "rotation:x", deg_to_rad(-9.0), 0.18)
				tw.tween_interval(0.9)
				tw.tween_property(rig, "global_position", p0, 0.8).set_trans(Tween.TRANS_SINE)
				tw.parallel().tween_property(rig, "rotation:x", 0.0, 0.8)
			if _has("natsuki"):
				var nr: Node3D = main._rig_of("natsuki")
				var me := _plan(); var at := [nr.global_position.x + 4.8, nr.global_position.z + 6.3]
				create_tween().tween_property(nr, "rotation:y", nr.rotation.y + wrapf(_face(at, me) - nr.rotation.y, -PI, PI), 0.5)
			conte_done[0] = true; _conte_fill()
		"knock_play":
			_knock_hand(true); _one("knock", -2.0, gp(DOOR[0], DOOR[1], 1.2))
		"door_open":
			# the door swings out: he steps to its latch side, out of the doorway's sight, and
			# waits. She opens it and leans out to look for him
			var side := gp(SIDE_AT[0], SIDE_AT[1], 0.0); side.y = player.global_position.y
			var to := gp(DOOR[0], 0.25, 1.35) - Vector3(side.x, side.y + EYE, side.z)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(player, "global_position", side, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(player, "yaw", player.yaw + wrapf(atan2(-to.x, -to.z) - player.yaw, -PI, PI), 0.8).set_trans(Tween.TRANS_SINE)
			tw.tween_property(player, "pitch", asin(clampf(to.normalized().y, -1.0, 1.0)), 0.8)
			player.velocity = Vector3.ZERO
			_after(0.9, func():
				_one("door_open", -4.0, gp(DOOR[0], DOOR[1], 1.0))
				_door_to(82.0, 0.7)
				if _has("mio"):
					var rig: Node3D = main._rig_of("mio")
					var out := gp(DOOR[0] - 0.05, 0.18, -0.18)
					var tm := create_tween()
					tm.tween_interval(0.5)
					tm.tween_property(rig, "global_position", out, 0.9).set_trans(Tween.TRANS_SINE)
					tm.parallel().tween_property(rig, "rotation:y", _face([DOOR[0], 0.18], SIDE_AT), 0.9).set_delay(0.3))
			talk_with = "mio"
		"lunge":
			_lunge()
			conte_done[1] = true; _conte_fill()
		"fade_out":
			stage = "fade"; script_q.clear(); mode = FREE
			_set_mission("")
			_fade(1.0, 1.6)
			_after(3.4, func():
				if demo7 and "--ch7only" in OS.get_cmdline_user_args(): print("DEMO DONE ch7 dusk"); get_tree().quit(); return
				DEMO_HOUSE = demo7
				_next_part("ch7n"))
		"night":
			pass
		"go_out":
			_go_out_now()
		"outside":
			pass
		"slip":
			_one("c7_slip", -3.0)
			var cam := _cam()
			var tw := create_tween().set_parallel(true)
			tw.tween_property(cam, "rotation:z", deg_to_rad(-38.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(cam, "position:y", -0.75, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(player, "pitch", deg_to_rad(28.0), 0.45)
			_after(0.5, func():
				_fade(1.0, 0.0)   # a cut, not a fade
				_loop_db("c7_party", -60.0, 0.1)
				_one("body_fall", -4.0))
			_after(4.2, func():
				DEMO_HOUSE = demo7
				_next_part("ch7b"))
		"wake":
			_fade(0.0, 4.0)
			_after(5.0, func(): _eye_to(EYE - 0.12, 2.6); create_tween().tween_property(player, "pitch", deg_to_rad(-6.0), 2.6).set_trans(Tween.TRANS_SINE))
		"watch":
			watch_said = true
			_watch_show(true); _after(3.2, func(): if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): _watch_show(false))
		"knock_real":
			_knock_hand(false); _one("knock_weak" if knocks > 3 else "knock", -3.0, gp(DOOR[0], DOOR[1], 1.2))
		"inside_voices":
			_one("c7_voices", -13.0, gp(2.6, 0.9, 1.2))
		"inside_laugh":
			_one("c7_laugh", -12.0, gp(2.6, 0.9, 1.2))
		"conte_add":
			conte_done[2] = true
			_conte_fill(true)
			_conte_show(true); _one("c7_pencil", -8.0)
			_after(3.6, func(): _conte_show(false))
			_after(3.8, func(): if stage == "door_end": _begin("to_back"))
			hour = 2; minute = 7
		"cut":
			script_q.clear(); mode = END
			_fade(1.0, 0.0)
			_set_mission(""); _clear_page()
			_after(1.0, func(): _start_end())
		"end":
			pass
		_: super._do(what)

func _start_end():
	# black. The crickets go on, and stop
	_after(5.0, func(): _loop_db("c7_crickets", -70.0, 0.05))
	_after(8.0, func():
		if demo7: print("DEMO ch7 t=%.1f fails=%d" % [t_now, DEMO_FAILS])
		if demo7 and "--ch7only" in OS.get_cmdline_user_args(): print("DEMO DONE ch7"); get_tree().quit(); return
		DEMO_HOUSE = demo7
		if main.has_method("next_chapter"): main.call("next_chapter", "ch7")
		else: _next_part("ch11"))

# ================================================================ his hands
# 澪の腕と同じ作り（ch6.gd _mk_arm）。陽太の腕（props/yota_arm_l|r.glb）ができるまでは澪の腕で形だけ
func _hands():
	rig7 = Node3D.new(); rig7.name = "rig7"; _cam().add_child(rig7)
	hand_l = _mk_arm(true); hand_r = _mk_arm(false)
	if hand_l == null: return
	rig7.add_child(hand_l); rig7.add_child(hand_r)
	hand_l.visible = false; hand_r.visible = false
	hand_l.position = Vector3(-0.2, -0.6, -0.3); hand_r.position = Vector3(0.2, -0.6, -0.3)
	fill7 = OmniLight3D.new(); fill7.light_color = Color(0.85, 0.9, 1.0); fill7.light_energy = 0.0; fill7.omni_range = 1.0; fill7.omni_attenuation = 1.4
	fill7.shadow_enabled = false; fill7.light_specular = 0.05; fill7.light_cull_mask = 2; fill7.position = Vector3(0.0, 0.1, 0.05); rig7.add_child(fill7)

func _arm_path(left: bool) -> String:
	var s := "l" if left else "r"
	for who in ["yota", "mio"]:
		if ResourceLoader.exists("res://props/%s_arm_%s.glb" % [who, s]): return "res://props/%s_arm_%s.glb" % [who, s]
	return ""

func _mk_arm(left: bool) -> Node3D:
	var path := _arm_path(left)
	if path == "": return null
	var h := Node3D.new(); h.name = "hand_l" if left else "hand_r"
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	h.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; m.extra_cull_margin = 0.6; m.layers = 2 | 16   # (not layer 1: door_sky7 burnt the arms to paper in the doorway)
	var fb := []
	var to_h := Transform3D(); var nd2: Node3D = sk
	while nd2 != h: to_h = nd2.transform * to_h; nd2 = nd2.get_parent()
	for f in ["index", "middle", "ring", "pinky", "thumb"]:
		for j in 3:
			var bi := sk.find_bone("%s_0%d_%s" % [f, j + 1, "l" if left else "r"])
			if bi < 0: continue
			var gb: Basis = (to_h * sk.get_bone_global_rest(bi)).basis.orthonormalized()
			var ax: Vector3 = (gb.y.cross(Vector3.DOWN)).normalized()
			if f == "thumb":
				var o: Vector3 = (to_h * sk.get_bone_global_rest(bi)).origin
				ax = gb.y.cross((Vector3(0.0, -0.035, -0.075) - o).normalized()).normalized()
			fb.append({"i": bi, "ax": (gb.inverse() * ax).normalized(), "thumb": f == "thumb", "j": j})
	h.set_meta("sk", sk); h.set_meta("fb", fb); h.set_meta("curl", 0.0)
	_curl(h, 0.25)
	return h

# the fingers' curl: 0 flat, 1.3 a fist
func _curl(h: Node3D, a: float):
	if h == null: return
	var sk: Skeleton3D = h.get_meta("sk")
	h.set_meta("curl", a)
	for b in h.get_meta("fb"):
		var ang: float = (a * 0.6 * [0.30, 0.55, 0.40][b.j]) if b.thumb else (a * [0.80, 1.05, 0.70][b.j])
		sk.set_bone_pose_rotation(b.i, sk.get_bone_rest(b.i).basis.get_rotation_quaternion() * Quaternion(b.ax, ang))

func _curl_to(h: Node3D, a: float, dur := 0.3):
	if h == null: return
	create_tween().tween_method(func(v: float): _curl(h, v), float(h.get_meta("curl")), a, dur)

func _hq(deg: Vector3) -> Quaternion:
	return Quaternion(Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)), EULER_ORDER_YXZ))

func _hand_to(h: Node3D, pos: Vector3, deg: Vector3, dur := 0.4) -> Tween:
	if h == null: return create_tween()
	if h.has_meta("tw") and (h.get_meta("tw") as Tween).is_valid(): (h.get_meta("tw") as Tween).kill()
	h.visible = true
	var tw := create_tween()
	tw.tween_property(h, "position", pos, dur).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(h, "quaternion", _hq(deg), dur).set_trans(Tween.TRANS_SINE)
	h.set_meta("tw", tw)
	return tw

func _hand_away(h: Node3D, dur := 0.5):
	if h == null: return
	var side := -1.0 if h == hand_l else 1.0
	var tw := _hand_to(h, Vector3(0.24 * side, -0.66, -0.25), Vector3(30, 0, 0), dur)
	tw.tween_callback(func(): h.visible = false)

# the fist on the door: three raps (play: quick and loud; real: slower, the third weaker)
const KNOCK_POS := Vector3(0.13, -0.14, -0.36)
const KNOCK_DEG := Vector3(62, 8, -78)
func _knock_hand(play: bool):
	if hand_r == null: return
	_curl(hand_r, 1.25)
	var tw := _hand_to(hand_r, KNOCK_POS, KNOCK_DEG, 0.22)
	var gap := 0.16 if play else 0.24
	for i in 3:
		tw.tween_property(hand_r, "position", KNOCK_POS + Vector3(0, 0.01, -0.09), gap * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(hand_r, "position", KNOCK_POS, gap * 0.55)
	tw.tween_interval(0.5 if play else 1.1)
	tw.tween_callback(func(): _hand_away(hand_r))

# both palms on the living room's window
const SLAP_DEG := Vector3(82, 0, 0)
func _slap():
	_one("c7_slap", 0.0)
	# square to the pane and an arm's length from it, wherever along the windows he stood: the palms land on the glass
	var tw9 := create_tween().set_parallel(true)
	tw9.tween_property(player, "yaw", player.yaw + wrapf(PI - player.yaw, -PI, PI) * 0.8, 0.12)
	tw9.tween_property(player, "pitch", deg_to_rad(-3.0), 0.12)
	tw9.tween_property(player, "global_position:z", -0.54 - 6.3, 0.12)
	var cx := 1.2 if _plan()[0] < 2.1 else 2.95   # (the two windows' middles; between them is wall)
	tw9.tween_property(player, "global_position:x", clampf(_plan()[0], cx - 0.22, cx + 0.22) - 4.8, 0.12)
	if hand_r == null: return
	_curl(hand_l, 0.05); _curl(hand_r, 0.05)
	for h in [hand_l, hand_r]:
		var side := -1.0 if h == hand_l else 1.0
		var at := Vector3(0.17 * side, -0.05, -0.40)
		(h as Node3D).position = at + Vector3(0.05 * side, -0.25, 0.22); (h as Node3D).quaternion = _hq(Vector3(40, 0, 0))
		var tw := _hand_to(h, at, SLAP_DEG + Vector3(0, 0, -12.0 * side), 0.13)
		tw.tween_interval(1.5)
		tw.tween_property(h, "position", at + Vector3(0, -0.07, 0.0), 1.2).set_trans(Tween.TRANS_SINE)   # the palms drag down the glass
		tw.tween_callback(func(): _hand_away(h))

# at Mio in the doorway: the hands up, a lurch in
func _lunge():
	_one("c7_scream", -4.0, gp(HALL_MIO[0], HALL_MIO[1], 1.4))
	# out from beside the door into the doorway, onto her
	var dst := gp(DOOR[0] + 0.22, -0.5, 0.0); dst.y = player.global_position.y
	var to := gp(DOOR[0] - 0.05, 0.5, 1.4) - Vector3(dst.x, dst.y + EYE, dst.z)
	var twp := create_tween().set_parallel(true)
	twp.tween_property(player, "global_position", dst, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	twp.tween_property(player, "yaw", player.yaw + wrapf(atan2(-to.x, -to.z) - player.yaw, -PI, PI), 0.2)
	twp.tween_property(player, "pitch", asin(clampf(to.normalized().y, -1.0, 1.0)), 0.2)
	var tw0 := create_tween()
	tw0.tween_property(player, "lean", 0.42, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw0.tween_interval(0.5)
	tw0.tween_property(player, "lean", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	if _has("mio"):
		var rig: Node3D = main._rig_of("mio"); var p0 := rig.global_position
		var tw := create_tween()
		tw.tween_property(rig, "global_position", p0 + Vector3(0.12, 0, 0.6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hand_r == null: return
	_curl(hand_l, 0.55); _curl(hand_r, 0.55)
	for h in [hand_l, hand_r]:
		var side := -1.0 if h == hand_l else 1.0
		var at := Vector3(0.2 * side, -0.02, -0.42)
		var tw := _hand_to(h, at, Vector3(55, 0, -20.0 * side), 0.15)
		tw.tween_interval(0.9)
		tw.tween_callback(func(): _hand_away(h, 0.8))

# ================================================================ his watch (the chapter's clock: 右クリック, held)
# a cheap digital watch on the left wrist. Seven-segment digits made of small bars; at 2:00 the light's button turns them green
const SEG := {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg"}
func _watch():
	if hand_l == null: return
	watch = Node3D.new(); watch.name = "watch"; hand_l.add_child(watch)
	watch.position = Vector3(0.0, 0.031, 0.03)
	var blackm := StandardMaterial3D.new(); blackm.albedo_color = Color(0.05, 0.05, 0.055); blackm.roughness = 0.6
	var strap := MeshInstance3D.new(); var sm := BoxMesh.new(); sm.size = Vector3(0.07, 0.006, 0.022); strap.mesh = sm; strap.material_override = blackm; watch.add_child(strap)
	var body := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.04, 0.011, 0.036); body.mesh = bm; body.material_override = blackm; body.position.y = 0.005; watch.add_child(body)
	var face := MeshInstance3D.new(); var fm := QuadMesh.new(); fm.size = Vector2(0.03, 0.02); face.mesh = fm
	seg_mat = StandardMaterial3D.new(); seg_mat.albedo_color = Color(0.56, 0.6, 0.5); seg_mat.roughness = 0.4
	face.material_override = seg_mat; face.rotation.x = -PI / 2.0; face.position.y = 0.0108; watch.add_child(face)
	var dark := StandardMaterial3D.new(); dark.albedo_color = Color(0.06, 0.07, 0.06); dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var holder := Node3D.new(); holder.position.y = 0.011; holder.rotation.y = PI / 2.0; watch.add_child(holder)   # read along the arm
	holder.set_meta("mat", dark)
	watch.set_meta("digits", holder)
	for mi in watch.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).layers = 2 | 16; (mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_watch_set()

func _watch_set():
	if watch == null: return
	var holder: Node3D = watch.get_meta("digits")
	for c in holder.get_children(): holder.remove_child(c); c.queue_free()
	var text := "%d:%02d" % [hour, minute]
	var w := 0.0052; var hgt := 0.0095; var th := 0.0011
	var x := -0.5 * (text.length() - 1) * (w + 0.0022)
	for ch in text:
		if ch == ":":
			for dy in [-0.002, 0.002]:
				var d := MeshInstance3D.new(); var q := BoxMesh.new(); q.size = Vector3(th, 0.0002, th); d.mesh = q
				d.material_override = holder.get_meta("mat"); d.position = Vector3(x, 0, dy); holder.add_child(d)
		else:
			var on: String = SEG[ch]
			var bars := {"a": [0, -hgt / 2.0, true], "g": [0, 0, true], "d": [0, hgt / 2.0, true],
				"f": [-w / 2.0, -hgt / 4.0, false], "b": [w / 2.0, -hgt / 4.0, false], "e": [-w / 2.0, hgt / 4.0, false], "c": [w / 2.0, hgt / 4.0, false]}
			for k in bars:
				if not on.contains(k): continue
				var s := MeshInstance3D.new(); var q2 := BoxMesh.new()
				q2.size = Vector3(w - th, 0.0002, th) if bars[k][2] else Vector3(th, 0.0002, hgt / 2.0 - th)
				s.mesh = q2; s.material_override = holder.get_meta("mat"); s.position = Vector3(x + bars[k][0], 0, bars[k][1]); holder.add_child(s)
		x += w + 0.0022
	for mi in holder.get_children(): (mi as MeshInstance3D).layers = 2 | 16

const WATCH_POS := Vector3(-0.03, -0.17, -0.3)
const WATCH_DEG := Vector3(0, -82, -58)
func _watch_show(on: bool):
	if watch == null or watch_up == on: return
	watch_up = on
	if on:
		_watch_set()
		_curl(hand_l, 0.9)
		_hand_to(hand_l, WATCH_POS, WATCH_DEG, 0.45)
		# in the dark he presses the light: the face goes green
		var night := part != "ch7"
		seg_mat.emission_enabled = night; seg_mat.emission = Color(0.35, 0.95, 0.55); seg_mat.emission_energy_multiplier = 0.0
		if night: create_tween().tween_property(seg_mat, "emission_energy_multiplier", 1.6, 0.15).set_delay(0.5)
	else:
		seg_mat.emission_energy_multiplier = 0.0
		_hand_away(hand_l)

func _clock_tick(dt: float):
	sec7 += dt
	if sec7 >= 60.0:
		sec7 -= 60.0; minute += 1
		if minute >= 60: minute = 0; hour = (hour + 1) % 24
		if watch_up: _watch_set()

# ================================================================ his storyboard (Tab)
# 陽太の手描き。コマ1・2は夕方に丸が付き、コマ3は2時に自分で描き足す。（手描きの画は画像生成で作る。それまでは字だけ）
func _conte():
	# his own sheet (ui/make_conte7.py): the print's paper, drawn on in its blue ink like the 12 panels' board (story.gd _board).
	# The done marks and the third panel are sheets of the same size laid over it
	conte_layer = CanvasLayer.new(); conte_layer.layer = 12; add_child(conte_layer)
	var vs := get_viewport().get_visible_rect().size
	var h := vs.y * 0.88; var w := h * 2000.0 / 1414.0
	var hold := Control.new(); hold.position = Vector2((vs.x - w) / 2.0, (vs.y - h) / 2.0); hold.size = Vector2(w, h)
	hold.pivot_offset = Vector2(w, h) / 2.0; hold.rotation = deg_to_rad(-1.6); conte_layer.add_child(hold)
	var sh := ColorRect.new(); sh.color = Color(0.0, 0.33, 0.6, 0.85); sh.position = Vector2(7, 9) * u; sh.size = Vector2(w, h); hold.add_child(sh)
	for n in ["base", "ok1", "ok2", "add"]:
		var r := TextureRect.new(); var p := "res://ui/conte7_%s.png" % n
		if ResourceLoader.exists(p): r.texture = load(p)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = Vector2(w, h); hold.add_child(r)
		conte_rows.append(r)
	conte_layer.visible = false
	_conte_fill()

func _conte_fill(_added := false):
	if part != "ch7": conte_done[0] = true; conte_done[1] = true
	if part == "ch7b" and stage in ["cut", "end"]: conte_done[2] = true
	for i in 3: (conte_rows[i + 1] as Control).visible = conte_done[i]

func _conte_show(on: bool):
	conte_up = on; conte_layer.visible = on

# ================================================================ every frame
func _process(dt):
	t_now += dt; t_stage += dt
	_black_tick(dt)
	_clock_tick(dt)
	if card_t > 0.0:
		card_t -= dt
		card.visible = true; player.move_enabled = false; player.look_enabled = false
		if card_t <= 0.0:
			card.visible = false; player.look_enabled = true
			match start7:
				"win":
					_stand_at(WIN_AT, [2.6, 2.0], 0.0); player.eye_height = EYE; player.get_node("Head").position.y = EYE; _begin("to_window"); _set_mission("窓を叩く")
				"door":
					_stand_at([5.0, -0.8], DOOR, 0.0); player.eye_height = EYE; player.get_node("Head").position.y = EYE
					conte_done[0] = true; _begin("to_door"); _set_mission("扉を叩く")
					_put("natsuki", HALL_NAT, _face(HALL_NAT, DOOR)); _put("mio", HALL_MIO, _face(HALL_MIO, DOOR), -0.18)
					main.walkers.erase("natsuki"); main.walkers.erase("mio")
				_: _begin("mirror")
		return
	if mode == TALK: _talk_tick(dt)
	_update_looks()
	if look_all:
		for k in looks: (looks[k] as Look).want = 1.0
	var wk: String = "mio" if cur.get("who", "") == "澪" else String(cur.get("who_key", ""))
	main.talk_now = wk if mode == TALK and cur.has("who") and typed < float(String(cur.get("text", "")).length()) else ""
	main.story_talking = (mode == TALK)
	player.move_enabled = mode == FREE and stage in ["to_window", "to_door", "party", "outside", "climb", "door2", "to_back"]
	_mirror_tick(dt)
	_gait_tick(dt)
	# main.gd's stand-in for the sky in the open doorway (lights.doorsky) is a spot just outside the door, aimed in: with the
	# door shut it burnt a white disc on the door's outside. It comes with the door's opening
	if door_sky7 == null and main.door_pivot and not door_sky_looked:
		door_sky_looked = true
		for k in main.lights:
			var l = main.lights[k]
			if l is SpotLight3D and (l as Node3D).global_position.distance_to(gp(DOOR[0], -0.25, 1.1)) < 0.6: door_sky7 = l; door_sky_e = (l as Light3D).light_energy
	if door_sky7:
		var open := clampf(absf(main.door_pivot.rotation.y - door_closed) / deg_to_rad(82.0), 0.0, 1.0)
		door_sky7.light_energy = door_sky_e * open
		if mio_sky == null:
			# her own share of the porch's sky, soft and from the front: without any she was a black shape in the doorway
			mio_sky = OmniLight3D.new(); mio_sky.light_color = Color(0.95, 0.93, 0.9); mio_sky.omni_range = 4.5; mio_sky.omni_attenuation = 0.6
			mio_sky.shadow_enabled = false; mio_sky.light_specular = 0.0; mio_sky.light_cull_mask = 8; mio_sky.light_bake_mode = Light3D.BAKE_DISABLED
			main.add_child(mio_sky); mio_sky.global_position = gp(DOOR[0] + 0.5, -1.9, 1.7)
		mio_sky.light_energy = 0.9 * open
		door_sky7.light_cull_mask = 0xFFFFF & ~(2 | 8 | 16)  # (not Mio, whose meshes are on layer 4 alone: in the doorway she burnt to paper white in it)
	if dn and dn.is_processing() != (stage == "party"):
		dn.set_process(stage == "party"); dn.set_process_unhandled_input(stage == "party")
		if stage != "party": dn.label.text = ""
	if page_clear_t >= 0.0:
		page_clear_t -= dt
		if page_clear_t < 0.0 and mode == FREE: _clear_box(lines_box)
	# what E would do here
	var note := ""
	tgt7 = ""
	if mode == FREE:
		match stage:
			"mirror":
				if t_stage > 0.5: _begin("to_window")
			"to_window":
				if _at_window(): note = String(D.lines("七.窓")[0])
			"slapped":
				_begin("to_door"); _set_mission("扉を叩く")
			"to_door":
				if _near_door(): note = String(D.lines("七.扉")[0])
			"party":
				tgt7 = _talk_target()
				if tgt7 != "" and (not talked7.has(tgt7) or tgt7 == "taiga"): note = "［Ｅ　%s］" % NAME7[tgt7]
			"outside":
				var p := _plan()
				if not said_moon and t_stage > 7.0: said_moon = true
				if p[1] < SLIP_Y or t_stage > 90.0: _slip_now()
			"wake":
				_begin("climb")
			"climb":
				var p2 := _plan()
				if not said_light and p2[1] > -13.0: said_light = true; hour = 2; minute = 2; _start(B("七.灯り"))
				elif _near_door(2.2): hour = 2; minute = 4; _begin("door2")
			"door2":
				if _near_door(): note = String(D.lines("七.扉二")[0])
				knock_idle += dt
				if knocks > 0 and knock_idle > 9.0 and laugh_due < 0.0: laugh_due = 0.0; knock_idle = 0.0; _do("inside_laugh"); laugh_due = -1.0
			"to_back":
				var p3 := _plan()
				if Vector2(p3[0] - CUT_AT[0], p3[1] - CUT_AT[1]).length() < 1.3 or p3[1] > 2.0 and p3[0] > 10.0: stage = "cut"; _start(B("七.裏"))
	if note_lb: note_lb.text = T(note) if note != "" else ""
	if demo7: _demo7_tick(dt)

func _at_window() -> bool:
	var p := _plan()
	return p[1] < -0.2 and p[1] > -1.3 and p[0] > WIN_X0 and p[0] < WIN_X1

# drunk: a slow roll and a drift he does not steer. hurt: slow, and the view sinks on the left foot
func _gait_tick(dt: float):
	var cam := _cam()
	if stage in ["slip", "cut"]: return
	var moving: float = clampf(player.step_amp, 0.0, 1.0)
	var rz := 0.0; var px := 0.0; var py := 0.0
	var d := drunk if stage in ["party", "outside", "going"] else 0.0
	if d > 0.0:
		rz += sin(t_now * 0.62) * 0.035 * d + sin(t_now * 1.31) * 0.012 * d
		px += sin(t_now * 0.47) * 0.035 * d
		if stage == "outside" and moving > 0.2: player.yaw += sin(t_now * 0.53) * 0.16 * d * dt
	if limp > 0.0 and stage in ["climb", "door2", "to_back", "door_end"]:
		var ph: float = fmod(player.step_phase, 1.0)
		var hurt: bool = player.foot < 0.0          # the left foot is down
		var s := sin(ph * PI) * moving
		if hurt: py -= 0.085 * s; rz += 0.045 * s
		player.walk_speed = lerpf(0.62, 0.3, 1.0 if hurt else 0.0)
		player.step_length = 0.46
	elif stage in ["party"]:
		player.walk_speed = 0.9
	elif stage == "outside":
		player.walk_speed = 0.85
	cam.rotation.z = lerp_angle(cam.rotation.z, rz, minf(1.0, dt * 6.0))
	cam.position.x = lerpf(cam.position.x, px, minf(1.0, dt * 6.0))
	cam.position.y = lerpf(cam.position.y, py, minf(1.0, dt * 9.0))
	if fill7: fill7.light_energy = 0.14 if part == "ch7" else 0.12

# ================================================================ keys
func _unhandled_input(e):
	if card_t > 0.0 or mode == END: return
	if e is InputEventKey and e.pressed and not e.echo:
		if mode == TALK and cur.has("choose") and e.keycode in [KEY_W, KEY_UP, KEY_A, KEY_LEFT]: _move_choice(-1); return
		if mode == TALK and cur.has("choose") and e.keycode in [KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT]: _move_choice(1); return
		if e.keycode == KEY_TAB: _conte_fill(); _conte_show(not conte_up); return
	if e is InputEventMouseButton and e.pressed and mode == TALK and cur.has("choose"):
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: _move_choice(-1); return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move_choice(1); return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if e.pressed and mode == FREE and stage in ["climb", "door2", "to_back", "to_window", "to_door", "party", "outside"]:
			if stage == "climb" and not watch_said: _start(B("七.時計"))
			else: _watch_show(true)
		elif not e.pressed: _watch_show(false)
		return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if press: get_viewport().set_input_as_handled(); _press7()

func _press7():
	if conte_up: _conte_show(false); return
	if mode == TALK: _advance(); return
	match stage:
		"to_window":
			if _at_window(): stage = "slapped"; t_stage = 0.0; _set_mission(""); _start(B("七.窓.叩いた"))
		"to_door":
			if _near_door(): stage = "door"; t_stage = 0.0; _set_mission(""); _start(B("七.扉.叩いた"))
		"party":
			_talk_to(tgt7)
		"door2":
			if _near_door(): _knock2()

func _talk_tick(dt):
	if demo7 and cur.has("choose") and not cur.get("chosen", false):
		read_t += dt
		if read_t > 1.5: read_t = 0.0; choice_idx = 0; _show_choice(); _choose()
		return
	super._talk_tick(dt)

# ================================================================ the unattended run (--demo)
var demo_goal: Array = []
var demo_wait := 0.0
# player.gd's timed path is a point that runs ahead at a set speed, and the body goes straight for it: when he falls behind
# (the limp, a line said on the way) the point is legs ahead and he cuts the corners, into the bank beside the drive. So the
# route is given one leg at a time: the next leg starts when he is at the end of this one
var demo_route: Array = []
var demo_leg_to: Array = []
var demo_speed := 1.0
func _demo_go(route_all: Array, speed := 1.0, resume := false):
	if player.auto_path.size() > 0: return
	var p: Vector3 = player.global_position
	var route := route_all.duplicate(); var bi := 0; var bd := 1e9
	for i in route_all.size():
		var dd := Vector2(route_all[i][0] - 4.8 - p.x, route_all[i][1] - 6.3 - p.z).length()
		if dd < bd: bd = dd; bi = i
	if resume and bi > 0 and bi < route_all.size() - 1: route = route_all.slice(bi + 1)
	elif resume and bi == route_all.size() - 1: route = [route_all[-1]]
	if limp > 0.0 and part == "ch7b": speed = 0.36
	demo_route = route; demo_speed = speed
	demo_goal = route[-1]
	_demo_leg()

func _demo_leg():
	if demo_route.is_empty(): return
	var p: Vector3 = player.global_position
	var q: Array = demo_route.pop_front()
	var to := Vector2(q[0] - 4.8, q[1] - 6.3); var dvec := to - Vector2(p.x, p.z)
	var y0 := rad_to_deg(player.yaw); var y1 := y0 + wrapf(rad_to_deg(atan2(-dvec.x, -dvec.y)) - y0, -180.0, 180.0)
	var turn := clampf(absf(y1 - y0) / 140.0, 0.15, 1.2)
	var v: float = 0.38 if (limp > 0.0 and part == "ch7b") else player.walk_speed * demo_speed   # (the limp's speed changes with each foot)
	var t := turn + dvec.length() / maxf(v, 0.05)
	player.auto_path = [[0.0, p.x, p.z, y0, rad_to_deg(player.pitch)], [turn, p.x, p.z, y1, -4.0], [t, to.x, to.y, y1, -4.0]]
	player.auto_t = 0.0
	demo_leg_to = q

func _demo_there(r := 0.5) -> bool:
	if demo_goal.is_empty(): return false
	var p := _plan()
	if Vector2(p[0] - demo_goal[0], p[1] - demo_goal[1]).length() < r:
		player.auto_path = []; demo_goal = []; demo_route = []; return true
	if not demo_route.is_empty() and not demo_leg_to.is_empty() and Vector2(p[0] - demo_leg_to[0], p[1] - demo_leg_to[1]).length() < 0.7:
		player.auto_path = []; _demo_leg(); return false
	if player.auto_path.is_empty() and mode != TALK and not demo_leg_to.is_empty():   # (story.gd's turn to a speaker took the path and dropped it)
		demo_route.push_front(demo_leg_to); _demo_leg(); return false
	if mode == TALK: player.auto_t = minf(player.auto_t, float(player.auto_path[-1][0])) if player.auto_path.size() > 0 else 0.0   # (a line on the way is not being stuck)
	if player.auto_path.size() > 0 and player.auto_t > float(player.auto_path[-1][0]) + 3.0:
		print("DEMO ch7 stuck at (%.2f, %.2f) for %s" % [p[0], p[1], stage]); DEMO_FAILS += 1
		var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 0.3, 0), player.global_position + Vector3(0, -0.6, 0.0)); q.exclude = [player.get_rid()]
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
		print("C7STUCK y=%.2f hit=%s %s" % [player.global_position.y, hit.get("position", ""), (hit.collider as Node).get_path() if hit.has("collider") else ""])
		for i in player.get_slide_collision_count(): print("C7SLIDE ", (player.get_slide_collision(i).get_collider() as Node).get_path(), " n=", player.get_slide_collision(i).get_normal(), " at ", player.get_slide_collision(i).get_position())
		player.auto_path = []; demo_goal = []; demo_route = []
		return true
	return false

func _demo_look(at: Vector3):
	var to := at - _cam().global_position
	player.yaw = atan2(-to.x, -to.z); player.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))

func _demo7_tick(dt: float):
	if "--ch7trace" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 12 == 0:
		var a: Array = player._sample_path(player.auto_t) if player.auto_path.size() > 0 else []
		print("C7TRACE %s plan(%.2f, %.2f) y=%.2f v=%s floor=%s target=%s" % [stage, _plan()[0], _plan()[1], player.global_position.y, player.velocity, player.is_on_floor(), a])
	if mode != FREE: return
	demo_wait -= dt
	if demo_wait > 0.0: return
	match stage:
		"to_window":
			if demo_goal.is_empty() and not _at_window(): _demo_go([[4.6, -4.2], [3.4, -1.6], WIN_AT])
			elif _demo_there(0.35) or _at_window():
				player.auto_path = []; demo_goal = []; _demo_look(gp(TABLE[0], TABLE[1], 0.8)); demo_wait = 1.2; _press7()
		"to_door":
			if demo_goal.is_empty() and not _near_door(1.0): _demo_go([[3.3, -3.3], [5.0, -3.5], [5.0, -0.8]])
			elif _demo_there(0.35) or _near_door(1.0):
				player.auto_path = []; demo_goal = []; _demo_look(gp(DOOR[0], DOOR[1], 1.2)); demo_wait = 1.0; _press7()
		"party":
			var order := ["kiryu", "natsuki", "mio", "taiga"]
			for k in order:
				if talked7.has(k): continue
				var at: Array = SEATS.get(k, STAND7.get(k))
				var pos := gp(at[0], at[1], 1.1)
				if _has(k): pos = main._rig_of(k).global_position + Vector3(0, 1.1, 0)
				_demo_look(pos)
				var p := _plan()
				if Vector2(p[0] - at[0], p[1] - at[1]).length() > 2.3:
					if demo_goal.is_empty(): _demo_go([[lerpf(p[0], at[0], 0.5), lerpf(p[1], at[1], 0.5)]])
					else: _demo_there(0.3)
					return
				player.auto_path = []; demo_goal = []
				tgt7 = k; demo_wait = 1.0; _talk_to(k)
				return
		"outside":
			if demo_goal.is_empty(): _demo_go(DRIVE, 1.0, true)
			else: _demo_there(0.5)
		"climb":
			if not watch_said and t_stage > 2.0: _start(B("七.時計")); return
			if demo_goal.is_empty(): _demo_go(BACK_ROUTE, 1.0, true)
			else: _demo_there(0.5)
		"door2":
			if not _near_door(1.2):
				if demo_goal.is_empty(): _demo_go([[5.0, -0.8]])
				else: _demo_there(0.3)
				return
			player.auto_path = []; demo_goal = []
			_demo_look(gp(DOOR[0], DOOR[1], 1.2)); demo_wait = 2.6; _knock2()
		"to_back":
			if demo_goal.is_empty(): _demo_go(EAST_ROUTE, 1.0, true)
			else: _demo_there(0.6)
