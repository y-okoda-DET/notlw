## ステップ F：第3章「隔離」 0時〜3時半の前（docs/資料/第3章の設計_2026-11-16.md）。台詞は story/ch3.txt。
## 家まるごとの23時の光（発電機の電球、ランタン、ろうそく、板の窓）で動く。main.gd が play="ch3" で作り、終わると第4章へ。
##
## 零時：地下から上がってきた大河。真琴が傷を素手で押さえる。桐生「四時間か」。言えたはずの一言の所は（沈黙）。大河は自分で
##   地下へ下り、閂をかける。澪は手すりの定点のカメラのテープを替える。
## 零時半：目張り。隙間ごとに風の音がその場所から鳴り、真琴のろうそくの炎がそちらへ傾く。Ｅでテープ。5か所。玄関の下は貼れない。
## 零時四十五分：二階へ毛布を取りに。寝室3つと洗面所の物を調べられる（澪の証言が出る）。
## 一時〜三時：扉の番。玄関の上がり框に毛布で座ったまま、見る・聞くだけ。音のするほうを見て Ｅ で証言の文。
##   二時、桐生が下りてきてカメラを外し、「俺でもだ」と出ていく。鍵を閉めるのはプレイヤー。二時半、ノックと欠けた声。三時、裏で何かが鳴る。
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")

const F2 := 2.75                       # the upstairs floor (house4: H1 2.45 + .3)
const ZBASE := -2.45                   # the cellar's floor
# where they stand at midnight (plan metres), and whom they face
const AT0 := {"taiga": [5.45, 5.95], "makoto": [4.8, 5.5], "kiryu": [4.45, 6.5]}
const MIO0 := [4.55, 4.25]
const TAIGA_DOWN := [[5.5, 5.75, 0.0], [5.5, 5.55, 0.0], [5.5, 2.65, ZBASE], [5.5, 2.1, ZBASE]]
const CAM_Y := 2.85                    # the small camera on the handrail (story.gd _house_ready)
# the gaps (plan x, y, z of the tape; the sound comes from there) and what the transcript calls them
const GAPS := [
	{"key": "g1", "at": [2.6, 0.13, 1.45], "n": [0, 1], "name": "板の隙間", "snd": "ch3_gap1"},     # the living room's front window
	{"key": "g2", "at": [0.13, 6.2, 1.5], "n": [1, 0], "name": "板の隙間", "snd": "ch3_gap2"},      # the dining room's west window
	{"key": "g3", "at": [7.4, 7.87, 1.5], "n": [0, -1], "name": "板の隙間", "snd": "ch3_gap3"},     # the kitchen's north window
	{"key": "g4", "at": [9.87, 6.2, 1.55], "n": [-1, 0], "name": "換気口", "snd": "ch3_gap4"},      # the kitchen's small east window
	{"key": "g5", "at": [9.96, 5.30, 1.0], "n": [-1, 0], "name": "勝手口の縁", "snd": "ch3_gap5"},   # the back door's edge
]
const FRONT_GAP := [5.0, 0.08, -0.1]   # under the front door: it stays
const FRONT_DOOR := [5.0, 0.03, 1.0]
const SIT_AT := [5.0, 1.62]            # the step up from the genkan, the door before her
const SIT_EYE := 0.84
const STAND_EYE := 1.52
# upstairs: what she can look at, and the block it gives (the node in env.glb gives the place; the plan point if not found)
const UP_ITEMS := [
	["blanket", "bed1b_blanket", [1.2, 3.62, F2 + 0.6], "毛布", "二階.毛布"],
	["hoodie", "natsuki_hoodie", [1.25, 0.6, F2 + 0.66], "上着", "二階.上着"],
	["bag_n", "bag_natsuki", [2.75, 0.55, F2 + 0.15], "鞄", "二階.夏希の鞄"],
	["bag_m", "bag_mio", [2.55, 3.85, F2 + 0.2], "鞄", "二階.澪の鞄"],
	["window", "", [1.5, 0.06, F2 + 1.3], "窓", "二階.窓"],
	["makeup", "makeup_box", [3.6, 5.0, F2 + 0.78], "道具箱", "二階.メイク道具"],
	["case", "case_cam", [2.6, 4.65, F2 + 0.18], "ケース", "二階.カメラのケース"],
	["shiori", "bag_taiga", [1.0, 6.15, F2 + 0.28], "鞄", "二階.しおり"],
	["food", "crew_crate", [2.55, 6.05, F2 + 0.22], "箱", "二階.食料"],
	["torch", "torch_kiryu", [2.85, 4.75, F2 + 0.36], "懐中電灯", "二階.懐中電灯"],
	["sweets", "bag_makoto", [7.3, 0.5, F2 + 0.2], "鞄", "二階.お菓子"],
	["reflector", "makoto_reflector", [9.9, 3.75, F2 + 0.33], "レフ板", "二階.レフ板"],
	["bath", "bath_water", [9.2, 7.27, F2 + 0.5], "風呂", "二階.風呂"],
]
# what she can turn to while she keeps the door (plan points), the word under the frame, and the block
const SOUNDS := {
	"door": [[5.0, 0.03, 0.5], "扉", "扉の番.音.扉"],
	"gen": [[5.5, 5.6, 0.5], "発電機", "扉の番.音.発電機"],
	"car": [[4.14, 0.0, 1.1], "外", "扉の番.音.車"],
	"cellar": [[5.5, 5.6, 0.9], "地下", "扉の番.音.地下"],
	"cough": [[5.5, 3.6, 2.4], "二階", "扉の番.音.咳"],
	"steps": [[5.5, 3.6, 2.4], "二階", "扉の番.音.足音"],
	"knock": [[5.0, 0.03, 1.2], "扉", "扉の番.音.ノック"],
	"back": [[5.0, 7.6, 1.0], "裏", "扉の番.音.裏"],
}

var stage := "card"     # card | t0 | tape | seal | up | back | watch | t2 | lock | flow | end
var card: Control
var card_t := 0.0
var card_next := ""
var t_stage := 0.0
var flow: Array = []
var fi := 0
var flow_key := ""
var flow_after := ""
var dn                         # doors.gd
var front_leaf: MeshInstance3D
var door_rest := 0.0
var door_pos := Vector3.ZERO
var knock_ts: Array = []
var gaps := []                 # {key, at (Godot), player, sealed, tape}
var sealed_n := 0
var seal_order: Array = []     # 第5章 peels them in this order
var front_seen := false
var cellar_said := false
var candle: Node3D
var flame: Node3D
var candle_light: OmniLight3D
var up_items := {}             # key -> {pos, name, block, seen}
var has_blanket := false
var blanket_view: MeshInstance3D
var shiori: MeshInstance3D
var car_glow: OmniLight3D
var s_heard := {}                # sound key -> the clock it was last s_heard (what she can turn to)
var said := {}                 # blocks already said once
var tes_t := -1.0              # an answer being typed at the top left
var tes_text := ""
var tes_lb: Label
var silence_t := -1.0
var silence_lb: Label
var silence_len := 9.0
var kiryu_tally: Node3D
var sit_tw: Tween
var demo3 := false
var demo_steps: Array = []
var ds := 0
var dwait := 0.0
var follow_t := 0.0
var wind_dim := {}             # gap key -> fading out (s)
var look_at_k := ""
var start_at := "t0"

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = ["ラジオ", "大河"]   # 大河's lines from behind the cellar door keep his name (the midnight ones are said in the hall: the rule shows it once)
	_load_file("ch3")
	_page()
	_lookers()
	main.generator(true)
	for e in main.torches:
		if is_instance_valid(e[0]): (e[0] as Node3D).visible = false
	main.phones(false)
	_hide("natsuki")   # she is in the car (her collider goes too)
	if main.S.has("natsuki_node"): (main.S.natsuki_node as Node3D).visible = false
	main.TALK = {}
	_night_cam()
	_gaps()
	_candle()
	_up_items()
	_car_glow()
	call_deferred("_front_door_mine")
	demo3 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	if "--ch3map" in OS.get_cmdline_user_args(): _map.call_deferred()
	demo_on = demo3
	start_at = "t0"; var start := "t0"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch3at="): start = a.substr(8); start_at = start     # check stills and the playthrough of one part: t0 | seal | up | watch | t2 | t230 | t3
	var c: Array = D.lines("三.カード")
	card = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	card_t = 2.75; card_next = start
	if start != "t0": card_t = 0.3
	_place_for(start)
	print("STORY ch3 start=", start)

static func _load_file(file: String):
	D.load_all()
	if D.blocks.has("三.カード"): return
	var p := "res://story/%s.txt" % file
	if not FileAccess.file_exists(p): print("SCRIPT ERROR 台本: no file ", p); return
	var key := ""
	for raw in FileAccess.get_file_as_string(p).split("\n"):
		var ln := String(raw).strip_edges()
		if ln == "" or ln.begins_with("//"): continue
		if ln.begins_with("【") and ln.ends_with("】"): key = ln.substr(1, ln.length() - 2); D.blocks[key] = []
		elif key != "": D.blocks[key].append(String(raw).rstrip(" \t\r"))

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

func _stand(eye: float):
	player.eye_height = eye; player.get_node("Head").position.y = eye

func _place_for(st: String):
	match st:
		"t0", "tape":
			for k in AT0:
				_put(k, AT0[k], _face(AT0[k], MIO0))
				main.set_stand(k, "talk/idle" if k != "makoto" else "talk/think", 0.0)
			player.global_position = gp(MIO0[0], MIO0[1], 0.0); _look_from(MIO0, [5.2, 5.8])
		"seal":
			_hide("taiga"); _put("kiryu", [1.6, 1.2], _face([1.6, 1.2], [1.9, 1.85]))   # in the living room by the lantern
			main.set_stand("kiryu", "talk/sit_b", 0.0)
			_put("makoto", [4.75, 6.1], _face([4.75, 6.1], [4.6, 5.0])); main.set_stand("makoto", "talk/idle", 0.0)
			player.global_position = gp(4.6, 5.1, 0.0); _look_from([4.6, 5.1], [4.75, 6.1])
		"up":
			_hide("taiga"); _hide("kiryu")   # 試作127 B5: he tapes the upstairs (零時半 kiryu_up)
			_put("makoto", [4.6, 1.9], _face([4.6, 1.9], [5.0, 0.0])); main.set_stand("makoto", "talk/idle", 0.0)
			sealed_n = 5
			for gq in gaps: _seal(gq, true)
			player.global_position = gp(4.75, 1.9, 0.0); _look_from([4.75, 1.9], [5.5, 3.5])
		"watch", "t2", "t230", "t3":
			_hide("taiga"); _hide("makoto")
			_put("kiryu", [1.6, 1.2], 0.0); main.set_stand("kiryu", "talk/sit_b", 0.0)
			if st != "t2": _hide("kiryu")
			sealed_n = 5; has_blanket = true
			for gq in gaps: _seal(gq, true)
			_sit()

# the small camera on the handrail, recording (2026-11-15: always there by 20:00)
func _night_cam():
	_fixed_cam()
	fixed_cam.global_position = g([0.30, CAM_Y, _rail_z(CAM_Y) + 0.065])
	fixed_cam.rotation.y = 0.0
	var ta := _target_angles()
	fixed_cam.global_basis = Basis.from_euler(Vector3(ta[1], ta[0], 0.0), EULER_ORDER_YXZ)
	_rec3(true)

# the camera's own lamp and dot (no finder in this chapter: story._set_rec would reach for it)
func _rec3(on: bool):
	recording = on
	var l := fixed_cam.get_node_or_null("rec") as OmniLight3D
	if l: l.light_energy = 1.2 if on else 0.0
	var d := fixed_cam.get_node_or_null("recdot") as MeshInstance3D
	if d and d.material_override is StandardMaterial3D: (d.material_override as StandardMaterial3D).emission_energy_multiplier = 16.0 if on else 0.0

# the front door is this chapter's: locked (22時, Mio locked it), its gap the one that stays, opened for Kiryu at two
func _front_door_mine():
	await get_tree().physics_frame; await get_tree().physics_frame
	dn = main.get_node_or_null("Doors")
	if dn:
		for k in dn.doors.keys():
			if dn.doors[k].pivot == main.door_pivot: front_leaf = k; dn.doors.erase(k)
	if main.door_pivot:
		door_rest = float(main.S.get("door_rot", 0.0)); door_pos = main.S.get("door_rest", main.door_pivot.position)
		main.door_pivot.rotation.y = door_rest; main.door_pivot.position = door_pos
	main.set_meta("knock_by_scene", true)
	if dn: dn.open_key("door_kitchen")   # they have been through it all evening (the water, the candles): it stands open
	if start_at != "t0": _shut_key("door_cellar")
	if "--ch3map" in OS.get_cmdline_user_args(): _shut_key("door_cellar")

# ---------------------------------------------------------------- the gaps: where the wind gets in
func _gaps():
	var front := AudioStreamPlayer3D.new(); front.stream = Sound.stream("ch3_gapfront", true); front.unit_size = 1.6; front.max_db = 0.0
	front.volume_db = -8.0; add_child(front); front.global_position = gp(FRONT_GAP[0], FRONT_GAP[1], FRONT_GAP[2] + 0.1)
	if front.stream: front.play()
	for gd in GAPS:
		var p := AudioStreamPlayer3D.new(); p.stream = Sound.stream(gd.snd, true); p.unit_size = 1.4; p.max_db = 0.0
		p.volume_db = -60.0; p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p); p.global_position = gp(gd.at[0], gd.at[1], gd.at[2])
		gaps.append({"key": gd.key, "at": gp(gd.at[0], gd.at[1], gd.at[2]), "n": gd.n, "name": gd.name, "player": p, "sealed": false, "tape": null})

func _seal(gq: Dictionary, quiet := false):
	if gq.sealed: return
	gq.sealed = true
	seal_order.append(gq.key)
	# the tape: a strip of grey cloth tape over the gap, on the boards' inside face
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	var along_x: bool = gq.n[0] == 0
	bm.size = Vector3(0.34 if along_x else 0.004, 0.05, 0.004 if along_x else 0.34)
	mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.62, 0.62, 0.6); m.roughness = 0.55; m.metallic = 0.1
	mi.material_override = m; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	mi.global_position = gq.at + Vector3(gq.n[0] * 0.006, 0.0, gq.n[1] * 0.006)
	mi.rotation.z = randf_range(-0.06, 0.06)
	# 試作127（ユーザー「扉の縁に貼られていない」）: the strip stood 11 cm in front of the middle of the back door. Down the
	# seam on the latch side (plan y 5.35, hinge at 4.4): one strip on the leaf's inside face (plan x 9.98), one on the jamb
	if gq.key == "g5":
		bm.size = Vector3(0.003, 1.86, 0.065); mi.rotation.z = 0.0
		mi.global_position = gp(9.977, 5.318, 0.97)
		var j := MeshInstance3D.new(); var jb := BoxMesh.new(); jb.size = Vector3(0.05, 1.86, 0.003); j.mesh = jb
		j.material_override = m; j.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; mi.add_child(j)
		j.global_position = gp(9.958, 5.348, 0.97)
	gq.tape = mi
	if quiet:
		(gq.player as AudioStreamPlayer3D).stop()
	else:
		Sound.one(self, "ch3_tape", -4.0, gq.at)
		wind_dim[gq.key] = 0.0

# ---------------------------------------------------------------- Makoto's candle
func _candle():
	if not main.S.has("makoto_node"): return
	candle = Node3D.new(); candle.name = "ch3_candle"
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
	add_child(candle)
	candle.visible = false

# held before her, at the height of her hands: it follows her body, not a bone (the talk clips move the hands about)
func _candle_tick(dt: float):
	if candle == null or not candle.visible: return
	var r := _rig("makoto")
	candle.global_position = r.global_transform * Vector3(0.12, 1.02, 0.28)
	# 試作127（ユーザー「ろうそくの炎が傾くってのは目に見えない＆重くなる原因になるのではないかと懸念」）: no lean to the
	# gaps any more (Makoto stands by the gap instead): the flame only shivers
	flame.basis = Basis(Vector3.RIGHT, 0.05 * sin(t_now * 13.0))
	candle_light.light_energy = 0.26 + 0.04 * sin(t_now * 17.0) + 0.025 * sin(t_now * 5.3)

# ---------------------------------------------------------------- upstairs
func _up_items():
	for it in UP_ITEMS:
		var pos: Vector3 = gp(it[2][0], it[2][1], it[2][2])
		if it[1] != "":
			var found: Array = main.S.env_node.find_children(String(it[1]) + "*", "MeshInstance3D", true, false)
			if not found.is_empty():
				var mi := found[0] as MeshInstance3D
				var bb: AABB = mi.global_transform * mi.get_aabb()
				pos = bb.get_center() + Vector3(0, bb.size.y * 0.3, 0)
				if it[0] == "blanket": blanket_mesh = mi
			else: print("CH3 item %s: no node %s, at the plan point" % [it[0], it[1]])
		up_items[it[0]] = {"pos": pos, "name": it[3], "block": it[4], "seen": false}
	# the old schedule in Taiga's bag (the one thing put here for this chapter): a folded sheet on top of the bag
	shiori = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.15, 0.004, 0.21); shiori.mesh = bm
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.93, 0.92, 0.88); pm.roughness = 0.9
	shiori.material_override = pm; add_child(shiori)
	shiori.global_position = up_items.shiori.pos + Vector3(0.05, 0.02, 0.0); shiori.rotation.y = 0.5; shiori.rotation.z = 0.12
var blanket_mesh: MeshInstance3D

# Natsuki in the car on the drive: her phone's screen, a faint cool light inside it (0:00 to 1:30)
func _car_glow():
	var cars: Array = main.S.env_node.find_children("ext_car*", "MeshInstance3D", true, false)
	if cars.is_empty(): print("CH3 no ext_car"); return
	var mi := cars[0] as MeshInstance3D
	var bb: AABB = mi.global_transform * mi.get_aabb()
	car_glow = OmniLight3D.new(); car_glow.light_color = Color(0.78, 0.86, 1.0); car_glow.light_energy = 0.9
	car_glow.omni_range = 1.4; car_glow.omni_attenuation = 1.2; car_glow.shadow_enabled = false; car_glow.light_volumetric_fog_energy = 0.4
	add_child(car_glow)
	car_glow.global_position = bb.get_center() + Vector3(0, 0.15, 0)

# the blanket in her arms, and then round her: the edge of it at the bottom of the frame
func _blanket_view(on: bool, sitting := false):
	if blanket_view == null:
		blanket_view = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.9, 0.08, 0.4); blanket_view.mesh = bm
		var m: Material = null
		if blanket_mesh: m = blanket_mesh.get_active_material(0)
		if m == null:
			var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.45, 0.4, 0.35); sm.roughness = 0.95; m = sm
		blanket_view.material_override = m; blanket_view.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		blanket_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		player.get_node("Head/Camera").add_child(blanket_view)
	blanket_view.visible = on
	blanket_view.position = Vector3(0.0, -0.42, -0.36) if sitting else Vector3(0.05, -0.38, -0.34)
	blanket_view.rotation = Vector3(deg_to_rad(-30.0 if sitting else -40.0), 0.0, deg_to_rad(4.0))

# ---------------------------------------------------------------- cards
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
	_knock_tick()
	_tes_tick(dt)
	main.talk_now = cur.get("who_key", "") if mode == TALK and cur.has("who") and typed < float(String(cur.get("text", "")).length()) else ""
	main.story_talking = (mode == TALK)
	var free_walk := stage in ["tape", "seal", "up", "back", "t2walk", "lock"]
	player.move_enabled = mode == FREE and free_walk
	match stage:
		"tape": _tape_tick()
		"seal": _seal_tick(dt)
		"up", "back": _up_tick(dt)
		"flow": _flow_tick(dt)
		"lock": _lock_tick()
		"t2walk": _t2walk_tick()
	_watch_look()
	if demo3: _demo_tick(dt)

func _begin(st: String):
	t_stage = 0.0
	print("STORY ch3 %s t=%.1f" % [st, t_now])
	match st:
		"t0":
			stage = "t0"; talk_with = "taiga"
			_start(B("零時.会話"))
		"tape":
			stage = "tape"; _set_mission("桐生さんに言われて、定点のカメラのテープを替えました。")
		"seal":
			stage = "seal"; candle.visible = true
			_start(B("零時半.会話"))
		"up":
			stage = "up"; candle.visible = true
			_set_mission("二階の寝室から、毛布を取ってきました。")
		"watch":
			_hide("makoto"); candle.visible = false   # 一時: Mio alone at the door (Makoto is in the kitchen with the candle)
			_sit(); _flow_start("扉の番.一時", "watch15")
		"watch15":
			_flow_start("扉の番.一時半", "t2card")
		"t2":
			# 試作127（B7、ユーザー「ここ、立ち上がった方がいいかな」）: she gets up, the blanket on her shoulders, to see the
			# cellar door; Kiryu comes down the stair as she goes
			stage = "t2walk"; kiryu_sent = false
			_stand(STAND_EYE); _blanket_view(true, false)
			_start(B("二時.地下へ"))
		"t230":
			_sit()
			_flow_start("扉の番.二時半", "t3card")
		"t3":
			_flow_start("扉の番.三時", "end")
		"end":
			_end()

# ---------------------------------------------------------------- 零時
func _do(what: String):
	print("STORY ch3 do %s t=%.1f" % [what, t_now])
	match what:
		"taiga_arm":
			talk_with = "makoto"
		"makoto_press":
			# 試作127（ユーザー「カメラ位置のせいで、真琴が何をやっているかわからない」）: she stood between Mio and Taiga, her
			# back to Mio. She goes round to his west side: from Mio's place she is seen side on, her hands on his arm
			main.walk_to("makoto", [[4.85, 5.75, 0.0], [4.88, 6.0, 0.0]], Callable(), _face([4.88, 6.0], AT0.taiga))
		"makoto_wipe":
			main.set_stand("makoto", "talk/think")
		"taiga_down":
			talk_with = ""
			if dn: dn.open_key("door_cellar"); dn.open_key("door_barred")
			main.walk_to("taiga", TAIGA_DOWN, func():
				_hide("taiga")
				_bar_shut())
		"camera_go":
			script_q.clear(); mode = FREE
			get_tree().create_timer(0.2).timeout.connect(func(): _begin("tape"))
		"to0030":
			script_q.clear(); mode = FREE
			get_tree().create_timer(2.0).timeout.connect(func(): _place_for("seal"); _card(D.lines("零時半.カード")[0], "seal"))
		"upstairs":
			script_q.clear(); mode = FREE
			get_tree().create_timer(0.6).timeout.connect(func(): _begin("up"))
		"to0100":
			script_q.clear(); mode = FREE
			get_tree().create_timer(1.2).timeout.connect(func(): _card(D.lines("一時.カード")[0], "watch"))
		"silence":
			_silence_open()
		"shake":
			var y0: float = player.yaw
			var tw := create_tween()
			for i in 2:
				tw.tween_property(player, "yaw", y0 + 0.07, 0.16).set_trans(Tween.TRANS_SINE)
				tw.tween_property(player, "yaw", y0 - 0.07, 0.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(player, "yaw", y0, 0.16)
		"kiryu_up":   # 試作127 B5「2階は桐生がやっておく」: from the lantern up the stair, a roll of tape in his hand
			main.walk_to("kiryu", [[1.6, 0.95, 0.0], [2.7, 0.95, 0.0], [2.7, 2.8, 0.0], [3.6, 3.7, 0.0], [4.3, 3.6, 0.0], [4.8, 2.9, 0.0], [5.5, 2.45, 0.0], [5.5, 5.7, F2], [5.0, 6.3, F2]], func(): _hide("kiryu"))
		"kiryu_rec":
			_kiryu_tally()
		"kiryu_out":
			script_q.clear(); mode = FREE
			_kiryu_out()
		"next":
			pass
		_: super._do(what)

# a door someone else shut (no "locked" line)
func _shut_key(key: String):
	if not dn: return
	for d in dn.doors.keys():
		if dn.doors[d].key == key and dn.doors[d].is_open: dn.toggle(d)

# the cellar's barred door shuts behind him: the bar drops on its brackets, from his side
func _bar_shut():
	_shut_key("door_cellar")   # the top one too (open, it lies across the way to the kitchen)
	if dn:
		for k in dn.doors.keys():
			var s: Dictionary = dn.doors[k]
			if s.key == "door_barred":
				if s.is_open: dn.toggle(k)
				s.locked = "開かない。"
	get_tree().create_timer(0.8).timeout.connect(func(): Sound.one(self, "ch3_bar", -6.0, gp(5.5, 2.5, ZBASE + 1.0)))

# the silence where she could have said it: counted, as at the door at eleven (one only in this chapter)
func _silence_open():
	var r = _line_row("澪", "（沈黙）")
	silence_lb = r[1]; silence_t = 0.0
	script_q.push_front({"do": "next"})
	cur = {"silence": true}

func _talk_tick(dt):
	if cur.has("silence"):
		silence_t += dt
		if is_instance_valid(silence_lb): silence_lb.text = T("（沈黙・%s秒）") % num(int(silence_t))
		if silence_t >= silence_len: silence_t = -1.0; _next()
		return
	if demo3 and cur.has("choose") and not cur.get("chosen", false):
		read_t += dt
		if read_t > 2.0: read_t = 0.0; choice_idx = 0; _show_choice(); _choose()
		return
	super._talk_tick(dt)

func _advance():
	if cur.has("silence"): return   # the silence is not hers to cut short
	super._advance()

# ---------------------------------------------------------------- the tape in the small camera
func _cam_near() -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := fixed_cam.global_position - cam.global_position
	return to.length() < 1.7 and (-cam.global_basis.z).angle_to(to) < deg_to_rad(18.0)

func _tape_tick():
	if mode != FREE: return
	note_lb.text = T(String(D.lines("零時.テープ")[0])) if _cam_near() else ""

func _swap_tape():
	note_lb.text = ""
	Sound.one(self, "tape_clunk", -6.0, fixed_cam.global_position)
	_rec3(false)
	get_tree().create_timer(1.4).timeout.connect(func(): _rec3(true))
	stage = "tape_done"
	_start(B("零時.替えた"))

# ---------------------------------------------------------------- 零時半: the gaps
func _near_gap() -> Dictionary:
	var cam: Camera3D = player.get_node("Head/Camera")
	for gq in gaps:
		if gq.sealed or gq.key != _next_gap(): continue
		var to: Vector3 = (gq.at as Vector3) - cam.global_position
		if to.length() < 1.6 and (-cam.global_basis.z).angle_to(to) < deg_to_rad(28.0): return gq
	return {}

func _looking_at(p: Vector3, reach: float, deg: float) -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := p - cam.global_position
	return to.length() < reach and (-cam.global_basis.z).angle_to(to) < deg_to_rad(deg)

func _seal_tick(dt: float):
	_makoto_follow(dt)
	# 試作127（ユーザー「虚空に向かって話している。変。直す。」）: when she speaks (or Mio does) she turns to Mio
	if mode == TALK and not main.walking("makoto"):
		var rig: Node3D = main._rig_of("makoto")
		if rig and rig.visible:
			var y1 := _face([rig.global_position.x + 4.8, rig.global_position.z + 6.3], [player.global_position.x + 4.8, player.global_position.z + 6.3])
			var y0 := rig.global_rotation.y
			rig.global_transform = Transform3D(Basis(Vector3.UP, y0 + wrapf(y1 - y0, -PI, PI) * minf(1.0, dt * 2.5)), rig.global_position)
	if mode != FREE: note_lb.text = ""; return
	var gq := _near_gap()
	if not gq.is_empty() and _makoto_near(gq.at): note_lb.text = T(String(D.lines("目張り.案内")[0]))
	elif _looking_at(gp(FRONT_GAP[0], FRONT_GAP[1], 0.4), 2.2, 30.0): note_lb.text = T("［玄関の下］")
	elif _looking_at(gp(5.5, 5.62, 1.0), 1.8, 25.0) and not cellar_said: note_lb.text = T("［地下の扉］")
	else: note_lb.text = ""

func _makoto_near(p: Vector3) -> bool:
	return candle and mk_at != "" and mk_at == _next_gap() and candle.global_position.distance_to(p) < 2.2

# 試作127（ユーザー「真琴、主人公にぶつかったり、壁を通り抜けたりする」「「風の音とろうそくの炎が隙間の方へ傾く」が機能していない。
# 真琴がどこにいるかよくわからない＆挙動不審」）: she no longer trails Mio (a straight line to a point behind her went through
# walls, and a step behind Mio is a step into her). She goes ahead, by the ways the playthrough walks (laid on the --ch3map),
# to the next gap in a fixed order, stands by it with the candle and waits; only that gap's wind is heard. After the fifth
# she goes to the front door. Her spots stand off the place Mio stands to tape.
const SEAL_ORDER_FIXED := ["g1", "g2", "g3", "g4", "g5"]
const MK_WAY := {
	"g1": [[4.95, 5.4], [4.8, 3.95], [4.3, 3.6], [3.6, 3.7], [2.7, 2.8], [2.7, 1.2], [1.95, 0.75]],
	"g2": [[2.7, 1.2], [2.7, 2.8], [2.6, 3.5], [1.6, 4.6], [1.25, 5.1]],
	"g3": [[1.6, 5.2], [3.1, 3.7], [4.1, 3.7], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.8, 6.2], [6.5, 6.2], [6.6, 6.8]],
	"g4": [[7.4, 6.6], [7.9, 6.3], [8.95, 6.0]],
	"g5": [[8.85, 4.9]],
	"front": [[8.2, 4.9], [6.9, 6.2], [5.7, 6.2], [5.1, 6.0], [4.8, 5.7], [4.8, 4.2], [4.3, 3.7], [4.2, 3.4], [4.3, 3.2], [4.3, 2.9], [4.6, 2.6], [4.55, 1.8]],
}
var mk_at := ""        # the gap (or "front") she stands at, "" while she walks
var mk_going := ""

func _next_gap() -> String:
	for k in SEAL_ORDER_FIXED:
		for gq in gaps:
			if gq.key == k and not gq.sealed: return k
	return "front"

func _gap_at(k: String) -> Array:
	for gd in GAPS:
		if gd.key == k: return [gd.at[0], gd.at[1]]
	return [FRONT_DOOR[0], FRONT_DOOR[1]]

func _makoto_follow(_dt: float):
	if mode != FREE or main.walking("makoto"): return
	var k := _next_gap()
	if mk_at == k or mk_going == k: return
	mk_going = k; mk_at = ""
	_wind_for(k)
	var way: Array = MK_WAY[k]
	var pts := []
	for w in way: pts.append([w[0], w[1], 0.0])
	var last: Array = way[way.size() - 1]
	main.walk_to("makoto", pts, func(): mk_at = k; mk_going = "", _face([last[0], last[1]], _gap_at(k)))

# only the gap she goes to is heard (the front's stays, under the door)
func _wind_for(k: String):
	for gq in gaps:
		var p: AudioStreamPlayer3D = gq.player
		if gq.sealed or wind_dim.has(gq.key): continue
		if gq.key == k:
			p.volume_db = -6.0
			if p.stream and not p.playing: p.play(randf() * 4.0)
		else:
			p.volume_db = -60.0; p.stop()

func _press_seal():
	var gq := _near_gap()
	if gq.is_empty() or not _makoto_near(gq.at): return false
	_seal(gq)
	sealed_n += 1
	talk_with = "makoto"
	var q: Array = []
	if gq.key == "g5": q.append_array(B("目張り.勝手口"))
	else: q.append_array(B("目張り.貼った.%d" % mini(sealed_n, 4)))
	if sealed_n == 3: q.append_array(B("目張り.問い"))
	if sealed_n == 5: q.append_array(B("目張り.五つ"))
	_start(q)
	return true

func _wind_tick(dt: float):
	for k in wind_dim.keys():
		wind_dim[k] += dt
		for gq in gaps:
			if gq.key != k: continue
			var p: AudioStreamPlayer3D = gq.player
			p.volume_db = lerpf(-6.0, -60.0, clampf(wind_dim[k] / 1.6, 0.0, 1.0))
			if wind_dim[k] > 1.7: p.stop(); wind_dim.erase(k)

# ---------------------------------------------------------------- 零時四十五分: upstairs
func _item_looked() -> String:
	var cam: Camera3D = player.get_node("Head/Camera")
	var best := ""; var ba := 99.0
	for k in up_items:
		var it: Dictionary = up_items[k]
		if k == "blanket" and has_blanket: continue
		var to: Vector3 = (it.pos as Vector3) - cam.global_position
		var reach := 3.2 if k == "window" else 1.9
		if to.length() > reach: continue
		var a := (-cam.global_basis.z).angle_to(to)
		if a < deg_to_rad(16.0) and a < ba: ba = a; best = k
	return best

func _up_tick(_dt: float):
	if car_glow: car_glow.light_energy = 0.9 + 0.1 * sin(t_now * 0.7)
	if mode != FREE: return
	var k := _item_looked()
	look_at_k = k
	if k == "blanket": note_lb.text = T(String(D.lines("二階.毛布")[0]))
	elif k != "": note_lb.text = T("［%s］" % up_items[k].name)
	elif has_blanket and _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], 0.6), 2.4, 30.0) and player.global_position.y < 0.5: note_lb.text = T(String(D.lines("二階.戻る")[0]))
	else: note_lb.text = ""

func _press_up():
	var k := look_at_k
	if k == "blanket" and not has_blanket:
		has_blanket = true
		Sound.one(self, "ch3_blanket", -6.0, up_items.blanket.pos)
		if blanket_mesh: blanket_mesh.visible = false
		_blanket_view(true)
		stage = "back"
		_say_tes(B("二階.取った")[0].text)
		_set_mission("毛布を持って、玄関に戻りました。")
		return
	if k != "":
		var e: Array = B(up_items[k].block)
		up_items[k].seen = true
		if not e.is_empty(): _say_tes(e[0].text)
		return
	if stage == "back" and has_blanket and _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], 0.6), 2.4, 30.0):
		note_lb.text = ""
		_do("to0100")

# her answer, months later, at the top left: typed, it stays a while and fades
func _say_tes(text: String):
	if demo3: print("SAY 澪＊：", text)
	var r = _line_row("澪", "", SAY_SIZE, "testimony")
	tes_lb = r[1]; tes_text = _wrap_row(Tw(text)); tes_t = 0.0
	tes_box.modulate.a = 1.0

func _tes_tick(dt: float):
	if tes_t < 0.0 or not is_instance_valid(tes_lb): return
	tes_t += dt
	_type(tes_lb, tes_text, int(tes_t * 20.0))
	var hold := 2.5 + tes_text.length() * 0.08
	if tes_t * 20.0 > tes_text.length() + hold * 20.0:
		tes_box.modulate.a = clampf(1.0 - (tes_t - tes_text.length() / 20.0 - hold) / 1.2, 0.0, 1.0)
		if tes_box.modulate.a <= 0.0: tes_t = -1.0; _clear_box(tes_box); tes_box.modulate.a = 1.0

# ---------------------------------------------------------------- 一時から: she keeps the door
func _sit():
	stage = "watch"
	player.move_enabled = false
	player.global_position = gp(SIT_AT[0], SIT_AT[1], 0.0)
	player.velocity = Vector3.ZERO
	_stand(SIT_EYE)
	_look_from(SIT_AT, [5.0, 0.0], SIT_EYE, 0.7)
	_blanket_view(true, true)
	_foot_keys()

func _foot_keys():
	var f: Label = main.foot
	if f: f.text = T("マウス 見る　Ｅ 聞く　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")

func _hear(k: String):
	s_heard[k] = t_now

func _watch_look():
	if not stage in ["watch", "flow", "t2", "lock"]: return
	if stage == "lock" or mode == TALK: return
	var cam: Camera3D = player.get_node("Head/Camera")
	var best := ""; var ba := 99.0
	for k in SOUNDS:
		if k in ["door", "gen"]: pass
		elif not s_heard.has(k) or t_now - float(s_heard[k]) > 40.0: continue
		if said.has(SOUNDS[k][2]): continue
		var to: Vector3 = gp(SOUNDS[k][0][0], SOUNDS[k][0][1], SOUNDS[k][0][2]) - cam.global_position
		var a := (-cam.global_basis.z).angle_to(to)
		if a < deg_to_rad(15.0) and a < ba: ba = a; best = k
	look_at_k = best
	note_lb.text = T("［%s］" % SOUNDS[best][1]) if best != "" else ""

func _press_watch():
	var k := look_at_k
	if k == "" or said.has(SOUNDS[k][2]): return
	said[SOUNDS[k][2]] = true
	_say_tes(D.lines(SOUNDS[k][2])[0])
	print("STORY ch3 s_heard %s t=%.1f" % [k, t_now])

# the timed parts (扉の番.*): lines at their second, the sounds with them
func _flow_start(key: String, after: String):
	flow = []
	for e in B(key):
		if not e.has("t"): continue
		flow.append(e)
	fi = 0; flow_key = key; flow_after = after; t_stage = 0.0
	stage = "flow"
	_clear_page()

func _flow_tick(_dt: float):
	while fi < flow.size() and t_stage >= float(flow[fi].t):
		_flow_event(flow[fi]); fi += 1
	if cur.has("text") and typed < String(cur.text).length():
		typed = min(float(String(cur.text).length()), typed + _dt * (20.0 if cur.get("testimony", false) else 15.0))
		_type(cur_lb, String(cur.text), int(typed))

func _flow_event(e: Dictionary):
	if demo3: print("SAY %.1f %s" % [float(e.t), (String(e.who) + "：" + String(e.text)) if e.has("who") else ("＞" + String(e.do)) if e.has("do") else String(e.get("note", ""))])
	if e.has("do"):
		match String(e.do):
			"next":
				match flow_after:
					"watch15": _card(D.lines("一時半.カード")[0], "watch15")
					"t2card": _card(D.lines("二時.カード")[0], "t2")
					"t3card": _card(D.lines("三時.カード")[0], "t3")
					_: _begin(flow_after)
			"end": _begin("end")
			"car_door":
				Sound.one(self, "car_door", -16.0, gp(6.5, -6.0, 0.5)); _hear("car")
			"cellar_voice":
				Sound.one(self, "ch3_murmur", -10.0, gp(5.5, 5.4, -0.6)); _hear("cellar")
				get_tree().create_timer(6.0).timeout.connect(func(): Sound.one(self, "ch3_murmur", -11.0, gp(5.5, 5.4, -0.6)))
				get_tree().create_timer(12.0).timeout.connect(func(): Sound.one(self, "ch3_murmur", -12.0, gp(5.5, 5.4, -0.6)))
			"thud":
				Sound.one(self, "ch3_thud", -2.0, gp(5.5, 2.6, ZBASE + 0.8)); _hear("cellar")
			"makoto_come":
				_put("makoto", [4.75, 4.6], PI); main.set_stand("makoto", "talk/idle", 0.0); candle.visible = true
				main.walk_to("makoto", [[4.7, 2.6, 0.0]], Callable(), _face([4.7, 2.6], SIT_AT))
				talk_with = "makoto"
			"makoto_head":
				main.set_stand("makoto", "talk/think")
			"makoto_up":
				talk_with = ""
				main.walk_to("makoto", [[4.7, 2.4, 0.0], [5.5, 2.45, 0.0], [5.5, 5.7, F2], [5.0, 6.3, F2]], func(): _hide("makoto"); candle.visible = false)
				get_tree().create_timer(8.0).timeout.connect(func(): Sound.one(self, "ch3_cough", -8.0, gp(8.5, 1.5, F2 + 0.8)); _hear("cough"))
				get_tree().create_timer(20.0).timeout.connect(func(): Sound.one(self, "ch3_steps", -10.0, gp(2.5, 5.5, F2 + 0.2)); _hear("steps"))
			"knock":
				Sound.one(self, "knock", -2.0, gp(FRONT_DOOR[0], FRONT_DOOR[1], 1.2)); _hear("knock")
				for i in 3: knock_ts.append(t_now + 0.42 * i)
			"leave":
				pass
			"rattle":
				Sound.one(self, "ch3_rattle", -9.0, gp(9.8, 4.9, 1.0)); _hear("back")
			"silence":
				_line_row("澪", "（沈黙）")
			_: print("CH3 unknown do ", e.do)
		return
	if e.has("note"):
		_line_row("", String(e.note), 22, "note"); cur = {}
		var n := String(e.note)
		if n.contains("うめき"): Sound.one(self, "ch3_moan", -8.0, gp(5.5, 2.6, ZBASE + 1.0)); _hear("cellar")
		if n.contains("大河くんの声"): _hear("cellar")
		return
	cur = {"who": e.who, "text": _wrap_row(Tw(String(e.text))), "who_key": WHO_KEY.get(e.who, ""), "testimony": e.get("testimony", false)}
	typed = 0.0
	var r = _line_row(String(e.who), "", SAY_SIZE, "testimony" if cur.testimony else "say")
	cur_lb = r[1]
	if e.who == "大河": Sound.one(self, "ch3_murmur", -12.0, gp(5.5, 5.4, -0.6))

# the front door jumps in its frame with each knock
func _knock_tick():
	if main.door_pivot == null: return
	var j := 0.0
	for kt in knock_ts:
		var d := t_now - float(kt)
		if d >= 0.0 and d < 0.12: j = maxf(j, 0.004 * (1.0 - d / 0.12))
	main.door_pivot.position = door_pos + main.door_pivot.global_basis.z * j
	knock_ts = knock_ts.filter(func(x): return t_now - float(x) < 0.5)

# ---------------------------------------------------------------- 二時: Kiryu
const KIRYU_DOWN := [[5.0, 6.3, F2], [5.5, 5.7, F2], [5.5, 2.55, 0.0], [4.75, 2.2, 0.0]]
var kiryu_sent := false
func _t2walk_tick():
	if kiryu_sent or mode != FREE: return
	var off := Vector2(player.global_position.x + 4.8 - SIT_AT[0], player.global_position.z + 6.3 - SIT_AT[1]).length()
	if off > 0.9 or t_stage > 20.0: kiryu_sent = true; _kiryu_comes()

func _kiryu_comes():
	stage = "t2walk"
	_put("kiryu", [5.0, 6.6], PI, F2)
	main.set_stand("kiryu", "talk/idle", 0.0)
	main.walk_to("kiryu", KIRYU_DOWN, func():
		# the big camera off its tripod (the tripod stays: 第4章)
		for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name)
			if nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"): (mi as Node3D).visible = false
		# he turns to her where she is (the hall, on her way to the cellar door) and she to him
		var me := [4.75, 2.2]; var mio := [player.global_position.x + 4.8, player.global_position.z + 6.3]
		var k := _rig("kiryu"); k.global_transform = Transform3D(Basis(Vector3.UP, _face(me, mio)), k.global_position)
		var to: Vector3 = (k.global_position + Vector3(0, 1.45, 0)) - player.get_node("Head/Camera").global_position
		var tw := create_tween(); tw.set_parallel(true)
		tw.tween_property(player, "yaw", player.yaw + wrapf(atan2(-to.x, -to.z) - player.yaw, -PI, PI), 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player, "pitch", asin(clampf(to.normalized().y, -1.0, 1.0)), 0.8).set_trans(Tween.TRANS_SINE)
		_set_mission("")
		talk_with = "kiryu"; stage = "t2"
		_start(B("扉の番.二時")))

func _kiryu_tally():
	if not main.S.has("kiryu_node"): return
	kiryu_tally = Node3D.new()
	var dot := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.006; sm.height = 0.012; dot.mesh = sm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(1, 0.15, 0.05)
	m.emission_enabled = true; m.emission = Color(1, 0.15, 0.05); m.emission_energy_multiplier = 6.0
	dot.material_override = m; kiryu_tally.add_child(dot)
	var l := OmniLight3D.new(); l.light_color = Color(1, 0.12, 0.04); l.light_energy = 0.4; l.omni_range = 0.25; l.shadow_enabled = false
	kiryu_tally.add_child(l)
	_rig("kiryu").add_child(kiryu_tally)
	kiryu_tally.position = Vector3(0.1, 1.38, 0.22)
	Sound.one(self, "dial_tick", -14.0, _rig("kiryu").global_position + Vector3(0, 1.3, 0))

func _kiryu_out():
	Sound.one(self, "ch3_lock", -8.0, gp(5.0, 0.05, 1.0))
	get_tree().create_timer(0.5).timeout.connect(func():
		Sound.one(self, "door_open", -4.0, gp(5.0, 0.0, 1.0))
		var tw := create_tween()
		tw.tween_property(main.door_pivot, "rotation:y", door_rest + deg_to_rad(80.0), 1.0).set_trans(Tween.TRANS_SINE)
		main.walk_to("kiryu", [[5.0, 0.4, -0.18], [5.0, -0.6, -0.21], [6.2, -1.1, -0.2]], func():
			_hide("kiryu")
			var tw2 := create_tween()
			tw2.tween_property(main.door_pivot, "rotation:y", door_rest, 1.1).set_trans(Tween.TRANS_SINE)
			tw2.tween_callback(func():
				Sound.one(self, "knock1", -10.0, gp(5.0, 0.0, 1.0))
				stage = "lock"; t_stage = 0.0
				_start(B("二時.鍵")))))

func _lock_tick():
	if mode != FREE: note_lb.text = ""; return
	note_lb.text = T(String(D.lines("二時.鍵")[0])) if _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2]), 2.3, 25.0) else ""

func _lock_now():
	if stage != "lock": return
	stage = "locked"; note_lb.text = ""; _set_mission("")
	Sound.one(self, "ch3_lock", -6.0, gp(5.0, 0.05, 1.0))
	_start(B("二時.閉めた"))

# 二時.閉めた ends in ＞next: on to 二時半
func _next():
	# the counted silence holds the talk: story._next goes straight on after a ＞ (it went on with the next line in the same frame, and the silence was never seen)
	if cur.has("silence") and silence_t >= 0.0: return
	if script_q.is_empty() and stage == "locked" and mode == TALK:
		super._next()
		stage = "wait"
		get_tree().create_timer(2.0).timeout.connect(func(): _card(D.lines("二時半.カード")[0], "t230"))
		return
	if script_q.is_empty() and stage == "tape_done" and mode == TALK:
		super._next(); return
	super._next()

# ---------------------------------------------------------------- the end: the chapter's question again, then 第四章
func _end():
	stage = "end"
	_clear_page(); note_lb.text = ""
	if car_glow: car_glow.visible = false
	if card: card.queue_free()
	card = main.make_card(self, [[D.lines("三.終わり")[0], 64, 0]], Type.card(), false)
	card.visible = true
	get_tree().create_timer(5.0 if demo3 else 8.0).timeout.connect(func():
		if demo3: print("DEMO ch3 t=%.1f fails=%d seal=%s" % [t_now, DEMO_FAILS, ",".join(seal_order)]); DEMO_HOUSE = true
		if demo3 and "--ch3only" in OS.get_cmdline_user_args(): print("DEMO DONE ch3"); get_tree().quit(); return
		SEAL_ORDER = seal_order.duplicate()
		main.to_chapter("ch4"))
static var SEAL_ORDER: Array = []   # 第5章 peels the tape in the order she put it on

# ---------------------------------------------------------------- input
func _unhandled_input(e):
	if card_t > 0.0 or stage == "end": return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if mode == TALK:
		if cur.has("choose") and e is InputEventKey and e.pressed and e.keycode in [KEY_W, KEY_UP, KEY_A, KEY_LEFT]: _move_choice(-1); return
		if cur.has("choose") and e is InputEventKey and e.pressed and e.keycode in [KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT]: _move_choice(1); return
		if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and cur.has("choose"):
			_move_choice(-1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1); return
		if press: _advance()
		return
	if not press: return
	_press()

func _press():
	match stage:
		"tape":
			if _cam_near(): _swap_tape()
		"seal":
			if _press_seal(): return
			if _looking_at(gp(FRONT_GAP[0], FRONT_GAP[1], 0.4), 2.2, 30.0):
				talk_with = "makoto"
				if sealed_n >= 5:
					var q: Array = [] if front_seen else B("目張り.玄関")
					q.append_array(B("目張り.終わり"))
					front_seen = true
					_start(q)
				elif not front_seen:
					front_seen = true; _start(B("目張り.玄関"))
				return
			if _looking_at(gp(5.5, 5.62, 1.0), 1.8, 25.0) and not cellar_said:
				cellar_said = true; talk_with = "makoto"; _start(B("目張り.地下の扉"))
		"up", "back":
			_press_up()
		"watch", "flow", "t2":
			_press_watch()
		"lock":
			if _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2]), 2.3, 25.0): _lock_now()

# ---------------------------------------------------------------- the unattended playthrough (--demo): every step a player has to take
func _demo_script():
	var steps := []
	# 零時: the talk runs by itself; then the camera on the handrail
	steps.append(["wait_stage", "tape"])
	steps.append(["walk", [[4.55, 3.4]]]); steps.append(["aim", g([0.30, CAM_Y, _rail_z(CAM_Y) + 0.065])]); steps.append(["press_if", "tape"])
	steps.append(["wait_stage", "seal"]); steps.append(["wait_free"])
	# 零時半: five gaps, the cellar door once, the front last (routes laid on the --ch3map of the house: the narrow
	# way past the lamp stand at x 4.3, the dining table, the open kitchen door)
	steps.append(["walk", [[4.6, 4.2], [4.1, 3.7], [3.6, 3.7], [2.7, 2.8], [2.7, 0.7], [2.6, 0.6]]]); steps.append(["gap", "g1"])
	steps.append(["walk", [[2.6, 3.5], [0.7, 5.4], [0.7, 6.0], [0.5, 6.2]]]); steps.append(["gap", "g2"])
	steps.append(["walk", [[0.5, 5.6], [0.9, 5.2], [1.6, 5.2], [3.1, 3.7], [4.1, 3.7], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.8, 6.2], [6.5, 6.2], [7.4, 7.1]]]); steps.append(["gap", "g3"])
	steps.append(["walk", [[7.4, 6.8], [7.9, 6.3], [9.4, 6.3], [9.5, 6.2]]]); steps.append(["gap", "g4"])
	steps.append(["walk", [[9.5, 4.9]]]); steps.append(["gap", "g5"])
	steps.append(["walk", [[8.2, 4.9], [6.9, 6.2], [5.7, 6.2], [5.5, 6.3]]]); steps.append(["aim", gp(5.5, 5.62, 1.0)]); steps.append(["press"]); steps.append(["wait_free"])
	steps.append(["walk", [[5.5, 6.0], [5.1, 6.0], [4.8, 5.7], [4.8, 4.2], [4.3, 3.7], [4.2, 3.4], [4.3, 3.2], [4.3, 2.9], [4.6, 2.6], [4.6, 1.9], [4.8, 1.5], [5.0, 1.2]]])
	steps.append(["aim", gp(FRONT_GAP[0], FRONT_GAP[1], 0.4)]); steps.append(["press"])
	steps.append(["wait_stage", "up"]); steps.append(["wait_free"])
	# 零時四十五分: up the stair, every one of the things in the rooms, the blanket, down to the door
	steps.append(["walk", [[4.8, 1.9], [5.0, 1.9], [5.5, 2.4], [5.5, 5.75], [5.5, 6.0]]])
	steps.append(["walk", [[5.2, 6.0], [4.8, 5.6], [4.8, 4.4], [4.1, 3.7], [3.2, 3.7], [2.6, 3.1]]]); steps.append(["item", "bag_m"])
	steps.append(["walk", [[2.3, 3.1], [2.1, 2.9], [1.4, 2.9], [1.2, 2.7]]]); steps.append(["item", "blanket"])
	steps.append(["walk", [[1.2, 1.6], [1.3, 1.5]]]); steps.append(["item", "hoodie"])
	steps.append(["walk", [[2.5, 1.5], [3.5, 0.5]]]); steps.append(["item", "bag_n"])
	steps.append(["walk", [[3.1, 0.9], [2.6, 0.9], [2.2, 1.3], [1.7, 1.3], [1.5, 1.5]]]); steps.append(["item", "window"])
	steps.append(["walk", [[1.5, 1.7], [3.1, 3.3], [3.7, 3.3], [4.3, 3.9], [4.3, 6.7], [4.2, 6.8], [3.8, 6.8], [3.7, 6.6], [2.8, 5.7], [2.1, 5.7], [1.8, 6.0]]]); steps.append(["item", "food"])
	steps.append(["walk", [[1.6, 5.7]]]); steps.append(["item", "shiori"])
	steps.append(["walk", [[2.3, 5.7], [2.6, 5.4]]]); steps.append(["item", "case"]); steps.append(["item", "torch"]); steps.append(["item", "makeup"])
	steps.append(["walk", [[2.9, 5.9], [3.8, 6.8], [4.2, 6.8], [4.3, 6.7], [4.3, 3.1], [5.1, 2.3], [5.4, 2.3], [5.9, 1.8], [6.5, 1.8], [7.1, 1.2], [6.9, 0.9], [6.6, 0.7]]]); steps.append(["item", "sweets"])
	steps.append(["walk", [[7.1, 1.1], [7.1, 1.6], [9.1, 3.6], [9.2, 3.6]]]); steps.append(["item", "reflector"])
	steps.append(["walk", [[8.2, 3.6], [7.7, 3.1], [7.4, 3.1], [6.1, 1.8], [5.6, 1.8], [4.8, 2.6], [4.8, 5.9], [5.8, 6.9], [7.2, 6.9], [7.9, 6.2], [9.2, 6.2]]]); steps.append(["item", "bath"])
	steps.append(["walk", [[6.9, 6.2], [6.2, 6.9], [5.7, 6.8], [5.7, 6.2], [5.5, 6.0], [5.5, 5.6], [5.5, 2.4], [5.0, 1.9], [4.8, 1.6], [5.0, 1.3]]])
	steps.append(["aim", gp(FRONT_DOOR[0], FRONT_DOOR[1], 0.6)]); steps.append(["press"])
	# 一時から: turn to each sound as it comes, and press
	steps.append(["wait_stage", "flow"])
	for k in ["door", "gen", "car", "cellar"]: steps.append(["hear", k])
	steps.append(["wait_card", "watch15"]); steps.append(["hear", "cough"]); steps.append(["hear", "steps"])
	steps.append(["wait_stage", "t2walk"]); steps.append(["wait_free"]); steps.append(["walk", [[4.8, 1.9], [4.7, 3.3]]])
	steps.append(["wait_stage", "lock"]); steps.append(["wait_free"]); steps.append(["walk", [[4.8, 1.9], [5.0, 1.3]]])
	steps.append(["aim", gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2])]); steps.append(["press"])
	steps.append(["wait_stage", "flow"]); steps.append(["hear", "knock"])
	steps.append(["wait_card", "t3"]); steps.append(["hear", "back"])
	return steps

func _demo_tick(dt):
	if demo_steps.is_empty():
		demo_steps = _demo_script(); ds = 0
		var mark: Array = {"seal": ["wait_stage", "seal"], "up": ["wait_stage", "up"], "watch": ["wait_stage", "flow"], "t2": ["wait_stage", "t2walk"]}.get(start_at, [])
		if not mark.is_empty():
			while ds < demo_steps.size() and not (demo_steps[ds][0] == mark[0] and demo_steps[ds][1] == mark[1]): ds += 1
	if ds >= demo_steps.size() or card_t > 0.0: return
	var s: Array = demo_steps[ds]
	dwait += dt
	var done := false
	match String(s[0]):
		"wait_stage":
			done = stage == s[1] or (s[1] == "flow" and stage == "flow")
			if dwait > 400.0: _dfail("never reached stage %s (at %s)" % [s[1], stage]); done = true
		"wait_card":
			done = card_next == s[1] and card_t <= 0.0 and stage in ["flow", "t2"] and t_stage > 1.0
			if dwait > 300.0: _dfail("never reached %s" % s[1]); done = true
		"wait_free":
			done = mode == FREE and dwait > 0.5
			if dwait > 120.0: _dfail("the talk did not end"); done = true
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
				# on the stair's ramp she is slower than the path's clock: the path holds its last point, give her time
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
			if mode == FREE: _press(); done = true
		"press_if":
			if mode == FREE:
				if stage == s[1]: _press()
				if stage == s[1]: _dfail("pressed, still at %s (no camera in reach?)" % stage)
				done = true
		"gap":
			var gq: Dictionary = {}
			for x in gaps: if x.key == s[1]: gq = x
			if s.size() < 3: s.append(0)
			var cam2: Camera3D = player.get_node("Head/Camera")
			var to2: Vector3 = (gq.at as Vector3) - cam2.global_position
			var k2 := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to2.x, -to2.z), k2)
			player.pitch = lerpf(player.pitch, asin(clampf(to2.normalized().y, -1.0, 1.0)), k2)
			if dwait > 1.2 and mode == FREE and not gq.sealed: _press()
			if gq.sealed and mode == FREE: done = true
			if dwait > 25.0: _dfail("gap %s: cannot seal (Mio %s, candle %s)" % [s[1], _plan_of(player), _plan_of(candle) if candle else []]); _seal(gq); sealed_n += 1; done = true
		"open":
			if dn: dn.open_key(s[1])
			done = true
		"item":
			var it: Dictionary = up_items[s[1]]
			var cam3: Camera3D = player.get_node("Head/Camera")
			var to3: Vector3 = (it.pos as Vector3) - cam3.global_position
			var k3 := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to3.x, -to3.z), k3)
			player.pitch = lerpf(player.pitch, asin(clampf(to3.normalized().y, -1.0, 1.0)), k3)
			if dwait > 1.0 and look_at_k == s[1]:
				_press_up(); done = true
			elif dwait > 5.0: _dfail("item %s: cannot look at it from %s (%.1f m)" % [s[1], _plan_of(player), to3.length()]); done = true
		"hear":
			if s.size() < 3: s.append(0.0)
			if not s_heard.has(s[1]) and not (s[1] in ["door", "gen"]):
				s[2] = float(s[2]) + dt; dwait = 0.0   # the time to turn counts from the sound
				if float(s[2]) > 200.0: _dfail("never s_heard %s" % s[1]); done = true
			else:
				var q: Array = SOUNDS[s[1]][0]
				var cam4: Camera3D = player.get_node("Head/Camera")
				var to4: Vector3 = gp(q[0], q[1], q[2]) - cam4.global_position
				var k4 := 1.0 - exp(-dt * 5.0)
				player.yaw = lerp_angle(player.yaw, atan2(-to4.x, -to4.z), k4)
				player.pitch = lerpf(player.pitch, asin(clampf(to4.normalized().y, -1.0, 1.0)), k4)
				if look_at_k == s[1] and mode == FREE: _press_watch(); done = true
				elif dwait > 30.0: _dfail("cannot turn to %s" % s[1]); done = true
	if done: ds += 1; dwait = 0.0

func _dfail(what: String):
	DEMO_FAILS += 1
	print("DEMO FAIL ch3: %s t=%.1f" % [what, t_now])

# --ch3map: where a body fits, floor by floor (to lay the playthrough's routes): '#' blocked, '.' free
func _map():
	for k in ["mio", "natsuki", "kiryu", "taiga", "makoto", "yota"]: _hide(k)   # the house only, not the people in it
	for i in 120: await get_tree().physics_frame
	if dn:
		for d in dn.doors: print("MAPDOOR %s open=%s locked=%s rot=%.2f" % [dn.doors[d].key, dn.doors[d].is_open, dn.doors[d].locked, (dn.doors[d].pivot as Node3D).rotation.y])
	var sp: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var sh := CapsuleShape3D.new(); sh.radius = 0.18; sh.height = 1.2
	var q := PhysicsShapeQueryParameters3D.new(); q.shape = sh; q.exclude = [player.get_rid()]
	for pq in [[5.95, 6.4], [5.9, 6.2], [6.05, 6.5], [3.3, 2.5], [3.0, 0.3]]:
		q.transform = Transform3D(Basis.IDENTITY, gp(pq[0], pq[1], 0.85))
		var hits := sp.intersect_shape(q, 4)
		print("MAPHIT %s %s" % [pq, ", ".join(hits.map(func(h): return "%s<%s>" % [str(h.collider.name), str(h.collider.get_parent().name) if h.collider.get_parent() else ""]))])
	for fl in [[0.0, "1F"], [F2, "2F"]]:
		print("MAP ", fl[1], "  x -0.4..10.4 step 0.1 →, y 8..-0.6 ↓")
		var y := 8.0
		while y >= -0.6:
			var row := ""
			var x := -0.4
			while x <= 10.4:
				q.transform = Transform3D(Basis.IDENTITY, gp(x, y, fl[0] + 0.85))
				row += "#" if not sp.intersect_shape(q, 1).is_empty() else "."
				x += 0.1
			print("MAP %5.2f %s" % [y, row])
			y -= 0.1
	get_tree().quit()
