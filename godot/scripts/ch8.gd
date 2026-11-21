## ステップ F：割り込み「監督」二時（旧第8章。docs/資料/第8章の設計_2026-11-19.md）。台詞は story/ch8.txt。
## 桐生として、カメラのファインダー越しに撮りながら歩く。澪の証言が一行で飛ばした一時間を、扉の外の側から。
## 誰の証言でもない章：澪＊の行は一つも無い。◇ は桐生の段取りの言葉。
##   二階の踊り場（桐生の目）→ 階段の下でカメラを三脚から外す（ここから全部ファインダー）→ 廊下の澪（口元から下）
##   → Ｅ 録画（夏希の1秒が出て、消える）→「俺でもだ」→ 玄関 → 車の夏希 → 自分の家の扉を外から三度叩く
##   → 私道 → 林道 → 沢の上の曲がり角（崩れた路肩を撮りに寄って、落ちる）→ 雨の空。テープは回り続ける
## 光は三つ：カメラのライト（暖かい。刷りでは橙の版）、夏希のスマホ（冷たい）、稲光（紙の白）。
## ほかの章とそろえた所は ch8.txt の頭。main.gd は play="ch8"（二時の光 t02）。終わりで main.next_chapter("ch8")。
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")

# ---------------------------------------------------------------- where things are (plan metres: x east, y north from the front wall)
const F2 := 2.75
const DOOR := [5.0, 0.0]
const TOP_AT := [5.0, 6.45]                    # the upstairs landing (ch3.gd KIRYU_DOWN starts here)
const STAIR := [[5.5, 5.7, F2], [5.5, 2.55, 0.0], [4.75, 2.2, 0.0]]
const TRIPOD := [4.35, 1.6]                    # the big camera's tripod at the stair's foot (main.gd _tripod_clear)
const TAKE_AT := [4.75, 2.2]                   # where he stands with it (ch3.gd)
const MIO_WAIT := [4.95, 5.05]                 # at the cellar door, her back to the hall
const MIO_SIT := [4.9, 1.62]                  # 2026-11-19（ユーザー「一番気になるのはこの人」）：立たせず、第3章で扉の番をしていた上がり框に座らせる（ch3.gd SIT_AT）。扉を向いた背中を、桐生が後ろの上から撮る
const SIT_DROP := 0.36                        # 座った澪の腰の骨は体から 0.44 の高さ（--ch8probe）。框に腰が来るように体を下げ、床から下は毛布が隠す
const CELLAR_DOOR := [5.5, 5.62]
const OUT_AT := [5.0, -0.95]
const EYE := 1.66                              # Kiryu's eye (Mio's is 1.52)
const CHEST := 1.27                            # the camera held at his chest
const PIC_H := 0.86                            # the finder's picture, of the screen's height (story.gd FinderFrame)
const FOV_WIDE := 64.0
const FOV_TELE := 20.0
const DRIVE := [[5.0, -2.4], [6.4, -5.5], [8.6, -11.0], [10.6, -16.5], [12.4, -21.5], [13.6, -25.6]]
const ROAD := [[18.0, -27.1], [26.0, -28.0], [34.0, -28.9], [42.0, -30.2], [50.0, -31.8], [57.0, -34.8], [63.0, -39.0], [67.4, -43.6]]
const CORNER_AT := [69.3, -46.6]               # where Natsuki stops: the road's inner side, before the gap
const SLIP_MID := [72.4, -53.7]                # the middle of the shoulder that went (outside_geo.SLIP_IDX)
const SLIP_OUT := [0.97, -0.24]                # out over the ravine there (plan)
const KNOCKS := 3

var stage := ""
var t_stage := 0.0
var card: Control
var card_t := 0.0
var demo8 := false
var start8 := ""
var dn
var door_closed := 0.0
var door_tw: Tween
var finder8: Control
var fin_on := false            # the picture is the camera's
var rec8 := false
var rec_c0 := 7200.0           # the clock when he pressed: the counter is the clock less this (the clock jumps with the chapter's cuts, and the tape ran through them)
var rec_t := 0.0               # the tape's counter
var clock := 2.0 * 3600.0      # the camera's clock, seconds of the day
var clock_run := true
var cam_h := EYE               # the eye's height now (the camera's once he has it)
var zoom := 0.0                # 0 wide .. 1 tele
var zoom_want := -1.0          # the operator's own zoom (the car: in on her, thighs up); -1 leaves it to the player
var zoom_v := 0.0
var zoom_snd_t := 0.0
var cam_light: OmniLight3D
var light_want := 0.0
var car_dome: OmniLight3D
var door_gap: OmniLight3D
var bolt8: DirectionalLight3D
var bolt_e := 0.0
var bolt_next := -1.0
var rain8: MultiMeshInstance3D
var rain_mat: ShaderMaterial
var rain_on := 0.0
var white: ColorRect
var flash_tex: TextureRect
var mio_shake: Shake
var blanket: MeshInstance3D
var nat_phone: OmniLight3D
var nat_phone_want := 0.0
var knocks := 0
var knock_ready := true
var door_shake := 0.0
var cam_shake := 0.0
var road_said := {}
var nat_i := 0                 # the next point of her way down
var nat_way: Array = []
var nat_wait := false
var edge_t := 0.0
var fall_t := -1.0
var fall_from := Transform3D()
var fall_to := Transform3D()
var fall_path: Array = []
var sky_q: Array = []
var sky_i := 0
var lapse := 0
var loops8 := {}
var yaw_lock := false
var hall_framed := false
var free_look_after := 0.0

# a small turn of the head from side to side (she shakes her head: the chin, the hair and the blanket's collar move)
class Shake extends SkeletonModifier3D:
	var a := 0.0
	var bones: Array = []
	func setup():
		var sk := get_skeleton()
		bones = [[sk.find_bone("neck_01"), 0.35], [sk.find_bone("head"), 0.65]]
	func _process_modification():
		var sk := get_skeleton()
		if sk == null or absf(a) < 0.0005: return
		var up_sk := (sk.global_basis.inverse() * Vector3.UP).normalized()
		for pair in bones:
			if pair[0] < 0: continue
			var p := sk.get_bone_global_pose(pair[0])
			sk.set_bone_global_pose(pair[0], Transform3D(Basis(up_sk, a * pair[1]) * p.basis, p.origin))

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = []
	_load_story("ch8")
	_page()
	demo8 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	demo_on = demo8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch8at="): start8 = a.substr(8)
		if a == "--ch8probe": call_deferred("_probe")
		if a.begins_with("--ch8portrait="): call_deferred("_portrait", a.substr(14))
	main.TALK = {}
	main.phones(false)
	for e in main.torches:
		if is_instance_valid(e[0]): (e[0] as Node3D).visible = false
	for k in ["kiryu", "taiga", "makoto", "natsuki"]: _hide(k)   # Kiryu is the eye; Taiga is in the cellar, Makoto upstairs in bed
	_load_natsuki()
	_load_mio()
	_front_door()
	_finder8()
	_lights8()
	_rain8()
	_car()
	_tally_off()
	player.eye_height = EYE; player.get_node("Head").position.y = EYE
	player.walk_speed = 1.12
	var c: Array = D.lines("八.カード")
	card = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	card_t = 2.75 if start8 == "" else 0.3
	stage = "card"
	call_deferred("_place")
	print("STORY ch8 start=%s" % start8)

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

# ---------------------------------------------------------------- small helpers
func _has(k: String) -> bool:
	return main.S.has(k + "_node")

func _hide(k: String):
	if not _has(k): return
	(main.S[k + "_node"] as Node3D).visible = false
	if main.S.has(k + "_col"): (main.S[k + "_col"] as Node3D).global_position = Vector3(0, -50, 0)

func _show(k: String):
	if _has(k): (main.S[k + "_node"] as Node3D).visible = true

func _face(from: Array, to: Array) -> float:
	return atan2(to[0] - from[0], to[1] - from[1])

func _put(k: String, at: Array, yaw: float, z := 0.0):
	if _has(k): main.place_person(k, [at[0] - 4.8, 6.3 - at[1], z], yaw)

func _plan() -> Array:
	return [player.global_position.x + 4.8, player.global_position.z + 6.3]

func _plan_of(k: String) -> Array:
	var r: Node3D = main._rig_of(k)
	return [r.global_position.x + 4.8, r.global_position.z + 6.3]

func _cam() -> Camera3D:
	return player.get_node("Head/Camera")

func _after(sec: float, c: Callable):
	get_tree().create_timer(sec).timeout.connect(c)

func _ground(x: float, y: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(gp(x, y, 8.0), gp(x, y, -60.0))
	q.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else 0.0

func _stand_at(at: Array, yaw_deg: float, pitch_deg := -4.0, z = null):
	var gy: float = _ground(at[0], at[1]) if z == null else float(z)
	player.global_position = Vector3(at[0] - 4.8, gy + 0.02, at[1] - 6.3); player.velocity = Vector3.ZERO
	player.yaw = deg_to_rad(yaw_deg); player.pitch = deg_to_rad(pitch_deg)

func _yaw_to(at: Vector3) -> float:
	var to: Vector3 = at - _cam().global_position
	return atan2(-to.x, -to.z)

func _pitch_to(at: Vector3) -> float:
	var to: Vector3 = at - _cam().global_position
	return asin(clampf(to.normalized().y, -1.0, 1.0))

func _turn_to(yaw: float, pitch: float, dur: float) -> Tween:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "yaw", player.yaw + wrapf(yaw - player.yaw, -PI, PI), dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player, "pitch", pitch, dur).set_trans(Tween.TRANS_SINE)
	return tw

func _eye_to(h: float, dur: float):
	create_tween().tween_method(func(v: float): cam_h = v, cam_h, h, dur).set_trans(Tween.TRANS_SINE)

func _one(name: String, db := 0.0, at = null):
	if "--nosound" in OS.get_cmdline_user_args(): return
	Sound.one(self, name, db, at)

func _loop8(name: String, db: float, at = null):
	if "--nosound" in OS.get_cmdline_user_args() or loops8.has(name): return
	var s := Sound.stream(name, true)
	if s == null: return
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new(); p3.stream = s; p3.unit_size = 4.0; p3.max_db = 0.0; add_child(p3); p3.global_position = at; p = p3
	else:
		var p2 := AudioStreamPlayer.new(); p2.stream = s; add_child(p2); p = p2
	p.set("volume_db", db); p.call("play")
	loops8[name] = p

func _loop_db(name: String, db: float, sec := 1.0):
	if loops8.has(name): create_tween().tween_property(loops8[name], "volume_db", db, sec)

# ---------------------------------------------------------------- the people
# Natsuki as she was outside the door at eleven (wet, her shoes on), with the walk and the talk the 20:00 people have (fps.gd)
func _load_natsuki():
	if not ResourceLoader.exists("res://assets/natsuki.glb"): return
	main._load_scene("res://assets/natsuki.glb", "natsuki")
	var inst: Node3D = main.S.natsuki_node
	main._faces()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for ap in inst.find_children("*", "AnimationPlayer", true, false): (ap as AnimationPlayer).stop()
	sk.reset_bone_poses()
	main._talk_anims("natsuki", inst)
	main._walk_anims("natsuki", inst)
	for ba in sk.find_children("nphone*", "BoneAttachment3D", true, false): (ba as Node3D).visible = false
	if not main.S.has("natsuki_col"):
		var col := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new()
		cy.radius = 0.2; cy.height = 1.8; cs.shape = cy; cs.position.y = 0.9; col.add_child(cs); main.add_child(col)
		main.S["natsuki_col"] = col
	main.set_stand("natsuki", "talk/idle", 0.0)
	# 夏希の体には当たらない：車の横で話したあと、通しが彼女の立っていた所で止まった（2026-11-19）。先を歩く人なので、当たりは要らない
	for cs2 in (main.S["natsuki_col"] as Node).find_children("*", "CollisionShape3D", true, false): (cs2 as CollisionShape3D).disabled = true
	for mi in inst.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).extra_cull_margin = 1.0
	# her phone held up for a signal: a cold light at her raised hand
	nat_phone = OmniLight3D.new(); nat_phone.light_color = Color(0.74, 0.86, 1.0); nat_phone.light_energy = 0.0
	nat_phone.omni_range = 2.6; nat_phone.omni_attenuation = 1.3; nat_phone.shadow_enabled = false; nat_phone.light_specular = 0.1
	main._rig_of("natsuki").add_child(nat_phone); nat_phone.position = Vector3(0.18, 1.52, 0.3)
	_hide("natsuki")

# 澪の体（第7章のスレッドの export_ch7.py。ch7.gd _load_mio と同じ持ち方）。この章では口元から下しか画に入らない
func _load_mio():
	if not ResourceLoader.exists("res://assets/dusk/mio.glb") or OS.get_cmdline_user_args().has("--nomio"): return
	main._load_scene("res://assets/dusk/mio.glb", "mio")
	var inst: Node3D = main.S.mio_node
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		m3.extra_cull_margin = 1.0
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
		if ResourceLoader.exists("res://assets/dusk/mio_talk.res"):
			var src: AnimationLibrary = load("res://assets/dusk/mio_talk.res"); var tl := AnimationLibrary.new()
			for cn in ["idle", "sit_idle"]:
				if src.has_animation(cn): tl.add_animation(cn, src.get_animation(cn))
			(ap as AnimationPlayer).add_animation_library("talk", tl)
	main._walk_anims("mio", inst)
	if FileAccess.file_exists("res://assets/dusk/ch7.json"):
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://assets/dusk/ch7.json"))
		if j is Dictionary and j.has("walk"): main.WALKJ["mio"] = j.walk
	var col := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new()
	cy.radius = 0.16; cy.height = 1.8; cs.shape = cy; cs.position.y = 0.9; col.add_child(cs); main.add_child(col)
	main.S["mio_col"] = col
	main.set_stand("mio", "talk/idle", 0.0)
	mio_shake = Shake.new(); sk.add_child(mio_shake); mio_shake.setup()
	_blanket()
	# 2026-11-20 練り直し：澪は框に座っていない。二時、地下の扉（地下へ下りる階段の下、閂の扉）を押そうとしている。桐生が手首を
	# つかみ、話は廊下で、澪は地下の扉の前に立って（第3章 to_hall と同じ所）。座った形の毛布は立ち姿に合わないので出さない
	blanket.visible = false
	_put("mio", MIO_WAIT, _face(MIO_WAIT, TAKE_AT))

# the blanket round her shoulders (ch3: she sat at the door wrapped in it, and got up with it on). A shell that hangs from the
# shoulders to the thighs, closed at the front where her hands hold it from inside; the checks follow the folds
func _blanket():
	var rig: Node3D = main._rig_of("mio")
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var NU := 64; var NV := 30
	# 座った体にかけた毛布：襟から肩へ広がり、後ろは框の床（体から見て高さ SIT_DROP）に落ちて溜まる。前は膝を越えて土間まで。
	# 高さは体（rig）から。座った澪の骨（--ch8probe）：頭 0.95、首 0.87、肩 0.78、腰 0.44
	var FL := SIT_DROP + 0.012; var FLF := SIT_DROP - 0.17
	var ss := [0.0, 0.08, 0.2, 0.36, 0.55, 0.74, 0.9, 1.0]
	var hb := [0.875, 0.85, 0.805, 0.74, 0.65, 0.55, 0.45, FL]             # the back's fall
	var rxs := [0.07, 0.12, 0.205, 0.245, 0.275, 0.305, 0.345, 0.39]
	var rzb := [0.075, 0.1, 0.125, 0.16, 0.2, 0.245, 0.3, 0.36]
	var rzf := [0.075, 0.1, 0.135, 0.2, 0.33, 0.43, 0.45, 0.43]          # the front: over her knees
	var hf := [0.875, 0.85, 0.805, 0.75, 0.69, 0.56, 0.38, FLF]
	var at := func(arr: Array, v: float) -> float:
		for i in arr.size() - 1:
			if v <= ss[i + 1]:
				var k: float = (v - ss[i]) / (ss[i + 1] - ss[i]); k = k * k * (3.0 - 2.0 * k)
				return lerpf(arr[i], arr[i + 1], k)
		return arr[-1]
	var P := []
	for iv in NV + 1:
		var v := float(iv) / NV
		for iu in NU + 1:
			var th := float(iu) / NU * TAU            # 0 at the front (+z), round by her left
			var c := cos(th)
			var fw := smoothstep(-0.25, 0.55, c)       # how much of the front this is
			var h: float = lerpf(at.call(hb, v), at.call(hf, v), fw)
			var rx: float = at.call(rxs, v); var rz: float = lerpf(at.call(rzb, v), at.call(rzf, v), fw)
			var down := smoothstep(0.15, 0.75, v)
			# folds that hang from the shoulders and open toward the floor; the hem lies in waves where it pools
			var fold := (0.016 * sin(th * 7.0 + 0.6) + 0.009 * sin(th * 13.0 + v * 4.0) + 0.006 * sin(th * 23.0 - v * 7.0)) * down
			var pool := smoothstep(0.82, 1.0, v) * (0.035 + 0.03 * sin(th * 5.0 + 1.1) + 0.02 * sin(th * 11.0))
			# her left shoulder a little lower: it has slipped
			var slip := -0.022 * maxf(sin(th), 0.0) * (1.0 - smoothstep(0.3, 0.7, v))
			# held shut at the breastbone from inside
			var fist := fw * 0.04 * exp(-pow((v - 0.3) / 0.1, 2.0))
			var r := 1.0 + (fold + pool) / maxf(rx, 0.06)
			P.append(Vector3(sin(th) * rx * r, h + slip + 0.012 * sin(th * 9.0) * smoothstep(0.9, 1.0, v), c * (rz * r + fist)))
	var W := NU + 1
	for iv in NV + 1:
		for iu in NU + 1:
			var a: Vector3 = P[iv * W + iu]
			var du: Vector3 = P[iv * W + (iu + 1) % NU] - P[iv * W + (iu - 1 + NU) % NU]
			var dv: Vector3 = P[mini(iv + 1, NV) * W + iu] - P[maxi(iv - 1, 0) * W + iu]
			st.set_normal(du.cross(dv).normalized() * -1.0)
			st.set_uv(Vector2(float(iu) / NU * 7.0, float(iv) / NV * 3.4))
			st.add_vertex(a)
	for iv in NV:
		for iu in NU:
			var a := iv * W + iu
			st.add_index(a); st.add_index(a + 1); st.add_index(a + W)
			st.add_index(a + 1); st.add_index(a + W + 1); st.add_index(a + W)
	blanket = MeshInstance3D.new(); blanket.mesh = st.commit()
	var dm := StandardMaterial3D.new(); dm.albedo_texture = ImageTexture.create_from_image(_plaid())
	dm.roughness = 1.0; dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	blanket.material_override = dm; blanket.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	rig.add_child(blanket)

# the same worn wool plaid as 第5章's (ch5.gd _plaid): it is the one blanket
func _plaid() -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var base := Color(0.50, 0.30, 0.17); var band := Color(0.20, 0.17, 0.14); var thin := Color(0.72, 0.62, 0.42)
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for y in n:
		for x in n:
			var bx := (x % 128) < 34; var by := (y % 128) < 34
			var tx := absi(x % 128 - 80) < 3; var ty := absi(y % 128 - 80) < 3
			var c := base
			if bx and by: c = band.darkened(0.25)
			elif bx or by: c = base.lerp(band, 0.7)
			if tx or ty: c = c.lerp(thin, 0.6)
			c = c.darkened(rng.randf_range(0.0, 0.12) + (0.06 if (x + y) % 4 < 2 else 0.0))
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img

# ---------------------------------------------------------------- the front door (this chapter's, not doors.gd's: ch7.gd と同じ)
func _front_door():
	dn = main.get_node_or_null("Doors")
	if dn:
		for k in dn.doors.keys():
			if dn.doors[k].pivot == main.door_pivot: dn.doors.erase(k)
	main.S.erase("knocks")
	if main.door_pivot:
		door_closed = float(main.S.get("door_rot", 0.0)) - deg_to_rad(float(main.ST.get("front", 0)))   # 二時の家は扉が開いた形で焼いてある（times.py）。閉じた所から始める
		main.S["door_rot"] = door_closed
		main.door_pivot.rotation.y = door_closed
		main.door_pivot.position = main.S.get("door_rest", main.door_pivot.position)

func _door_to(deg: float, dur: float):
	if main.door_pivot == null: return
	if door_tw and door_tw.is_valid(): door_tw.kill()
	door_tw = create_tween()
	door_tw.tween_property(main.door_pivot, "rotation:y", door_closed + deg_to_rad(deg) * float(main.S.get("door_sign", 1.0)), dur).set_trans(Tween.TRANS_SINE)

func _near_door(r := 1.7) -> bool:
	var p := _plan()
	return Vector2(p[0] - DOOR[0], p[1] - DOOR[1]).length() < r

# the porch's two steps: a ramp over them, unseen (ch7.gd _porch_ramp)
func _porch_ramp():
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

# the big camera on its tripod: he takes it (the tripod stays: 第4章). Its tally by the stair is its own
func _vcam(on: bool):
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"): (mi as Node3D).visible = on
	if main.lights.has("rec_light"): (main.lights.rec_light as Light3D).visible = false

# the small fixed camera on the handrail (第1章) is not in this chapter's picture (第6章の設計)
func _tally_off():
	if main.lights.has("rec_light"): (main.lights.rec_light as Light3D).visible = false

func _car():
	var cars: Array = main.S.env_node.find_children("ext_car*", "MeshInstance3D", true, false)
	if cars.is_empty(): print("CH8 no ext_car"); car_at = gp(6.4, -8.0, -0.3); return
	var bb := AABB()
	for i in cars.size():
		var mi := cars[i] as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		bb = b if i == 0 else bb.merge(b)
	car_at = bb.get_center(); car_r = maxf(bb.size.x, bb.size.z) * 0.5
	_car_level(cars)
	# her phone inside: a faint cold light in the car (ch3.gd _car_glow)
	var gl := OmniLight3D.new(); gl.name = "car_glow"; gl.light_color = Color(0.78, 0.86, 1.0); gl.light_energy = 0.9
	gl.omni_range = 1.4; gl.omni_attenuation = 1.2; gl.shadow_enabled = false
	add_child(gl); gl.global_position = car_at + Vector3(0, 0.15, 0)
	# the cabin's lamp while her door is open: the one warm light out here
	car_dome = OmniLight3D.new(); car_dome.name = "car_dome"; car_dome.light_color = Color(1.0, 0.74, 0.42); car_dome.light_energy = 0.0
	car_dome.omni_range = 7.0; car_dome.omni_attenuation = 1.0; car_dome.shadow_enabled = false; car_dome.light_specular = 0.2
	add_child(car_dome); car_dome.global_position = car_at + Vector3(0, 0.75, 0)   # _natsuki_out moves it to her open door
	# the house's light under its own front door, seen from outside while he knocks (第3章の扉の下の隙間、FRONT_GAP)
	door_gap = OmniLight3D.new(); door_gap.name = "door_gap"; door_gap.light_color = Color(1.0, 0.7, 0.38); door_gap.light_energy = 0.0
	door_gap.omni_range = 1.7; door_gap.omni_attenuation = 1.4; door_gap.shadow_enabled = false; door_gap.light_specular = 0.0
	add_child(door_gap); door_gap.global_position = gp(5.0, -0.12, -0.12)

# 車は平らに置いてあり、私道は下っている：坂の上側の車輪が地面に沈んで見えた（2026-11-19 ユーザー「車が沈んでる感じ」）。
# この章の間だけ、車の四隅の外の地面から坂の傾きを取り、車をその傾きに寝かせて、いちばん低い所が地面に載るまで持ち上げる。
# （家の書き出しの側で直すのが本筋：入口のスレッドに伝える。第0章・第3章の外でも同じはず）
# ---------------------------------------------------------------- the finder (the whole chapter is its picture)
class Finder8 extends Control:
	var st
	var fnt: Font
	var u := 1.0
	var glitch := 0.0
	var drops: Array = []     # [pos (0..1 in the picture), radius, age]
	var end_mark := false
	var rng := RandomNumberGenerator.new()
	func _draw():
		if not st.fin_on: return
		var s := size
		var h: float = s.y * st.PIC_H; var w: float = h * 4.0 / 3.0
		var x0: float = (s.x - w) / 2.0; var y0: float = (s.y - h) / 2.0
		var lc := Color(0.92, 0.92, 0.88)
		# the lens's water (after the fall): each drop a pale ring that spreads and runs
		var wet: Array = []
		for d in drops:
			# 試作232（ユーザー「ここの雨粒、急に安っぽい」）: crisp rings with a white glint read as drawn bubbles. Water on the
			# lens is out of focus: a soft pale smear, a little long, its lower edge darker, and a faint wet trail when it runs
			var c := Vector2(x0 + d[0].x * w, y0 + d[0].y * h); var r: float = d[1] * u * (0.6 + minf(d[2], 1.0) * 0.4)
			if d.size() > 3 and d[0].y - d[3] > 0.004:
				var c0 := Vector2(c.x, y0 + float(d[3]) * h)
				# 試作233: an even line read as a stick. The wet trail is narrow and faint at its top, wider and wetter near the
				# drop, and wanders a little
				var ph: float = float(d[3]) * 37.0
				var prev := c0
				for k in range(1, 11):
					var t := float(k) / 10.0
					var pt := c0.lerp(c, t) + Vector2(sin(ph + t * 5.0) * r * 0.12 * (1.0 - t), 0.0)
					draw_line(prev, pt, Color(0.8, 0.84, 0.88, 0.006 + 0.03 * t * t), r * (0.12 + 0.5 * t))
					prev = pt
			wet.append(Vector4(c.x, c.y, r, float(d[3]) * 91.0))   # the drop itself: refracted in st.lens_water (2026-11-22)
		if st.lens_water:
			var lm: ShaderMaterial = st.lens_water.material
			var arr: Array = []
			for i in 18: arr.append(wet[i] if i < wet.size() else Vector4.ZERO)
			lm.set_shader_parameter("drops", arr); lm.set_shader_parameter("n", mini(wet.size(), 18))
		# the tumble: the picture tears in bands
		if glitch > 0.01:
			rng.seed = int(Time.get_ticks_msec() / 60)
			for i in int(10 * glitch):
				var by: float = y0 + rng.randf() * h; var bh := (4.0 + rng.randf() * 34.0) * u
				draw_rect(Rect2(x0, by, w, bh), Color(0.03, 0.05, 0.08) if rng.randf() < 0.6 else Color(0.9, 0.9, 0.86, 0.8))
		var bez := Color(0.05, 0.05, 0.055)
		draw_rect(Rect2(0, 0, s.x, y0), bez); draw_rect(Rect2(0, y0 + h, s.x, s.y - y0 - h), bez)
		draw_rect(Rect2(0, y0, x0, h), bez); draw_rect(Rect2(x0 + w, y0, s.x - x0 - w, h), bez)
		var fs := int(32 * u)
		var blink: bool = fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6
		if end_mark:
			if blink: draw_string(fnt, Vector2(x0, y0 + h * 0.5), "TAPE END", HORIZONTAL_ALIGNMENT_CENTER, w, int(48 * u), lc)
		elif st.rec8: draw_string(fnt, Vector2(x0 + 26 * u, y0 + 46 * u), "● REC", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.35, 0.15))
		else: draw_string(fnt, Vector2(x0 + 26 * u, y0 + 46 * u), "STBY", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
		# the tape's counter (from where he pressed) top right; the clock bottom left
		var tc := "%d:%02d:%02d" % [int(st.rec_t / 3600.0), int(st.rec_t / 60.0) % 60, int(st.rec_t) % 60]
		draw_string(fnt, Vector2(x0 + w - 230 * u, y0 + 46 * u), tc, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, lc)
		var ck: float = st.clock
		var hh := int(ck / 3600.0) % 24; var mm := int(ck / 60.0) % 60
		draw_string(fnt, Vector2(x0 + 26 * u, y0 + h - 24 * u), "AM %d:%02d" % [hh, mm], HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * u), lc)
		# the zoom: W ▬▬▬▬ T
		var zx: float = x0 + w * 0.5 - 90 * u; var zy: float = y0 + h - 34 * u
		if st.zoom_show > 0.0:
			draw_string(fnt, Vector2(zx - 34 * u, zy + 10 * u), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * u), lc)
			draw_string(fnt, Vector2(zx + 190 * u, zy + 10 * u), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * u), lc)
			draw_line(Vector2(zx, zy), Vector2(zx + 180 * u, zy), lc, 2.0 * u)
			draw_rect(Rect2(zx + st.zoom * 172 * u, zy - 9 * u, 8 * u, 18 * u), lc)
		# the battery: three bars, two by the road, the last one blinking under the sky
		var bx: float = x0 + w - 110 * u; var by2: float = y0 + h - 48 * u
		draw_rect(Rect2(bx, by2, 70 * u, 28 * u), lc, false, 2.0 * u)
		var bars: int = st.batt
		for i in range(bars):
			if bars == 1 and not blink: continue
			draw_rect(Rect2(bx + (5 + i * 21) * u, by2 + 5 * u, 17 * u, 18 * u), lc)
		draw_rect(Rect2(bx + 70 * u, by2 + 8 * u, 6 * u, 12 * u), lc)
		if not end_mark:
			var c2 := Vector2(x0 + w / 2.0, y0 + h / 2.0)
			draw_line(c2 - Vector2(18 * u, 0), c2 + Vector2(18 * u, 0), lc, 2.0 * u); draw_line(c2 - Vector2(0, 18 * u), c2 + Vector2(0, 18 * u), lc, 2.0 * u)
var batt := 3
var zoom_show := 0.0

func _finder8():
	var layer := CanvasLayer.new(); layer.layer = 8; add_child(layer)   # under the print (10): the camera's marks are printed with the picture
	# the second of tape that was there before (夏希の「上映用」): a still, torn by the heads coming up to speed
	flash_tex = TextureRect.new(); flash_tex.set_anchors_preset(Control.PRESET_FULL_RECT); flash_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; flash_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://ui/ch8_natsuki.png"): flash_tex.texture = load("res://ui/ch8_natsuki.png")
	flash_tex.visible = false; layer.add_child(flash_tex)
	white = ColorRect.new(); white.color = Color(0.93, 0.92, 0.88, 0.0); white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(white)
	# 2026-11-22（全体レビュー 5、ユーザー「急に安っぽい」）：レンズの水は、描いた丸では刷りで同じ円盤になった。
	# 本物のレンズの水滴は、その奥の画を逆さに小さく映してぼかす。画そのものを水滴の中で屈折させる
	lens_water = ColorRect.new(); lens_water.set_anchors_preset(Control.PRESET_FULL_RECT); lens_water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsh := Shader.new(); lsh.code = LENS_WATER; var lm := ShaderMaterial.new(); lm.shader = lsh; lens_water.material = lm
	layer.add_child(lens_water)
	var f := Finder8.new(); f.st = self; f.fnt = Type.cam(); f.u = u
	f.set_anchors_preset(Control.PRESET_FULL_RECT); f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(f); finder8 = f
	if "--ch8nofin" in OS.get_cmdline_user_args(): layer.visible = false   # 確認用：ファインダーの枠なしで見る

var lens_water: ColorRect
const LENS_WATER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform vec4 drops[18];      // x, y (pixels), radius (pixels), shape seed
uniform int n = 0;
void fragment() {
	vec2 vs = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = SCREEN_UV * vs;
	vec4 o = vec4(0.0);
	for (int i = 0; i < 18; i++) {
		if (i >= n) break;
		vec4 d = drops[i];
		vec2 q = (p - d.xy) / vec2(d.z, d.z * 1.22);
		float a = atan(q.y, q.x);
		float edge = 1.0 + 0.10 * sin(a * 3.0 + d.w) + 0.06 * sin(a * 5.0 + d.w * 2.3);   // not a circle
		float r = length(q) / edge;
		if (r < 1.0) {
			// the scene behind, upside down and small, out of focus (a lens in the lens)
			vec2 s = (d.xy - (p - d.xy) * 0.55) / vs;
			vec3 c = textureLod(scr, s, 2.5).rgb;
			c *= mix(1.05, 0.55, smoothstep(0.55, 1.0, r) * smoothstep(-0.2, 0.9, q.y));   // its lower edge dark
			c += vec3(0.035) + vec3(0.22) * smoothstep(0.72, 0.95, r) * smoothstep(0.3, -0.8, q.y);   // the water lifts the dark a little; a thin light on its upper rim
			c += vec3(0.25) * smoothstep(0.16, 0.0, length(q - vec2(-0.35, -0.45)));              // the camera's lamp caught in it, a speck
			float al = smoothstep(1.0, 0.86, r) * 0.85;
			o = mix(o, vec4(c, 1.0), al);
		}
	}
	COLOR = o;
}
"""

func _fin8(on: bool):
	fin_on = on
	_cam().fov = lerpf(FOV_WIDE, FOV_TELE, zoom) if on else 70.0
	if main.get_viewport().use_occlusion_culling and on: pass

# ---------------------------------------------------------------- light: the camera's lamp, the lightning
func _lights8():
	# 2026-11-19：カメラのライト（暖色のスポット）はやめた。闇に丸い光が一つ、は「懐中電灯一灯」（使わない記号）と同じ画になる。
	# 代わりに、カメラが暗い所で感度を上げたぶん：向きも縁も影もない、近くだけの冷たい明るさ（青の版）。
	# オレンジの版は、画の中にある灯り（車の室内灯、扉の下から漏れる家の灯り）から。
	cam_light = OmniLight3D.new(); cam_light.name = "cam_gain"
	cam_light.light_color = Color(0.72, 0.82, 1.0)
	cam_light.light_energy = 0.0; cam_light.omni_range = 16.0; cam_light.omni_attenuation = 0.7
	cam_light.shadow_enabled = false; cam_light.light_specular = 0.0; cam_light.light_volumetric_fog_energy = 0.0
	_cam().add_child(cam_light); cam_light.position = Vector3(0.0, 0.6, 0.4)
	bolt8 = DirectionalLight3D.new(); bolt8.name = "bolt8"; bolt8.light_color = Color(0.86, 0.9, 1.0); bolt8.light_energy = 0.0
	bolt8.shadow_enabled = true; bolt8.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; bolt8.directional_shadow_max_distance = 45.0
	bolt8.light_volumetric_fog_energy = 0.3; bolt8.light_specular = 0.2
	main.add_child(bolt8)
	bolt8.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.62, -0.5), Vector3.UP)

# one stroke: two quick flashes and an afterglow; the finder's iris is late (the picture goes to paper, then comes back)
func _bolt(k := 1.0, thunder := true):
	var tw := create_tween()
	tw.tween_property(self, "bolt_e", 7.0 * k, 0.03)
	tw.tween_property(self, "bolt_e", 0.6 * k, 0.07)
	tw.tween_property(self, "bolt_e", 5.0 * k, 0.03)
	tw.tween_property(self, "bolt_e", 1.4 * k, 0.12)
	tw.tween_property(self, "bolt_e", 0.0, 0.5)
	if fin_on:
		var tw2 := create_tween()
		tw2.tween_property(white, "color:a", 0.75 * minf(k, 1.0), 0.04)
		tw2.tween_property(white, "color:a", 0.0, 0.22)
	if thunder: _after(randf_range(1.2, 2.4), func(): _one("thunder%d" % randi_range(1, 3), -3.0))

# ---------------------------------------------------------------- rain outside: streaks round the camera, lit by its lamp and by the lightning
const RAIN_N := 900
const RAIN_BOX := 12.0
const RAIN_H := 8.0
func _rain8():
	var q := QuadMesh.new(); q.size = Vector2(0.0035, 0.3)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = q; mm.instance_count = RAIN_N
	var rng := RandomNumberGenerator.new(); rng.seed = 8
	for i in RAIN_N:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(rng.randf() * RAIN_BOX, rng.randf() * RAIN_H, rng.randf() * RAIN_BOX)))
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec3 cam_pos; uniform vec3 cam_fwd; uniform float lit = 0.0; uniform float flash = 0.0; uniform float amount = 1.0;
uniform vec3 wind = vec3(0.9, 0.0, 0.35);
varying float bright;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float sp = 8.5 + fract(o.x * 7.31 + o.z * 3.17) * 3.0;
	o.y = mod(o.y - TIME * sp, %f);
	o.xz += wind.xz * (o.y / sp);
	o.xz = cam_pos.xz + mod(o.xz - cam_pos.xz + %f, %f) - %f;
	o.y += cam_pos.y - 2.5;
	vec3 to = o - cam_pos; float d = length(to);
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to));
	vec3 up = normalize(vec3(-wind.x / sp, 1.0, -wind.z / sp));
	vec3 wp = o + right * VERTEX.x * (1.0 + d * 0.12) + up * VERTEX.y;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wp, 1.0));
		bright = (lit * 0.22 * exp(-d / 5.0) + 0.012 + flash * 0.5) * amount * smoothstep(0.25, 0.9, d);
}
void fragment() { ALBEDO = vec3(0.6, 0.68, 0.8) * bright; }
""" % [RAIN_H, RAIN_BOX * 0.5, RAIN_BOX, RAIN_BOX * 0.5]
	rain_mat = ShaderMaterial.new(); rain_mat.shader = sh
	rain8 = MultiMeshInstance3D.new(); rain8.multimesh = mm; rain8.material_override = rain_mat
	rain8.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; rain8.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	rain8.custom_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 200, 1000))
	main.add_child(rain8); rain8.visible = false

# 外は夜の2時：遠くは闇に沈み、カメラのライトの届く所だけが見える。稲妻の一瞬だけ、谷まで見える。
# （本体の夜の外は、家の中から窓越しに見るための明るさ。そのまま歩くと昼のように見えた：2026-11-19 の確認画）
var night_k := 0.0; var dawn := 0.0; var fog0 := []
func _night8(dt: float, on: bool):
	var e: Environment = main.env
	if e == null: return
	if fog0.is_empty(): fog0 = [e.fog_density, e.fog_light_color, e.fog_light_energy, e.fog_sky_affect]
	# 試作232（全体レビュー5「外に出た直後と山道でファインダーがほぼ白に飛ぶ」）: the house's outside night (bright, for the
	# windows) stayed on for most of a second after the door, a white fog. The night comes at once outside; it goes slowly
	night_k = move_toward(night_k, 1.0 if on else 0.0, dt * (8.0 if on else 1.2))
	if night_k <= 0.0 and not on:
		e.fog_density = fog0[0]; e.fog_light_color = fog0[1]; e.fog_light_energy = fog0[2]; e.fog_sky_affect = fog0[3]; return
	var fl := clampf(bolt_e / 5.0, 0.0, 1.0)
	var dark := Color(0.012, 0.02, 0.035).lerp(Color(0.2, 0.27, 0.36), dawn)
	e.fog_light_color = (fog0[1] as Color).lerp(dark.lerp(Color(0.22, 0.26, 0.33), fl), night_k)   # (the flash's fog: 0.34-0.5 burnt the finder white)
	e.fog_light_energy = lerpf(fog0[2], 1.0, night_k)
	e.fog_density = lerpf(fog0[0], lerpf(0.075, 0.012, maxf(fl, dawn)), night_k)
	e.fog_sky_affect = lerpf(fog0[3], 1.0, night_k)

func _outside() -> bool:
	var p := _plan()
	return p[1] < -0.05 and stage != "top"

# ---------------------------------------------------------------- the start
func _place():
	await get_tree().physics_frame
	await get_tree().physics_frame
	_porch_ramp()
	# 試作232（全体レビュー2「二階の廊下を真正面から見た一点透視の画で始まる」）: he starts turned across the landing to the
	# stairwell and its rail (three-quarter), not down the corridor
	_stand_at(TOP_AT, -38.0, -14.0, F2)
	player.eye_height = EYE
	match start8:
		"take": _stand_at(TAKE_AT, 150.0, -20.0, 0.0)
		"rec":
			_stand_at(TAKE_AT, 180.0, -21.0, 0.0); _take_now(true); script_q.clear(); mode = FREE
		"out", "car", "knock", "road", "corner", "sky":
			_stand_at(OUT_AT, 0.0, -3.0); _take_now(true); _set_rec_now(); cam_h = EYE; _hide("mio")

func _begin(st: String):
	stage = st; t_stage = 0.0
	print("STORY ch8 %s t=%.1f" % [st, t_now])
	match st:
		"top":
			if cel8 == "":
				_put("mio", CEL_MIO, _face(CEL_MIO, [5.5, 2.2]), CEL_Z)
				if dn: dn.open_key("door_cellar")
			_start(B("八.二階"))
			_one("ch3_moan", -16.0, gp(5.5, 2.6, -1.4))
			_after(2.6, func(): _one("ch3_cough", -12.0, gp(8.5, 1.5, F2 + 0.8)))
		"to_car":
			_set_mission(String(D.lines("八.録画")[-1]).substr(1))
		"door":
			knock_ready = true; d_on = false; d_t = 0.0
		"road":
			_road_start()
		"corner":
			_start(B("八.角"))
		"edge":
			edge_t = 0.0
		"sky":
			sky_q = B("八.空"); sky_i = 0

# he lifts it off the head: from here the picture is the camera's
func _take_now(quick := false):
	_vcam(false)
	_one("tape_clunk", -10.0)
	_fin8(true)
	cam_h = CHEST
	stage = "hall"; t_stage = 0.0
	_set_mission("")
	player.look_enabled = false
	_show("mio")
	if quick: return
	# his eyes on the camera in his hands; her feet come into the bottom of the picture; he tilts up, and stops at her mouth
	# his eyes on the camera in his hands; then the picture comes up onto her back: she sits at the step, the door before her
	# 試作232（全体レビュー4「澪を真上から見下ろす画（頭のてっぺん）」）: 0.6 m from her at his chest's height the picture
	# looked down on her crown. He takes a step back up the hall first: from 1.4 m her back and shoulders, the door past her
	var back := gp(4.62, 2.95, 0.0); back.y = player.global_position.y
	create_tween().tween_property(player, "global_position", back, 1.1).set_trans(Tween.TRANS_SINE)
	var hd := gp(MIO_WAIT[0], MIO_WAIT[1], 1.05)
	_turn_to(_yaw_to(hd), deg_to_rad(-40.0), 0.6)
	_after(1.1, func(): _turn_to(_yaw_to(hd), deg_to_rad(-14.0), 1.8))
	_after(2.6, func(): _start(B("八.廊下")))

# the picture's top edge at her mouth (the interview cuts its listener at the chest, the chin, the mouth: the same grammar)
func _talk_pitch() -> float:
	var mouth := 1.45    # 2026-11-20 立った澪の口元（座っていたときは 1.325：頭の骨の付け根が 1.26、--ch8probe）
	var d := 1.6
	if _has("mio"):
		var r: Node3D = main._rig_of("mio"); d = Vector2(r.global_position.x - player.global_position.x, r.global_position.z - player.global_position.z).length()
	var half := atan(PIC_H * tan(deg_to_rad(FOV_WIDE * 0.5)))
	return atan2(mouth - CHEST, maxf(d, 0.5)) - half

func _set_rec_now():
	rec8 = true; rec_t = 0.0; rec_c0 = clock

# ================================================================ what the lines set off
func _do(what: String):
	if _flag_do(what): return   # 2026-11-20 the night's record (story.gd FLAG_DOS)
	print("STORY ch8 do %s t=%.1f" % [what, t_now])
	match what:
		"mio_shake":
			if mio_shake:
				var tw := create_tween()
				for i in 2:
					tw.tween_property(mio_shake, "a", 0.24, 0.2).set_trans(Tween.TRANS_SINE)
					tw.tween_property(mio_shake, "a", -0.24, 0.26).set_trans(Tween.TRANS_SINE)
				tw.tween_property(mio_shake, "a", 0.0, 0.2)
		"rec_wait":
			script_q.clear(); mode = FREE
			stage = "rec_wait"; t_stage = 0.0
		"to_door":
			stage = "to_door"; t_stage = 0.0
			# the camera comes up to his eye as he turns to the door: from here he walks looking through it
			_eye_to(EYE, 1.4)
			var tw := _turn_to(0.0, deg_to_rad(-4.0), 1.5)
			tw.chain().tween_callback(func(): player.look_enabled = true; yaw_lock = true)
		"car_door":
			_one("car_door", -6.0, car_at)
			_natsuki_out()
			_after(3.0, func(): if stage == "car": zoom_want = 0.5)
		"to_knock":
			stage = "to_knock"; t_stage = 0.0; player.look_enabled = true; zoom_want = 0.0
			clock = 2.0 * 3600.0 + 29.0 * 60.0 + 30.0
			if _has("natsuki"): main.walk_to("natsuki", _way([[5.9, -4.6], [5.75, -2.9], [5.72, -1.05]]), Callable(), _face([5.72, -1.05], [5.0, 0.0]))
		"knock":
			_knock()
		"knock_ready":
			knock_ready = true
		"grab_mio":
			_grab_arm()
		"cel_done":
			_cel_done()
		"to_road":
			script_q.clear(); mode = FREE
			_begin("road")
		"natsuki_turn":
			if _has("natsuki"):
				nat_wait = true
				main.walkers.erase("natsuki"); main.set_stand("natsuki", "talk/idle", 0.3)
				var r: Node3D = main._rig_of("natsuki")
				create_tween().tween_property(r, "rotation:y", r.rotation.y + wrapf(_face(_plan_of("natsuki"), _plan()) - r.rotation.y, -PI, PI), 0.7)
				_after(4.5, func(): nat_wait = false)
		"bolt":
			_bolt(1.3)
		"to_edge":
			script_q.clear(); mode = FREE
			_begin("edge")
		"tape_end":
			_tape_lapse()
		_: super._do(what)

# ---------------------------------------------------------------- 録画：押すのはプレイヤー。夏希の1秒が出て、消える
func _press_rec():
	if stage != "rec_wait": return
	stage = "flash"; t_stage = 0.0
	note_lb.text = ""
	_one("tape_clunk", -6.0)
	# the heads come up to speed on what was there: her face, one second, the line torn; then his own picture, recording
	flash_tex.visible = flash_tex.texture != null
	(finder8 as Finder8).glitch = 0.5
	var ln: Array = B("八.一秒")
	if demo_on: print("SAY 夏希：%s" % String(ln[0].text))
	_clear_page(); named.clear(); last_who = ""
	var r := _line_row("夏希", String(ln[0].text))
	(r[1] as Label).visible_characters = -1
	_one("tape_hiss", -12.0)
	_after(1.0, func():
		flash_tex.visible = false; (finder8 as Finder8).glitch = 0.9
		_clear_page()
		_after(0.12, func():
			(finder8 as Finder8).glitch = 0.0
			_set_rec_now()
			_one("dial_tick", -8.0)
			stage = "rec"; t_stage = 0.0
			_after(1.3, func(): _start(B("八.録画")))))

# ---------------------------------------------------------------- 玄関を出る。後ろで澪が鍵を閉める
func _open_front():
	if stage != "to_door" or not _near_door(1.5): return
	stage = "opening"; t_stage = 0.0
	_one("ch3_lock", -8.0, gp(5.0, 0.05, 1.0))
	_after(0.5, func():
		_one("door_open", -4.0, gp(DOOR[0], DOOR[1], 1.0))
		_door_to(84.0, 1.0)
		_loop_db("rain_out", -7.0, 1.0)
		_after(1.0, func(): stage = "leaving"; t_stage = 0.0))

func _left():
	stage = "out"; t_stage = 0.0
	yaw_lock = false
	_door_to(0.0, 1.0)
	_after(1.0, func(): _one("door_close", -5.0, gp(DOOR[0], DOOR[1], 1.0)); _hide("mio"))
	_after(2.9, func():
		_one("ch3_lock", -6.0, gp(5.0, 0.05, 1.0))
		_start(B("八.外"))
		_after(0.2, func(): stage = "to_car"; _begin("to_car")))

# ---------------------------------------------------------------- 車の夏希
func _natsuki_out():
	if not _has("natsuki"): return
	# she gets out on the far side and comes round the back of the car, and stops when he says so
	var me := Vector3(player.global_position.x, 0, player.global_position.z); var c := Vector3(car_at.x, 0, car_at.z)
	var away := (c - me).normalized(); var side := away.cross(Vector3.UP)
	# she stops where he says to: two and a half metres off, a little to one side of the line to the car (the car stays in the picture behind her)
	var p0 := c + side * 1.25; var p1 := c + side * 1.2 - away * (car_r + 0.4); var p2 := me + away * 2.6 + side * 0.45
	var pl := func(v: Vector3) -> Array: return [v.x + 4.8, v.z + 6.3]
	if car_dome: car_dome.global_position = c + side * 0.95 + Vector3(0, car_at.y + 0.5, 0)
	_show("natsuki")
	_put("natsuki", pl.call(p0), 0.0, _ground(pl.call(p0)[0], pl.call(p0)[1]))
	# 試作232（全体レビュー6「約50秒の会話の間、腕を下ろした棒立ち」）: where she stops she talks with her hands (talk_a), not idle
	main.walk_to("natsuki", _way([pl.call(p1), pl.call(p2)]), func(): main.set_stand("natsuki", "talk/talk_a", 0.5), _face(pl.call(p2), _plan()))
	talk_with = "natsuki"

# the operator keeps her in the picture: her face a little above the middle
func _frame8(k: String, h: float, dt: float):
	if not _has(k) or not (main.S[k + "_node"] as Node3D).visible: return
	var to: Vector3 = main._rig_of(k).global_position + Vector3(0, h, 0) - _cam().global_position
	var yaw := atan2(-to.x, -to.z); var pitch := atan2(to.y, Vector2(to.x, to.z).length()) - deg_to_rad(_cam().fov * 0.07)
	var kk := 1.0 - exp(-dt * 2.2)
	if "--ch8trace" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 24 == 0: print("C8FRAME yaw %.1f want %.1f pitch %.1f want %.1f to %s auto %d" % [rad_to_deg(player.yaw), rad_to_deg(yaw), rad_to_deg(player.pitch), rad_to_deg(pitch), to, player.auto_path.size()])
	player.yaw = lerp_angle(player.yaw, yaw, kk); player.pitch = lerp_angle(player.pitch, pitch, kk)

# plan points [x, y] with the ground's height under each
func _way(pts: Array) -> Array:
	var out := []
	for q in pts: out.append([q[0], q[1], _ground(q[0], q[1])])
	return out

# ---------------------------------------------------------------- 扉を外から叩く（三度）
func _knock_press():
	if stage != "door": return
	if not (_near_door(1.5) and _plan()[1] < -0.2): return
	if t_now - knock_last < 1.4: return
	knock_last = t_now
	_knock()   # his own: as often as he likes. Nothing comes back for it
	if not d_on: _dflow_start()

# ---------------------------------------------------------------- 2026-11-20 二時半を外から（第3章の記録 door_0230 で組む）
# The seconds are 第3章's (扉の番.二時半), from his first knock. Her questions come at the times she asked them, from inside,
# a little muffled, and his answer at once (he does not choose it). Where she kept still nothing comes back. While she was at
# the door the light under it is less (her shadow, the blanket). The set knocks (2, 11, 38) are his hand's if he does not knock.
var d_on := false
var d_t := 0.0
var d_flow: Array = []
var d_fi := 0
var d_q: Array = []            # her question and his answer, being said (his side waits)
var d_hold := 0.0
var d_rec := {}
var d_asks: Array = []
var knock_last := -9.0
func _dflow_start():
	d_on = true; d_t = 0.0; d_fi = 0; d_q = []; d_hold = 0.0
	_set_mission("")
	clock = 2.0 * 3600.0 + 31.0 * 60.0
	d_flow = []
	for e in D.entries("八.扉.流れ"): if e.has("t"): d_flow.append(e)
	var r = get_flag("door_0230", null)
	d_rec = r if r is Dictionary else {}
	if d_rec.is_empty() and "--ch8rec" in OS.get_cmdline_user_args():   # (the check of this part alone: a night as the playthrough of 第3章 leaves it)
		d_rec = {"pos": [[0.0, "sit"], [9.0, "near"], [10.0, "ear"], [25.0, "near"], [44.0, "sit"]], "asks": [[13.0, 0], [30.5, 1]], "silences": [[13.0, 17.5], [30.5, 32.5]], "said_rule": true}
		set_flag("said_rule")
	d_asks = []
	for a in d_rec.get("asks", []):
		if a is Array and a.size() >= 2 and not (a[1] is String): d_asks.append([float(a[0]), int(a[1])])
	print("CH8 door record asks=%s pos=%s" % [d_asks, d_rec.get("pos", [])])
	_clear_page()

func _dflow_tick(dt: float):
	if not d_on:
		return
	if not d_q.is_empty() or d_hold > 0.0:
		if cur.has("text") and typed < String(cur.text).length(): pass
		else:
			d_hold -= dt
			if d_hold <= 0.0 and not d_q.is_empty():
				var e: Dictionary = d_q.pop_front(); _dline(e)
				d_hold = 0.9 + String(e.get("text", e.get("note", ""))).length() * 0.05
	else:
		d_t += dt
		if not d_asks.is_empty() and d_t >= float(d_asks[0][0]):
			var a: Array = d_asks.pop_front()
			var ch: Array = D.entries("八.扉.問い")
			if not ch.is_empty() and int(a[1]) < (ch[0].then as Array).size(): d_q = ((ch[0].then as Array)[int(a[1])] as Array).duplicate(true)
			print("CH8 door ask %d at %.1f" % [int(a[1]), d_t])
		else:
			while d_fi < d_flow.size() and d_t >= float(d_flow[d_fi].t):
				var e: Dictionary = d_flow[d_fi]; d_fi += 1
				if e.has("if") and not has_flag(String(e["if"])): continue
				if e.has("do"):
					match String(e.do):
						"knock":
							if t_now - knock_last > 1.0: knock_last = t_now; _knock()
						"to_road":
							d_on = false; _begin("road")
							return
						_: _do(String(e.do))
				else: _dline(e)
	if cur.has("text") and typed < String(cur.text).length():
		if not is_instance_valid(cur_lb): cur = {}; return
		typed = minf(float(String(cur.text).length()), typed + dt * 15.0)
		_type(cur_lb, String(cur.text), int(typed))

func _dline(e: Dictionary):
	if demo8: print("SAY %.1f %s" % [d_t, (String(e.who) + "：" + String(e.text)) if e.has("who") else String(e.get("note", ""))])
	if e.has("note"):
		_line_row("", String(e.note), 22, "note"); cur = {}
		if String(e.note).contains("咳"): _one("ch3_cough", -6.0, gp(5.72, -1.05, 1.0))
		return
	cur = {"who": e.who, "text": _wrap_row(Tw(String(e.text))), "who_key": WHO_KEY.get(e.who, "")}
	typed = 0.0
	var r = _line_row(String(e.who), "", SAY_SIZE, "say")
	cur_lb = r[1]
	if String(e.who).begins_with("澪"): (cur_lb as Label).modulate = Color(1, 1, 1, 0.8)   # from inside, through the wood

# where she was at this second (第3章): at the door, the light under it is less
func _gap_k() -> float:
	if stage != "door" or not d_on: return 1.0
	var at := "sit"
	for pq in d_rec.get("pos", []):
		if pq is Array and float(pq[0]) <= d_t: at = String(pq[1])
	return 0.55 if at in ["near", "ear"] else 1.0

# ---------------------------------------------------------------- 2026-11-20 地下の扉（ここだけファインダーでない）
# Down the stair: behind the open cellar door, at the foot of the cellar stair, Mio pushes at the barred door. E: his hand
# on her wrist. Then the hall (a cut: 第3章 to_hall), and the camera off its tripod as before.
const CEL_MIO := [5.5, 3.05]
const CEL_Z := -1.95                 # the cellar stair's ramp there (rooms2.climb_boxes: y 5.6 at 0 down to y 2.45 at -2.45)
const MIO_WAIT2 := [4.95, 5.05]
var cel8 := ""                       # "" | heard | grabbing | done
var grab8: Node3D
func _cel_parts() -> Array:
	var before := []; var prompt := ""; var after := []
	for e in D.entries("八.地下の扉"):
		if prompt == "" and e.has("note") and String(e.note).begins_with("［Ｅ"): prompt = String(e.note); continue
		if prompt == "": before.append(e)
		else: after.append(e)
	return [before, prompt, after]

func _cel_heard():
	cel8 = "heard"
	_one("ch3_thud", -2.0, gp(5.5, 2.45, -1.6)); _one("body_fall", -8.0, gp(5.5, 2.45, -1.6))
	_set_mission("")
	_start(_cel_parts()[0])

func _cel_look() -> bool:
	if mode != FREE or not _has("mio"): return false
	var hd: Vector3 = main._rig_of("mio").global_position + Vector3(0, 1.2, 0)
	var to := hd - _cam().global_position
	if not (to.length() < 4.5 and (-_cam().global_basis.z).angle_to(to) < deg_to_rad(30.0)): return false
	# 2026-11-21 (review): not through the floor from the hall. At the stair head (plan 5.0, 5.9) she is seen down the stairwell, whose
	# edge the ray clips (試作238: a height limit, then a plain ray, stopped the demo there), so there it is let through
	var p := _plan()
	if Vector2(p[0] - 5.0, p[1] - 5.9).length() < 0.9: return true
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_cam().global_position, hd))
	return hit.is_empty() or (hit.position as Vector3).distance_to(hd) < 0.6

func _cel_grab():
	cel8 = "grabbing"; note_lb.text = ""
	var q: Array = (_cel_parts()[2] as Array).duplicate(true)
	q.append({"do": "cel_done"})
	_start(q)

# his hand comes down from the lower right onto her wrist (she reaches for the door: her hand at her chest's height, before her)
func _grab_arm():
	if grab8 == null:
		grab8 = _fp_arm("kiryu", "r", Vector3(0.35, -0.55, 0.76), Vector3(0, 1, 0.15), 0.8)
	if grab8 == null: return
	var rig: Node3D = main._rig_of("mio")
	var fwd := Vector3(sin(rig.rotation.y), 0, cos(rig.rotation.y))
	var wr: Vector3 = rig.global_position + Vector3(0, 1.05, 0) + fwd * 0.3 + rig.global_basis.x * -0.18
	var loc := _cam().to_local(wr)
	if loc.length() > 0.75: loc = loc.normalized() * 0.75
	grab8.position = Vector3(0.32, -0.5, -0.15); grab8.visible = true
	var tw := create_tween()
	tw.tween_property(grab8, "position", loc, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(grab8, "position", Vector3(0.32, -0.55, -0.1), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): grab8.visible = false)
	_one("ch3_blanket", -4.0, wr)

# a cut: the hall, she by the cellar door, he a few steps toward the tripod
func _cel_done():
	cel8 = "done"
	player.auto_path = []; demo_goal = []; demo_route = []
	if grab8: grab8.visible = false
	var cl := CanvasLayer.new(); cl.layer = 11; add_child(cl)
	var bk := ColorRect.new(); bk.color = Color(0, 0, 0, 1); bk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bk.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(bk)
	var tw := create_tween(); tw.tween_interval(0.25); tw.tween_property(bk, "color:a", 0.0, 0.9); tw.tween_callback(cl.queue_free)
	_put("mio", MIO_WAIT2, _face(MIO_WAIT2, TAKE_AT))
	_stand_at([4.75, 3.7], rad_to_deg(atan2(-(TRIPOD[0] - 4.75), -(TRIPOD[1] - 3.7))), -10.0, 0.0)
	_set_mission("")

func _knock():
	# 試作232（ユーザー「ここ、叩いてる動きを入れたい」）: his free hand comes into the picture from the lower right and strikes
	# the door three times, on the sound (the camera is in his other hand)
	var arm := _knock_arm()
	var cam: Camera3D = _cam()
	var dp: Vector3 = cam.to_local(gp(DOOR[0], DOOR[1] - 0.05, 1.25))
	var hit := Vector3(0.09, -0.06, -clampf(-dp.z - 0.06, 0.32, 0.62))
	var rest := Vector3(0.30, -0.42, -0.22); var back := hit + Vector3(0.05, -0.04, 0.16)
	arm.position = rest; arm.visible = true
	var tw := create_tween()
	tw.tween_property(arm, "position", back, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in 3:
		tw.tween_property(arm, "position", hit, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(arm, "position", back, 0.33).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(arm, "position", rest, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): arm.visible = false)
	_after(0.31, func(): _one("knock", 0.0, gp(DOOR[0], DOOR[1], 1.2)))
	for i in 3:
		_after(0.31 + 0.42 * i, func(): door_shake = 1.0; cam_shake = 1.0)

var knock_arm: Node3D
func _knock_arm() -> Node3D:
	if knock_arm and is_instance_valid(knock_arm): return knock_arm
	if ResourceLoader.exists("res://props/kiryu_arm_r.glb"): return _knock_arm_kiryu()
	knock_arm = Node3D.new(); knock_arm.name = "knock_arm"
	var sleeve := StandardMaterial3D.new(); sleeve.albedo_color = Color(0.13, 0.13, 0.13); sleeve.roughness = 0.95
	var skin := StandardMaterial3D.new(); skin.albedo_color = Color(0.42, 0.31, 0.25); skin.roughness = 0.75
	# 試作233: the forearm runs from the wrist back to the lower right corner of the picture (seen from behind, as his own arm)
	var d := Vector3(0.42, -0.55, 0.72).normalized()
	var bas := Basis(Quaternion(Vector3.UP, d))
	var fore := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.058; cy.bottom_radius = 0.042; cy.height = 0.55; fore.mesh = cy
	fore.material_override = sleeve; fore.transform = Transform3D(bas, Vector3(0, -0.005, 0.03) + d * 0.3)
	knock_arm.add_child(fore)
	var cuff := MeshInstance3D.new(); var cc := CylinderMesh.new(); cc.top_radius = 0.047; cc.bottom_radius = 0.047; cc.height = 0.03; cuff.mesh = cc
	cuff.material_override = sleeve; cuff.transform = Transform3D(bas, Vector3(0, -0.005, 0.03) + d * 0.035)
	knock_arm.add_child(cuff)
	var wrist := MeshInstance3D.new(); var wc := CylinderMesh.new(); wc.top_radius = 0.03; wc.bottom_radius = 0.027; wc.height = 0.07; wrist.mesh = wc
	wrist.material_override = skin; wrist.transform = Transform3D(bas, Vector3(0, -0.005, 0.03))
	knock_arm.add_child(wrist)
	var fist := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.085, 0.075, 0.09); fist.mesh = bm
	fist.material_override = skin; fist.rotation = Vector3(deg_to_rad(8.0), deg_to_rad(-12.0), deg_to_rad(-10.0))
	knock_arm.add_child(fist)
	for k in 4:   # the knuckles and the folded fingers, on the door side
		var kn := MeshInstance3D.new(); var ks := SphereMesh.new(); ks.radius = 0.014; ks.height = 0.028; kn.mesh = ks
		kn.material_override = skin; kn.position = Vector3(-0.03 + 0.02 * k, 0.03, -0.045); knock_arm.add_child(kn)
		var fg := MeshInstance3D.new(); var fc := CapsuleMesh.new(); fc.radius = 0.011; fc.height = 0.05; fg.mesh = fc
		fg.material_override = skin; fg.position = Vector3(-0.03 + 0.02 * k, 0.0, -0.05); knock_arm.add_child(fg)
	var thumb := MeshInstance3D.new(); var tc := CapsuleMesh.new(); tc.radius = 0.012; tc.height = 0.06; thumb.mesh = tc
	thumb.material_override = skin; thumb.position = Vector3(-0.045, -0.02, -0.02); thumb.rotation = Vector3(0.0, deg_to_rad(30.0), deg_to_rad(70.0))
	knock_arm.add_child(thumb)
	for m in knock_arm.get_children(): (m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cam().add_child(knock_arm); knock_arm.visible = false
	return knock_arm

# 試作234（独立レビュー「灰色の筒に箱が付いたよう」）: Kiryu's own forearm and hand (props/kiryu_arm_r.glb, WHO=kiryu
# export_mio_arms.py; the same frame as Mio's: the wrist at the origin, the fingers -Z, the palm -Y, the sleeve +Z), the fingers
# curled into a fist, the knuckles to the door and the palm to the left, the forearm back to the lower right of the picture
func _knock_arm_kiryu() -> Node3D:
	knock_arm = Node3D.new(); knock_arm.name = "knock_arm"
	var inst: Node3D = (load("res://props/kiryu_arm_r.glb") as PackedScene).instantiate()
	var d := Vector3(0.42, -0.55, 0.72).normalized()
	var yb := (Vector3(1, 0.25, 0) - d * Vector3(1, 0.25, 0).dot(d)).normalized()
	inst.basis = Basis(yb.cross(d), yb, d)
	knock_arm.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; m.extra_cull_margin = 0.6
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var to_h := Transform3D(); var nd: Node3D = sk
	while nd != knock_arm: to_h = nd.transform * to_h; nd = nd.get_parent()
	var to_a := inst.transform.affine_inverse() * to_h   # in the arm's own frame
	var fist := []
	for f in ["index", "middle", "ring", "pinky", "thumb"]:
		for j in 3:
			var bi := sk.find_bone("%s_0%d_r" % [f, j + 1])
			if bi < 0: continue
			var gb: Basis = (to_a * sk.get_bone_global_rest(bi)).basis.orthonormalized()
			var ax: Vector3 = (gb.y.cross(Vector3.DOWN)).normalized()
			if f == "thumb":
				var o: Vector3 = (to_a * sk.get_bone_global_rest(bi)).origin
				ax = gb.y.cross((Vector3(0.0, -0.035, -0.075) - o).normalized()).normalized()
			var ang: float = (1.3 * 0.6 * [0.30, 0.55, 0.40][j]) if f == "thumb" else (1.65 * [0.80, 1.05, 0.70][j])
			fist.append([bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion((gb.inverse() * ax).normalized(), ang)])
	_cam().add_child(knock_arm); knock_arm.visible = false
	for b in fist: sk.set_bone_pose_rotation(b[0], b[1])   # once it is in the tree (a pose set before was reset)
	print("CH8 knock arm bones ", fist.size())
	return knock_arm

# ---------------------------------------------------------------- 山道：夏希が先を行く。桐生はカメラに話し続ける
func _road_start():
	clock = 2.0 * 3600.0 + 34.0 * 60.0
	batt = 2
	nat_way = _way(DRIVE + ROAD + [CORNER_AT]); nat_i = 0
	_set_mission(String(D.lines("八.扉.流れ")[-1]).substr(1))
	nat_phone_want = 1.0

func _nat_tick():
	if not _has("natsuki") or nat_wait or nat_i >= nat_way.size(): return
	if main.walkers.has("natsuki"): return
	var me := _plan(); var n := _plan_of("natsuki")
	var ahead := Vector2(n[0] - me[0], n[1] - me[1]).length()
	if ahead > 7.5:      # she waits for him, looking back
		var r: Node3D = main._rig_of("natsuki")
		r.rotation.y = lerp_angle(r.rotation.y, _face(n, me), 0.04)
		return
	var seg := [nat_way[nat_i]]; nat_i += 1
	main.walk_to("natsuki", seg)

func _road_progress() -> float:
	# metres along the way down, by the nearest point of it
	var p := _plan(); var all: Array = DRIVE + ROAD + [CORNER_AT]
	var best := 0.0; var bd := 1e9; var acc := 0.0
	for i in all.size() - 1:
		var a := Vector2(all[i][0], all[i][1]); var b := Vector2(all[i + 1][0], all[i + 1][1])
		var ab := b - a; var k := clampf((Vector2(p[0], p[1]) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := (a + ab * k).distance_to(Vector2(p[0], p[1]))
		if d < bd: bd = d; best = acc + ab.length() * k
		acc += ab.length()
	return best

const ROAD_LINES := [[4.0, "一"], [19.0, "二"], [36.0, "三"], [54.0, "四"], [72.0, "五"]]
func _road_tick():
	if mode != FREE: return
	var s := _road_progress()
	for e in ROAD_LINES:
		if s >= float(e[0]) and not road_said.has(e[1]):
			road_said[e[1]] = true
			if e[1] == "三": batt = 2
			_start(B("八.道." + String(e[1]))); return
	var p := _plan()
	if road_said.size() == ROAD_LINES.size() and Vector2(p[0] - CORNER_AT[0], p[1] - CORNER_AT[1]).length() < 7.0:
		clock = 2.0 * 3600.0 + 41.0 * 60.0
		_begin("corner")

# ---------------------------------------------------------------- 崩れた路肩：撮りに寄って、落ちる
# how far the ground drops a step ahead of him toward the ravine
func _drop_ahead(dist := 0.9) -> float:
	var p := _plan()
	var here := _ground(p[0], p[1])
	return here - _ground(p[0] + SLIP_OUT[0] * dist, p[1] + SLIP_OUT[1] * dist)

func _edge_tick(dt: float):
	edge_t += dt
	var p := _plan()
	var near_slip := Vector2(p[0] - SLIP_MID[0], p[1] - SLIP_MID[1]).length() < 9.0
	var looking_down: bool = player.pitch < deg_to_rad(-10.0)
	if near_slip and _drop_ahead() > 0.7 and (looking_down or edge_t > 20.0): _fall(); return
	if not road_said.has("寄る") and near_slip and _drop_ahead(2.2) > 0.7:
		road_said["寄る"] = true; _start(B("八.角.寄る"))
	# he does not wait for ever: the shot is his, and he goes for it
	if edge_t > 45.0 and player.auto_path.is_empty() and not demo8:
		var to := Vector2(SLIP_MID[0] + SLIP_OUT[0] * 1.5 - p[0], SLIP_MID[1] + SLIP_OUT[1] * 1.5 - p[1])
		var y1 := rad_to_deg(atan2(-to.x, -to.y))
		player.auto_path = [[0.0, player.global_position.x, player.global_position.z, rad_to_deg(player.yaw), rad_to_deg(player.pitch)],
			[1.5, player.global_position.x, player.global_position.z, rad_to_deg(player.yaw) + wrapf(y1 - rad_to_deg(player.yaw), -180.0, 180.0), -24.0],
			[1.5 + to.length() / 0.8, SLIP_MID[0] + SLIP_OUT[0] * 1.5 - 4.8, SLIP_MID[1] + SLIP_OUT[1] * 1.5 - 6.3, y1, -24.0]]
		player.auto_t = 0.0

func _fall():
	if stage == "fall": return
	stage = "fall"; t_stage = 0.0; fall_t = 0.0
	script_q.clear(); mode = END
	_clear_page(); _set_mission(""); note_lb.text = ""
	player.auto_path = []; player.velocity = Vector3.ZERO
	player.set_physics_process(false); player.input_enabled = false
	_one("ch8_slide", -2.0); _one("body_fall", -6.0)
	nat_wait = true; main.walkers.erase("natsuki")
	# down the slumped earth: points on the ground every metre out from the edge, the camera a hand's height over them
	var p := _plan(); fall_path = []
	var cam := _cam()
	fall_from = cam.global_transform
	for i in 9:
		var x: float = p[0] + SLIP_OUT[0] * (0.6 + i * 0.85); var y: float = p[1] + SLIP_OUT[1] * (0.6 + i * 0.85)
		fall_path.append(Vector3(x - 4.8, _ground(x, y) + 0.22, y - 6.3))
	# where it comes to rest: in his hand on the slope, looking up past the broken edge into the rain
	var rest: Vector3 = fall_path[-1]
	var up_slope := Vector3(-SLIP_OUT[0], 0.0, -SLIP_OUT[1]).normalized()
	var look := (up_slope * 0.32 + Vector3.UP).normalized()
	fall_to = Transform3D(Basis.looking_at(look, up_slope.rotated(Vector3.UP, 0.5)), rest)
	cam.top_level = true; cam.global_transform = fall_from

func _fall_tick(dt: float):
	fall_t += dt
	var cam := _cam()
	var dur := 2.1
	var k := clampf(fall_t / dur, 0.0, 1.0)
	var ke := 1.0 - pow(1.0 - k, 2.2)
	var f := ke * (fall_path.size() - 1); var i0 := mini(int(f), fall_path.size() - 2)
	var pos: Vector3 = (fall_path[i0] as Vector3).lerp(fall_path[i0 + 1], f - i0)
	if k < 0.12: pos = fall_from.origin.lerp(pos, k / 0.12)
	pos.y += 0.25 * absf(sin(k * PI * 3.0)) * (1.0 - k)
	# it turns over and over in his grip, slower as the slope takes him
	var spin := Basis(Vector3(0.3, 0.2, 1.0).normalized(), ke * TAU * 1.75) * Basis(Vector3.RIGHT, ke * TAU * 1.0)
	var b: Basis = (fall_from.basis * spin).slerp(fall_to.basis, pow(k, 3.0)) if k < 1.0 else fall_to.basis
	cam.global_transform = Transform3D(b.orthonormalized(), pos if k < 1.0 else fall_to.origin)
	(finder8 as Finder8).glitch = (0.35 + 0.65 * absf(sin(k * 19.0))) * (1.0 - k) if k < 1.0 else 0.0
	if fall_t > dur + 0.01 and stage == "fall":
		_one("tripod_bump", -6.0)
		light_want = 0.35   # the lamp's glass is cracked: a little of it left, on the rain over the lens
		batt = 1
		clock = 2.0 * 3600.0 + 41.0 * 60.0 + 20.0
		_begin("sky")

# ---------------------------------------------------------------- 雨の空。操作は無い。行は秒で出る
var sky_light: OmniLight3D
func _sky_tick(dt: float):
	# the lens's water
	var F := finder8 as Finder8
	if randf() < dt * 2.4 and F.drops.size() < 18:
		var y0 := randf_range(0.05, 0.9); F.drops.append([Vector2(randf_range(0.06, 0.94), y0), randf_range(9.0, 30.0), 0.0, y0])
	for d in F.drops:
		d[2] += dt
		if d[2] > 2.5: d[0].y += dt * 0.012 * d[1] / 20.0
	F.drops = F.drops.filter(func(d): return d[2] < 9.0 and d[0].y < 1.0)
	while sky_i < sky_q.size() and t_stage >= float(sky_q[sky_i].get("t", 0.0)):
		var e: Dictionary = sky_q[sky_i]; sky_i += 1
		if e.has("if") and not has_flag(String(e["if"])): continue
		if demo_on: print("SAY %s%s" % [(String(e.who) + "：") if e.has("who") else "", str(e.get("text", e.get("note", e.get("do", ""))))])
		if e.has("do"): _do(String(e.do)); continue
		if e.has("note"):
			_line_row("", String(e.note), 22, "note")
			var n := String(e.note)
			if n.contains("下りてくる"): _one("ch8_scramble", -8.0, _cam().global_position + Vector3(-3, 3, 0))
			if n.contains("滑る"): _one("ch8_slide", -7.0, _cam().global_position + Vector3(-2, 1.5, 1))
			if n.contains("鈍い"): _one("body_fall", -5.0, _cam().global_position + Vector3(-1.5, 0.3, 1.5)); nat_phone_want = 0.0; if sky_light: create_tween().tween_property(sky_light, "light_energy", 0.0, 0.15)
			if n.contains("上がっていく"): _one("ch8_steps_away", -9.0, _cam().global_position + Vector3(-3, 3, 0))
			continue
		named.clear(); last_who = ""
		var r := _line_row(String(e.who), String(e.text)); (r[1] as Label).visible_characters = -1
		if sky_light == null:
			# her phone's light from the road above: it finds the slope, comes down it
			sky_light = OmniLight3D.new(); sky_light.light_color = Color(0.74, 0.86, 1.0); sky_light.omni_range = 9.0; sky_light.omni_attenuation = 1.1
			sky_light.shadow_enabled = false; sky_light.light_energy = 0.0; main.add_child(sky_light)
			var upv := Vector3(-SLIP_OUT[0], 0.0, -SLIP_OUT[1]).normalized()
			sky_light.global_position = _cam().global_position + upv * 5.5 + Vector3(0, 3.6, 0)
			create_tween().tween_property(sky_light, "light_energy", 1.6, 1.2)
		if String(e.text).contains("いま行く"):
			var upv2 := Vector3(-SLIP_OUT[0], 0.0, -SLIP_OUT[1]).normalized()
			create_tween().tween_property(sky_light, "global_position", _cam().global_position + upv2 * 2.4 + Vector3(0.8, 1.7, 0), 5.5)

# the tape runs on: three cuts of the same frame (雨と空). Nothing of 三時半 is on it (証言 三「このテープには、映っていません」)
func _tape_lapse():
	stage = "lapse"; t_stage = 0.0
	_clear_page()
	var cut := func(h: int, m: int, sky: float, rain: float):
		white.color.a = 0.0
		(finder8 as Finder8).glitch = 1.0
		_after(0.1, func(): (finder8 as Finder8).glitch = 0.0)
		clock = h * 3600.0 + m * 60.0
		_sky_set(sky); rain_on = rain; dawn = clampf((sky - 1.0) / 8.0, 0.0, 1.0)
		if rain <= 0.01: _loop_db("rain_out", -50.0, 0.2); _loop_db("ch8_wind", -50.0, 0.2); light_want = 0.0
		(finder8 as Finder8).drops = (finder8 as Finder8).drops.slice(0, 5)
	cut.call(3, 30, 1.0, 1.0)
	_after(6.0, func(): cut.call(4, 52, 9.0, 0.0); batt = 0)
	_after(12.5, func():
		(finder8 as Finder8).end_mark = true; rec8 = false; clock_run = false
		_one("tape_clunk", -6.0))
	_after(15.5, func(): _end())

var sky_e0 := -1.0
func _sky_set(k: float):
	for mi in main.S.env_node.find_children("ext_sky*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		if m == null: continue
		if sky_e0 < 0.0: sky_e0 = m.emission_energy_multiplier
		m.emission_energy_multiplier = sky_e0 * k
	if main.env and k > 1.0:
		main.env.ambient_light_energy = 0.02 * k * 2.0

func _end():
	if stage == "end": return
	stage = "end"
	_clear_page(); note_lb.text = ""
	fin_on = false
	card = main.make_card(self, [["", 46, 0]], Type.card())
	card.visible = true
	for k in loops8: _loop_db(k, -60.0, 1.5)
	_after(3.0, func():
		if demo8: print("DEMO ch8 t=%.1f fails=%d" % [t_now, DEMO_FAILS])
		if demo8 and "--ch8only" in OS.get_cmdline_user_args(): print("DEMO DONE ch8"); get_tree().quit(); return
		DEMO_HOUSE = demo8
		if main.has_method("next_chapter"): main.call("next_chapter", "ch8")
		else: main.to_chapter("ch11"))

# ================================================================ every frame
func _process(dt):
	t_now += dt; t_stage += dt
	if clock_run: clock += dt
	if rec8: rec_t = maxf(0.0, clock - rec_c0)
	if card_t > 0.0:
		card_t -= dt
		card.visible = true; player.move_enabled = false; player.look_enabled = false
		if card_t <= 0.0:
			card.visible = false; player.look_enabled = true
			_loop8("rain_out", -40.0); _loop8("ch8_wind", -40.0)
			match start8:
				"take": stage = "top"; cel8 = "done"
				"rec": stage = "rec_wait"
				"out": _left()
				"car": _begin("to_car")
				"knock": _show("natsuki"); _put("natsuki", [5.72, -1.05], _face([5.72, -1.05], DOOR), _ground(5.72, -1.05)); stage = "to_knock"; clock = 2.0 * 3600.0 + 30.0 * 60.0
				"road": _show("natsuki"); _put("natsuki", [5.72, -1.05], PI, _ground(5.72, -1.05)); knocks = 3; _begin("road")
				"corner":
					_show("natsuki"); _put("natsuki", CORNER_AT, 0.0, _ground(CORNER_AT[0], CORNER_AT[1])); nat_i = 999; nat_phone_want = 1.0
					_stand_at([63.0, -39.0], -120.0, -3.0); batt = 2; for e in ROAD_LINES: road_said[e[1]] = true
					stage = "road"
				"sky":
					_stand_at([SLIP_MID[0] - 0.6, SLIP_MID[1]], -100.0, -20.0); stage = "edge"; _fall()
				_: _begin("top")
		return
	if mode == TALK: _talk_tick(dt)
	var wk: String = "mio" if cur.get("who", "") == "澪" else String(cur.get("who_key", ""))
	if wk == "kiryu": wk = ""
	main.talk_now = wk if mode == TALK and cur.has("who") and typed < float(String(cur.get("text", "")).length()) else ""
	main.story_talking = (mode == TALK)
	player.move_enabled = stage in ["top", "to_door", "leaving", "out", "to_car", "to_knock", "door", "road", "corner", "edge"] and not (mode == TALK and stage in ["to_car", "door", "corner"] and talk_with == "natsuki" and stage != "road")
	if stage == "to_car" and mode == TALK and cur.get("who", "") != "" and not (String(cur.get("who", "")) == "桐生" and script_q.size() < 2 and false): pass
	# the eye's height (his own, or the camera's)
	if stage != "fall" and stage != "sky" and stage != "lapse" and stage != "end":
		player.eye_height = cam_h
	# the view he may not turn: in the hall after the take he does not look back at her (her face is not in this chapter)
	if yaw_lock: player.yaw = clampf(wrapf(player.yaw, -PI, PI), -1.75, 1.75)
	# 澪の顔はこの章の画に入れない：廊下で向き合っている間、画の上の縁は口元より上へ行かない（自動の通しの向き直しにも勝つ）
	_zoom_tick(dt)
	_light_tick(dt)
	_door_tick(dt)
	var note := ""
	if mode == FREE or stage == "road":
		match stage:
			"top":
				var p := _plan()
				if cel8 == "" and player.global_position.y < 0.4 and Vector2(p[0] - 5.5, p[1] - 4.0).length() < 2.6: _cel_heard()
				elif cel8 == "heard" and _cel_look(): note = String(_cel_parts()[1])
				elif cel8 == "done" and player.global_position.y < 0.4 and Vector2(p[0] - TRIPOD[0], p[1] - TRIPOD[1]).length() < 1.5: note = String(D.lines("八.三脚")[0])
			"rec_wait":
				note = String(D.lines("八.録画.案内")[0])
			"to_door":
				if _near_door(1.5) and t_stage > 1.6: note = String(D.lines("八.玄関")[0])
			"leaving":
				if _plan()[1] < -0.85: _left()
			"to_car":
				if mode == FREE and t_stage > 1.0:
					var d := Vector2(player.global_position.x - car_at.x, player.global_position.z - car_at.z).length()
					if d < car_r + 4.0: stage = "car"; t_stage = 0.0; _set_mission(""); player.look_enabled = false; player.auto_path = []; demo_goal = []; demo_route = []; _start(B("八.車"))
			"to_knock":
				if _near_door(2.2): _begin("door"); clock = maxf(clock, 2.0 * 3600.0 + 30.0 * 60.0 + 40.0)
			"door":
				if _near_door(1.5) and _plan()[1] < -0.2: note = String(D.lines("八.扉")[0])
			"road":
				_nat_tick(); _road_tick()
			"corner":
				pass
			"edge":
				_edge_tick(dt)
	if stage == "car":
		_frame8("natsuki", 1.3, dt)
		# 話している間は話す動き、聞いている間は立ち姿（立ったままの棒立ちに見えた：2026-11-19 ユーザー）
		if _has("natsuki") and not main.walkers.has("natsuki"):
			var nap: AnimationPlayer = (main.S.natsuki_node as Node).find_children("*", "AnimationPlayer", true, false)[0]
			var want := "talk/talk_a" if (mode == TALK and String(cur.get("who", "")) == "夏希") else "talk/idle"
			if nap.has_animation(want) and nap.current_animation != want: nap.play(want, 0.5)
	if stage == "door": _dflow_tick(dt)
	if stage == "fall": _fall_tick(dt)
	if stage == "sky": _sky_tick(dt)
	if stage == "lapse": _sky_tick(dt)
	if note_lb: note_lb.text = T(note) if note != "" else ""
	# random lightning on the way (the scripted one is at the corner)
	if stage in ["to_car", "road", "sky", "to_knock"] :
		if bolt_next < 0.0: bolt_next = t_now + randf_range(14.0, 30.0)
		if t_now > bolt_next: bolt_next = -1.0; _bolt(randf_range(0.5, 1.0))
	if nat_phone: nat_phone.light_energy = move_toward(nat_phone.light_energy, 0.9 * nat_phone_want, dt * 1.5)
	finder8.queue_redraw()
	if demo8: _demo8_tick(dt)

func _zoom_tick(dt: float):
	if not fin_on or stage in ["fall", "sky", "lapse", "end"]: return
	zoom_v = move_toward(zoom_v, 0.0, dt * 3.0)
	var z := 0.0
	if Input.is_key_pressed(KEY_R) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): z += 1.0
	if Input.is_key_pressed(KEY_F): z -= 1.0
	if z != 0.0 and stage != "hall": zoom_v = z * 0.55
	zoom_snd_t -= dt
	if absf(zoom_v) > 0.001:
		var z0 := zoom
		zoom = clampf(zoom + zoom_v * dt, 0.0, 1.0); zoom_show = 2.0; zoom_want = -1.0
		if absf(zoom - z0) > 0.0001 and zoom_snd_t <= 0.0:   # 2026-11-21: the small motor of his zoom (cut_1121.py)
			Sound.one(self, "cam_zoom", -14.0, _cam().global_position); zoom_snd_t = 0.75
	elif zoom_want >= 0.0 and absf(zoom - zoom_want) > 0.002:
		zoom = move_toward(zoom, zoom_want, dt * 0.3); zoom_show = 1.2
	zoom_show = maxf(0.0, zoom_show - dt)
	_cam().fov = lerpf(FOV_WIDE, FOV_TELE, zoom * zoom * (3.0 - 2.0 * zoom) * 0.0 + zoom)
	player.mouse_sens = lerpf(0.0022, 0.0009, zoom)

func _light_tick(dt: float):
	var out := _outside() and fin_on
	if stage in ["to_car", "car", "to_knock", "door", "road", "corner", "edge", "out", "leaving"] and out: light_want = 1.0
	elif stage == "top": light_want = 0.0
	elif stage in ["taking", "hall", "rec_wait", "flash", "rec", "to_door", "opening"]: light_want = 0.4
	cam_light.light_energy = move_toward(cam_light.light_energy, 0.55 * light_want, dt * 2.0)
	if car_dome: car_dome.light_energy = move_toward(car_dome.light_energy, 3.0 if stage == "car" else 0.0, dt * 4.0)
	if door_gap: door_gap.light_energy = move_toward(door_gap.light_energy, (2.2 * _gap_k()) if stage in ["out", "to_knock", "door"] else 0.0, dt * 2.0)
	bolt8.light_energy = bolt_e
	_night8(dt, out or stage in ["fall", "sky", "lapse"])
	rain_on = move_toward(rain_on, 1.0 if (out or stage in ["sky"]) else (rain_on if stage == "lapse" else 0.0), dt * 2.0)
	rain8.visible = rain_on > 0.01
	if rain8.visible:
		var cam := _cam()
		rain_mat.set_shader_parameter("cam_pos", cam.global_position)
		rain_mat.set_shader_parameter("cam_fwd", -cam.global_basis.z)
		rain_mat.set_shader_parameter("lit", cam_light.light_energy / 0.55)
		rain_mat.set_shader_parameter("flash", clampf(bolt_e / 5.0, 0.0, 1.0))
		rain_mat.set_shader_parameter("amount", rain_on)
	if loops8.has("rain_out") and stage not in ["lapse", "end"]:
		var want := -7.0 if out or stage in ["sky", "fall"] else -34.0
		(loops8["rain_out"] as AudioStreamPlayer).volume_db = move_toward((loops8["rain_out"] as AudioStreamPlayer).volume_db, want, dt * 30.0)
		if loops8.has("ch8_wind"): (loops8["ch8_wind"] as AudioStreamPlayer).volume_db = move_toward((loops8["ch8_wind"] as AudioStreamPlayer).volume_db, want - 6.0, dt * 30.0)
	# walking with it at his eye: each step is in the picture
	if cam_shake > 0.0:
		cam_shake = maxf(0.0, cam_shake - dt * 5.0)
		_cam().rotation.z = 0.012 * cam_shake * sin(t_now * 70.0); _cam().rotation.x = 0.008 * cam_shake * sin(t_now * 55.0)
	elif stage not in ["fall", "sky", "lapse", "end"]:
		_cam().rotation.z = lerp_angle(_cam().rotation.z, 0.0, 0.3); _cam().rotation.x = lerp_angle(_cam().rotation.x, 0.0, 0.3)

func _door_tick(dt: float):
	if main.door_pivot == null: return
	if door_shake > 0.0:
		door_shake = maxf(0.0, door_shake - dt * 8.0)
		main.door_pivot.position = main.S.get("door_rest", main.door_pivot.position) + main.door_pivot.global_basis.z * 0.004 * door_shake

# ================================================================ keys
func _unhandled_input(e):
	if card_t > 0.0 or mode == END: return
	if e is InputEventMouseButton and e.pressed and fin_on and stage not in ["hall", "fall", "sky", "lapse"]:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_v = 1.4; return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_v = -1.4; return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if press: get_viewport().set_input_as_handled(); _press8()

func _press8():
	match stage:
		"rec_wait":
			_press_rec(); return
	if mode == TALK: _advance(); return
	match stage:
		"top":
			var p := _plan()
			if cel8 == "heard" and _cel_look(): _cel_grab(); return
			if cel8 == "done" and player.global_position.y < 0.4 and Vector2(p[0] - TRIPOD[0], p[1] - TRIPOD[1]).length() < 1.5: _take()
		"to_door": _open_front()
		"door": _knock_press()

func _take():
	# he steps to where the camera comes off the head (ch3.gd: he stands at TAKE_AT)
	stage = "taking"
	note_lb.text = ""
	var dst := gp(TAKE_AT[0], TAKE_AT[1], 0.0); dst.y = player.global_position.y
	var tw := create_tween().set_parallel(true)
	tw.tween_property(player, "global_position", dst, 0.7).set_trans(Tween.TRANS_SINE)
	var tp := gp(TRIPOD[0], TRIPOD[1], 1.35)
	tw.tween_property(player, "yaw", player.yaw + wrapf(_yaw_to(tp) - player.yaw, -PI, PI), 0.6)
	tw.tween_property(player, "pitch", deg_to_rad(-18.0), 0.6)
	tw.chain().tween_interval(0.5)
	tw.chain().tween_callback(func(): _take_now())

# ================================================================ the unattended run (--demo)
var demo_goal: Array = []
var demo_wait := 0.0
var demo_route: Array = []
var demo_leg_to: Array = []
func _demo_go(route_all: Array, resume := false):
	if player.auto_path.size() > 0: return
	var p: Vector3 = player.global_position
	var route := route_all.duplicate(); var bi := 0; var bd := 1e9
	for i in route_all.size():
		var dd := Vector2(route_all[i][0] - 4.8 - p.x, route_all[i][1] - 6.3 - p.z).length()
		if dd < bd: bd = dd; bi = i
	if resume and bi > 0 and bi < route_all.size() - 1: route = route_all.slice(bi + 1)
	elif resume and bi == route_all.size() - 1: route = [route_all[-1]]
	demo_route = route
	demo_goal = route[-1]
	_demo_leg()

func _demo_leg():
	if demo_route.is_empty(): return
	var p: Vector3 = player.global_position
	var q: Array = demo_route.pop_front()
	var to := Vector2(q[0] - 4.8, q[1] - 6.3); var dvec := to - Vector2(p.x, p.z)
	var y0 := rad_to_deg(player.yaw); var y1 := y0 + wrapf(rad_to_deg(atan2(-dvec.x, -dvec.y)) - y0, -180.0, 180.0)
	var turn := clampf(absf(y1 - y0) / 140.0, 0.15, 1.2)
	var t := turn + dvec.length() / maxf(player.walk_speed, 0.05)
	var pd: float = -4.0 if q.size() < 3 else float(q[2])
	player.auto_path = [[0.0, p.x, p.z, y0, rad_to_deg(player.pitch)], [turn, p.x, p.z, y1, pd], [t, to.x, to.y, y1, pd]]
	player.auto_t = 0.0
	demo_leg_to = q

func _demo_there(r := 0.5) -> bool:
	if demo_goal.is_empty(): return false
	var p := _plan()
	if Vector2(p[0] - demo_goal[0], p[1] - demo_goal[1]).length() < r:
		player.auto_path = []; demo_goal = []; demo_route = []; return true
	if not demo_route.is_empty() and not demo_leg_to.is_empty() and Vector2(p[0] - demo_leg_to[0], p[1] - demo_leg_to[1]).length() < 0.7:
		player.auto_path = []; _demo_leg(); return false
	if player.auto_path.is_empty() and not demo_leg_to.is_empty():
		demo_route.push_front(demo_leg_to); _demo_leg(); return false
	if player.auto_path.size() > 0 and player.auto_t > float(player.auto_path[-1][0]) + 4.0:
		print("DEMO ch8 stuck at (%.2f, %.2f) y=%.2f for %s" % [p[0], p[1], player.global_position.y, stage]); DEMO_FAILS += 1
		for i in player.get_slide_collision_count(): print("C8SLIDE ", (player.get_slide_collision(i).get_collider() as Node).get_path(), " n=", player.get_slide_collision(i).get_normal())
		player.auto_path = []; demo_goal = []; demo_route = []
		return true
	return false

func _demo_look(at: Vector3):
	var to: Vector3 = at - (player.global_position + Vector3(0, player.eye_height, 0))
	player.yaw = atan2(-to.x, -to.z); player.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))

func _demo8_tick(dt: float):
	if "--ch8trace" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 48 == 0 and stage == "road":
		for i in player.get_slide_collision_count():
			var kc: KinematicCollision3D = player.get_slide_collision(i)
			print("C8HIT ", kc.get_collider(), " ", (kc.get_collider() as Node).get_path() if kc.get_collider() is Node else "", " n=", kc.get_normal(), " at=", kc.get_position() + Vector3(4.8, 0, 6.3))
	if "--ch8trace" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 24 == 0:
		print("C8TRACE %s plan(%.2f, %.2f) y=%.2f mode=%d prog=%.1f pitch=%.1f nat=%s goal=%s vel=%.2f" % [stage, _plan()[0], _plan()[1], player.global_position.y, mode, _road_progress(), rad_to_deg(player.pitch), _plan_of("natsuki") if _has("natsuki") else [], demo_goal, player.velocity.length()])
	demo_wait -= dt
	if demo_wait > 0.0: return
	match stage:
		"top":
			if mode != FREE: return
			var p := _plan()
			if cel8 == "heard":
				if _cel_look(): player.auto_path = []; demo_goal = []; demo_route = []; demo_wait = 1.0; _press8(); return
				if demo_goal.is_empty() and Vector2(p[0] - 5.0, p[1] - 5.9).length() < 0.4: _demo_look(main._rig_of("mio").global_position + Vector3(0, 1.2, 0)); return
				if demo_goal.is_empty(): _demo_go([[5.3, 1.95], [4.7, 2.2], [4.3, 2.9], [4.3, 3.7], [4.8, 4.2], [5.0, 5.9]])   # off the stair foot, round by the hall (ch3.gd walks it the other way)
				else: _demo_there(0.3)
				return
			if cel8 == "":
				if demo_goal.is_empty(): _demo_go([[5.5, 5.75], [5.5, 2.5]])
				else: _demo_there(0.3)
				return
			if cel8 != "done": return
			if player.global_position.y < 0.4 and Vector2(p[0] - TRIPOD[0], p[1] - TRIPOD[1]).length() < 1.4:
				player.auto_path = []; demo_goal = []; demo_route = []; demo_wait = 1.0; _press8()
			elif demo_goal.is_empty(): _demo_go([[4.6, 3.0], [4.85, 2.25]])   # from where _cel_done leaves her, in the hall
			else: _demo_there(0.3)
		"rec_wait":
			if t_stage > 1.5: demo_wait = 1.0; _press8()
		"to_door":
			if mode != FREE or t_stage < 2.0: return
			if _near_door(1.2): player.auto_path = []; demo_goal = []; demo_route = []; _demo_look(gp(DOOR[0], DOOR[1], 1.3)); demo_wait = 1.0; _press8()
			elif demo_goal.is_empty(): _demo_go([[5.42, 1.85], [5.38, 0.95], [5.05, 0.6]])
			else: _demo_there(0.3)
		"leaving":
			if demo_goal.is_empty(): _demo_go([[5.0, -0.4], [5.0, -1.2]])
			else: _demo_there(0.3)
		"to_car":
			if mode != FREE: return
			if demo_goal.is_empty(): _demo_go([[5.0, -2.4], [5.4, -4.2]])
			else: _demo_there(0.4)
		"car":
			pass   # _frame8 keeps her in the picture
		"to_knock", "door":
			if mode != FREE: return
			if not (_near_door(1.3) and _plan()[1] < -0.3):
				if demo_goal.is_empty(): _demo_go([[5.0, -2.4], [5.0, -0.9]], true)
				else: _demo_there(0.3)
				return
			player.auto_path = []; demo_goal = []; demo_route = []
			_demo_look(gp(DOOR[0], DOOR[1], 1.3))
			if stage == "door" and not d_on: demo_wait = 1.5; _press8()
		"road", "corner":
			if stage == "corner" and mode == TALK: player.auto_path = []; demo_goal = []; demo_route = []; return
			if demo_goal.is_empty(): _demo_go(DRIVE + ROAD + [[CORNER_AT[0] - 1.6, CORNER_AT[1] + 2.2]], true)
			else: _demo_there(0.8)
		"edge":
			if mode == TALK: return
			var tgt := [SLIP_MID[0] + SLIP_OUT[0] * 1.2, SLIP_MID[1] + SLIP_OUT[1] * 1.2, -26.0]
			if demo_goal.is_empty(): _demo_go([[SLIP_MID[0] - 1.6, SLIP_MID[1] + 3.5], tgt])
			else: _demo_there(0.3)

func _talk_tick(dt):
	super._talk_tick(dt)

# ================================================================ a look at the ground (--ch8probe)
func _probe():
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("C8CAR at plan (%.2f, %.2f) y=%.2f r=%.2f" % [car_at.x + 4.8, car_at.z + 6.3, car_at.y, car_r])
	for q in DRIVE + ROAD + [CORNER_AT, SLIP_MID]: print("C8WAY (%.1f, %.1f) ground %.2f" % [q[0], q[1], _ground(q[0], q[1])])
	for dy in range(-12, 13, 2):
		var row := "C8SLIP y=%.1f:" % (SLIP_MID[1] + dy)
		for dx in range(-8, 14, 1): row += " %6.2f" % _ground(SLIP_MID[0] + dx, SLIP_MID[1] + dy)
		print(row)
	for k in ["mio", "natsuki"]:
		if _has(k):
			var sk: Skeleton3D = (main.S[k + "_node"] as Node).find_children("*", "Skeleton3D", true, false)[0]
			for bn in ["head", "neck_01", "clavicle_l", "upperarm_l", "hand_l", "pelvis"]:
				var bi := sk.find_bone(bn)
				if bi >= 0: print("C8BONE %s %s %s" % [k, bn, (sk.global_transform * sk.get_bone_global_pose(bi)).origin - main._rig_of(k).global_position])
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("vcam_") or nm.begins_with("tpd_") or nm.begins_with("ext_car") or nm.begins_with("ext_slipfall"): print("C8MESH ", nm, " plan=(%.2f, %.2f, %.2f) vis=%s" % [(mi as Node3D).global_position.x + 4.8, (mi as Node3D).global_position.z + 6.3, (mi as Node3D).global_position.y, (mi as Node3D).is_visible_in_tree()])
	for k in main.lights:
		if main.lights[k] is Light3D:
			var l: Light3D = main.lights[k]
			print("C8LIGHT ", k, " ", l.get_class(), " ", l.global_position + Vector3(4.8, 0, 6.3), " e=", l.light_energy, " c=", l.light_color, " vis=", l.is_visible_in_tree(), " mask=", l.light_cull_mask)
	# 廊下の間取り：2.3 m から下へ当てた高さ（. 床、# 1.6 m より上、+ その間）。左が x=3.4、上が y=6.0
	for iy in range(60, -6, -2):
		var row := "C8HALL y=%4.1f " % (iy * 0.1)
		for ix in range(34, 66, 1):
			var q := PhysicsRayQueryParameters3D.create(gp(ix * 0.1, iy * 0.1, 2.3), gp(ix * 0.1, iy * 0.1, -0.5))
			var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
			var hh: float = hit.position.y if not hit.is_empty() else -9.0
			row += "." if hh < 0.12 else ("#" if hh > 1.6 else "+")
		print(row)
	var e: Environment = main.env
	print("C8ENV bg=", e.background_mode, " amb_src=", e.ambient_light_source, " amb_c=", e.ambient_light_color, " amb_e=", e.ambient_light_energy, " sky_contrib=", e.ambient_light_sky_contribution, " bg_e=", e.background_energy_multiplier, " fog=", e.fog_enabled, " fogc=", e.fog_light_color, " fogd=", e.fog_density, " vol=", e.volumetric_fog_enabled, " exp=", e.tonemap_exposure)
	for n in main.find_children("*", "DirectionalLight3D", true, false): print("C8DIR ", n.name, " e=", n.light_energy, " c=", n.light_color, " vis=", n.is_visible_in_tree(), " rot=", n.global_rotation_degrees)

# 夏希の1秒の画（ui/ch8_natsuki.png）を作る道具。ゲームでは呼ばれない。
#   godot --path <重ねたプロジェクト> -- --basepack=… --housepack=… --scene=house --play=ch8 --nocard --print=0 --ch8portrait=<出す png>
# 合宿の前、夏希が自分の部屋で、三脚に載せたカメラに一人で話している。昼の窓の光（刷りではオレンジの版）。
# 自分で据えたので、頭の上が少し空きすぎ、体は真ん中から少しずれている。
func _portrait(path: String):
	for i in 30: await get_tree().process_frame
	stage = "end"; fin_on = false; card_t = 0.0
	if card and is_instance_valid(card): card.visible = false
	var at := [300.0, 300.0]; var z := 40.0
	_show("natsuki"); _put("natsuki", at, 0.0, z)
	if nat_phone: nat_phone.light_energy = 0.0
	if main.faces.has("natsuki"): main.faces["natsuki"].mat.albedo_texture = main.faces["natsuki"].tex.talk
	var o := gp(at[0], at[1], z)
	main.env.fog_enabled = false; main.env.volumetric_fog_enabled = false
	get_viewport().disable_3d = false
	main.env.background_mode = Environment.BG_COLOR; main.env.background_color = Color(0.02, 0.02, 0.02)
	main.env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; main.env.ambient_light_color = Color(0.5, 0.48, 0.45); main.env.ambient_light_energy = 0.35
	for cl in main.find_children("*", "CanvasLayer", true, false): (cl as CanvasLayer).visible = false
	for cl in find_children("*", "CanvasLayer", true, false): (cl as CanvasLayer).visible = false
	var set8 := Node3D.new(); main.add_child(set8); set8.global_position = o
	var wall := MeshInstance3D.new(); var qm := QuadMesh.new(); qm.size = Vector2(5.0, 3.2); wall.mesh = qm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.78, 0.74, 0.66); wm.roughness = 1.0; wall.material_override = wm
	set8.add_child(wall); wall.position = Vector3(0, 1.4, -0.75)
	# a shelf's edge and a curtain's fall behind her: a room, not a studio
	for q in [[Vector3(-0.95, 1.52, -0.7), Vector3(1.1, 0.04, 0.2), Color(0.34, 0.26, 0.2)], [Vector3(-0.95, 1.12, -0.7), Vector3(1.1, 0.04, 0.2), Color(0.34, 0.26, 0.2)],
			[Vector3(-1.2, 1.66, -0.66), Vector3(0.05, 0.24, 0.16), Color(0.5, 0.2, 0.16)], [Vector3(-1.13, 1.65, -0.66), Vector3(0.04, 0.22, 0.16), Color(0.2, 0.3, 0.4)], [Vector3(-1.07, 1.67, -0.66), Vector3(0.06, 0.26, 0.16), Color(0.7, 0.62, 0.4)],
			[Vector3(-0.78, 1.63, -0.66), Vector3(0.26, 0.19, 0.12), Color(0.12, 0.12, 0.13)],
			[Vector3(1.15, 1.5, -0.68), Vector3(0.5, 2.6, 0.06), Color(0.6, 0.5, 0.36)]]:
		var bx := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = q[1]; bx.mesh = bm
		var mm := StandardMaterial3D.new(); mm.albedo_color = q[2]; mm.roughness = 0.9; bx.material_override = mm
		set8.add_child(bx); bx.position = q[0]
	var key := SpotLight3D.new(); key.light_color = Color(1.0, 0.86, 0.66); key.light_energy = 9.0; key.spot_range = 8.0; key.spot_angle = 50.0
	key.shadow_enabled = true; key.shadow_blur = 2.5; set8.add_child(key); key.position = Vector3(1.9, 2.0, 1.5); key.look_at(o + Vector3(0, 1.3, 0))
	var fill := OmniLight3D.new(); fill.light_color = Color(0.8, 0.86, 1.0); fill.light_energy = 0.5; fill.omni_range = 6.0; set8.add_child(fill); fill.position = Vector3(-1.6, 1.3, 1.8)
	var pc := Camera3D.new(); set8.add_child(pc); pc.fov = 30.0; pc.position = Vector3(0.1, 1.3, 1.6); pc.look_at(o + Vector3(-0.06, 1.27, 0)); pc.make_current()
	for i in 40: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w := int(img.get_height() * 4.0 / 3.0)
	img = img.get_region(Rect2i((img.get_width() - w) / 2, 0, w, img.get_height()))
	img.save_png(path); print("C8PORTRAIT ", path, " ", img.get_size())
	get_tree().quit()
