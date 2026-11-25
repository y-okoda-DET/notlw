## ステップ F：第3章「隔離」 0時〜3時半の前（docs/資料/第3章の設計_2026-11-16.md）。台詞は story/ch3.txt。
## 家まるごとの23時の光（発電機の電球、ランタン、ろうそく、板の窓）で動く。main.gd が play="ch3" で作り、終わると第4章へ。
##
## 零時：地下から上がってきた大河。真琴が傷を素手で押さえる。桐生「四時間か」。言えたはずの一言の所は（沈黙）。大河は自分で
##   地下へ下り、閂をかける。澪は手すりの定点のカメラのテープを替える。
## 零時半：目張り。隙間ごとに風の音がその場所から鳴り、真琴のろうそくの炎がそちらへ傾く。Ｅでテープ。5か所。玄関の下は貼れない。
## 一時：区切り（2026-11-18 レビュー5）。時計は止まり、家を歩ける。台所の真琴、地下の扉越しの大河、二階の桐生と一度ずつ話せる。
##   二階へ毛布を取りに。寝室3つと洗面所の物を調べられる（澪の証言が出る）。毛布を持って玄関で「座る」と一時半へ。
## 一時半〜三時：扉の番。玄関の上がり框に毛布で座ったまま、見る・聞くだけ。音のするほうを見て Ｅ で証言の文。
##   二時、桐生が下りてきてカメラを外し、「俺でもだ」と出ていく。鍵を閉めるのはプレイヤー。二時半、ノックと欠けた声。三時、裏で何かが鳴る。
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")

const F2 := 2.75                       # the upstairs floor (house4: H1 2.45 + .3)
const ZBASE := -2.45                   # the cellar's floor
# where they stand at midnight (plan metres), and whom they face
const AT0 := {"taiga": [5.2, 5.7], "makoto": [4.6, 5.15], "kiryu": [4.4, 6.5]}   # 2026-11-17 夜（ユーザー「大河の姿を見せたい。真琴と向かい合う感じで」）: he was in the cellar doorway, out of sight; now a step out of it, Makoto before him
# 試作278（ユーザー点検2「零時・23時・3時半の構図を、一点透視の廊下から外す」2026-11-23）: she stood in the hall's middle
# (4.55, 4.25) and looked up it: the walls ran to a point behind Taiga. Now at the west wall, a step from Makoto, turned to
# the cellar doorway at 45°: the doorway and the two in it side on, the hall only a sliver at the right
const MIO0 := [4.4, 4.75]
var face_lights := []
const MIO0_LOOK := [4.95, 5.6]
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
	# 試作232（ユーザー「調べられるようにしたい」「人が住んでいる感」。台詞は筋のスレッドと合わせた 2026-11-20）
	["mark", "", [6.02, 2.93, F2 + 1.51], "壁の跡", "二階.四角い跡"],
	["note_n", "", [2.51, 0.88, F2 + 0.02], "ノート", "二階.撮影ノート"],
	["book_m", "", [7.11, 1.04, F2 + 0.05], "本", "二階.看護の教科書"],
	["tapes_k", "", [3.11, 4.51, F2 + 0.06], "テープ", "二階.映画"],
	["batt_t", "", [1.55, 6.38, F2 + 0.04], "電池", "二階.備え"],
	["photo", "", [4.03, 5.275, 1.54], "写真", "廊下.写真"],
]
# 試作232: in 零時半 (the tape round with Makoto) the hall's photograph, and a word with Makoto, once each
const HALL_PHOTO := [4.03, 5.275, 1.54]
var photo_said := false
var mk_seal_said := false
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
# 2026-11-20 練り直し（docs/資料/台本下書き_2026-11-20/ch3.txt）
var nail_lb: Label             # 0時: the line she can say in the silence
var cel_segs: Array = []       # 2時: at the barred door, [prompt, entries] in turn
var cel_i := 0
var barred: Dictionary = {}    # the barred door (out of doors.gd while she is at it: E is the story's here)
var grab_arms: Array = []
var ask_on := false            # 2時半: the questions through the door
var ask_left: Array = []       # indices into 【二時半.問い】's choose
var ask_sel := 0
var ask_q: Array = []          # what is said for the one asked (the flow waits)
var ask_hold := 0.0
var rule_on := false
var door_pos3 := "sit"         # sit | near | ear
var pos_tw: Tween
var rec230 := {}               # door_0230: the record 第8章 and 第11章 give back
var last_ask_t := 8.0
var doze_rect: ColorRect
var mirror_done := false

func _ready():
	player = main.player
	if not ("--keepflags" in OS.get_cmdline_user_args()):
		for fk in ["said_nail", "said_rule", "lean", "leaned", "door_0230", "talked_kiryu_1am", "talked_makoto_1am", "stay_watch", "stay_knock", "stay_air", "asked1_0", "asked1_1", "asked1_2", "asked1_3"]: if get_flag(fk, null) != null: set_flag(fk, null)   # 2026-11-21 (review): this chapter played again keeps none of its last run
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = ["ラジオ", "大河"]   # 大河's lines from behind the cellar door keep his name (the midnight ones are said in the hall: the rule shows it once)
	_load_file("ch3")
	T1_TALK = {}
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
		if a.begins_with("--ch3pose="): pose_dbg = Array(a.substr(10).split(",")).map(func(x): return float(x))   # check stills: upstairs, she stands here (plan x, y, yaw°)
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

# 試作282（ユーザー「桐生がパッと消えた」「真琴がパッと出る」）: a person put away at the end of a walk goes only when she
# cannot see them: in her frame (and not behind her), they wait there till she looks away
func _seen(k: String) -> bool:
	var r := _rig(k)
	if r == null or not r.visible: return false
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null: return false
	for h in [0.3, 1.0, 1.6]:
		var p: Vector3 = r.global_position + Vector3(0, h, 0)
		if cam.is_position_in_frustum(p) and cam.global_position.distance_to(p) < 14.0: return true
	return false

func _hide_unseen(k: String, then := Callable()):
	if not _seen(k) or card_t > 0.0:
		_hide(k)
		if then.is_valid(): then.call()
		return
	get_tree().create_timer(0.3).timeout.connect(_hide_unseen.bind(k, then))

func _plan_of(n: Node3D) -> Array:
	return [n.global_position.x + 4.8, n.global_position.z + 6.3]

func _look_from(a: Array, b: Array, eye := 1.52, bz := 1.3):
	var to: Vector3 = gp(b[0], b[1], bz) - (gp(a[0], a[1], 0.0) + Vector3(0, eye, 0))
	player.yaw = atan2(-to.x, -to.z); player.pitch = asin(clampf(to.normalized().y, -1.0, 1.0))

func _stand(eye: float):
	player.eye_height = eye; player.get_node("Head").position.y = eye

# 2026-11-17 夜（ユーザー「ここ、立ち上がるアクション入れよう」）: from the floor to her feet: the head goes forward over
# the knees first, then up (a hand on the wall), the blanket's sound; she can walk once she is up
func _stand_up():
	var e0: float = player.eye_height
	var p0: float = player.pitch
	player.move_enabled = false
	Sound.one(self, "ch3_blanket", -16.0, player.global_position)
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var lean := sin(k * PI)                                   # forward, then back upright
		_stand(lerpf(e0, STAND_EYE, smoothstep(0.15, 1.0, k)) - 0.08 * lean)
		player.pitch = p0 - deg_to_rad(16.0) * lean
		player.get_node("Head").position.z = -0.12 * lean, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): player.get_node("Head").position.z = 0.0; player.move_enabled = true)

func _place_for(st: String):
	match st:
		"t0", "tape":
			for k in AT0:
				var to: Array = MIO0
				# 試作278（独立レビュー「大河の顔は暗い塊」）: he faced Makoto square, his face away from Mio and from Kiryu's
				# light; half toward the hall (Mio, the light), he still talks to Makoto
				if k == "taiga": to = [(AT0.makoto[0] + MIO0[0]) * 0.5, (AT0.makoto[1] + MIO0[1]) * 0.5]
				elif k == "makoto": to = AT0.taiga
				_put(k, AT0[k], _face(AT0[k], to))
				main.set_stand(k, "talk/idle" if k != "makoto" else "talk/think", 0.0)
			player.global_position = gp(MIO0[0], MIO0[1], 0.0); _look_from(MIO0, MIO0_LOOK)
			# 点検3: Kiryu holds his phone's light up to the bite (their own phones are in their pockets at 0時: a light from
			# them lit nothing, snap 試作278); it falls on Taiga's face and on Makoto's at his arm. Gone at 零時半 (the candle)
			if face_lights.is_empty():
				main.phones(true, ["kiryu"])
				for k in [["taiga", 1.4], ["makoto", 0.7]]:
					var fl = _face_light(k[0], k[1], "kiryu")
					if fl: face_lights.append(fl)
		"seal":
			for fl in face_lights:
				if is_instance_valid(fl): fl.queue_free()
			face_lights.clear()
			main.phones(false, ["kiryu"])
			_hide("taiga"); _put("kiryu", [1.6, 1.2], _face([1.6, 1.2], [1.9, 1.85]))   # in the living room by the lantern
			main.set_stand("kiryu", "talk/sit_b", 0.0)
			_put("makoto", [4.75, 6.1], _face([4.75, 6.1], [4.6, 5.0])); main.set_stand("makoto", "talk/idle", 0.0)
			player.global_position = gp(4.6, 5.1, 0.0); _look_from([4.6, 5.1], [4.75, 6.1])
		"up":
			sealed_n = 5
			for gq in gaps: _seal(gq, true)
			_place_one()
			player.global_position = gp(4.75, 1.9, 0.0); _look_from([4.75, 1.9], [5.5, 3.5])
		"watch", "t2", "t230", "t3":
			_hide("taiga"); _hide("makoto")
			_put("kiryu", [1.6, 1.2], 0.0); main.set_stand("kiryu", "talk/sit_b", 0.0)
			if st != "t2": _hide("kiryu")
			sealed_n = 5; has_blanket = true
			for gq in gaps: _seal(gq, true)
			_sit()

# 一時 (2026-11-18 レビュー5): where they are while the clock stands: Makoto in the kitchen with the candle, Kiryu on the
# landing upstairs taping its window, Taiga behind the barred door (a voice only)
const KR_HALL := [4.35, 3.7]           # 試作176 A14: Kiryu in the hall at 0:30, a step off Mio (4.6, 5.1), before he goes up
const MK_ONE := [6.9, 6.2]
const KR_ONE := [4.9, 7.5]
const CELLAR_DOOR := [5.5, 5.62]
func _place_one():
	_hide("taiga")
	_put("makoto", MK_ONE, _face(MK_ONE, [5.7, 6.2])); main.set_stand("makoto", "talk/idle", 0.0)
	mk_at = "one"; mk_going = ""
	_put("kiryu", KR_ONE, _face(KR_ONE, [4.9, 8.0]), F2); main.set_stand("kiryu", "talk/idle", 0.0)

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
# 2026-11-17 夜（ユーザー「ロウソク、持っているように見せたい」）: both her hands go to it (reach.gd): the right under the
# saucer, the left cupped beside the flame's side
var candle_hands := []
func _candle_tick(dt: float):
	for rc in candle_hands: rc.w = move_toward(rc.w, 1.0 if (candle and candle.visible) else 0.0, dt * 3.0)
	if candle == null or not candle.visible: return
	var r := _rig("makoto")
	candle.global_position = r.global_transform * Vector3(0.0, 1.0, 0.30)
	if candle_hands.is_empty() and main.S.has("makoto_node"):
		var sk: Skeleton3D = main.S.makoto_node.find_children("*", "Skeleton3D", true, false)[0]
		for sd in ["r", "l"]:
			var rc: Node = load("res://scripts/reach.gd").new()
			rc.side = sd; rc.target_node = candle
			rc.offset = Vector3.ZERO
			sk.add_child(rc); candle_hands.append(rc)
	if candle_hands.size() == 2:
		var b := r.global_basis
		candle_hands[0].offset = b * Vector3(-0.03, -0.03, -0.06)   # right: under the saucer, the near side
		candle_hands[1].offset = b * Vector3(0.06, 0.03, -0.02)     # left: cupped at its side
		candle_hands[0].pole = b * Vector3(-1.0, -1.0, -0.3); candle_hands[1].pole = b * Vector3(1.0, -1.0, -0.3)
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
	var hm: Array = {"零時": [0, 0], "零時半": [0, 30], "一時": [1, 0], "一時半": [1, 30], "二時": [2, 0], "二時半": [2, 30], "三時": [3, 0]}.get(text.strip_edges(), [])
	if not hm.is_empty(): main.clock_at(hm[0], hm[1])   # the kitchen clock (main.gd _clock_tick)
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
		"swap": _swap_tick(dt)
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
		"watch", "watch15":   # (--ch3at=watch starts here, sat)
			_hide("makoto"); _hide("kiryu"); candle.visible = false
			_flow_start("扉の番.一時半", "t2card")
		"t2":
			# 試作127（B7、ユーザー「ここ、立ち上がった方がいいかな」）: she gets up, the blanket on her shoulders, to see the
			# cellar door; Kiryu comes down the stair as she goes
			stage = "t2walk"; kiryu_sent = true   # (2026-11-20: he comes only when she pushes the barred door)
			_stand_up(); _blanket_view(true, false)
			_cellar_ready()
			_start(B("二時.地下へ"))
		"t230":
			_sit()
			_t230_start()
			_flow_start("扉の番.二時半", "t3card")
		"t3":
			# 2026-11-21 (review): a lean held over the card stayed: she is back on the step, her head upright
			if door_pos3 != "sit" and door_pos3 != "": _door_to("sit")
			player.get_node("Head").rotation.z = 0.0
			_flow_start("扉の番.三時", "end")
		"end":
			_end()

# ---------------------------------------------------------------- 零時
func _do(what: String):
	if _flag_do(what): return   # 2026-11-20 the night's record (story.gd FLAG_DOS)
	print("STORY ch3 do %s t=%.1f" % [what, t_now])
	match what:
		"taiga_arm":
			talk_with = "makoto"
		"makoto_press":
			# 試作127（ユーザー「カメラ位置のせいで、真琴が何をやっているかわからない」）: she stood between Mio and Taiga, her
			# back to Mio. She goes round to his west side: from Mio's place she is seen side on, her hands on his arm
			main.walk_to("makoto", [[4.66, 5.55, 0.0], [4.72, 5.82, 0.0]], _pulse_on, _face([4.72, 5.82], AT0.taiga))   # (2026-11-17 夜: his new place, a step out of the cellar door)
		"makoto_wipe":
			_pulse_off()
			main.set_stand("makoto", "talk/think"); _vary("makoto", "talk/think", "talk/idle")
		"taiga_down":
			talk_with = ""
			if dn: dn.open_key("door_cellar"); dn.open_key("door_barred")
			main.walk_to("taiga", TAIGA_DOWN, func():
				_hide("taiga")
				_bar_shut())
		"cam_stop":   # 2026-11-18 the tape ran out: the clunk on the rail and the red lamp out (第6章 opens on the same sound)
			Sound.one(self, "tape_clunk", -4.0, fixed_cam.global_position if fixed_cam else player.global_position)
			_rec3(false)
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
			get_tree().create_timer(1.2).timeout.connect(func(): _place_one(); _card(D.lines("一時.カード")[0], "up"))
		"cellar_voice":
			Sound.one(self, "ch3_murmur", -10.0, gp(5.5, 5.4, -0.6)); _hear("cellar")
		"silence":
			_silence_open()
		"silence_nail":   # 2026-11-20 12時31分④: the silence, and the one line she could say in it (E)
			_silence_open(); silence_len = 12.0
			var nr = _line_row("", String(D.lines("零時.釘")[0]), SAY_SIZE, "choose")
			nail_lb = nr[1]; cur["nail"] = true
			for c in lines_box.get_children(): (c as Control).modulate.a = 1.0
			foot_was = main.foot.text if main.foot else ""
			_foot("マウス 見る　Ｅ 言う")
		"cellar_knob":
			_cellar_jolt()
		"kiryu_grab":
			_kiryu_grab()
		"mirror_pass":
			pass
		"to_hall":   # 2026-11-20: up from the cellar stair; the talk in the hall (第8章 films it there), he by the tripod with the camera
			_shade().color.a = 1.0
			create_tween().tween_property(_shade(), "color:a", 0.0, 0.9).set_delay(0.25)
			for a in grab_arms: (a as Node3D).visible = false
			player.global_position = gp(MIO_WAIT[0], MIO_WAIT[1], 0.0); player.velocity = Vector3.ZERO
			player.get_node("Head").rotation.z = 0.0
			_look_from(MIO_WAIT, TAKE_AT, STAND_EYE, 1.45)
			_put("kiryu", TAKE_AT, _face(TAKE_AT, MIO_WAIT)); main.set_stand("kiryu", "talk/idle", 0.0)
		"shake":
			var y0: float = player.yaw
			var tw := create_tween()
			for i in 2:
				tw.tween_property(player, "yaw", y0 + 0.07, 0.16).set_trans(Tween.TRANS_SINE)
				tw.tween_property(player, "yaw", y0 - 0.07, 0.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(player, "yaw", y0, 0.16)
		"kiryu_come":   # 試作176 A14: from the lantern into the hall, where Mio will see him when he speaks
			main.walk_to("kiryu", [[1.6, 0.95, 0.0], [2.7, 0.95, 0.0], [2.7, 2.8, 0.0], [3.6, 3.7, 0.0], [KR_HALL[0], KR_HALL[1], 0.0]], Callable(), _face(KR_HALL, [4.6, 5.1]))
		"kiryu_look":   # she turns to him (he is there, or nearly: the talk before took longer than his walk)
			talk_with = "kiryu"
			var kr := _rig("kiryu")
			if kr:
				var to: Vector3 = (kr.global_position + Vector3(0, 1.45, 0)) - player.get_node("Head/Camera").global_position
				var tw := create_tween(); tw.set_parallel(true)
				tw.tween_property(player, "yaw", player.yaw + wrapf(atan2(-to.x, -to.z) - player.yaw, -PI, PI), 0.9).set_trans(Tween.TRANS_SINE)
				tw.tween_property(player, "pitch", asin(clampf(to.normalized().y, -1.0, 1.0)), 0.9).set_trans(Tween.TRANS_SINE)
		"kiryu_up":   # 試作127 B5「2階は桐生がやっておく」: from the hall up the stair, a roll of tape in his hand
			talk_with = ""
			main.walk_to("kiryu", [[4.3, 3.6, 0.0], [4.8, 2.9, 0.0], [5.5, 2.45, 0.0], [5.5, 5.7, F2], [5.0, 6.3, F2], [5.0, 7.3, F2]], func(): _hide_unseen("kiryu"))
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
		if demo3 and cur.has("nail") and "--ch3nail" in OS.get_cmdline_user_args() and silence_t > 3.0: _say_nail(); return
		if silence_t >= silence_len:
			silence_t = -1.0
			if cur.has("nail"): _strike_nail()
			_next()
		return
	if demo3 and cur.has("choose") and not cur.get("chosen", false):
		read_t += dt
		if read_t > 2.0: read_t = 0.0; choice_idx = 0; _show_choice(); _choose()
		return
	super._talk_tick(dt)

func _advance():
	if cur.has("silence"):
		if cur.has("nail") and silence_t >= 0.0: _say_nail()
		return   # the silence is not hers to cut short (but the line she could say, she can)
	super._advance()

var foot_was := ""
func _foot_back():
	if main.foot: (main.foot as Label).text = foot_was

func _foot(t: String):
	var f: Label = main.foot
	if f: f.text = T(t + "　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")

# 0時: she says it. The silence ends; the "next" it held goes; the lines of 【零時.釘】 come in its place
func _say_nail():
	silence_t = -1.0
	if not script_q.is_empty() and script_q[0].get("do", "") == "next": script_q.pop_front()
	var q: Array = D.entries("零時.釘"); q.remove_at(0)   # (the first is the line as she could say it)
	for i in range(q.size() - 1, -1, -1): script_q.push_front(q[i])
	# 試作281（ユーザー「このあと「釘で切ったの、見てた～～」がダブる」）: the line she could say stays, as said, where it stood;
	# the silence goes from under it, and the script no longer has her say it a second time
	if is_instance_valid(silence_lb) and silence_lb.get_parent(): silence_lb.get_parent().queue_free()
	nail_lb = null
	cur = {}; _foot_back()
	print("STORY ch3 said_nail t=%.1f" % t_now)
	_next()

# 試作281（ユーザー「ここ、脈取っているように見せたい」）: she takes his wrist, the one on her side: her left hand under it,
# two fingers of her right on the inside of it, a little above the hand (reach.gd, both arms)
var pulse_rc := []
func _pulse_on():
	if not main.S.has("taiga_node") or not main.S.has("makoto_node"): return
	var tsk: Skeleton3D = (main.S.taiga_node as Node).find_children("*", "Skeleton3D", true, false)[0]
	var mk: Node3D = main._rig_of("makoto")
	var best := "hand_l"; var bd := 1e9
	for b in ["hand_l", "hand_r"]:
		var bi := tsk.find_bone(b)
		if bi < 0: continue
		var d := (tsk.global_transform * tsk.get_bone_global_pose(bi).origin).distance_to(mk.global_position)
		if d < bd: bd = d; best = b
	# 試作281（レビュー「手首を取っていない」）: his wrist hung at his hip, and her hands stopped short of it. He holds the cut
	# arm out a little, at her chest's height between them, and she takes it there
	var trig: Node3D = main._rig_of("taiga")
	var mid: Vector3 = trig.global_position.lerp(mk.global_position, 0.45) + Vector3.UP * 1.05
	var hold = _reach("taiga", null, mid); hold.side = best.substr(5, 1)
	create_tween().tween_property(hold, "w", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	var ba := BoneAttachment3D.new(); ba.bone_name = best; tsk.add_child(ba)
	var under := Node3D.new(); ba.add_child(under); under.position = Vector3(0, -0.02, 0)
	var fingers := Node3D.new(); ba.add_child(fingers); fingers.position = Vector3(0, -0.05, 0.0)
	pulse_rc = [ba, hold]
	# 試作282（ユーザー「真琴の腕が大河の手をすり抜ける」）: reach.gd puts her wrist on the point, so her hand went on past it,
	# into his. Her wrists stop a hand's length short of his wrist, on her side of it: the left a little under, the right over
	var back: Vector3 = (mk.global_position + Vector3.UP * 1.3) - mid; back.y = 0.0; back = back.normalized()
	for pr in [["l", under, back * 0.13 - Vector3.UP * 0.05], ["r", fingers, back * 0.11 + Vector3.UP * 0.035]]:
		var rc = _reach("makoto", pr[1], mk.global_position + Vector3.UP)
		rc.side = pr[0]; rc.offset = pr[2]
		pulse_rc.append(rc)
		create_tween().tween_property(rc, "w", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _pulse_off():
	for n in pulse_rc:
		if not is_instance_valid(n): continue
		if n is BoneAttachment3D: get_tree().create_timer(0.7).timeout.connect(n.queue_free)
		else:
			var tw := create_tween(); tw.tween_property(n, "w", 0.0, 0.5); tw.tween_callback(n.queue_free)
	pulse_rc = []

# not said: the transcriber's double line through it, as through the choices not taken
func _strike_nail():
	_foot_back()
	if not is_instance_valid(nail_lb): return
	var st := Strike.new(); st.u = u
	st.w = font.get_string_size(nail_lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(SAY_SIZE * u)).x
	st.size = nail_lb.size; st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nail_lb.add_child(st)
	nail_lb.add_theme_color_override("font_color", Color(paper.r, paper.g, paper.b, 0.38))

# ---------------------------------------------------------------- the tape in the small camera
func _cam_near() -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := fixed_cam.global_position - cam.global_position
	return _aim_ok(to, 1.9, 24.0)   # 試作281: 1.7 m and 18° were narrow (story.gd _aim_ok)

func _tape_tick():
	if mode != FREE: return
	note_lb.text = T(String(D.lines("零時.テープ")[0])) if _cam_near() else ""

# 手の遊び④（決定事項 2026-11-23 7時33分）：定点のカメラのテープ替え＝手順。暗がりで、手が震える。
# 一、横のふたを押す（ふたが開いて、古いテープが少し出る）。二、古いテープを抜く。三、新しいテープを差す。四、裏の録画を押す。
# 三と四は、ふたの口・ボタンを見て Ｅ。外れると、テープがカメラに当たって鳴り、手の震えが少し増える。ゲージも文字も出さない。
var swap := {}
func _swap_tape():
	note_lb.text = ""
	var cam: Camera3D = player.get_node("Head/Camera")
	var sx := 1.0 if (fixed_cam.global_basis.x).dot(cam.global_position - fixed_cam.global_position) > 0.0 else -1.0
	swap = {"step": 0, "sx": sx, "shake": 1.0, "t": 0.0, "hand": null, "old": null, "cool": 0.0}
	stage = "swap"
	_swap_do()   # 一（ふた）は、カメラを見て押した Ｅ で開く

func _swap_point(step: int) -> Vector3:
	var lp := Vector3(0.03 * float(swap.sx), 0.0, 0.0) if step == 2 else Vector3(0.012, 0.046, 0.067)
	return fixed_cam.global_transform * lp

func _swap_aimed(step: int) -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := _swap_point(step) - cam.global_position
	var f := -cam.global_basis.z
	var off := (to - f * to.dot(f)).length()   # how far the point sits from the line of sight
	return to.dot(f) > 0.0 and off < 0.06   # 試作281（ユーザー「どうしたらいいかわからず混乱した」）: .035 was a pinpoint

func _cassette() -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.062, 0.012, 0.047); mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.08, 0.08, 0.085); m.roughness = 0.4; mi.material_override = m
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mi

func _swap_press():
	if float(swap.cool) > 0.0: return
	var st := int(swap.step)
	if st >= 2 and not _swap_aimed(st):
		# off the slot / the button: the tape knocks the camera, the hand shakes more
		swap.shake = minf(1.8, float(swap.shake) + 0.25); swap.cool = 0.5
		Sound.one(self, "tripod_bump", -16.0, fixed_cam.global_position)
		if swap.hand: (swap.hand as Node3D).position.x += randf_range(-0.01, 0.01)
		print("STORY ch3 swap miss step %d" % st)
		return
	_swap_do()

func _swap_do():
	var st := int(swap.step)
	var cam: Camera3D = player.get_node("Head/Camera")
	swap.cool = 0.6
	match st:
		0:   # the lid: it springs, the old tape shows
			Sound.one(self, "tape_clunk", -8.0, fixed_cam.global_position)
			var o := _cassette(); fixed_cam.add_child(o); o.position = Vector3(0.018 * float(swap.sx), 0.0, 0.0); o.rotation.z = PI / 2.0
			create_tween().tween_property(o, "position:x", 0.04 * float(swap.sx), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			swap.old = o
		1:   # the old one out, into her pocket (it holds 0時 and before)
			var o: Node3D = swap.old
			if o: create_tween().tween_property(o, "position:x", 0.12 * float(swap.sx), 0.3).finished.connect(o.queue_free)
			Sound.one(self, "cassette_in", -16.0, fixed_cam.global_position)
			var h := _cassette(); cam.add_child(h); h.position = Vector3(0.06, -0.11, -0.3); h.rotation = Vector3(0.3, 0.2, PI / 2.0)
			swap.hand = h
		2:   # the new one in
			var h: Node3D = swap.hand
			if h: h.queue_free(); swap.hand = null
			Sound.one(self, "cassette_in", -6.0, fixed_cam.global_position)   # 試作127: the cassette in (soundreality tape-cassette-insert)
		3:   # the button on the back: it records again
			Sound.one(self, "tape_clunk", -12.0, fixed_cam.global_position)
			_rec3(false)   # already out since cam_stop (the tape ran out); on again once the button is in
			get_tree().create_timer(0.5).timeout.connect(func(): _rec3(true))
			cam.rotation = Vector3.ZERO
			note_lb.text = ""
			swap = {}
			stage = "tape_done"
			_start(B("零時.替えた"))
			return
	swap.step = st + 1

func _swap_tick(dt: float):
	if swap.is_empty(): return
	swap.t = float(swap.t) + dt
	swap.cool = maxf(0.0, float(swap.cool) - dt)
	# the hand shakes: the view with it (small, uneven; more after each miss)
	var t := float(swap.t); var a := float(swap.shake) * 0.0012   # 試作281（ユーザー「震えが極端」）: .0035 → .0012
	var cam: Camera3D = player.get_node("Head/Camera")
	cam.rotation = Vector3(a * (sin(t * 23.0) + 0.6 * sin(t * 37.0 + 1.3)), a * (sin(t * 19.0 + 0.4) + 0.5 * sin(t * 41.0)), 0.0)
	if swap.hand: (swap.hand as Node3D).position.y = -0.11 + a * 2.0 * sin(t * 29.0)
	# 試作281: what the hand does next, in the same corner as every other［Ｅ］
	var stp := int(swap.step)
	if stp == 1: note_lb.text = T("［Ｅ　古いテープを抜く］")
	elif stp == 2: note_lb.text = T("［Ｅ　新しいテープを差す］") if _swap_aimed(2) else T("（横の、ふたの口を見る）")
	elif stp == 3: note_lb.text = T("［Ｅ　録画を押す］") if _swap_aimed(3) else T("（裏の、録画のボタンを見る）")
	if demo_on and float(swap.cool) <= 0.0 and t > 0.9 * float(swap.step):
		_swap_do()   # the unattended run: each step in turn, a hand that does not miss

# ---------------------------------------------------------------- 零時半: the gaps
func _near_gap() -> Dictionary:
	var cam: Camera3D = player.get_node("Head/Camera")
	for gq in gaps:
		if gq.sealed or gq.key != _next_gap(): continue
		var to: Vector3 = (gq.at as Vector3) - cam.global_position
		if _aim_ok(to, 1.9, 32.0): return gq   # 試作281 (story.gd _aim_ok)
	return {}

func _looking_at(p: Vector3, reach: float, deg: float) -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := p - cam.global_position
	return _aim_ok(to, reach, deg)   # 試作281 (story.gd)

func _seal_tick(dt: float):
	if not trace.is_empty(): _trace_tick(dt); return
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
	elif not photo_said and _looking_at(gp(HALL_PHOTO[0], HALL_PHOTO[1], HALL_PHOTO[2]), 2.2, 16.0): note_lb.text = T("［写真］")
	elif not mk_seal_said and _mk_seal_looked(): note_lb.text = T("［真琴］")
	else: note_lb.text = ""

func _mk_seal_looked() -> bool:
	var r: Node3D = main._rig_of("makoto")
	if r == null or not r.visible or main.walking("makoto"): return false
	return _looking_at(r.global_position + Vector3(0, 1.3, 0), 2.4, 20.0)

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
	# 試作277（ユーザー「1つ目のテープを貼ったら、真琴がこちらに向かってくる。向かって左側の方の通路から」）: by the west passage
	# (x 1.0〜1.3 on the --ch3map), not up the east one where Mio stands after the first tape
	"g2": [[1.17, 1.05], [1.2, 2.6], [1.45, 2.85], [1.6, 3.4], [1.6, 4.6], [1.25, 5.1]],
	"g3": [[1.6, 5.2], [3.1, 3.7], [4.1, 3.7], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.8, 6.2], [6.5, 6.2], [6.6, 6.8]],
	"g4": [[7.4, 6.6], [7.9, 6.3], [8.95, 6.0]],
	"g5": [[8.85, 4.9]],
	# 試作176 A13（ユーザー「ここ歩くとき、真琴が三脚をすり抜けてくる」）: the genkan's tripod stands at plan (4.35, 1.6) with its legs
	# .45 out; she ended at 4.55, 1.8, in them. Now down the hall's right side to the door's side of it, .6 m off the column
	"front": [[8.2, 4.9], [6.9, 6.2], [5.7, 6.2], [5.1, 6.0], [4.8, 5.7], [4.8, 4.2], [4.3, 3.7], [4.2, 3.4], [4.3, 3.2], [4.4, 2.9], [4.8, 2.5], [4.95, 2.15]],
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
		if gq.sealed or wind_dim.has(gq.key) or gq.get("weak", false): continue
		if gq.key == k:
			p.volume_db = -6.0
			if p.stream and not p.playing: p.play(randf() * 4.0)
		else:
			p.volume_db = -60.0; p.stop()

# ---------------------------------------------------------------- 手の遊び②：0時半のテープ貼り（試作283 で遊び方から作り直し）
# 試作282（ユーザー「窓にテープを貼るあそび、まだ微妙に直ってない。視点が動いて貼れない。遊び方から考え直したほうが早いかも」）:
# 281 は澪の目のまま視点を止め、マウスを動かした量でテープを伸ばした。視点は澪の頭なので、ほかの動き（向きを合わせる動き、
# 震え、話の始まり）がそのまま画を揺らし、マウスは「見る」と「貼る」の二役で、どちらに効いているか分からなかった。
# いま：Ｅ で、隙間の寄りの画に切り替わる（澪の目ではない、据えたカメラ。マウスは何もしない）。Ｅ（か左ボタン）を押しているあいだ、
# テープが一定の速さで隙間に沿って伸び、ロールのはがれる音が続く。伸びたぶんだけ、その隙間の風の音が細くなり、真琴の炎が起き上がる。
# 離すと止まり、また押すと続きから。失敗はない（手は失敗させない、第6章と同じ）。貼り終えると「ビッ」と切る音で、澪の目に戻る。
var trace := {}
const TRACE_SECS := 1.7        # holding, one strip (the back door's long edge: twice that)
func _trace_start(gq: Dictionary):
	if not trace.is_empty(): return
	if gq.has("crumpled") and is_instance_valid(gq.crumpled): (gq.crumpled as Node).queue_free(); gq.erase("crumpled")
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	var along_x: bool = gq.n[0] == 0
	bm.size = Vector3(0.34 if along_x else 0.004, 0.05, 0.004 if along_x else 0.34); mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.8, 0.8, 0.78); m.roughness = 0.45; m.metallic = 0.1   # 試作278: lighter, it was lost on the wall
	mi.material_override = m; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi); mi.global_position = gq.at + Vector3(gq.n[0] * 0.006, 0.0, gq.n[1] * 0.006)
	if gq.key == "g5": bm.size = Vector3(0.003, 1.86, 0.065); mi.global_position = gp(9.977, 5.318, 0.97)
	mi.scale = Vector3(0.02, 1, 1) if along_x and gq.key != "g5" else (Vector3(1, 0.02, 1) if gq.key == "g5" else Vector3(1, 1, 0.02))
	trace = {"gq": gq, "mi": mi, "p": 0.0, "snd": 0.0, "hold": false, "along_x": along_x}
	player.look_enabled = false; player.move_enabled = false
	Sound.one(self, "ch3_tape", -10.0, gq.at)
	# the close shot: a set camera a little off the gap's face, slightly from above and from the side the strip starts on
	var n3 := Vector3(float(gq.n[0]), 0.0, float(gq.n[1]))
	if n3.length() < 0.1: n3 = (player.global_position - (gq.at as Vector3)) * Vector3(1, 0, 1)
	n3 = n3.normalized()
	var mid: Vector3 = mi.global_position
	var side := n3.cross(Vector3.UP).normalized()
	var dist := 1.25 if gq.key == "g5" else 0.62
	var cc := Camera3D.new(); cc.fov = 50.0; cc.near = 0.02
	add_child(cc)
	var eye: Vector3 = mid + n3 * dist + Vector3.UP * (0.0 if gq.key == "g5" else 0.16) - side * dist * 0.25
	# never below the floor (the gaps by the floor) nor inside a wall: the eye stays in the room
	eye.y = maxf(eye.y, player.global_position.y + 0.18)
	cc.look_at_from_position(eye, mid, Vector3.UP)
	cc.make_current()
	trace["cc"] = cc
	note_lb.text = T("［Ｅ（押したまま）　貼る］")

# holding E (or the left button) lays the strip at an even pace; the gap's wind thins as it goes
func _trace_tick(dt: float):
	if trace.is_empty(): return
	var held: bool = bool(trace.hold) or Input.is_key_pressed(KEY_E) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if not held: return
	var gq: Dictionary = trace.gq
	var step := dt / (TRACE_SECS * (2.0 if gq.key == "g5" else 1.0))
	trace.p = minf(1.0, float(trace.p) + step)
	trace.snd = float(trace.snd) + step
	if float(trace.snd) > 0.14:
		trace.snd = 0.0
		var pl := Sound.one(self, "ch3_tape", -15.0, gq.at)
		if pl is AudioStreamPlayer3D: (pl as AudioStreamPlayer3D).pitch_scale = randf_range(0.92, 1.12)
	var mi := trace.mi as MeshInstance3D
	var k: float = maxf(0.02, float(trace.p))
	if gq.key == "g5": mi.scale = Vector3(1, k, 1)
	elif trace.along_x: mi.scale = Vector3(k, 1, 1)
	else: mi.scale = Vector3(1, 1, k)
	var wp: AudioStreamPlayer3D = gq.player
	if wp: wp.volume_db = lerpf(-6.0, -30.0, float(trace.p))
	if float(trace.p) >= 1.0: _trace_end()

func _trace_end():
	var gq: Dictionary = trace.gq
	Sound.one(self, "ch3_tape", -6.0, gq.at)   # cut from the roll
	if trace.has("cc") and is_instance_valid(trace.cc):
		(trace.cc as Camera3D).queue_free()
	(player.get_node("Head/Camera") as Camera3D).make_current()
	player.look_enabled = true; player.move_enabled = true; note_lb.text = ""
	(trace.mi as Node).queue_free()
	trace = {}
	wind_dim[gq.key] = 0.6   # what is left of its wind fades from where the strip left it
	_seal_done(gq)

func _press_seal():
	var gq := _near_gap()
	if gq.is_empty() or not _makoto_near(gq.at): return false
	_trace_start(gq)
	return true

func _seal_done(gq: Dictionary):
	var was_weak: bool = gq.get("weak", false)
	gq.erase("weak")
	_seal(gq)
	if was_weak: wind_dim[gq.key] = 0.8   # the thin wind fades from where it was, not from full
	sealed_n += 1
	talk_with = "makoto"
	var q: Array = []
	if gq.key == "g5": q.append_array(B("目張り.勝手口"))
	else: q.append_array(B("目張り.貼った.%d" % mini(sealed_n, 4)))
	if sealed_n == 3: q.append_array(B("目張り.問い"))
	if sealed_n == 5: q.append_array(B("目張り.五つ"))
	_start(q)

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
		if not _aim_ok(to, reach, 22.0): continue   # 試作281: 16° was narrow (story.gd _aim_ok)
		var a := (-cam.global_basis.z).angle_to(to)
		if a < ba: ba = a; best = k
	return best

func _up_tick(_dt: float):
	if car_glow: car_glow.light_energy = 0.9 + 0.1 * sin(t_now * 0.7)
	_wash_mirror_tick()
	if mode != FREE: return
	var k := _item_looked()
	look_at_k = k
	var who := _one_looked()
	if who != "" and k != "blanket": look_at_k = ""; one_k = who; note_lb.text = T("［%s］" % ONE_NAME[who]); return
	one_k = ""
	if k == "blanket": note_lb.text = T(String(D.lines("二階.毛布")[0]))
	elif k != "": note_lb.text = T("［%s］" % up_items[k].name)
	elif has_blanket and _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], 0.6), 2.4, 30.0) and player.global_position.y < 0.5: note_lb.text = T(String(D.lines("二階.戻る")[0]))
	else: note_lb.text = ""

# ---------------------------------------------------------------- 2026-11-20 ジャンプスケア④：二階の洗面所の鏡
# The basin's mirror (rooms2.py wash_mirror: plan x 6.08, y 4.95..5.65, F2 + 1.05..1.75, facing east) is clouded (B3, 2026-11-17):
# it shows the room behind her as a grey haze and never her. The first time she stands at it and looks in, someone crosses
# the room behind her in the glass (Kiryu, sealing the tub's window), one board of the floor sounds; she turns and it is him.
const WASH_MIRROR := [6.085, 5.30, 1.40]   # its middle (z above F2)
const WASH_PATH := [[6.35, 7.05], [7.4, 6.2], [8.7, 5.95]]
var pose_dbg := []
var wm_vp: SubViewport
var wm_cam: Camera3D
var wm_quad: MeshInstance3D
const CLOUD_SH := """shader_type spatial;
render_mode cull_back;
uniform sampler2D refl : source_color, filter_linear;
void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec3 c = vec3(0.0);
	for (int i = -2; i <= 2; i++) for (int j = -2; j <= 2; j++) c += texture(refl, uv + vec2(float(i), float(j)) * 0.006).rgb;
	c /= 25.0;
	float edge = smoothstep(0.0, 0.25, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = vec3(0.16, 0.17, 0.17);            // the fogged glass: only as light as the room is
	ROUGHNESS = 0.6;
	EMISSION = c * 0.75 * edge;                  // what it shows, already lit by the room's own light
}"""
func _wash_mirror_make():
	wm_vp = SubViewport.new(); wm_vp.size = Vector2i(192, 192); wm_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(wm_vp)
	wm_cam = Camera3D.new(); wm_cam.near = 0.1; wm_cam.far = 12.0
	wm_cam.cull_mask = 0xFFFFF & ~128   # (Mio's own body/shadow layers are not in it: she is never in the glass)
	wm_vp.add_child(wm_cam)
	wm_quad = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.68, 0.68); wm_quad.mesh = q
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = CLOUD_SH; sm.shader = sh
	sm.set_shader_parameter("refl", wm_vp.get_texture()); wm_quad.material_override = sm
	wm_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(wm_quad)
	wm_quad.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), gp(WASH_MIRROR[0] + 0.006, WASH_MIRROR[1], F2 + WASH_MIRROR[2]))   # its face to the east (+x)

func _wash_mirror_tick():
	if not pose_dbg.is_empty() and mode == FREE:
		player.global_position = gp(pose_dbg[0], pose_dbg[1], F2); player.velocity = Vector3.ZERO
		player.yaw = deg_to_rad(pose_dbg[2]); player.pitch = deg_to_rad(-6.0)
		if mirror_done: pose_dbg = []
	var at := gp(WASH_MIRROR[0], WASH_MIRROR[1], F2 + WASH_MIRROR[2])
	var cam: Camera3D = player.get_node("Head/Camera")
	var near: bool = player.global_position.y > F2 - 0.6 and cam.global_position.distance_to(at) < 3.2
	if not near:
		if wm_vp: wm_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if wm_vp == null: _wash_mirror_make()
	wm_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var n := Vector3(1, 0, 0)
	var e := cam.global_position
	var refl := e - 2.0 * (e - at).dot(n) * n
	wm_cam.global_transform = Transform3D(Basis.looking_at((at - refl).normalized(), Vector3.UP), refl)
	wm_cam.fov = clampf(rad_to_deg(2.0 * atan(0.34 / maxf(refl.distance_to(at), 0.2))), 10.0, 90.0)
	if mirror_done or mode != FREE: return
	var looking: bool = (-cam.global_basis.z).angle_to(at - e) < deg_to_rad(22.0) and e.distance_to(at) < 1.6
	if not looking: return
	if _seen("kiryu"): return   # 試作282（ユーザー「桐生がパッと消えた」）: he went from where she could see him to behind her
	mirror_done = true
	print("STORY ch3 mirror t=%.1f" % t_now)
	var r := _rig("kiryu")
	if r:
		r.visible = true
		r.global_transform = Transform3D(Basis(Vector3.UP, _face(WASH_PATH[0], WASH_PATH[1])), gp(WASH_PATH[0][0], WASH_PATH[0][1], F2))
		# his torch, low in his hand: what the glass catches of him is the light going by
		if not r.has_node("wm_torch"):
			var tl := OmniLight3D.new(); tl.name = "wm_torch"; tl.light_color = Color(1.0, 0.86, 0.66); tl.light_energy = 1.4
			tl.omni_range = 2.6; tl.shadow_enabled = false; tl.position = Vector3(0.25, 1.0, -0.3); r.add_child(tl)
		var pts := []
		for p in WASH_PATH.slice(1): pts.append([p[0], p[1], F2])
		main.walk_to("kiryu", pts, Callable(), _face(WASH_PATH[2], [WASH_MIRROR[0] + 0.6, WASH_MIRROR[1]]))
	get_tree().create_timer(0.9).timeout.connect(func():
		Sound.one(self, "creak2", -4.0, gp(7.4, 6.2, F2 + 0.1))
		if mode == FREE and stage in ["up", "back"]: _start(B("二階.鏡")))   # (not over a talk begun in that second)

# 一時: whom she can talk to, once each (T1_TALK keeps who: 第10章・第11章)
const ONE_NAME := {"makoto": "真琴", "kiryu": "桐生", "taiga": "地下の扉"}
var one_k := ""
static var T1_TALK := {}
func _one_looked() -> String:
	if mode != FREE: return ""
	for w in ["makoto", "kiryu"]:
		if T1_TALK.has(w): continue
		var r := _rig(w)
		if r == null or not r.visible: continue
		if _looking_at(r.global_position + Vector3(0, 1.3, 0), 2.4, 18.0): return w
	if not T1_TALK.has("taiga") and player.global_position.y < 0.5 and _looking_at(gp(CELLAR_DOOR[0], CELLAR_DOOR[1], 1.0), 1.9, 25.0): return "taiga"
	return ""

func _talk_one(w: String):
	T1_TALK[w] = true
	note_lb.text = ""; one_k = ""
	talk_with = w if w != "taiga" else ""
	if w == "makoto" or w == "kiryu":
		var r := _rig(w); var me := _plan_of(r); var mio := _plan_of(player)
		r.global_transform = Transform3D(Basis(Vector3.UP, _face(me, mio)), r.global_position)
	print("STORY ch3 one %s t=%.1f" % [w, t_now])
	_start(B({"makoto": "一時.真琴", "kiryu": "一時.桐生", "taiga": "一時.大河"}[w]))

func _press_up():
	if one_k != "": _talk_one(one_k); return
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
	if stage == "back" and has_blanket and _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], 0.6), 2.4, 30.0) and player.global_position.y < 0.5:
		note_lb.text = ""
		_sit_down()

# 一時の区切り: she sits on the step with the blanket round her, and the clock goes on to half past
func _sit_down():
	_sit(); stage = "sat"
	Sound.one(self, "ch3_blanket", -10.0, player.global_position)
	print("STORY ch3 sat t=%.1f talked=%s" % [t_now, ",".join(T1_TALK.keys())])
	get_tree().create_timer(1.2).timeout.connect(func(): _card(D.lines("一時半.カード")[0], "watch15"))

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
	if stage in ["lock", "t2walk"] or mode == TALK: return
	if stage == "flow" and flow_key == "扉の番.二時半" and (ask_on or rule_on): return   # (the question she can ask is there)
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
	for e in D.entries(key):   # not B(): a ［flag］ line is judged when its second comes (said_rule is set during the flow)
		if not e.has("t"): continue
		flow.append(e)
	fi = 0; flow_key = key; flow_after = after; t_stage = 0.0
	stage = "flow"
	_clear_page()

func _flow_tick(_dt: float):
	if flow_key == "扉の番.二時半": _t230_tick(_dt)
	if not ask_q.is_empty() or ask_hold > 0.0:
		t_stage -= _dt   # 2026-11-20: his side waits while she asks and he answers
		_ask_tick(_dt)
	while fi < flow.size() and t_stage >= float(flow[fi].t):
		_flow_event(flow[fi]); fi += 1
	if cur.has("text") and typed < String(cur.text).length():
		if not is_instance_valid(cur_lb): cur = {}; return   # an answer at the top left took its row (2026-11-18: the cough came while it typed)
		typed = min(float(String(cur.text).length()), typed + _dt * (20.0 if cur.get("testimony", false) else 15.0))
		_type(cur_lb, String(cur.text), int(typed))

func _flow_event(e: Dictionary):
	if e.has("if") and not has_flag(String(e["if"])): return
	if demo3: print("SAY %.1f %s" % [float(e.t), (String(e.who) + "：" + String(e.text)) if e.has("who") else ("＞" + String(e.do)) if e.has("do") else String(e.get("note", ""))])
	if e.has("do"):
		if _flag_do(String(e.do)): return
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
				# 試作282（ユーザー「この絵の直前、真琴がパッと出る」）: she was put down in the hall, 3 m before Mio. She comes from the
				# kitchen, where she kept the candle at one, through its door and down the hall, the candle with her
				_put("makoto", [6.6, 6.4], -PI / 2.0); main.set_stand("makoto", "talk/idle", 0.0); candle.visible = true
				main.walk_to("makoto", [[5.6, 6.4, 0.0], [4.75, 6.0, 0.0], [4.7, 2.6, 0.0]], Callable(), _face([4.7, 2.6], SIT_AT))
				talk_with = "makoto"
			"makoto_head":
				main.set_stand("makoto", "talk/think"); _vary("makoto", "talk/think", "talk/idle")
			"makoto_up":
				talk_with = ""
				main.walk_to("makoto", [[4.7, 2.4, 0.0], [5.5, 2.45, 0.0], [5.5, 5.7, F2], [5.0, 6.3, F2], [5.0, 7.3, F2]], func(): _hide_unseen("makoto", func(): candle.visible = false))
				get_tree().create_timer(7.0).timeout.connect(func(): Sound.one(self, "ch3_cough", -8.0, gp(8.5, 1.5, F2 + 0.8)); _hear("cough"))
				get_tree().create_timer(13.0).timeout.connect(func(): Sound.one(self, "ch3_steps", -10.0, gp(2.5, 5.5, F2 + 0.2)); _hear("steps"))
			"knock":
				Sound.one(self, "knock", -2.0, gp(FRONT_DOOR[0], FRONT_DOOR[1], 1.2)); _hear("knock")
				for i in 3: knock_ts.append(t_now + 0.42 * i)
			"leave":
				pass
			"rattle":
				Sound.one(self, "ch3_rattle", -9.0, gp(9.8, 4.9, 1.0)); _hear("back")
			"ask_open": ask_on = true; last_ask_t = t_stage
			"ask_close": ask_on = false; _t230_record(true)
			"rule_open": rule_on = true
			"rule_close": rule_on = false
			"doze": _doze()
			"slam": _slam()
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
const KIRYU_DOWN := [[5.0, 6.3, F2], [5.5, 5.7, F2], [5.5, 2.55, 0.0]]
var kiryu_sent := false
func _t2walk_tick():
	if mode != FREE: note_lb.text = ""; return
	if cel_i < cel_segs.size() and _looking_at(_cellar_at(), 1.7, 30.0): note_lb.text = T(String(cel_segs[cel_i][0]))
	else: note_lb.text = ""
	if kiryu_sent: return
	# 試作232（ユーザー「地下を見に行こうとしたらここで会話が始まった。変」）: he set off only once she had walked 0.9 m, and
	# reached the hall when she was already at the cellar door: the talk caught her there, out of nowhere. He comes down as soon
	# as she stands, so she meets him on the stair on her way, and he stops at its foot
	kiryu_sent = true; _kiryu_comes()

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
		_kiryu_lcd()
		var me := [5.5, 2.55]; var mio := [player.global_position.x + 4.8, player.global_position.z + 6.3]
		var k := _rig("kiryu"); k.global_transform = Transform3D(Basis(Vector3.UP, _face(me, mio)), k.global_position)
		var to: Vector3 = (k.global_position + Vector3(0, 1.45, 0)) - player.get_node("Head/Camera").global_position
		var tw := create_tween(); tw.set_parallel(true)
		tw.tween_property(player, "yaw", player.yaw + wrapf(atan2(-to.x, -to.z) - player.yaw, -PI, PI), 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player, "pitch", asin(clampf(to.normalized().y, -1.0, 1.0)), 0.8).set_trans(Tween.TRANS_SINE)
		_set_mission("")
		talk_with = "kiryu"; stage = "t2"
		_start(B("扉の番.二時")))

# 試作282（ユーザー「桐生の顔も照らされているのが自然、表情を見せたい」）: the camera off the tripod is in his hands with its
# screen open; that screen's light is on his face from below and in front (gone with him: FaceLight follows his rig's visibility)
func _kiryu_lcd():
	if not main.S.has("kiryu_node"): return
	var r := _rig("kiryu")
	var scr := Node3D.new(); scr.name = "kcam_lcd"; r.add_child(scr); scr.position = Vector3(0.08, 1.22, 0.3)
	var sks: Array = (main.S.kiryu_node as Node).find_children("*", "Skeleton3D", true, false)
	if sks.is_empty(): return
	var f := FaceLight.new(); f.sk = sks[0]; f.src = scr
	f.head = f.sk.find_bone("head")
	if f.head < 0: f.head = f.sk.find_bone("mixamorig_Head")
	f.light_color = Color(0.8, 0.87, 1.0); f.light_energy = 0.55; f.spot_range = 1.2; f.spot_angle = 18.0
	f.spot_attenuation = 0.8; f.spot_angle_attenuation = 2.0; f.shadow_enabled = false; f.light_volumetric_fog_energy = 0.0; f.light_specular = 0.08
	main.add_child(f)

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
	# 2026-11-17 夜（ユーザー「桐生が壁を抜けて出ていく。丁寧に描く」）: he turns the lock, takes the knob, the door comes to him
	# and he steps back with it (it swung through him before), then out through the open side and along the porch
	Sound.one(self, "ch3_lock", -8.0, gp(5.0, 0.05, 1.0))
	_front_open_by("kiryu", func(rest: float):
		main.walk_to("kiryu", [[5.15, 0.55, -0.18], [5.05, -0.6, -0.21], [6.2, -1.1, -0.2]], func():
			_hide("kiryu")
			var tw2 := create_tween()
			tw2.tween_property(main.door_pivot, "rotation:y", rest, 1.1).set_trans(Tween.TRANS_SINE)
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

# ---------------------------------------------------------------- 二時 (2026-11-20 12時31分①、13時35分、14時8分): the barred door
# She goes down the cellar stair to the barred door (the bar on Taiga's side; he took it off at half past one). E, in turn:
# she calls him, turns the knob (the door is heavy; behind it something slides down against it), pushes, and Kiryu, come
# down behind her, takes her wrist. The talk is there, on the stair.
func _cellar_ready():
	cel_segs = []; cel_i = 0
	var seg = null
	for e in D.entries("二時.地下の扉"):
		if e.has("note") and String(e.note).begins_with("［Ｅ"): seg = [String(e.note), []]; cel_segs.append(seg)
		elif seg != null: seg[1].append(e)
	if dn and barred.is_empty():
		for k in dn.doors.keys():
			if dn.doors[k].key == "door_barred":
				barred = dn.doors[k]; barred["leaf"] = k; dn.doors.erase(k); break   # E here is the story's (doors.gd said 「開かない。」)

func _cellar_at() -> Vector3:
	if not barred.is_empty() and is_instance_valid(barred.leaf): return (barred.leaf as MeshInstance3D).global_transform * (barred.leaf as MeshInstance3D).get_aabb().get_center()
	return gp(5.5, 2.45, ZBASE + 1.0)

func _press_cellar():
	if cel_i >= cel_segs.size() or not _looking_at(_cellar_at(), 1.7, 30.0): return
	note_lb.text = ""
	var q: Array = (cel_segs[cel_i][1] as Array).duplicate(true)
	cel_i += 1
	if cel_i == cel_segs.size():
		q.append({"do": "to_hall"}); q.append({"do": "kiryu_look"})
		q.append_array(B("扉の番.二時"))
	print("STORY ch3 cellar %d t=%.1f" % [cel_i, t_now])
	_start(q)

# the knob turns; the door gives a finger's width and is heavy; behind it a weight slides and knocks against it
func _cellar_jolt():
	var at := _cellar_at()
	get_tree().create_timer(0.35).timeout.connect(func():
		Sound.one(self, "body_fall", -8.0, at)
		Sound.one(self, "ch3_thud", -1.0, at))
	if barred.is_empty(): return
	var piv: Node3D = barred.pivot
	var r0: float = piv.rotation.y
	var dir := signf(float(barred.open) - float(barred.rest))
	if absf(float(barred.open) - float(barred.rest)) < 0.1: dir = 1.0
	var tw := create_tween()
	tw.tween_property(piv, "rotation:y", r0 + dir * 0.045, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(piv, "rotation:y", r0 + dir * 0.01, 0.06)
	tw.tween_property(piv, "rotation:y", r0 + dir * 0.02, 0.25).set_trans(Tween.TRANS_SINE)

const MIO_WAIT := [4.75, 5.0]   # (ch8.gd: at the cellar door, the hall before her)
const TAKE_AT := [5.05, 2.45]    # (by the tripod, the camera off it; not behind its pole from where she stands)
func _shade() -> ColorRect:
	if doze_rect == null:
		var cl := CanvasLayer.new(); cl.layer = 11; add_child(cl)
		doze_rect = ColorRect.new(); doze_rect.color = Color(0, 0, 0, 0); doze_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		doze_rect.set_anchors_preset(Control.PRESET_FULL_RECT); cl.add_child(doze_rect)
	return doze_rect

func _cellar_z(y: float) -> float:
	return ZBASE * clampf((5.55 - y) / 2.9, 0.0, 1.0)

# she pushes: her hand on the door; from behind, his on her wrist. The camera stays (the hand comes into the foot of the frame)
func _kiryu_grab():
	_set_mission("")
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):   # the big camera is off its tripod (第4章: the tripod stays)
		var nm := String(mi.name)
		if nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"): (mi as Node3D).visible = false
	var me := _plan_of(player)
	var ky := minf(float(me[1]) + 0.75, 5.2)
	_put("kiryu", [5.5, ky], _face([5.5, ky], me), _cellar_z(ky))
	main.set_stand("kiryu", "talk/idle", 0.0)
	Sound.one(self, "ch3_blanket", -4.0, player.global_position)
	if barred.has("pivot"):   # the door goes back as her hand is pulled from it
		var piv: Node3D = barred.pivot
		create_tween().tween_property(piv, "rotation:y", float(barred.rest), 0.3)
	if grab_arms.is_empty():
		var dm := Vector3(0.30, -0.50, 0.81).normalized()
		var hm := _fp_arm("mio", "r", dm, Vector3(0, 0.35, 1), 0.15)
		var dk := Vector3(0.62, -0.42, 0.66).normalized()
		var hk := _fp_arm("kiryu", "r", dk, Vector3(0, 1, 0.1), 0.85)
		if hm and hk:
			hm.position = Vector3(0.10, -0.13, -0.42)
			hk.position = hm.position + dm * 0.10 + dk * 0.075 + Vector3(0, 0.035, 0)
			hk.set_meta("at", hk.position); hk.set_meta("from", hk.position + dk * 0.3)
			var fl := OmniLight3D.new(); fl.light_color = Color(1.0, 0.85, 0.7); fl.light_energy = 0.18; fl.omni_range = 0.7
			fl.shadow_enabled = false; fl.position = Vector3(0.0, 0.1, -0.15); hm.get_parent().add_child(fl)
			grab_arms = [hm, hk, fl]
	if grab_arms.size() == 3:
		var hm: Node3D = grab_arms[0]; var hk: Node3D = grab_arms[1]
		hm.visible = true; hk.visible = true; (grab_arms[2] as Node3D).visible = true
		hk.position = hk.get_meta("from")
		var tw := create_tween()
		tw.tween_property(hk, "position", hk.get_meta("at") as Vector3, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.4)
		tw.tween_property(hm, "position", hm.position + Vector3(0.05, -0.12, 0.1), 0.5).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(hk, "position", (hk.get_meta("at") as Vector3) + Vector3(0.05, -0.12, 0.1), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func():
			for a in grab_arms: (a as Node3D).visible = false)
	talk_with = "kiryu"; stage = "t2"
	print("STORY ch3 kiryu_grab t=%.1f" % t_now)

# ---------------------------------------------------------------- 二時半 (2026-11-20 12時、14時8分、14時14分): through the door
# Kiryu's voice is clear; only Natsuki's comes broken, from a little off the door. She can ask (each once, in any order),
# keep still, go to the door, lay her ear on it. All of it is kept (door_0230): 第8章 plays it back from his side of the door,
# 第11章 from the tape.
const T230_AT := {"sit": [5.0, 1.62], "near": [5.0, 0.86], "ear": [5.0, 0.6]}
func _t230_start():
	ask_left = []
	var ch: Array = D.entries("二時半.問い")
	if not ch.is_empty(): for i in (ch[0].choose as Array).size(): ask_left.append(i)
	ask_sel = 0; ask_q = []; ask_hold = 0.0; ask_on = false; rule_on = false
	door_pos3 = "sit"; last_ask_t = 8.0
	rec230 = {"pos": [[0.0, "sit"]], "asks": [], "silences": [], "said_rule": false, "ear_voice": 0.0}
	set_flag("lean", false)
	_foot("マウス 見る　Ｗ 扉に寄る　Ｓ 下がる　右ボタン 耳を当てる　ホイール 選ぶ　Ｅ 問う")

func _t230_input(e) -> bool:
	if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if ask_left.size() > 1: ask_sel = posmod(ask_sel + (-1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1), ask_left.size())
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in [KEY_W, KEY_UP]: _door_to("near" if door_pos3 == "sit" else door_pos3); return true
		if e.keycode in [KEY_S, KEY_DOWN]: _door_to("sit"); return true
		if e.keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT] and ask_left.size() > 1:
			ask_sel = posmod(ask_sel + (-1 if e.keycode in [KEY_A, KEY_LEFT] else 1), ask_left.size()); return true
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		if e.pressed and door_pos3 != "ear": _door_to("ear")
		elif not e.pressed and door_pos3 == "ear": _door_to("near")
		return true
	return false

# where she is: sat on the step, at the door on her knees, her ear on it (the head turned, the cheek to the wood)
func _door_to(p: String):
	if p == door_pos3: return
	var was := door_pos3
	door_pos3 = p
	(rec230.pos as Array).append([snappedf(t_stage, 0.1), p])
	if p == "ear": set_flag("leaned", true)
	if p == "ear" or was == "ear": set_flag("lean", p == "ear")
	if pos_tw and pos_tw.is_valid(): pos_tw.kill()
	var at: Array = T230_AT[p]
	var to: Vector3 = gp(at[0], at[1], 0.0); to.y = player.global_position.y
	var head: Node3D = player.get_node("Head")
	var yaw_door := atan2(0.0, 1.0)   # (facing the door: plan -y)
	var cam_to := gp(5.0, 0.0, 0.8) - (to + Vector3(0, SIT_EYE, 0))
	yaw_door = atan2(-cam_to.x, -cam_to.z)
	pos_tw = create_tween().set_parallel(true)
	pos_tw.tween_property(player, "global_position", to, 0.9 if was == "sit" or p == "sit" else 0.5).set_trans(Tween.TRANS_SINE)
	pos_tw.tween_property(head, "rotation:z", 0.22 if p == "ear" else 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	pos_tw.tween_property(player, "yaw", yaw_door + (deg_to_rad(62.0) if p == "ear" else 0.0), 0.6).set_trans(Tween.TRANS_SINE)
	pos_tw.tween_property(player, "pitch", 0.0 if p == "ear" else asin(clampf(cam_to.normalized().y, -1.0, 1.0)), 0.6).set_trans(Tween.TRANS_SINE)
	Sound.one(self, "ch3_blanket", -14.0, player.global_position)
	print("STORY ch3 door %s t=%.1f" % [p, t_stage])

func _t230_tick(dt: float):
	if door_pos3 == "ear" and t_stage >= 16.0 and t_stage <= 24.0: rec230.ear_voice = float(rec230.ear_voice) + dt
	if demo3: _t230_demo()
	if mode == TALK or stage != "flow": return
	var ch: Array = D.entries("二時半.問い")
	if not ask_q.is_empty() or ask_hold > 0.0: note_lb.text = ""
	elif rule_on: note_lb.text = T("［Ｅ　言う］　") + Tw(String(D.entries("二時半.ルール")[0].choose[0]))
	elif ask_on and not ask_left.is_empty() and not ch.is_empty():
		# 試作282（ユーザー「1/4の表記がよくわからない」）: the count read as a score. Now it says what the keys do
		var more := ("　" + T("［Ａ・Ｄ　ほかの問い］")) if ask_left.size() > 1 else ""
		note_lb.text = T("［Ｅ　問う］　") + Tw(String(ch[0].choose[ask_left[ask_sel]])) + more
	elif ask_on: note_lb.text = ""

func _ask() -> bool:
	if not ask_q.is_empty() or ask_hold > 0.0: return true
	if rule_on:
		rule_on = false; rec230.said_rule = true
		ask_q = ((D.entries("二時半.ルール")[0].then as Array)[0] as Array).duplicate(true)
		(rec230.asks as Array).append([snappedf(t_stage, 0.1), "rule"])
		print("STORY ch3 ask rule t=%.1f" % t_stage)
		return true
	if not ask_on or ask_left.is_empty(): return false
	var ch: Dictionary = D.entries("二時半.問い")[0]
	var idx: int = ask_left[ask_sel]
	ask_q = ((ch.then as Array)[idx] as Array).duplicate(true)
	ask_left.remove_at(ask_sel); ask_sel = 0
	var gap := t_stage - last_ask_t
	if gap >= 6.0: (rec230.silences as Array).append([snappedf(last_ask_t, 0.1), snappedf(gap, 0.1)])
	last_ask_t = t_stage
	(rec230.asks as Array).append([snappedf(t_stage, 0.1), idx])
	print("STORY ch3 ask %d %s t=%.1f" % [idx, ch.choose[idx], t_stage])
	return true

# what she asked and what he answered, one line after another; his side of the door goes on after
func _ask_tick(dt: float):
	if cur.has("text") and typed < String(cur.text).length(): return
	ask_hold -= dt
	if ask_hold > 0.0 or ask_q.is_empty(): return
	var e: Dictionary = (ask_q.pop_front() as Dictionary).duplicate()
	e["t"] = t_stage
	_flow_event(e)
	ask_hold = 0.9 + String(e.get("text", e.get("note", ""))).length() * 0.05
	if e.has("do"): ask_hold = 0.0

func _t230_record(final: bool):
	if final:
		var gap := 63.0 - last_ask_t
		if gap >= 6.0: (rec230.silences as Array).append([snappedf(last_ask_t, 0.1), snappedf(gap, 0.1)])
		last_ask_t = 63.0
	rec230["said_rule"] = has_flag("said_rule")
	set_flag("door_0230", rec230.duplicate(true))
	# 試作281（別のスレッド「選んだ返事が、まだ後で拾われない」）: the first thing she asked through the door, for 証言一 to quote
	for k in 4: set_flag("asked1_%d" % k, null)
	for a in rec230.asks:
		if typeof(a[1]) == TYPE_INT: set_flag("asked1_%d" % int(a[1])); break
	print("STORY ch3 door_0230 ", JSON.stringify(rec230))

# the unattended playthrough: to the door, the ear on it for Natsuki's voice, two questions, (with --ch3rule) the rule
var d230 := 0
func _t230_demo():
	var plan := [[9.0, "near"], [10.0, "ear"], [13.0, "ask"], [25.0, "near"], [30.5, "ask"], [44.0, "sit"], [50.0, "rule"]]
	if d230 >= plan.size() or t_stage < float(plan[d230][0]): return
	var a: String = plan[d230][1]; d230 += 1
	match a:
		"ask": _ask()
		"rule": if "--ch3rule" in OS.get_cmdline_user_args(): _ask()
		_: _door_to(a)

# ---------------------------------------------------------------- 三時 (2026-11-20 13時35分 ③): she dozes; the back door slams
func _doze():
	_shade()
	var tw := create_tween()   # the lids: heavy, up again, heavier
	tw.tween_property(doze_rect, "color:a", 0.55, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(doze_rect, "color:a", 0.25, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(doze_rect, "color:a", 0.86, 2.0).set_trans(Tween.TRANS_SINE)
	doze_rect.set_meta("tw", tw)
	var p0: float = player.pitch
	create_tween().tween_property(player, "pitch", p0 - 0.08, 3.9).set_trans(Tween.TRANS_SINE)

func _slam():
	var at := gp(9.96, 5.3, 1.0)
	Sound.one(self, "door_close", 6.0, at)
	Sound.one(self, "ch3_rattle", 2.0, at)
	Sound.one(self, "body_fall", -6.0, at)
	_hear("back")
	if doze_rect:
		var tw0 = doze_rect.get_meta("tw") if doze_rect.has_meta("tw") else null
		if tw0 and (tw0 as Tween).is_valid(): (tw0 as Tween).kill()
		create_tween().tween_property(doze_rect, "color:a", 0.0, 0.07)

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
	if not trace.is_empty():
		return   # 試作283: held keys are read in _trace_tick; the mouse does nothing in the close shot
	if stage == "flow" and flow_key == "扉の番.二時半" and _t230_input(e): return
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
		"swap": _swap_press()
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
				cellar_said = true; talk_with = "makoto"; _start(B("目張り.地下の扉")); return
			if not photo_said and _looking_at(gp(HALL_PHOTO[0], HALL_PHOTO[1], HALL_PHOTO[2]), 2.2, 16.0):
				photo_said = true; _say_tes(B("廊下.写真")[0].text); return
			if not mk_seal_said and _mk_seal_looked():
				mk_seal_said = true; talk_with = "makoto"; _start(B("目張り.真琴")); return
		"up", "back":
			_press_up()
		"t2walk":
			_press_cellar()
		"flow":
			if flow_key == "扉の番.二時半" and _ask(): return
			_press_watch()
		"watch", "t2":
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
	# 一時の区切り: Taiga through the cellar door, Makoto in the kitchen, then up the stair (Kiryu on the landing),
	# every one of the things in the rooms, the blanket, down to the door, and sit
	steps.append(["walk", [[4.8, 1.6], [4.6, 1.9], [4.6, 2.6], [4.3, 2.9], [4.3, 3.2], [4.2, 3.4], [4.3, 3.7], [4.8, 4.2], [4.8, 5.7], [5.1, 6.0], [5.5, 6.3]]])
	steps.append(["one", "taiga"]); steps.append(["wait_free"])
	steps.append(["walk", [[5.7, 6.2], [6.0, 6.2]]]); steps.append(["one", "makoto"]); steps.append(["wait_free"])
	steps.append(["walk", [[5.5, 6.2], [5.1, 6.0], [4.8, 5.7], [4.8, 4.2], [4.3, 3.7], [4.2, 3.4], [4.3, 3.2], [4.3, 2.9], [4.6, 2.6], [4.8, 1.9], [5.0, 1.9], [5.5, 2.4], [5.5, 5.75], [5.5, 6.0]]])
	steps.append(["one", "kiryu"]); steps.append(["wait_free"])
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
	for k in ["door", "gen", "car", "cellar", "cough", "steps"]: steps.append(["hear", k])
	# 二時 (2026-11-20): down the cellar stair to the barred door; call, the knob, push; Kiryu's hand; then up to the front door
	steps.append(["wait_stage", "t2walk"]); steps.append(["wait_free"])
	steps.append(["walk", [[4.8, 1.9], [4.6, 2.6], [4.3, 2.9], [4.3, 3.2], [4.2, 3.4], [4.3, 3.7], [4.8, 4.2], [4.8, 5.7], [5.0, 5.9]]])
	steps.append(["open", "door_cellar"]); steps.append(["sleep", 1.2]); steps.append(["walk", [[5.5, 5.9], [5.5, 5.5], [5.5, 3.0]]])
	for i in 3: steps.append(["cellar", i])
	steps.append(["wait_stage", "lock"]); steps.append(["wait_free"])
	steps.append(["walk", [[4.8, 4.2], [4.3, 3.7], [4.3, 2.9], [4.6, 2.5], [4.8, 1.9], [5.0, 1.3]]])
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
			if mode == FREE:
				var st0 := stage
				_press(); done = true
				if stage == st0 and st0 == "lock": _dfail("lock: not taken from %s" % [_plan_of(player)])
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
			if dwait > 1.2 and mode == FREE and not gq.sealed and trace.is_empty(): _press()
			if not trace.is_empty(): trace.hold = true   # (the run holds E)
			if gq.sealed and mode == FREE: done = true
			if dwait > 25.0: _dfail("gap %s: cannot seal (Mio %s, candle %s)" % [s[1], _plan_of(player), _plan_of(candle) if candle else []]); _seal(gq); sealed_n += 1; done = true
		"open":
			if dn: dn.open_key(s[1])
			done = true
		"sleep":
			done = dwait >= float(s[1])
		"cellar":
			var cam6: Camera3D = player.get_node("Head/Camera")
			var to6: Vector3 = _cellar_at() - cam6.global_position
			var k6 := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to6.x, -to6.z), k6)
			player.pitch = lerpf(player.pitch, asin(clampf(to6.normalized().y, -1.0, 1.0)), k6)
			if dwait > 1.0 and mode == FREE and cel_i == int(s[1]):
				_press_cellar()
				if cel_i == int(s[1]): _dfail("cellar %d: cannot reach the barred door from %s (%.1f m)" % [s[1], _plan_of(player), to6.length()])
				done = true
			elif dwait > 30.0: _dfail("cellar %d: the talk did not end" % s[1]); done = true
		"one":
			var tp: Vector3 = gp(CELLAR_DOOR[0], CELLAR_DOOR[1], 1.0) if s[1] == "taiga" else _rig(s[1]).global_position + Vector3(0, 1.3, 0)
			var cam5: Camera3D = player.get_node("Head/Camera")
			var to5: Vector3 = tp - cam5.global_position
			var k5 := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to5.x, -to5.z), k5)
			player.pitch = lerpf(player.pitch, asin(clampf(to5.normalized().y, -1.0, 1.0)), k5)
			if dwait > 1.0 and one_k == s[1] and mode == FREE: _talk_one(s[1]); done = true
			elif dwait > 6.0: _dfail("one %s: cannot talk from %s (%.1f m)" % [s[1], _plan_of(player), to5.length()]); done = true
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


# 試作277（ユーザー「ここの真琴、短いスパンで同じような動きを繰り返す」、23時）: "think" is a short Mixamo clip; looped, the same
# gesture came every few seconds. Once through, then the plain stand for 4〜7 s, then again, while nothing else is set on her
func _vary(k: String, a: String, b: String):
	if not main.S.has(k + "_node"): return
	var ap: AnimationPlayer = main.S[k + "_node"].find_children("*", "AnimationPlayer", true, false)[0]
	if not ap.has_animation(a) or not ap.has_animation(b): return
	var len_a: float = ap.get_animation(a).length
	get_tree().create_timer(len_a).timeout.connect(func():
		if main.stand_anim.get(k, "") != a: return
		main.set_stand(k, b, 0.6); main.stand_anim[k] = a   # (still "think" for the next turn; the body stands meanwhile)
		get_tree().create_timer(randf_range(4.0, 7.0)).timeout.connect(func():
			if main.stand_anim.get(k, "") != a or main.walkers.has(k): return
			main.set_stand(k, a, 0.6); _vary(k, a, b)))
