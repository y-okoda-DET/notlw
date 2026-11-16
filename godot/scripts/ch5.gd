## ステップ F：第5章「地下」 4時（docs/資料/第5章の設計_2026-11-17.md）。台詞は story/ch5.txt。
## 家まるごとの3時半の光（main の t0330）で動く。main.gd が play="ch5" で作り、終わると次の章へ（第6章がまだ無いので第11章）。
##
## 四時：第4章の終わりのまま。廊下に夏希が倒れ、三脚が澪の足もとにある。澪は歩けない（見るだけ）。真琴が二階から下りて、
##   「……冷たい」。三脚を一度見て、「……風。どこから」。
## 勝手口：真琴について台所へ。裂けたテープ、低い所の血の手形。真琴が一つずつ数え直し、「ゾンビなんて、いない」。
##   そのあとで手形に手を重ねる。ろうそくを澪に渡し、「来ないで」と地下へ。
## 四時十分：澪はろうそくを持って一階を回り、0時半に貼ったテープを貼った順にはがす（ch3.gd の SEAL_ORDER）。
##   はがすたびに風の音が戻り、炎が傾く。下からの音と声は、はがした数で進む（何もしないで90秒でも一段）。
##   勝手口・玄関・地下の扉は、近づけば Ｅ が出るが、澪はどれもしない。勝手口だけ、数える沈黙。
## 終わり：廊下。夏希の肩の毛布が、勝手口からの風で揺れる。章の問いが戻る。
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")
const FPS = preload("res://scripts/fps.gd")

const F2 := 2.75
const ZBASE := -2.45
const NAT_AT := [4.62, 1.95]          # where she stood when the second blow came (fps.gd: a metre short of Mio)
const MIO_AT := [4.55, 3.0]           # Mio, as 第4章 leaves her (fps.gd MIO_AT)
const TRIPOD_AT := [4.2, 3.15]        # dropped at her feet
const MAKOTO_DOWN := [[5.0, 6.3, F2], [5.5, 5.7, F2], [5.5, 2.55, 0.0]]
# plan points of the house as 第3章 has them (ch3.gd GAPS): the tape over each, and what Mio calls the place
const GAPS := [
	{"key": "g1", "at": [2.6, 0.13, 1.45], "n": [0, 1], "name": "居間の窓", "snd": "ch3_gap1"},
	{"key": "g2", "at": [0.13, 6.2, 1.5], "n": [1, 0], "name": "食堂の窓", "snd": "ch3_gap2"},
	{"key": "g3", "at": [7.4, 7.87, 1.5], "n": [0, -1], "name": "台所の窓", "snd": "ch3_gap3"},
	{"key": "g4", "at": [9.87, 6.2, 1.55], "n": [-1, 0], "name": "換気口", "snd": "ch3_gap4"},
	{"key": "g5", "at": [9.87, 4.88, 1.0], "n": [-1, 0], "name": "勝手口", "snd": "ch3_gap5"},
]
const FRONT_GAP := [5.0, 0.08, -0.1]
const FRONT_DOOR := [5.0, 0.03, 1.0]
const BACK_DOOR := [9.87, 4.88, 1.0]
const CELLAR_DOOR := [5.5, 5.62, 1.0]
const BACK_STAND := [9.25, 4.95]      # where Mio stops before the back door (the talk starts)
const MK_BACK := [9.35, 5.55]         # Makoto at the back door, her light on it
const MK_THINK := [8.6, 5.6]          # two steps in, where she puts it together
const HAND_AT := [9.86, 4.42, 0.42]   # the hand on the back door's frame, low: pushed, to get up
const IDLE_STEP := 90.0               # nothing done for this long: the cellar goes on one step
# the cellar's steps, by the tapes peeled: 1 → 地下.一, 3 → 地下.三, 4 → 地下.四, 5 → 地下.五
const BELOW := [[1, "地下.一"], [3, "地下.三"], [4, "地下.四"], [5, "地下.五"]]

var stage := "card"     # card | t4 | follow | back | peel | done | end
var card: Control
var card_t := 0.0
var card_next := ""
var t_stage := 0.0
var hold := false              # a line waits for someone to get where they are going
var dn
var nat: Node3D
var nsk: Skeleton3D
var gaps := []                 # {key, at, n, name, player, peeled, tape, tape2}
var order: Array = []          # the order she put them on (第3章), and so takes them off
var peeled_n := 0
var candle: Node3D
var flame: Node3D
var candle_light: OmniLight3D
var gen_fore: AudioStreamPlayer
var gen_db := -40.0
var gen_want := -40.0
var below_i := 0               # the next of BELOW to sound
var below_q: Array = []        # [[t, entry]] the timed lines from below
var below_t := 0.0
var idle_t := 0.0
var said := {}
var silence_t := -1.0
var silence_lb: Label
var silence_len := 9.0
var blanket: MeshInstance3D
var lantern: OmniLight3D
var wind_in := {}              # gap key -> fading in (s)
var tripod: Node3D
var page_clear_t := -1.0
var end_wait := -1.0
var look_k := ""
var demo5 := false
var demo_steps: Array = []
var ds := 0
var dwait := 0.0
var start_at := "t4"

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = ["真琴（下から）"]
	FPS.load_story("ch5")
	_page()
	for k in ["kiryu", "taiga", "natsuki", "mio", "yota"]: _hide(k)
	_natsuki()
	_borrow_clips()
	_lookers()
	main.phones(false)
	main.TALK = {}
	_tripod()
	_lantern()
	_gaps()
	_candle()
	_gen_fore()
	call_deferred("_doors")
	demo5 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	demo_on = demo5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch5at="): start_at = a.substr(8)   # check stills and a part's playthrough: t4 | back | peel | end
	var c: Array = D.lines("五.カード")
	card = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	card_t = 2.75; card_next = "t4card"
	if start_at != "t4": card_t = 0.3; card_next = start_at
	_place_for(start_at)
	print("STORY ch5 start=", start_at, " order=", ",".join(order))

# ---------------------------------------------------------------- the stage
func _face(from: Array, to: Array) -> float:
	return atan2(to[0] - from[0], to[1] - from[1])

func _put(k: String, at: Array, yaw: float, z := 0.0):
	if main.S.has(k + "_node"):
		main.place_person(k, [at[0] - 4.8, 6.3 - at[1], z], yaw)
		_rig(k).visible = true

func _rig(k: String) -> Node3D:
	return main._rig_of(k)

func _hide(k: String):
	if main.S.has(k + "_node"):
		_rig(k).visible = false
		if main.S.has(k + "_col"): (main.S[k + "_col"] as Node3D).global_position = Vector3(0, -50, 0)

func _plan_of(n: Node3D) -> Array:
	return [n.global_position.x + 4.8, n.global_position.z + 6.3]

func _look_from(a: Array, b: Array, eye := 1.52, bz := 1.3):
	var to: Vector3 = gp(b[0], b[1], bz) - (gp(a[0], a[1], 0.0) + Vector3(0, eye, 0))
	player.yaw = atan2(-to.x, -to.z); player.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))

func _looking_at(p: Vector3, reach: float, deg: float) -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := p - cam.global_position
	return to.length() < reach and (-cam.global_basis.z).angle_to(to) < deg_to_rad(deg)

func _place_for(st: String):
	_hide("makoto")
	match st:
		"t4":
			player.global_position = gp(MIO_AT[0], MIO_AT[1] + 0.35, 0.0)
			_look_from([MIO_AT[0], MIO_AT[1] + 0.35], [NAT_AT[0], NAT_AT[1] + 0.6], 1.52, 0.15)
		"back":
			player.global_position = gp(8.3, 5.2, 0.0)
			_look_from([8.3, 5.2], BACK_STAND)
			_put("makoto", [8.9, 5.5], _face([8.9, 5.5], MK_BACK)); main.set_stand("makoto", "talk/idle", 0.0)
			main.phones(true, ["makoto"])
		"peel", "end":
			player.global_position = gp(MK_THINK[0] + 0.3, MK_THINK[1] - 0.5, 0.0)
			_look_from([MK_THINK[0] + 0.3, MK_THINK[1] - 0.5], [7.4, 7.6])
			_blanket_on()
			_gen_loud()
			if st == "end":
				for gq in gaps: _peel(gq, true)
				below_i = BELOW.size()

# the doors as the night left them: the back door ajar (she came in by it), its "locked" gone; the cellar's top door shut
func _doors():
	await get_tree().physics_frame; await get_tree().physics_frame
	dn = main.get_node_or_null("Doors")
	if not dn: return
	for k in dn.doors.keys():
		var s: Dictionary = dn.doors[k]
		if s.key == "door_back": s.locked = ""
		if s.key == "door_barred": s.locked = "開かない。"
	dn.open_key("door_kitchen")
	dn.open_key("door_back")
	for k in dn.doors.keys():
		var s: Dictionary = dn.doors[k]
		if s.key == "door_back": (s.pivot as Node3D).rotation.y = lerpf(float(s.rest), float(s.open), 0.28)   # ajar: a hand's width more than a person
		if s.key == "door_cellar" and s.is_open: dn.toggle(k)
	if start_at in ["peel", "end"]: get_tree().create_timer(0.8).timeout.connect(_cellar_ajar)

# Makoto has only her two talk clips (main.gd TALK_CLIPS): the crouch is Taiga's (the cellar window, 20時), the plain
# stand Natsuki's. The bones are the same rig's; the clips turn them only, so they sit on her
func _borrow_clips():
	if not main.S.has("makoto_node"): return
	for ap in main.S.makoto_node.find_children("*", "AnimationPlayer", true, false):
		if not (ap as AnimationPlayer).has_animation_library("talk"): continue
		var lib: AnimationLibrary = (ap as AnimationPlayer).get_animation_library("talk")
		for c in [["taiga", "crouch"], ["natsuki", "idle"]]:
			var tp := "res://assets/dusk/%s_talk.res" % c[0]
			if lib.has_animation(c[1]) or not ResourceLoader.exists(tp): continue
			var src: AnimationLibrary = load(tp)
			if src.has_animation(c[1]):
				var an: Animation = src.get_animation(c[1]).duplicate()
				for ti in range(an.get_track_count() - 1, -1, -1):   # the hips' place is his: keep her own
					if an.track_get_type(ti) == Animation.TYPE_POSITION_3D and not String(an.track_get_path(ti)).ends_with("pelvis"): an.remove_track(ti)
				lib.add_animation(c[1], an)
				print("CH5 borrowed %s/%s" % c)

# she left the cellar's top door standing a little open behind her (wide, it lies across the way to the kitchen)
func _cellar_ajar():
	if not dn: return
	for k in dn.doors.keys():
		var s: Dictionary = dn.doors[k]
		if s.key != "door_cellar": continue
		s.is_open = true
		create_tween().tween_property(s.pivot, "rotation:y", lerpf(float(s.rest), float(s.open), 0.12), 0.8).set_trans(Tween.TRANS_SINE)

# Natsuki where she fell (第4章's second blow, at its end: on her knees and then forward, a little onto her right side)
func _natsuki():
	main._load_scene("res://assets/natsuki.glb", "natsuki")
	nat = main.S.natsuki_node
	main._faces()
	main._walk_anims("natsuki", nat)
	nsk = nat.find_children("*", "Skeleton3D", true, false)[0]
	var nrig := nsk.get_parent() as Node3D
	var nap: AnimationPlayer = nat.find_children("*", "AnimationPlayer", true, false)[0]
	for ba in nsk.find_children("nphone*", "BoneAttachment3D", true, false): (ba as Node3D).visible = false
	nap.play("walk/walk"); nap.seek(0.35, true); nap.pause()
	await get_tree().process_frame
	nap.stop(false)
	# fps.gd _pose with the night's numbers: the first blow's reel at 1.2 s (when the second came), the fall at its end
	var rec := 0.569; var kn := 0.38 * rec
	var reel := {"head": [0.30 * rec, 0.0, 0.42 * rec], "neck_01": [0.20 * rec, 0.0, 0.26 * rec], "spine_03": [0.20 * rec, 0.0, 0.12], "spine_02": [0.14 * rec, 0.0, 0.08],
		"spine_01": [0.08, 0.0, 0.0], "thigh_l": [-kn, 0.0, 0.0], "calf_l": [2.0 * kn, 0.0, 0.0], "foot_l": [-kn, 0.0, 0.0],
		"thigh_r": [-kn * 0.8, 0.0, 0.0], "calf_r": [1.6 * kn, 0.0, 0.0], "foot_r": [-kn * 0.8, 0.0, 0.0], "upperarm_r": [0.0, 0.0, -0.22]}
	var down := {"head": [-0.25, -0.75, 0.0], "neck_01": [0.0, -0.3, 0.0], "spine_03": [-0.06, 0.0, 0.10], "spine_02": [0.0, 0.0, 0.06], "spine_01": [0.0, 0.0, 0.0],
		"thigh_l": [-0.05, 0.0, 0.0], "calf_l": [0.65, 0.0, 0.0], "foot_l": [0.7, 0.0, 0.0], "thigh_r": [0.07, 0.0, 0.0], "calf_r": [0.9, 0.0, 0.0], "foot_r": [0.7, 0.0, 0.0],
		"upperarm_l": [-0.75, 0.0, 0.25], "lowerarm_l": [-0.3, 0.0, 0.0], "upperarm_r": [0.2, 0.0, -0.30], "lowerarm_r": [-0.35, 0.0, 0.0]}
	var pose0 := {}
	for i in nsk.get_bone_count():
		var par := nsk.get_bone_parent(i)
		pose0[nsk.get_bone_name(i)] = [nsk.get_bone_pose_rotation(i), nsk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()]
	for nm in pose0:
		if not (down.has(nm) or reel.has(nm)): continue
		var e: Array = down.get(nm, [0.0, 0.0, 0.0]).duplicate()
		if reel.has(nm): e = [e[0] + reel[nm][0] * 0.4, e[1] + reel[nm][1] * 0.4, e[2] + reel[nm][2] * 0.4]
		var bi := nsk.find_bone(nm)
		var pg: Basis = pose0[nm][1]
		var r := Basis(Vector3.UP, e[1]) * Basis(Vector3.BACK, e[2]) * Basis(Vector3.RIGHT, e[0])
		nsk.set_bone_pose_rotation(bi, (pg.inverse() * r * pg).get_rotation_quaternion() * (pose0[nm][0] as Quaternion))
	var b0 := Basis(Vector3.UP, 0.0)
	var base := gp(NAT_AT[0], NAT_AT[1], 0.0)
	var thk := 0.05 + kn * 0.4; var cfk := 0.65 + 2.0 * kn * 0.4
	var feet := base + b0 * Vector3(0, 0, -1) * 0.24 + b0 * Vector3(-1, 0, 0) * 0.10
	var rb := b0 * Basis(Vector3.BACK, 0.26) * Basis(Vector3.RIGHT, 1.43)
	var knee_l := Vector3(0.0, 0.74 - 0.33 * cos(thk), 0.33 * sin(thk))
	var knee_w := feet + b0 * Vector3(0.0, 0.0, 0.33 * sin(0.45)) + Vector3(0, 0.045, 0)
	nrig.global_transform = Transform3D(rb, knee_w - rb * knee_l)
	for mi in nat.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).extra_cull_margin = 3.0
	nat.visible = true
	if main.S.has("natsuki_col"): (main.S.natsuki_col as Node3D).global_position = Vector3(0, -50, 0)
	# the wound: fps.gd's own overlay, carried once (she does not move again)
	var sh := Shader.new(); sh.code = FPS.BLOOD_SHADER
	for mi in nat.find_children("natsuki_*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new(); m.shader = sh
		var is_head := String(mi.name).contains("head")
		m.set_shader_parameter("part", 0 if is_head else 1)
		m.set_shader_parameter("dbg", 0.0)
		(mi as MeshInstance3D).material_overlay = m
		var bi2 := nsk.find_bone("head" if is_head else "spine_03")
		var carry: Transform3D = nsk.global_transform * nsk.get_bone_global_pose(bi2) * nsk.get_bone_global_rest(bi2).affine_inverse()
		m.set_shader_parameter("inv", Projection(carry.affine_inverse()))
	# what has run from her head in half an hour, dark on the boards
	var hp := _nat_head()
	var pool := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.17; cm.bottom_radius = 0.17; cm.height = 0.002; cm.radial_segments = 20; cm.rings = 1
	pool.mesh = cm
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.16, 0.006, 0.006); pm.roughness = 0.1; pm.metallic_specular = 0.8
	pool.material_override = pm; pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; pool.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(pool); pool.global_position = Vector3(hp.x + 0.05, 0.003, hp.z); pool.scale = Vector3(1.0, 1.0, 1.35)

func _nat_head() -> Vector3:
	var bi := nsk.find_bone("head")
	return nsk.global_transform * nsk.get_bone_global_pose(bi).origin

func _nat_chest() -> Vector3:
	var bi := nsk.find_bone("spine_03")
	return nsk.global_transform * nsk.get_bone_global_pose(bi).origin

# the tripod, where it fell from her hands
func _tripod():
	var parts: Array = []
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"): (mi as Node3D).visible = false; continue
		if nm.begins_with("tpd_"): parts.append(mi)
	if parts.is_empty(): return
	var bb := AABB(); var first := true
	for mi in parts:
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a); first = false
	tripod = Node3D.new(); tripod.name = "tripod5"; main.add_child(tripod)
	tripod.global_position = Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	for mi in parts:
		var gt: Transform3D = (mi as Node3D).global_transform
		mi.get_parent().remove_child(mi); tripod.add_child(mi); (mi as Node3D).global_transform = gt
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		(mi as MeshInstance3D).extra_cull_margin = 2.0
	if main.lights.has("rec_light"): (main.lights.rec_light as Light3D).visible = false
	# on its side on the boards, its head toward her
	tripod.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-60.0)) * Basis(Vector3.BACK, deg_to_rad(84.0)), gp(TRIPOD_AT[0], TRIPOD_AT[1], 0.05))

# the crew's lantern under the handrail camera, as 第4章 hung it (fps.gd _lantern)
func _lantern():
	var src: Light3D = main.lights.get("lantern_stair")
	var from := Vector3.ZERO
	if src: from = src.global_position
	var to := gp(FPS.LANTERN_AT[0], FPS.LANTERN_AT[1], FPS.LANTERN_AT[2] + 0.154)
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.begins_with("crew_lantern_stair") or nm.begins_with("lampshade_lantern_stair")): continue
		var c := mi.duplicate() as MeshInstance3D
		c.name = "d_" + nm; mi.get_parent().add_child(c)
		c.global_transform = (mi as MeshInstance3D).global_transform.translated(to - from)
		c.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lantern = OmniLight3D.new(); lantern.light_color = Color(1.0, 0.74, 0.50); lantern.light_energy = 0.30
	lantern.omni_range = 5.0; lantern.omni_attenuation = 1.3; lantern.shadow_enabled = true
	lantern.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID; lantern.shadow_blur = 2.0
	lantern.light_volumetric_fog_energy = 0.2; lantern.light_specular = 0.2
	main.add_child(lantern); lantern.global_position = to

# ---------------------------------------------------------------- the tape, still on (0時半), and the wind behind it
func _gaps():
	var c3 = load("res://scripts/ch3.gd")
	order = (c3.SEAL_ORDER as Array).duplicate() if c3 and not (c3.SEAL_ORDER as Array).is_empty() else ["g1", "g2", "g3", "g4", "g5"]
	var front := AudioStreamPlayer3D.new(); front.stream = Sound.stream("ch3_gapfront", true); front.unit_size = 1.6; front.max_db = 0.0
	front.volume_db = -8.0; add_child(front); front.global_position = gp(FRONT_GAP[0], FRONT_GAP[1], FRONT_GAP[2] + 0.1)
	if front.stream: front.play()
	for gd in GAPS:
		var p := AudioStreamPlayer3D.new(); p.stream = Sound.stream(gd.snd, true); p.unit_size = 1.4; p.max_db = 0.0
		p.volume_db = -60.0; p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p); p.global_position = gp(gd.at[0], gd.at[1], gd.at[2])
		var gq := {"key": gd.key, "at": gp(gd.at[0], gd.at[1], gd.at[2]), "n": gd.n, "name": gd.name, "player": p, "peeled": false, "tape": null, "tape2": null}
		_tape(gq)
		gaps.append(gq)
		if gd.key == "g5":   # torn from outside: the storm is in at the back door already
			p.volume_db = -3.0
			if p.stream: p.play(randf() * 4.0)

func _tape_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.62, 0.62, 0.6); m.roughness = 0.55; m.metallic = 0.1
	return m

func _tape(gq: Dictionary):
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	var along_x: bool = gq.n[0] == 0
	bm.size = Vector3(0.34 if along_x else 0.004, 0.05, 0.004 if along_x else 0.34)
	var off := Vector3(gq.n[0] * 0.006, 0.0, gq.n[1] * 0.006)
	if gq.key == "g5":
		# 0時半 it ran down the door's edge (1.6 m). Pushed from outside, it tore at the height of a hand: the top stays,
		# the rest is torn off and hangs in, curled
		bm.size = Vector3(0.004, 0.72, 0.05)
		mi.mesh = bm; mi.material_override = _tape_mat(); add_child(mi)
		mi.global_position = gq.at + off + Vector3(0, 0.29, 0)
		var lo := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.004, 0.42, 0.05); lo.mesh = lb
		lo.material_override = _tape_mat(); add_child(lo)
		lo.global_transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(-38.0)) * Basis(Vector3.UP, 0.25), gq.at + off + Vector3(-0.12, -0.27, 0.0))
		gq.tape2 = lo
		# the torn end: a ragged lighter strip
		gq.tape = mi
		_hand()
		return
	mi.mesh = bm; mi.material_override = _tape_mat(); mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	mi.global_position = gq.at + off
	mi.rotation.z = randf_range(-0.06, 0.06)
	gq.tape = mi

# the hand on the back door's frame, low, from outside: a palm and fingers pressed flat to push up off the step.
# Drawn here (no new picture file): dark, dry at the edges, the fingers spread
func _hand():
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new(); rng.seed = 405
	var blot := func(cx: float, cy: float, rx: float, ry: float, a: float):
		for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
			for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
				if x < 0 or y < 0 or x >= 128 or y >= 128: continue
				var d := pow((x - cx) / rx, 2.0) + pow((y - cy) / ry, 2.0)
				if d > 1.0: continue
				var al: float = a * (0.55 + 0.45 * d) * rng.randf_range(0.75, 1.0)   # heavier at the edge, where it dried
				var o := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(0.22, 0.01, 0.01, maxf(o.a, al)))
	blot.call(64.0, 82.0, 26.0, 30.0, 0.8)                     # the palm
	for f in [[34.0, 44.0, 7.0, 17.0], [50.0, 34.0, 7.0, 20.0], [67.0, 31.0, 7.0, 21.0], [83.0, 38.0, 6.5, 18.0]]:
		blot.call(f[0], f[1], f[2], f[3], 0.75)               # the fingers
	blot.call(98.0, 78.0, 8.0, 16.0, 0.7)                      # the thumb
	for i in 5:   # where it slid down
		blot.call(58.0 + i * 6.0, 112.0 + rng.randf_range(0, 6), 2.5, 8.0, 0.5)
	var tex := ImageTexture.create_from_image(img)
	var dc := Decal.new(); dc.texture_albedo = tex; dc.size = Vector3(0.2, 0.3, 0.2)
	dc.albedo_mix = 1.0; dc.cull_mask = 1; dc.upper_fade = 0.1; dc.lower_fade = 0.1
	add_child(dc)
	dc.global_position = gp(HAND_AT[0] - 0.04, HAND_AT[1], HAND_AT[2])
	dc.rotation = Vector3(0.0, 0.0, PI / 2)   # projects along its -Y: into the frame (plan +x)

func _peel(gq: Dictionary, quiet := false):
	if gq.peeled: return
	gq.peeled = true
	if gq.key != "g5":
		if is_instance_valid(gq.tape): (gq.tape as Node3D).queue_free()
		var p: AudioStreamPlayer3D = gq.player
		if p.stream: p.play(randf() * 4.0)
		if quiet: p.volume_db = -6.0
		else: wind_in[gq.key] = 0.0; Sound.one(self, "ch3_tape", -2.0, gq.at)

func _wind_tick(dt: float):
	for k in wind_in.keys():
		wind_in[k] += dt
		for gq in gaps:
			if gq.key == k: (gq.player as AudioStreamPlayer3D).volume_db = lerpf(-40.0, -6.0, clampf(wind_in[k] / 1.4, 0.0, 1.0))
		if wind_in[k] > 1.5: wind_in.erase(k)

# ---------------------------------------------------------------- the candle (Makoto lights it, Mio holds it)
func _candle():
	candle = Node3D.new(); candle.name = "ch5_candle"
	var stick := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.011; cm.bottom_radius = 0.012; cm.height = 0.12
	stick.mesh = cm; var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.92, 0.9, 0.84); wm.roughness = 0.6
	stick.material_override = wm; stick.position.y = 0.06; candle.add_child(stick)
	var saucer := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.045; sm.bottom_radius = 0.04; sm.height = 0.01
	saucer.mesh = sm; var sw := StandardMaterial3D.new(); sw.albedo_color = Color(0.85, 0.84, 0.8); saucer.material_override = sw; candle.add_child(saucer)
	flame = Node3D.new(); flame.position.y = 0.125; candle.add_child(flame)
	var f := MeshInstance3D.new(); var fm := SphereMesh.new(); fm.radius = 0.007; fm.height = 0.028
	f.mesh = fm; f.position.y = 0.013
	var fmat := StandardMaterial3D.new(); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.78, 0.4); fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.7, 0.3); fmat.emission_energy_multiplier = 4.0
	f.material_override = fmat; f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; flame.add_child(f)
	candle_light = OmniLight3D.new(); candle_light.light_color = Color(1.0, 0.66, 0.34); candle_light.light_energy = 0.26
	candle_light.omni_range = 2.6; candle_light.omni_attenuation = 1.4; candle_light.shadow_enabled = true
	candle_light.light_volumetric_fog_energy = 0.2; candle_light.position.y = 0.16
	candle.add_child(candle_light)
	candle.visible = false
	add_child(candle)

var candle_held := false
func _candle_tick(dt: float):
	if not candle.visible: return
	if candle_held:
		var cam: Camera3D = player.get_node("Head/Camera")
		# low in her right hand, before her: it keeps upright whatever she looks at
		var p: Vector3 = cam.global_position + Basis(Vector3.UP, player.yaw) * Vector3(0.17, -0.42, -0.36)
		candle.global_transform = Transform3D(Basis(), p)
	var lean := Vector3.ZERO; var best := 99.0
	for gq in gaps:
		if not gq.peeled and gq.key != "g5": continue
		var d: float = (gq.at as Vector3).distance_to(candle.global_position)
		if d < best: best = d; lean = (gq.at as Vector3) - candle.global_position
	var fr := gp(FRONT_GAP[0], FRONT_GAP[1], FRONT_GAP[2])
	if fr.distance_to(candle.global_position) < best: best = fr.distance_to(candle.global_position); lean = fr - candle.global_position
	var k := clampf((2.2 - best) / 1.5, 0.0, 1.0)
	lean.y = 0.0
	var tilt := 0.9 * k + 0.05 * sin(t_now * 13.0) * (0.3 + k)
	if lean.length() > 0.001:
		var ax := Vector3.UP.cross(lean.normalized()).normalized()
		flame.basis = Basis(ax, tilt) if ax.length() > 0.5 else Basis()
	candle_light.light_energy = 0.26 + 0.04 * sin(t_now * 17.0) + 0.025 * sin(t_now * 5.3) - 0.07 * k * absf(sin(t_now * 9.0))

# ---------------------------------------------------------------- the generator: heard all night, now heard as the cause
func _gen_fore():
	gen_fore = AudioStreamPlayer.new(); gen_fore.stream = Sound.stream("generator_far", true)
	gen_fore.volume_db = -60.0; add_child(gen_fore)
	if gen_fore.stream: gen_fore.play()

func _gen_tick(dt: float):
	gen_db = move_toward(gen_db, gen_want, dt * 2.5)
	gen_fore.volume_db = gen_db

func _gen_loud():
	gen_want = -9.0

# ---------------------------------------------------------------- the blanket over her shoulders (after the answer)
func _blanket_on():
	if blanket: return
	blanket = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(0.95, 0.75); pm.subdivide_width = 6; pm.subdivide_depth = 6
	blanket.mesh = pm
	var m: Material = null
	var found: Array = main.S.env_node.find_children("bed1b_blanket*", "MeshInstance3D", true, false)
	if not found.is_empty(): m = (found[0] as MeshInstance3D).get_active_material(0)
	if m == null:
		var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.45, 0.4, 0.35); sm.roughness = 0.95; m = sm
	var dm := (m as Material).duplicate()
	if dm is BaseMaterial3D: (dm as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	blanket.material_override = dm
	blanket.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(blanket)
	var c := _nat_chest()
	var h := _nat_head()
	var along := Vector3(h.x - c.x, 0.0, h.z - c.z).normalized()
	# from her shoulders down her back: not over her face
	var mid := c - along * 0.22
	blanket.global_transform = Transform3D(Basis.looking_at(-along, Vector3.UP) * Basis(Vector3.RIGHT, 0.0), Vector3(mid.x, c.y + 0.12, mid.z))

func _blanket_tick():
	if blanket == null: return
	# its edge lifts a little in the draught from the back door
	var b := blanket.global_basis.orthonormalized()
	blanket.global_basis = b.slerp(b, 0.0)
	blanket.scale = Vector3(1.0, 1.0 + 0.02 * sin(t_now * 3.1) + 0.01 * sin(t_now * 7.3), 1.0)

# ---------------------------------------------------------------- cards and the clock
func _card(text: String, next: String, t := 1.5):
	if card: card.queue_free()
	card = main.make_card(self, [[text, 52, 0]], Type.card())
	card_t = t; card_next = next
	_clear_page(); _set_mission("")

func _process(dt):
	t_now += dt; t_stage += dt
	if card_t > 0.0:
		card_t -= dt
		card.visible = true; player.move_enabled = false; player.look_enabled = false
		if card_t <= 0.0:
			card.visible = false; player.look_enabled = true
			_begin(card_next)
		return
	if mode == TALK: _talk_tick(dt)
	_update_looks()
	_candle_tick(dt)
	_wind_tick(dt)
	_gen_tick(dt)
	_blanket_tick()
	_torch()
	main.talk_now = cur.get("who_key", "") if mode == TALK and cur.has("who") and typed < float(String(cur.get("text", "")).length()) else ""
	main.story_talking = (mode == TALK)
	player.move_enabled = mode == FREE and stage in ["follow", "peel", "done"]
	match stage:
		"follow": _follow_tick()
		"peel", "done": _peel_tick(dt)
		"end_wait": pass
	_below_tick(dt)
	if page_clear_t >= 0.0:
		page_clear_t -= dt
		if page_clear_t < 0.0 and mode == FREE: _clear_page()
	if demo5: _demo_tick(dt)

func _begin(st: String):
	t_stage = 0.0
	print("STORY ch5 %s t=%.1f" % [st, t_now])
	match st:
		"t4card":
			_card(D.lines("四時.カード")[0], "t4")
		"t4":
			stage = "t4"
			_start(B("四時.会話"))
		"back":
			stage = "back"; talk_with = "makoto"
			_start(B("四時.勝手口"))
		"peel":
			stage = "peel"; candle.visible = true; candle_held = true
			_below_start()
		"end":
			_end_scene()

# a line that waits for someone to arrive
func _next():
	if cur.has("silence") and silence_t >= 0.0: return   # the counted silence holds the talk (story._next goes straight on after a ＞)
	if hold: cur = {}; return
	super._next()

func _release():
	hold = false
	if mode == TALK: _next()

func _do(what: String):
	print("STORY ch5 do %s t=%.1f" % [what, t_now])
	match what:
		"makoto_down":
			_put("makoto", [5.0, 6.6], PI, F2); main.set_stand("makoto", "talk/idle", 0.0)
			main.phones(true, ["makoto"])
			hold = true
			main.walk_to("makoto", MAKOTO_DOWN, func(): _release(), _face([5.5, 2.55], [MIO_AT[0], MIO_AT[1]]))
		"makoto_see":
			talk_with = "makoto"
		"makoto_kneel":
			# beside her, by her shoulder, facing her: she goes down on her heels
			var c := _nat_chest()
			var at := [c.x + 4.8 + 0.5, c.z + 6.3]
			hold = true
			main.stand_anim["makoto"] = "talk/crouch"
			main.walk_to("makoto", [[5.3, 2.4, 0.0], [at[0], at[1], 0.0]], func(): _release(), _face(at, [c.x + 4.8, c.z + 6.3 + 0.2]))
		"makoto_tripod":
			var r := _rig("makoto")
			var to := gp(TRIPOD_AT[0], TRIPOD_AT[1], 0.0) - r.global_position
			var tw := create_tween()
			tw.tween_property(r, "global_rotation:y", r.global_rotation.y + wrapf(atan2(to.x, to.z) - r.global_rotation.y, -PI, PI) * 0.6, 1.2).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(1.4)
			tw.tween_property(r, "global_rotation:y", r.global_rotation.y, 1.0).set_trans(Tween.TRANS_SINE)
		"makoto_back":
			main.stand_anim["makoto"] = "talk/idle"
			talk_with = ""
			stage = "follow"
			main.walk_to("makoto", [[5.2, 2.3, 0.0], [4.3, 3.1, 0.0], [4.2, 3.3, 0.0], [4.2, 3.8, 0.0], [4.3, 3.9, 0.0], [4.3, 5.2, 0.0], [5.0, 5.9, 0.0], [5.5, 5.9, 0.0], [5.8, 6.2, 0.0], [8.1, 6.2, 0.0], [MK_BACK[0], MK_BACK[1], 0.0]],
				Callable(), _face(MK_BACK, [BACK_DOOR[0], BACK_DOOR[1]]))
		"makoto_light":
			torch_at = gp(BACK_DOOR[0], BACK_DOOR[1] - 0.25, 0.75)
		"shake":
			_nod(0.07, true)
		"nod":
			_nod(0.08, false)
		"makoto_temple":
			torch_at = Vector3.ZERO
			main.walk_to("makoto", [[MK_THINK[0], MK_THINK[1], 0.0]], func(): main.set_stand("makoto", "talk/think"), _face(MK_THINK, [player.global_position.x + 4.8, player.global_position.z + 6.3]))
			gen_want = -30.0
		"makoto_hand":
			hold = true
			main.stand_anim["makoto"] = "talk/crouch"
			torch_at = gp(HAND_AT[0], HAND_AT[1], HAND_AT[2])
			main.walk_to("makoto", [[9.45, 4.55, 0.0]], func():
				get_tree().create_timer(3.2).timeout.connect(func():
					main.set_stand("makoto", "talk/idle", 0.6); main.stand_anim["makoto"] = "talk/idle"
					torch_at = Vector3.ZERO
					get_tree().create_timer(1.4).timeout.connect(_release)), _face([9.45, 4.55], [HAND_AT[0], HAND_AT[1]]))
		"makoto_candle":
			# a candle from the kitchen, lit, into her hand: the light on Mio's hands first
			candle.visible = true; candle_held = true
			Sound.one(self, "ch3_blanket", -18.0, player.global_position)
		"makoto_go":
			hold = true
			main.walk_to("makoto", [[8.1, 5.6, 0.0], [7.3, 6.15, 0.0]], func(): _release(), _face([7.3, 6.15], [player.global_position.x + 4.8, player.global_position.z + 6.3]))
		"makoto_blanket":
			pass   # on her way down she lays Mio's blanket over her (seen at the end: _cellar_go)
		"makoto_cellar":
			talk_with = ""
			main.walk_to("makoto", [[5.8, 6.2, 0.0], [5.5, 5.9, 0.0]], func():
				if dn: dn.open_key("door_cellar")
				get_tree().create_timer(4.0).timeout.connect(_cellar_ajar)
				main.walk_to("makoto", [[5.5, 5.75, 0.0], [5.5, 5.55, 0.0], [5.5, 3.6, ZBASE * (5.55 - 3.6) / 2.9]], func():
					_hide("makoto"); main.phones(false, ["makoto"])))
			_blanket_on()
			get_tree().create_timer(1.5).timeout.connect(func(): _begin("peel"))
		"gen_loud":
			_gen_loud()
		"push":
			pass
		"silence":
			_silence_open()
		"end":
			script_q.clear()
			get_tree().create_timer(1.5).timeout.connect(_end_card)
		_: super._do(what)

# her head: a shake (no) or a nod (yes), the view itself moving
func _nod(a: float, shake: bool):
	var tw := create_tween()
	if shake:
		var y0: float = player.yaw
		for i in 2:
			tw.tween_property(player, "yaw", y0 + a, 0.16).set_trans(Tween.TRANS_SINE)
			tw.tween_property(player, "yaw", y0 - a, 0.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player, "yaw", y0, 0.16)
	else:
		var p0: float = player.pitch
		tw.tween_property(player, "pitch", p0 - a * 2.0, 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player, "pitch", p0, 0.3).set_trans(Tween.TRANS_SINE)

# Makoto's light: down ahead of her feet as main.gd aims it, or on what she looks at
var torch_at := Vector3.ZERO
func _torch():
	if torch_at == Vector3.ZERO or not main.S.has("makoto_node"): return
	var sk: Skeleton3D = main.S.makoto_node.find_children("*", "Skeleton3D", true, false)[0]
	for e in main.torches:
		if e[1] != sk or not is_instance_valid(e[0]): continue
		var sp: SpotLight3D = e[0]
		sp.global_basis = Basis.looking_at((torch_at - sp.global_position).normalized(), Vector3.UP)

# ---------------------------------------------------------------- following her to the kitchen
func _follow_tick():
	if mode != FREE: return
	var p: Vector3 = player.global_position
	if Vector2(p.x - gp(BACK_STAND[0], BACK_STAND[1], 0).x, p.z - gp(BACK_STAND[0], BACK_STAND[1], 0).z).length() < 1.0 and not main.walking("makoto"):
		_begin("back")

# ---------------------------------------------------------------- 四時十分: taking the tape off
func _next_key() -> String:
	for k in order:
		for gq in gaps:
			if gq.key == k and not gq.peeled: return k
	return ""

func _gap(k: String) -> Dictionary:
	for gq in gaps: if gq.key == k: return gq
	return {}

func _near_tape() -> Dictionary:
	var cam: Camera3D = player.get_node("Head/Camera")
	var best := {}; var ba := 99.0
	for gq in gaps:
		if gq.peeled: continue
		var to: Vector3 = (gq.at as Vector3) - cam.global_position
		var a := (-cam.global_basis.z).angle_to(to)
		if to.length() < 1.6 and a < deg_to_rad(28.0) and a < ba: ba = a; best = gq
	return best

func _what_looked() -> String:
	var gq := _near_tape()
	if not gq.is_empty(): return "tape"
	if _looking_at(gp(BACK_DOOR[0], BACK_DOOR[1], BACK_DOOR[2]), 1.9, 30.0): return "back"
	if _looking_at(gp(CELLAR_DOOR[0], CELLAR_DOOR[1], CELLAR_DOOR[2]), 1.9, 28.0): return "cellar"
	if _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2]), 2.4, 25.0): return "front"
	return ""

func _peel_tick(dt: float):
	idle_t += dt
	if idle_t > IDLE_STEP and below_i < BELOW.size() and below_q.is_empty() and stage == "peel":
		idle_t = 0.0; _below_step()
	if stage == "done" and end_wait >= 0.0:
		end_wait += dt
		if end_wait > 40.0 and mode == FREE: _begin("end"); return
	if mode != FREE: note_lb.text = ""; return
	look_k = _what_looked()
	match look_k:
		"tape": note_lb.text = T(String(D.lines("はがす.案内")[0]))
		"back": note_lb.text = T(String(D.lines("しない.勝手口")[0]))
		"cellar": note_lb.text = T(String(D.lines("しない.地下")[0]))
		"front": note_lb.text = T(String(D.lines("しない.玄関")[0]))
		_: note_lb.text = ""

func _press_peel():
	if not stage in ["peel", "done"]: return
	match look_k:
		"tape":
			var gq := _near_tape()
			var want := _next_key()
			idle_t = 0.0
			if gq.key != want:
				_start(B("はがす.ちがう", _gap(want).name))
				return
			_peel(gq)
			peeled_n += 1
			var q: Array = []
			if gq.key == "g5": q = B("はがす.勝手口.最後" if peeled_n == 5 else "はがす.勝手口")
			elif peeled_n == 1: q = B("はがす.一つ目")
			if peeled_n == 5:
				q.append_array(B("はがす.五つ目"))
				stage = "done"; end_wait = 0.0
			if not q.is_empty(): _start(q)
			while below_i < BELOW.size() and int(BELOW[below_i][0]) <= peeled_n: _below_step()
		"back", "cellar", "front":
			var key: String = {"back": "しない.勝手口", "cellar": "しない.地下", "front": "しない.玄関"}[look_k]
			var e: Array = B(key).slice(1)   # the first line is the key's own prompt
			if look_k == "back":
				Sound.one(self, "ch3_rattle", -10.0, gp(BACK_DOOR[0], BACK_DOOR[1], 1.0))   # her hand on it: it gives
				if below_i == 0: _below_step()   # the voice from below, if it has not come yet: she counts with it in her ears
			if said.has(key): e = e.filter(func(x): return x.has("do"))   # once: the testimony; again, only the silence
			said[key] = true
			if e.is_empty(): return
			_start(e)
			if stage == "done": end_wait = maxf(end_wait, 30.0)

# ---------------------------------------------------------------- the cellar: heard, not seen
func _below_start():
	below_q = []
	for e in B("地下.扉"):
		if e.has("t"): below_q.append(e)
	below_t = -9.0   # she is still on her way down

func _below_step():
	var k: String = BELOW[below_i][1]; below_i += 1
	print("STORY ch5 below %s peeled=%d t=%.1f" % [k, peeled_n, t_now])
	var t0 := below_t
	var i := 0
	for e in B(k):
		var e2: Dictionary = e.duplicate(); e2["t"] = t0 + 0.8 + i * 3.2; i += 1
		below_q.append(e2)
	if k == "地下.四": gen_want = -7.0

func _below_tick(dt: float):
	if below_q.is_empty() and stage != "peel" and stage != "done": return
	below_t += dt
	while not below_q.is_empty() and below_t >= float(below_q[0].t):
		if mode == TALK and not cur.has("silence") and not below_q[0].has("do"): below_t = float(below_q[0].t); break   # after what she is saying
		var e: Dictionary = below_q.pop_front()
		if e.has("do"):
			match String(e.do):
				"push": Sound.one(self, "creak3", -6.0, gp(5.5, 2.6, ZBASE + 1.0))
				"gen_loud": _gen_loud()
			continue
		if e.has("note"):
			var n := String(e.note)
			if n.contains("止まる"): Sound.one(self, "ch3_thud", -10.0, gp(5.5, 2.6, ZBASE + 1.0))
			if n.contains("肩で"): Sound.one(self, "ch3_thud", -12.0, gp(5.5, 2.6, ZBASE + 1.0))
			if n.contains("咳"): Sound.one(self, "ch3_cough", -9.0, gp(5.5, 4.0, ZBASE + 1.0))
			if n.contains("倒れる"): Sound.one(self, "ch3_thud", -7.0, gp(8.5, 6.0, ZBASE + 0.5))
			if mode == FREE: _line_row("", n, 22, "note"); page_clear_t = 7.0
			continue
		if mode == FREE or cur.has("silence"):
			var r = _line_row(String(e.who), Tw(String(e.text)), SAY_SIZE, "say")
			page_clear_t = 8.0

# the silence at the back door, counted (the one in this chapter)
func _silence_open():
	var r = _line_row("澪", "（沈黙）")
	silence_lb = r[1]; silence_t = 0.0
	cur = {"silence": true}

func _talk_tick(dt):
	if cur.has("silence"):
		silence_t += dt
		if is_instance_valid(silence_lb): silence_lb.text = T("（沈黙・%s秒）") % num(int(silence_t))
		if silence_t >= silence_len: silence_t = -1.0; _next()
		return
	if cur.is_empty() and hold: return
	super._talk_tick(dt)

func _advance():
	if cur.has("silence") or hold: return
	super._advance()

# ---------------------------------------------------------------- the end: back in the hall
func _end_scene():
	stage = "end"
	note_lb.text = ""; _set_mission("")
	var black := ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := CanvasLayer.new(); bl.layer = 12; add_child(bl); bl.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		# by her: the blanket, the shut front door, the cellar's open door behind; the generator
		var at := [5.15, 3.35]
		player.global_position = gp(at[0], at[1], 0.0); player.velocity = Vector3.ZERO
		var h := _nat_chest()
		_look_from(at, [h.x + 4.8 - 0.1, h.z + 6.3], 1.52, 0.1)
		candle_held = true)
	tw.tween_interval(0.6)
	tw.tween_property(black, "color:a", 0.0, 1.2)
	tw.tween_callback(func(): _start(B("五.終わり")))

func _end_card():
	stage = "fin"
	_clear_page(); note_lb.text = ""
	if card: card.queue_free()
	card = main.make_card(self, [[String(D.lines("五.カード")[2]), 64, 0]], Type.card(), false)
	card.visible = true
	get_tree().create_timer(5.0 if demo5 else 8.0).timeout.connect(func():
		if demo5: print("DEMO ch5 t=%.1f fails=%d" % [t_now, DEMO_FAILS]); DEMO_HOUSE = true
		if demo5 and "--ch5only" in OS.get_cmdline_user_args(): print("DEMO DONE ch5"); get_tree().quit(); return
		main.to_chapter("ch11"))

# ---------------------------------------------------------------- input
func _unhandled_input(e):
	if card_t > 0.0 or stage in ["end_card", "fin"]: return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if not press: return
	if mode == TALK: _advance(); return
	if stage in ["peel", "done"]: _press_peel()

# ---------------------------------------------------------------- the unattended playthrough (--demo)
func _demo_script() -> Array:
	var st := []
	st.append(["wait_stage", "follow"]); st.append(["wait_free"])
	st.append(["walk", [[4.4, 3.0], [4.3, 3.1], [4.2, 3.3], [4.2, 3.8], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.8, 6.2], [8.1, 6.2], [8.7, 5.4], [BACK_STAND[0], BACK_STAND[1]]]])
	st.append(["wait_stage", "peel"]); st.append(["wait_free"])
	# one wrong first (the kitchen's own window, unless it is the first in her order), then her order
	var routes := {
		"g1": [[6.9, 6.2], [5.8, 6.2], [5.5, 5.9], [5.0, 5.9], [4.8, 5.7], [4.8, 4.4], [4.1, 3.7], [3.6, 3.7], [2.7, 2.8], [2.7, 0.8], [2.6, 0.7]],
		"g2": [[2.6, 3.5], [0.7, 5.4], [0.7, 6.0], [0.5, 6.2]],
		"g3": [[0.5, 5.6], [0.9, 5.2], [1.6, 5.2], [3.1, 3.7], [4.1, 3.7], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.8, 6.2], [6.5, 6.2], [7.4, 7.1]],
		"g4": [[7.4, 6.8], [7.9, 6.3], [9.4, 6.3], [9.5, 6.2]],
		"g5": [[9.5, 5.0], [9.4, 4.9]]}
	if order[0] != "g3":
		st.append(["walk", [[8.4, 6.3], [7.6, 6.9], [7.4, 7.1]]]); st.append(["tape", "g3"]); st.append(["wait_free"])
	st.append(["walk", [[7.4, 6.8], [6.9, 6.2]]])
	for k in ["g1", "g2", "g3", "g4", "g5"]:
		st.append(["walk", routes[k]]); st.append(["tape", k]); st.append(["wait_free"])
	st.append(["walk", [[8.2, 4.9], [6.9, 6.2], [5.7, 6.2], [5.5, 6.1]]]); st.append(["aim", gp(CELLAR_DOOR[0], CELLAR_DOOR[1], CELLAR_DOOR[2])]); st.append(["press"]); st.append(["wait_free"])
	st.append(["walk", [[5.8, 6.2], [8.0, 6.2], [9.3, 4.9]]]); st.append(["aim", gp(BACK_DOOR[0], BACK_DOOR[1], BACK_DOOR[2])]); st.append(["press"])
	st.append(["wait_stage", "end"])
	return st

func _demo_tick(dt):
	if demo_steps.is_empty():
		demo_steps = _demo_script(); ds = 0
		if start_at == "peel":
			while ds < demo_steps.size() and not (demo_steps[ds][0] == "wait_stage" and demo_steps[ds][1] == "peel"): ds += 1
	if ds >= demo_steps.size() or card_t > 0.0: return
	var s: Array = demo_steps[ds]
	if stage in ["end", "fin"] and s[0] != "wait_stage": ds += 1; return
	dwait += dt
	var done := false
	match String(s[0]):
		"wait_stage":
			done = stage == s[1]
			if dwait > 400.0: _dfail("never reached stage %s (at %s)" % [s[1], stage]); done = true
		"wait_free":
			done = mode == FREE and dwait > 0.5 and not hold
			if dwait > 150.0: _dfail("the talk did not end"); done = true
		"walk":
			if player.auto_path.is_empty() and dwait < 0.1:
				var p: Vector3 = player.global_position
				var path := [[0.0, p.x, p.z, rad_to_deg(player.yaw), -6.0]]
				var t := 0.3; var prev := p
				for q in s[1]:
					var to: Vector3 = gp(q[0], q[1], 0.0); to.y = prev.y
					var d := Vector2(to.x - prev.x, to.z - prev.z)
					t += d.length() / 1.1 + 0.2
					path.append([t, to.x, to.z, rad_to_deg(atan2(-d.x, -d.y)), -6.0])
					prev = to
				player.auto_path = path; player.auto_t = 0.0
				s.append(t)
			elif s.size() > 2 and player.auto_t > float(s[2]) + 0.6:
				var last: Array = s[1][-1]
				var at: Vector3 = gp(last[0], last[1], 0.0)
				var off := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
				if off > 0.3 and player.auto_t < float(s[2]) + 12.0: return
				if off > 0.6: _dfail("walk: stuck at %s on the way to %s" % [_plan_of(player), last])
				player.auto_path = []; done = true
		"aim":
			var cam: Camera3D = player.get_node("Head/Camera")
			var to: Vector3 = (s[1] as Vector3) - cam.global_position
			var k := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to.x, -to.z), k)
			player.pitch = lerpf(player.pitch, asin(clampf(to.normalized().y, -1.0, 1.0)), k)
			done = (-cam.global_basis.z).angle_to(to) < deg_to_rad(4.0) or dwait > 4.0
		"press":
			if mode == FREE: _press_peel(); done = true
		"tape":
			var gq := _gap(s[1])
			var cam2: Camera3D = player.get_node("Head/Camera")
			var to2: Vector3 = (gq.at as Vector3) - cam2.global_position
			var k2 := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to2.x, -to2.z), k2)
			player.pitch = lerpf(player.pitch, asin(clampf(to2.normalized().y, -1.0, 1.0)), k2)
			if dwait > 1.2 and mode == FREE and s.size() < 3:
				var was := peeled_n
				_press_peel(); s.append(was)
			if s.size() >= 3: done = true
			if dwait > 20.0: _dfail("tape %s: cannot reach (Mio %s, looking %s)" % [s[1], _plan_of(player), look_k]); done = true
	if done: ds += 1; dwait = 0.0

func _dfail(what: String):
	DEMO_FAILS += 1
	print("DEMO FAIL ch5: %s t=%.1f" % [what, t_now])
