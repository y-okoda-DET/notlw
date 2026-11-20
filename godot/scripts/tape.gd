## ステップ D：第11章「再生」。数か月後、澪が手すりのカメラのテープを初めて再生する（docs/企画書.md「テープ再生（第11章）」）。
## fps.gd（第4章）と同じ夜を、同じ秒で、誰も操作しないまま走らせ、手すりの上の小さいカメラから撮った画をテレビに映す。
## 台詞は story/ch11.txt。
##
## A dark room, a television on the floor, the deck under it. E on the deck plays the tape; nothing else happens until
## she does. The picture is the wide frame Kiryu drew at dusk: the whole hall, the front door, and one hurt person
## walking in. Mio herself stands just under the camera, out of the frame; what comes into it from her side is the
## tripod. The tracking is off: the picture tears and the words drop out, as the radio's did at eight (第2章). Right
## mouse puts her hand on the tracking knob and the mouse turns it, the radio's own handling; this time the words come.
## What Natsuki says is written with her name. In 第4章 the same seconds were （うめき声）.
## When the tape runs out the view goes down to the deck's two keys, 録画 and 取り出し, and cuts to black.
extends "res://scripts/fps.gd"

const ROOM := Vector3(0.0, -40.0, 0.0)     # far under the house: nothing of the night reaches it
const TV_C := Vector3(0.0, 0.62, 0.0)      # the middle of the screen (room metres)
const SCR := Vector2(0.44, 0.33)           # a 21-inch tube, 4:3
const EYE := Vector3(0.0, 0.66, 0.74)      # she sits on the floor before it
const NIGHT_AT := 4.0                      # the tape's 0 s is the night's 4 s (ch4.txt)
const HIT_LAG := 0.4                       # a blow lands this long after it starts (fps.gd _swing)
enum {ROOM_WAIT, PLAYING, ENDED, BLACK}
var st := ROOM_WAIT
var vp: SubViewport
var tcam: Camera3D
var scr_mat: ShaderMaterial
var osd: Label
var osd_trk: Label
var stamp: Label
var glow: OmniLight3D
var knob: MeshInstance3D
var trk := 0.18                # the knob, 0..1
var on_knob := false
var tape_t := 0.0
var room_t := 0.0
var end_t2 := -1.0
var card11: Control
var card11_t := 0.0   # 2026-11-20: no card (its question went to 証言 三)
var tline := {}                # the line being written: {lb, text, written, segs, n_all, n_clear}
var heard_clear := 0
var heard_all := 0
var tswing := -1.0
var tswings := 0
var tqueue := []       # swing_0330 (第4章で振った通り): [tape clock, "head"|"body"|"miss"], the first blow to her head at the script's strike
var tswing_what := "head"
var held_since := -1.0
var black2: ColorRect
var demo11 := false
# 2026-11-19 試作220（「第11章のラストショットを試す」）：the last shot. Before E the screen is never dark glass: she is
# looking down at the deck, and the set, if she looks up, is on the deck's blue. After the tape her eyes go down to the
# two keys; the set goes off; her eyes come back up to the dead glass, and in it, faint, is she.
#   --d11refl=a  the door behind her: in the glass she is a shape against the light, no face
#             b  the door at her left: half her face, as it is (真顔)
#             c  as b, and she sits a little to the right: her face at the glass's edge, cut by the mask
#             d  ユーザーの元の案：the set off, the picture cuts to her face from the set's side
var refl := "e"   # 2026-11-19 ユーザーの流れ（e）
var mio_n: Node3D
var rvp: SubViewport
var rcam: Camera3D
var look_cam: Camera3D
var off_t := -1.0
var seat_x := 0.0
var tv_glass := Vector2(1.0, 1.0)
# 2026-11-19（ユーザー「いずれにしてもカメラ横に振ったバージョンが見たい」）: --d11pan. After the set goes off the picture
# leaves her eyes: a camera on a tripod at her right, on the dead glass, pans across to her
var pan := false
# 2026-11-19（ユーザー案「デッキから上にゆっくりパン→テレビに映り込む澪→ディゾルブでテレビ側からのカメラで澪を捉える→数秒写して
# 一気に黒味」）: --d11refl=e. The light of b; her eyes rise slowly to the dead glass, she is in it; the picture from the set's
# side dissolves in over it; a few seconds; black at once
var face_vp: SubViewport
const CREDITS_AT := 25.5      # the face for six seconds, then black at once
const CREDITS_LEN := 60.0     # 仮のエンドロール、1分
var credits: Label
var credits_y0 := 0.0
# the end roll: no picture, the names going up over black, and the one music from outside the story (決定事項 2026-11-13:
# 「音楽の冗談」をエンドロールで加工なしで流す。sound/credits_joke.ogg = the user's Menuetto, its first minute)
const CREDITS_TEXT := "RULES\n\n\n\n澪\n\n夏希\n\n桐生\n\n真琴\n\n大河\n\n陽太\n\n\n\n\nDIRECTOR\n○○\n\nSCRIPT\n○○\n\nART\n○○\n\nSOUND\n○○\n\n\n\nMUSIC\nW. A. Mozart\nEin musikalischer Spass K.522\nII. Menuetto\n\n\n\n\n(placeholder)"
func _credits():
	var cl := CanvasLayer.new(); cl.layer = 23; add_child(cl)
	credits = Label.new(); credits.text = CREDITS_TEXT; credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits.add_theme_font_override("font", Type.card()); credits.add_theme_font_size_override("font_size", 30)
	credits.add_theme_color_override("font_color", Color(0.86, 0.85, 0.80))
	var vs := get_viewport().get_visible_rect().size
	credits.size = Vector2(vs.x, 0); credits.position = Vector2(0, vs.y); cl.add_child(credits)
	credits.reset_size(); credits.size.x = vs.x; credits_y0 = vs.y
	Sound.one(self, "credits_joke", -3.0)
var face_tr: TextureRect
var pan_cam: Camera3D
const PAN_AT := Vector3(0.95, 0.70, 0.30)
const MIO_LAYER := 128         # her body: the mirror and the last cut see it, her own eyes do not
const SCR_LAYER := 4           # the glass itself: the mirror does not see it

# ---------------------------------------------------------------- 2026-11-20: the tape from 0:20 (時刻は 0:20:00 からの秒)
const N0 := 1200                      # 0:20:00, the head of the second cassette
const N230 := 7798.0                  # 2:29:58 (【テープ.二時半】 0 s)
const N330 := 11394.0                 # 3:29:54 (【テープ.流れ】 0 s = 第4章 4 s)
const N400 := 13200.0                 # 4:00:00 (【テープ.四時】)
const N_END := 14400.0                # 4:20:00: the tape runs out
const FF_RATE := 120.0
const T230_POS := {"sit": [5.0, 1.62], "near": [5.0, 0.86], "ear": [5.0, 0.6]}   # ch3.gd T230_AT
const SIT_AT := [4.9, 1.62]           # the 框 (ch8.gd MIO_SIT)
var night_n := 0.0
var play_room_t := 0.0
var post := false
var ff_on := false
var demo_ff := false
var jumped := false
var pre_q := []                       # [n, kind, ...] in night seconds, as _event takes them
var pre_pos := []                     # [n, "sit"|"near"|"ear"|"gone"]
var pre_pi := 0
var mio_h                             # a ch8.gd, not in the tree: its _load_mio/_blanket make her, sitting in the blanket
var mio_pose := ""

func _pre_build():
	pre_q = []; pre_pos = []
	if "--ch11rec" in OS.get_cmdline_user_args() and not (get_flag("door_0230") is Dictionary):   # (this part alone: a night as 第3章's playthrough leaves it; ch8.gd --ch8rec)
		set_flag("door_0230", {"pos": [[0.0, "sit"], [9.0, "near"], [10.0, "ear"], [25.0, "near"], [44.0, "sit"]], "asks": [[13.0, 0], [30.5, 1]], "silences": [[13.0, 17.5], [30.5, 32.5]], "said_rule": true})
		set_flag("said_rule")
	var rec = get_flag("door_0230")
	if not (rec is Dictionary): rec = {"pos": [[0, "sit"]], "asks": [], "said_rule": has_flag("said_rule")}
	# where she was: from 1:00 at the door in the blanket; 2:00-2:07 at the cellar door (out of the frame); 2:30 as recorded
	pre_pos.append([0.0, "gone"]); pre_pos.append([2400.0, "sit"]); pre_pos.append([6000.0, "gone"]); pre_pos.append([6420.0, "sit"])
	for pp in (rec.get("pos", []) as Array): pre_pos.append([N230 + float(pp[0]), String(pp[1])])
	pre_pos.append([N230 + 70.0, "sit"])
	pre_pos.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	for e in B("テープ.二時半"):
		if not e.has("t"): continue
		if e.has("if") and not has_flag(String(e["if"])): continue
		var n := N230 + float(e.t)
		if e.has("do"): continue
		if e.has("note"): pre_q.append([n, "note", e.note])
		else: pre_q.append([n, "say", e.get("who", ""), e.text])
	var ch: Array = D.entries("テープ.問い")
	for a in (rec.get("asks", []) as Array):
		if str(a[1]) == "rule" or ch.is_empty(): continue
		var i := int(a[1])
		if i >= (ch[0].then as Array).size(): continue
		var k := 0
		for e in ((ch[0].then as Array)[i] as Array):
			var n2 := N230 + float(a[0]) + 2.6 * k; k += 1
			if e.has("note"): pre_q.append([n2, "note", e.note])
			elif e.has("text"): pre_q.append([n2, "say", e.get("who", ""), e.text])
	var k4 := 0
	for e in B("テープ.四時"):
		var n4 := N400 + 3.0 * k4; k4 += 1
		if e.has("note"): pre_q.append([n4, "note", e.note])
		elif e.has("text"): pre_q.append([n4, "say", e.get("who", ""), e.text])
	pre_q.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	_hall_mio()
	print("STORY ch11 pre: %d lines, %d places (record %s)" % [pre_q.size(), pre_pos.size(), "yes" if get_flag("door_0230") is Dictionary else "no"])

func _pre_tick(_dt: float):
	while not pre_q.is_empty() and night_n >= float(pre_q[0][0]):
		var e: Array = pre_q.pop_front()
		if ff_on and night_n - float(e[0]) > 2.0: continue   # run past fast: a blur, not words
		_event(e)
	var want := "gone"
	for pp in pre_pos:
		if night_n >= float(pp[0]): want = String(pp[1])
	if post: want = "gone"
	_hall_mio_pose(want)

func _hall_mio():
	if mio_h != null: return
	mio_h = load("res://scripts/ch8.gd").new()
	mio_h.main = main; mio_h.player = player
	mio_h._load_mio()
	if not main.S.has("mio_node"): mio_h = null; return
	_hall_mio_pose("gone")

func _hall_mio_pose(p: String):
	if mio_h == null or p == mio_pose: return
	mio_pose = p
	var rig: Node3D = main._rig_of("mio")
	rig.visible = p != "gone"
	if mio_h.blanket: mio_h.blanket.visible = p == "sit"
	if p == "gone": return
	var at: Array = SIT_AT if p == "sit" else T230_POS.get(p, SIT_AT)
	var yaw := atan2(5.0 - float(at[0]), 0.0 - float(at[1]))   # to the door (plan 5.0, 0.0)
	main.place_person("mio", [float(at[0]) - 4.8, 6.3 - float(at[1]), -0.36 if p == "sit" else 0.0], yaw)
	main.set_stand("mio", "talk/sit_idle" if p == "sit" else "talk/idle", 0.3)
	if p == "ear": rig.rotate_object_local(Vector3.RIGHT, 0.22); rig.global_position += Vector3(0, -0.12, 0)

func _init():
	tape = true

func _ready():
	super._ready()
	for a in OS.get_cmdline_user_args():   # checks: --swings=50.0:miss,50.6:head,… stands in for the night's record
		if a.begins_with("--swings="):
			var r := []
			for w in a.substr(9).split(","): r.append([float(w.split(":")[0]), w.split(":")[1]])
			set_flag("swing_0330", r)
	load_story("ch11")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--d11refl="): refl = a.substr(10)
		if a == "--d11pan": pan = true
	if refl == "c": seat_x = 0.17
	for e in _flow("テープ.流れ"): e[0] = float(e[0]) + NIGHT_AT; LINES.append(e)
	_room()
	_screen()
	_mio_body()
	_back_light()
	card11 = Control.new(); card11.visible = false; add_child(card11)   # 2026-11-20: no card any more
	black2 = ColorRect.new(); black2.color = Color(0, 0, 0, 0); black2.set_anchors_preset(Control.PRESET_FULL_RECT); black2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := CanvasLayer.new(); bl.layer = 22; add_child(bl); bl.add_child(black2)
	# she sits; she does not walk in this chapter
	player.fly = true; player.collision_layer = 0; player.collision_mask = 0; player.move_enabled = false
	player.eye_height = EYE.y
	player.global_position = ROOM + Vector3(EYE.x + seat_x, 0.0, EYE.z)
	player.yaw = 0.0; player.pitch = deg_to_rad(-38.0)   # 試作220：she starts looking down at the deck; the screen is above the frame
	(player.get_node("Head/Camera") as Camera3D).fov = 34.0
	(player.get_node("Head/Camera") as Camera3D).cull_mask &= ~MIO_LAYER
	_foot.call_deferred("マウス 見る　Ｅ 再生　右クリック（押したまま） つまみに手を置く　　Ｆ１２ 画面の保存　Ｅｓｃ マウス解放")
	# the hall waits as it was at the tape's first frame
	clock = NIGHT_AT
	for a in OS.get_cmdline_user_args():
		if a == "--demo": demo11 = true
		if a == "--nocard4": card11_t = 0.0
		if a.begins_with("--d11at="):    # stills: the tape at this second, the tracking as --d11trk= has it (default: right)
			card11_t = 0.0; call_deferred("_tape_jump", float(a.substr(8)))
		if a.begins_with("--d11trk="): set_meta("trk", float(a.substr(9)))
		if a == "--d11full":   # stills: the tape's own picture over the whole view (what the small camera took), under the print
			var fl := CanvasLayer.new(); fl.layer = 9; add_child(fl)
			var tr := TextureRect.new(); tr.texture = vp.get_texture(); tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; fl.add_child(tr)
			var bg := ColorRect.new(); bg.color = Color.BLACK; bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.show_behind_parent = true; tr.add_child(bg)
		if a.begins_with("--d11gain="): (tcam.attributes as CameraAttributesPractical).exposure_multiplier = float(a.substr(10))
		if a == "--d11end": card11_t = 0.0; call_deferred("_end_tape"); set_meta("endstill", true)
		if a.begins_with("--d11endat="): card11_t = 0.0; set_meta("endat", float(a.substr(11))); call_deferred("_end_tape"); set_meta("endstill", true)   # stills: this many seconds after the tape

# ================================================================ the room
func _box(at: Vector3, size: Vector3, col: Color, rough := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough
	mi.material_override = m; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(mi); mi.global_position = ROOM + at
	return mi

# 2026-11-20（決定事項 13時7分「第11章の部屋は客間に替える」）: the interview's room (assets/interview/room.glb, 澪の実家の客間), at
# night. The deck and the set stand where the interview's did, on the low cabinet beside the tokonoma (interview.gd TV_AT, facing
# east): the room is turned so that east is toward her (+z) and lowered so that the cabinet's top is our board's (0.145).
# Its textures carry the day they were baked in; at night they are the night's: dark, a little blue, the set's light on them.
const GUEST_TV_AT := [-1.50, -0.95, 0.42]
func _guest_room() -> bool:
	if "--oldroom" in OS.get_cmdline_user_args() or not ResourceLoader.exists("res://assets/interview/room.glb"): return false
	var r: Node3D = (load("res://assets/interview/room.glb") as PackedScene).instantiate(); main.add_child(r)
	var rb := Basis(Vector3.UP, -PI / 2.0)
	var tv_g: Vector3 = rb * (Vector3(GUEST_TV_AT[0], GUEST_TV_AT[2], -GUEST_TV_AT[1]) + Vector3(0.06, 0, 0))
	# measured (2026-11-21, ユーザー「物が浮いているように見える」): set so, the cabinet's top was 3 cm over our board and its
	# front 0.37 m behind the deck. Moved so that the deck and the set stand on it, their backs to the tokonoma's wall
	r.global_transform = Transform3D(rb, ROOM + Vector3(0.0, 0.145, -0.06) - tv_g + Vector3(0.0, -0.03, 0.52))
	var night := Color(float(_arg("d11night", "0.4")), float(_arg("d11night", "0.4")) * 1.04, float(_arg("d11night", "0.4")) * 1.25)
	var hide_names := ["tape", "tape_label", "notebook", "notebook_pages", "recorder_tripo", "recorder_display", "rec_time", "cup_i", "cup_i_tea", "cup_m", "cup_m_tea"]
	for g in r.find_children("*", "MeshInstance3D", true, false):
		var m := g as MeshInstance3D
		if String(m.name) in hide_names: m.visible = false; continue
		m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for i in m.get_surface_override_material_count():
			var mat = m.get_active_material(i)
			if mat is BaseMaterial3D:
				var nm: BaseMaterial3D = mat.duplicate()
				nm.albedo_color = nm.albedo_color * night
				if nm.emission_enabled: nm.emission_energy_multiplier *= 0.1
				m.set_surface_override_material(i, nm)
	# the moon through the shoji: a low blue light over the whole room (the set does the rest)
	var moon := OmniLight3D.new(); moon.light_color = Color(0.55, 0.65, 0.95); moon.light_energy = float(_arg("d11moon", "0.35"))
	moon.omni_range = 4.0; moon.omni_attenuation = 0.8; moon.shadow_enabled = false; moon.light_specular = 0.0; moon.light_cull_mask = 1
	main.add_child(moon); moon.global_position = r.global_position + Vector3(0, 2.0, 0)
	print("TAPE guest room at ", r.global_position)
	for g in r.find_children("*", "MeshInstance3D", true, false):
		var nm := String(g.name)
		if nm.begins_with("waki") or nm.begins_with("toko_floor") or nm.begins_with("tatami0"):
			var bb: AABB = (g as MeshInstance3D).global_transform * (g as MeshInstance3D).get_aabb()
			print("TAPE part %s rel %s size %s" % [nm, bb.position - ROOM, bb.size])
	return true

func _tvbox(at: Vector3, size: Vector3, col: Color, rough := 0.5) -> MeshInstance3D:
	var mi := _box(at, size, col, rough); mi.layers = 2      # the set does not light its own face
	return mi

func _room():
	var n0: int = main.get_child_count()
	_box(Vector3(0, -0.05, 0.6), Vector3(4.0, 0.1, 4.0), Color(0.42, 0.36, 0.27))             # the floor
	_box(Vector3(0, 1.2, -0.42), Vector3(4.0, 2.6, 0.1), Color(0.62, 0.60, 0.55))             # the wall behind the set
	_box(Vector3(-2.0, 1.2, 0.6), Vector3(0.1, 2.6, 4.0), Color(0.62, 0.60, 0.55))
	_box(Vector3(2.0, 1.2, 0.6), Vector3(0.1, 2.6, 4.0), Color(0.62, 0.60, 0.55))
	_box(Vector3(0, 2.5, 0.6), Vector3(4.0, 0.1, 4.0), Color(0.5, 0.5, 0.48))
	_box(Vector3(0, 1.2, 2.6), Vector3(4.0, 2.6, 0.1), Color(0.5, 0.5, 0.48))
	# a low board on two bricks' worth of books; the deck on it, the television on the deck
	_box(Vector3(0, 0.13, -0.08), Vector3(0.95, 0.03, 0.46), Color(0.30, 0.22, 0.15))
	_box(Vector3(-0.36, 0.06, -0.08), Vector3(0.16, 0.12, 0.24), Color(0.55, 0.5, 0.42))
	_box(Vector3(0.36, 0.06, -0.08), Vector3(0.16, 0.12, 0.24), Color(0.45, 0.5, 0.52))
	var plain: Array = main.get_children().slice(n0)
	if _guest_room():
		for b in plain: (b as Node3D).visible = false
	var deck := _box(Vector3(0, 0.20, -0.06), Vector3(0.43, 0.10, 0.34), Color(0.10, 0.10, 0.11), 0.45)
	var slot := _box(Vector3(-0.035, 0.215, 0.111), Vector3(0.17, 0.028, 0.004), Color(0.03, 0.03, 0.03), 0.3)   # the slot（2026-11-14：前は「トラッキング」の字の右を隠していた）
	# 2026-11-14（ユーザー「VHSデッキはモデリングしたい」）: the user's Tripo deck (godot/props/vcr.glb, from tripo/prep_props.py),
	# drawn to the old box's size (its front toward +z); its own slot and face, our two keys and the knob on it
	if ResourceLoader.exists("res://props/vcr.glb"):
		var v: Node3D = (load("res://props/vcr.glb") as PackedScene).instantiate()
		main.add_child(v); v.scale = Vector3(0.44, 0.68, 0.44); v.global_position = ROOM + Vector3(0, 0.15, -0.06)
		for g in v.find_children("*", "GeometryInstance3D", true, false): (g as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		deck.visible = false; slot.visible = false
		# 2026-11-17（決定事項「テープは8ミリビデオ」）: the deck takes the small cassette (95 mm wide). Its own mouth is a full-size one
		# (x -0.194..-0.022 here); two dark plates close it in from both sides to an 11 cm mouth, the flap left as it is in the middle.
		for e in [[-0.1785, 0.031], [-0.0375, 0.031]]:
			_box(Vector3(e[0], 0.212, 0.102), Vector3(e[1], 0.046, 0.004), Color(0.13, 0.13, 0.14), 0.55)
	# its keys: 録画 and 取り出し at the right, each a key with its name printed over it
	for k in [[0.085, "録画", Color(0.55, 0.12, 0.08)], [0.150, "取り出し", Color(0.30, 0.30, 0.31)]]:
		_box(Vector3(k[0], 0.178, 0.112), Vector3(0.042, 0.016, 0.006), k[2], 0.5)
		var lb := Label3D.new(); lb.text = k[1]; lb.font = Type.cam(); lb.font_size = 32; lb.pixel_size = 0.00042
		lb.modulate = Color(0.82, 0.82, 0.78); lb.outline_size = 0; lb.shaded = false
		main.add_child(lb); lb.global_position = ROOM + Vector3(k[0], 0.198, 0.1115)
	# the tracking knob, at the left
	knob = MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.016; cy.bottom_radius = 0.016; cy.height = 0.012
	knob.mesh = cy; var km := StandardMaterial3D.new(); km.albedo_color = Color(0.32, 0.32, 0.33); km.roughness = 0.4; knob.material_override = km
	main.add_child(knob); knob.global_position = ROOM + Vector3(-0.175, 0.185, 0.114); knob.rotation.x = PI / 2.0
	var mark := MeshInstance3D.new(); var mb := BoxMesh.new(); mb.size = Vector3(0.003, 0.002, 0.014); mark.mesh = mb
	var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.9, 0.9, 0.85); mark.material_override = mm
	knob.add_child(mark); mark.position = Vector3(0, 0.0065, -0.008)
	var kl := Label3D.new(); kl.text = "トラッキング"; kl.font = Type.cam(); kl.font_size = 32; kl.pixel_size = 0.00036
	kl.modulate = Color(0.82, 0.82, 0.78); kl.outline_size = 0; kl.shaded = false
	main.add_child(kl); kl.global_position = ROOM + Vector3(-0.175, 0.216, 0.1115)
	# the television: a grey tube set, the glass a little back in its face
	var tv := Vector3(TV_C.x, TV_C.y, -0.10)
	_tvbox(tv + Vector3(0, -0.02, -0.02), Vector3(0.60, 0.50, 0.44), Color(0.20, 0.20, 0.21), 0.6)
	var mask := _tvbox(tv + Vector3(0, 0.0, 0.196), Vector3(0.50, 0.385, 0.012), Color(0.05, 0.05, 0.055), 0.4)    # the mask round the glass
	# 2026-11-19（ユーザー「テレビの箱がカクカクしてるのがチープ」）: the user's Tripo set (godot/props/crt_tv.glb, tripo/prep_props.py
	# crt_tv; 画像生成とTripo_7回目). Turned to her, sized so its own glass is our screen (SCR), its glass just behind ours
	if ResourceLoader.exists("res://props/crt_tv.glb") and not "--boxtv" in OS.get_cmdline_user_args():
		var body := get_meta("tvbody") as MeshInstance3D if has_meta("tvbody") else null
		for n in main.get_children():
			if n is MeshInstance3D and (n as MeshInstance3D).layers == 2: (n as MeshInstance3D).visible = false
		var t: Node3D = (load("res://props/crt_tv.glb") as PackedScene).instantiate(); main.add_child(t)
		t.rotation.y = deg_to_rad(float(_arg("d11tvyaw", "-82")))
		var bb := AABB(); var first := true
		for g in t.find_children("*", "MeshInstance3D", true, false):
			var m := g as MeshInstance3D; m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; m.layers = 2
			var b2: AABB = m.global_transform * m.get_aabb(); bb = b2 if first else bb.merge(b2); first = false
		var k := float(_arg("d11tvw", "0.597")) / bb.size.x
		t.scale = Vector3(k, k, k)
		var c := bb.get_center() * k
		t.global_position = ROOM + Vector3(-c.x + float(_arg("d11tvx", "-0.02")), 0.355 - bb.position.y * k, 0.103 + float(_arg("d11tvrec", "0.07")) - (bb.end.z * k))
		print("M220 tv aabb ", bb, " k ", k)
		tv_glass = Vector2(0.96, 0.93)
		if "--d11dbg" in OS.get_cmdline_user_args():   # a look at the set from above her right shoulder, lit
			var dc := Camera3D.new(); dc.fov = 50.0; main.add_child(dc)
			dc.global_transform = Transform3D(Basis(), ROOM + Vector3(0.9, 1.0, 1.1)).looking_at(ROOM + Vector3(0, 0.6, 0), Vector3.UP); dc.call_deferred("make_current")
			if "--d11dbgf" in OS.get_cmdline_user_args():   # straight on, orthographic: to measure the glass against the body
				dc.projection = Camera3D.PROJECTION_ORTHOGONAL; dc.size = 0.8; dc.global_transform = Transform3D(Basis(), ROOM + Vector3(0, 0.6, 1.5))
			var dl := OmniLight3D.new(); dl.light_energy = 3.0; dl.omni_range = 5.0; main.add_child(dl); dl.global_position = ROOM + Vector3(0.6, 1.4, 1.2)
	# the tape's case on the floor, its label to her
	_box(Vector3(0.52, 0.010, 0.42), Vector3(0.070, 0.020, 0.106), Color(0.12, 0.12, 0.13), 0.5).rotation.y = 0.5   # the small cassette's box (106 × 70 × 20 mm), no label
	# the only light: the screen
	glow = OmniLight3D.new(); glow.light_color = Color(0.72, 0.82, 1.0); glow.light_energy = 0.05
	glow.omni_range = 3.2; glow.omni_attenuation = 1.3; glow.shadow_enabled = true; glow.light_volumetric_fog_energy = 0.0; glow.light_specular = 0.2; glow.light_cull_mask = 1 | MIO_LAYER
	glow.set_meta("own_shadow", true); main.add_child(glow); glow.global_position = ROOM + tv + Vector3(0, 0.0, 0.50)

const SCREEN_SHADER := """shader_type spatial;
render_mode unshaded;
uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float err = 0.0;      // the tracking: 0 right .. 1 lost
uniform float tm = 0.0;
uniform float on = 0.0;       // 0 dark glass, 1 the tape, 2 the deck's blank blue (before E and after the tape), 3 the set off
uniform sampler2D refl_tex : source_color, filter_linear, repeat_disable;   // the room in the glass (rcam, mirrored)
uniform float rk = 0.0;       // how much of it the glass gives back
uniform float off_t = 0.0;    // seconds since the set went off
uniform float bulge = 0.0;   // the tube's face is a dome (the Tripo set's own glass)
void vertex() { vec2 n = UV * 2.0 - 1.0; VERTEX.z += bulge * (1.0 - 0.8 * n.x * n.x) * (1.0 - 0.8 * n.y * n.y); }
uniform vec2 glass = vec2(1.0, 1.0);   // the set's own glass, as a part of the quad (the Tripo set's opening is a little lower than 4:3)
float h(float x) { return fract(sin(x * 91.17) * 43758.5453); }
void fragment() {
	{	// the glass's rounded corners: outside it, the set's own bezel shows
		vec2 q = abs(UV - 0.5) * 2.0 - (glass - vec2(0.09, 0.12));
		if (length(max(q, 0.0)) > 0.09 && glass.y < 0.999) discard;
		if (abs(UV.y - 0.5) * 2.0 > glass.y) discard;
	}
	vec2 uv = UV;
	float ln = floor(uv.y * 240.0);
	// off its track the heads read between two fields: bands of lines sheared sideways roll up the picture, the bands
	// wider and more of them the further off; whole picture slides and its top hooks over
	float roll = fract(uv.y * 1.6 + tm * 0.23);
	float band = smoothstep(0.0, 0.04, roll) * (1.0 - smoothstep(0.10 + 0.55 * err, 0.16 + 0.6 * err, roll));
	float tear = (h(ln * 0.37 + floor(tm * 24.0)) - 0.5) * 0.34 * err * band;
	tear += 0.05 * err * sin(uv.y * 31.0 + tm * 5.0);
	tear += 0.08 * smoothstep(0.92, 1.0, uv.y) * (0.25 + err) * (h(ln + floor(tm * 12.0)) - 0.2);   // the head switch, at the foot, always
	uv.x += tear;
	uv.y = mix(uv.y, fract(uv.y + 0.18 * sin(tm * 0.7)), step(0.75, err));
	vec3 c = texture(tex, uv).rgb;
	float out_x = step(uv.x, 0.0) + step(1.0, uv.x);
	c = mix(c, vec3(0.02), clamp(out_x, 0.0, 1.0));
	c = mix(c, vec3(dot(c, vec3(0.3, 0.6, 0.1))) * 1.15 + 0.06, band * err);      // in the band the colour goes and the black lifts
	if (on < 0.5) c = vec3(0.012, 0.014, 0.018);
	if (on > 1.5) c = vec3(0.10, 0.16, 0.42);
	if (on > 2.5) {
		// the dead glass: dark grey, and the room in it; a tube's face bulges, so it holds a wider room, smaller at the edges
		vec2 d = UV - 0.5;
		vec2 ru = 0.5 + d / 1.35 * (0.8 + 0.9 * dot(d, d));
		vec3 r = texture(refl_tex, vec2(1.0 - ru.x, ru.y)).rgb;
		float edge = 1.0 - smoothstep(0.30, 0.62, length(d * vec2(1.0, 1.25)));
		c = vec3(0.018, 0.020, 0.022) + rk * r * (0.55 + 0.45 * edge);
		// going off: the picture falls to a line, the line to a point, the point fades
		float ln = exp(-pow((UV.y - 0.5) / max(0.004, 0.5 * (1.0 - off_t / 0.12)), 2.0)) * step(off_t, 0.12);
		float pt = exp(-dot(d, d) / 0.0009) * (1.0 - smoothstep(0.12, 1.4, off_t)) * step(0.12, off_t);
		c += vec3(0.8, 0.85, 0.9) * (ln + pt);
	}
	ALBEDO = c;
}"""

func _screen():
	vp = SubViewport.new(); vp.size = Vector2i(768, 576); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	add_child(vp)
	tcam = Camera3D.new(); tcam.fov = FINDER_FOV; tcam.near = 0.03; tcam.far = 60.0
	main.set_meta("shadow_eye", tcam)   # 2026-11-14 重さ：家の影は、テレビの中のカメラの近くの明かりだけ（main._shadow_budget）
	var at := CameraAttributesPractical.new(); tcam.attributes = at
	at.exposure_multiplier = 3.0       # the camcorder's gain is up in the dark: it has what her eyes did not
	vp.add_child(tcam); tcam.global_transform = _rail_cam(); tcam.current = true
	fixed_cam.visible = false          # the camera does not see itself
	# what the camcorder burned into its own picture, and what the deck writes over it
	var ui := Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); vp.add_child(ui)
	var mk = func(txt: String, pos: Vector2, fs: int) -> Label:
		var lb := Label.new(); lb.text = txt; lb.add_theme_font_override("font", Type.cam()); lb.add_theme_font_size_override("font_size", fs)
		lb.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9)); lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		lb.add_theme_constant_override("shadow_offset_x", 2); lb.add_theme_constant_override("shadow_offset_y", 2)
		lb.position = pos; ui.add_child(lb); return lb
	stamp = mk.call("AM 3:29:54", Vector2(566, 34), 32)
	osd = mk.call("再生", Vector2(44, 34), 32)
	osd_trk = mk.call("", Vector2(44, 78), 32)
	var q := MeshInstance3D.new(); var qm := PlaneMesh.new(); qm.size = SCR; qm.orientation = PlaneMesh.FACE_Z; qm.subdivide_width = 16; qm.subdivide_depth = 12; q.mesh = qm
	var sh := Shader.new(); sh.code = SCREEN_SHADER
	scr_mat = ShaderMaterial.new(); scr_mat.shader = sh
	scr_mat.set_shader_parameter("tex", vp.get_texture())
	scr_mat.set_shader_parameter("glass", tv_glass)
	if tv_glass.y < 0.999: scr_mat.set_shader_parameter("bulge", float(_arg("d11bulge", "0.05")))
	q.material_override = scr_mat; q.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; q.layers = SCR_LAYER
	if "--d11dbgf" in OS.get_cmdline_user_args(): q.visible = false
	main.add_child(q); q.global_position = ROOM + Vector3(TV_C.x, TV_C.y, 0.103)
	tcam.cull_mask &= ~MIO_LAYER
	# 試作220：the glass as a mirror. A camera at her eye reflected through the glass, looking back out through it
	rvp = SubViewport.new(); rvp.size = Vector2i(640, 480); rvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	rvp.msaa_3d = Viewport.MSAA_2X; add_child(rvp)
	rcam = Camera3D.new(); rcam.projection = Camera3D.PROJECTION_FRUSTUM; rcam.cull_mask = 0xFFFFF & ~(2 | SCR_LAYER)
	rcam.far = 8.0; rvp.add_child(rcam)
	scr_mat.set_shader_parameter("refl_tex", rvp.get_texture())

# where the mirror camera stands for an eye at e (the glass is the plane z = 0.103 in the room, facing +z)
func _mirror_cam(e: Vector3):
	var gz := ROOM.z + 0.103
	var m := Vector3(e.x, e.y, 2.0 * gz - e.z)
	rcam.global_transform = Transform3D(Basis(Vector3.UP, PI), m)     # it looks along +z, out of the glass
	var dist := gz - m.z
	var c := ROOM + Vector3(TV_C.x, TV_C.y, 0.103)
	rcam.keep_aspect = Camera3D.KEEP_HEIGHT
	rcam.near = dist; rcam.size = SCR.y * 1.35
	rcam.frustum_offset = Vector2(-(c.x - m.x), c.y - m.y) * 1.0

# her body for the glass: the seated Mio of the interview (tripo/interview/mio_seiza.glb), turned to the set, her eyes at the
# camera's place (the model's eyes: x 0, y 1.465, z 0.17 in its own room, facing +z)
func _mio_body():
	var path := "res://props/mio_seiza.glb"
	if not ResourceLoader.exists(path): print("M220 no mio body"); return
	mio_n = (load(path) as PackedScene).instantiate(); main.add_child(mio_n)
	# the glb's own nodes carry turns and offsets: measure her where she lands, turn her to the set, then put her eyes at the camera
	mio_n.global_transform = Transform3D(Basis(), ROOM)
	var hb := _mio_box("mio_head"); var nb := _mio_box("mio_hands")
	if nb.get_center().z > hb.get_center().z:     # she faces +z: turn her about her own head
		var hc := hb.get_center()
		mio_n.global_transform = Transform3D(Basis(Vector3.UP, PI), hc + Basis(Vector3.UP, PI) * (ROOM - hc))
		hb = _mio_box("mio_head")
	var eye := Vector3(hb.get_center().x, hb.position.y + hb.size.y * float(_arg("d11eyeh", "0.55")), hb.position.z + 0.03)
	mio_n.global_position += ROOM + Vector3(EYE.x + seat_x, EYE.y, EYE.z) - eye
	for mi in mio_n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = MIO_LAYER; (mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	print("M220 mio head ", _mio_box("mio_head"), " hands ", _mio_box("mio_hands"), " body ", _mio_box("mio_body"))

func _mio_box(n: String) -> AABB:
	var mi := mio_n.find_child(n, true, false) as MeshInstance3D
	return mi.global_transform * mi.get_aabb() if mi else AABB(mio_n.global_position, Vector3.ZERO)

# the one other light in the room: a door left ajar on a lit passage (behind her in a, at her left in b–d)
var pass_light: OmniLight3D
func _back_light():
	var at := Vector3(-0.45, 0.0, 2.54) if refl == "a" else Vector3(-1.94, 0.0, 1.05)
	var sz := Vector3(0.07, 1.95, 0.02) if refl == "a" else Vector3(0.02, 1.95, 0.07)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(1.0, 0.86, 0.66)
	mi.material_override = m; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; main.add_child(mi)
	mi.global_position = ROOM + at + Vector3(0, sz.y * 0.5, 0)
	pass_light = OmniLight3D.new(); pass_light.light_color = Color(1.0, 0.84, 0.62)
	pass_light.light_energy = float(_arg("d11door", "0.8" if refl == "a" else "0.35")); pass_light.omni_range = 4.5; pass_light.omni_attenuation = 1.2
	pass_light.shadow_enabled = true; pass_light.light_cull_mask = 1 | MIO_LAYER; pass_light.light_specular = 0.3
	pass_light.set_meta("own_shadow", true); main.add_child(pass_light)
	pass_light.global_position = ROOM + at + Vector3(0.0 if refl == "a" else 0.25, 1.15, -0.25 if refl == "a" else 0.0)
	# the last cut of d: from the set's side, at her face
	look_cam = Camera3D.new(); look_cam.fov = 30.0; main.add_child(look_cam)
	look_cam.global_transform = Transform3D(Basis(), ROOM + Vector3(seat_x + 0.05, 0.60, 0.16)).looking_at(ROOM + Vector3(seat_x, EYE.y - 0.02, EYE.z), Vector3.UP)
	look_cam.cull_mask = 0xFFFFF & ~(2 | SCR_LAYER)
	if refl == "e":   # the set's-side picture, drawn apart and laid over the view as it dissolves in (under the print)
		face_vp = SubViewport.new(); face_vp.size = get_viewport().get_visible_rect().size; face_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(face_vp); main.remove_child(look_cam); face_vp.add_child(look_cam); look_cam.current = true
		look_cam.global_transform = Transform3D(Basis(), ROOM + Vector3(seat_x + 0.05, 0.60, 0.16)).looking_at(ROOM + Vector3(seat_x, EYE.y - 0.02, EYE.z), Vector3.UP)
		var fl := CanvasLayer.new(); fl.layer = 9; add_child(fl)
		face_tr = TextureRect.new(); face_tr.texture = face_vp.get_texture(); face_tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		face_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; face_tr.modulate.a = 0.0; face_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE; fl.add_child(face_tr)
	pan_cam = Camera3D.new(); pan_cam.fov = float(_arg("d11panfov", "38")); main.add_child(pan_cam)
	pan_cam.cull_mask = 0xFFFFF   # it sees the set from outside, and her
	pan_cam.global_transform = Transform3D(Basis(), ROOM + PAN_AT)

func _pan_yaw(k: float) -> float:
	# from the dead glass to her face
	var a := ROOM + Vector3(TV_C.x - 0.02, TV_C.y, 0.10) - pan_cam.global_position
	var b := ROOM + Vector3(seat_x, EYE.y - 0.03, EYE.z) - pan_cam.global_position
	var ya := atan2(-a.x, -a.z); var yb := atan2(-b.x, -b.z)
	return lerp_angle(ya, yb, k)

func _arg(k: String, dflt: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % k): return a.substr(k.length() + 3)
	return dflt

# ================================================================ time
func _target_trk(t: float) -> float:
	# where the knob has to be: the tape was stretched in two places, so it wanders twice
	return 0.62 + 0.11 * smoothstep(20.0, 25.0, t) - 0.16 * smoothstep(29.5, 33.0, t)

func _err() -> float:
	return clampf(absf(trk - _target_trk(tape_t)) / 0.30, 0.0, 1.0)

func _clock(dt: float) -> bool:
	if card11_t > 0.0:
		card11_t -= dt; player.look_enabled = false
		if card11_t <= 0.0: card11.visible = false; player.look_enabled = true
		return false
	card11.visible = false
	room_t += dt
	_room_tick(dt)
	if st != PLAYING: return false
	# 2026-11-20: the tape from 0:20 (the second cassette's head). Before 3:29:54 and after the night's 61 s the hall is
	# still (the 第4章 night does not run): the 2:30 part from the record, Makoto's voice at 4:00. Ｆ held runs it fast.
	var ff := Input.is_key_pressed(KEY_F) or demo_ff
	ff_on = ff and not (night_n >= N330 - 1.0 and not post)
	var rate := FF_RATE if ff_on else 1.0
	if night_n < N330 or post:
		night_n += dt * rate
		if not post and night_n >= N330: night_n = N330; tape_t = 0.0; clock = NIGHT_AT; _hall_mio_pose("gone"); return true
		_pre_tick(dt)
		_typing(dt)
		if post and night_n >= N_END: _end_tape()
		return false
	tape_t += dt
	night_n = N330 + tape_t
	clock = tape_t + NIGHT_AT; t_now = clock
	return true

func _room_tick(dt: float):
	var cam: Camera3D = player.get_node("Head/Camera")
	var deck_at := ROOM + Vector3(0, 0.20, 0.11)
	var at_deck: bool = (-cam.global_basis.z).angle_to(deck_at - cam.global_position) < deg_to_rad(14.0)
	var e := _err()
	if ff_on: e = maxf(e, 0.8)   # the picture tears while it runs fast
	scr_mat.set_shader_parameter("tm", room_t)
	scr_mat.set_shader_parameter("err", e)
	# 試作220：before E the set is on the deck's blue (never the dead glass); off only at the end
	scr_mat.set_shader_parameter("on", 1.0 if st == PLAYING else (3.0 if off_t >= 0.0 else 2.0))
	glow.light_energy = 0.55 if st == PLAYING else (0.0 if off_t > 0.12 else 0.8)
	if off_t >= 0.0:
		off_t += dt
		scr_mat.set_shader_parameter("off_t", off_t)
		scr_mat.set_shader_parameter("rk", float(_arg("d11rk", "1.4" if refl == "a" else ("1.5" if refl == "c" else "1.1"))))
		_mirror_cam(get_viewport().get_camera_3d().global_position if not pan else cam.global_position)
		rvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	knob.rotation.z = (trk - 0.5) * 4.4
	player.look_enabled = not on_knob and st != ENDED
	match st:
		ROOM_WAIT:
			note_lb.text = T(String(B("十一.部屋")[0].note)) if at_deck else ""
			if demo11 and room_t > 3.0:
				player.pitch = lerp(player.pitch, deg_to_rad(-38.0), 1.0 - exp(-dt * 3.0))
				if at_deck and room_t > 5.0: _play()
		PLAYING:
			var G: Array = B("テープ.案内")
			# 2026-11-21 (review): the fast-forward was never told; before 3:30 a clear picture shows it
			if on_knob: note_lb.text = T(String(G[1].note))
			elif e > 0.2: note_lb.text = T(String(G[0].note))
			elif night_n < N330 and not ff_on and G.size() > 2: note_lb.text = T(String(G[2].note))
			else: note_lb.text = ""
			if tape_t < 1.6:                     # the key pressed, her eyes go back up to the picture
				var ku := 1.0 - exp(-dt * 4.0)
				player.yaw = lerp_angle(player.yaw, 0.0, ku); player.pitch = lerp(player.pitch, deg_to_rad(-7.0), ku)
			osd_trk.text = ("トラッキング " + "-".repeat(int(trk * 16.0)) + "|" + "-".repeat(16 - int(trk * 16.0))) if on_knob else ""
			var ns := N0 + int(night_n)
			stamp.text = "AM %d:%02d:%02d" % [ns / 3600, (ns / 60) % 60, ns % 60]
			osd.text = "▶▶" if ff_on else "再生"
			osd.visible = ff_on or room_t - play_room_t < 4.0 or (tape_t >= 0.0 and tape_t < 4.0 and not post)
			_tape_swing(dt)
			if demo11: _demo11(dt)
		ENDED:
			end_t2 += dt
			note_lb.text = ""
			# her eyes go down to the deck's two keys; the set goes off; her eyes come back up to the glass (試作220)
			if end_t2 > 2.0 and end_t2 < 9.5:
				var k := 1.0 - exp(-dt * 1.6)
				player.yaw = lerp_angle(player.yaw, deg_to_rad(-8.5), k); player.pitch = lerp(player.pitch, deg_to_rad(-36.5), k)
				cam.fov = lerp(cam.fov, 17.0, k * 0.7)
			if end_t2 > 8.0 and off_t < 0.0: off_t = 0.0; print("STORY ch11 set off")
			if end_t2 > 9.5:
				var k := 1.0 - exp(-dt * (0.55 if refl == "e" else 1.1))   # e: slowly
				player.yaw = lerp_angle(player.yaw, 0.0, k); player.pitch = lerp(player.pitch, deg_to_rad(-7.0), k)
				cam.fov = lerp(cam.fov, 34.0, k)
			if pan and end_t2 > 9.5:
				if not pan_cam.current: pan_cam.current = true; print("STORY ch11 pan cam")
				var pk := smoothstep(11.5, 16.0, end_t2)
				pan_cam.global_transform = Transform3D(Basis(Vector3.UP, _pan_yaw(pk)) * Basis(Vector3.RIGHT, deg_to_rad(-4.0)), ROOM + PAN_AT)
			if refl == "e":
				# 2026-11-19 21時（ユーザー「映りこませる画面、いまより+1秒、ディゾルブも+1秒、テレビ側から澪を捉えたショットは+2秒。
				# そこからエンドロール。仮の文字を1分流して。音（音楽の冗談）を入れて」）
				if end_t2 > 16.0: face_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				face_tr.modulate.a = smoothstep(16.5, 19.5, end_t2)
				if end_t2 > CREDITS_AT and black2.color.a < 1.0:
					black2.color.a = 1.0; print("STORY ch11 black (e)"); _credits()
				if credits: credits.position.y = lerp(credits_y0, -credits.size.y, clampf((end_t2 - CREDITS_AT) / CREDITS_LEN, 0.0, 1.0))
			if refl == "d" and end_t2 > 10.0 and not look_cam.current:
				look_cam.current = true; print("STORY ch11 her face")
			if end_t2 > (CREDITS_AT + CREDITS_LEN if refl == "e" else 22.0) and (refl == "e" or not has_meta("endstill")):
				st = BLACK; black2.color.a = 1.0
				print("STORY ch11 black room_t=%.1f heard %d/%d" % [room_t, heard_clear, heard_all])
		BLACK:
			end_t2 += dt
			if demo11 and end_t2 > 12.0:
				print("DEMO DONE t=%.1f fails=%d (ch11, heard %d/%d)" % [room_t, DEMO_FAILS, heard_clear, heard_all]); demo11 = false
				if "--demoquit" in OS.get_cmdline_user_args(): get_tree().quit()

func _play():
	st = PLAYING; tape_t = 0.0; play_room_t = room_t
	if not jumped: night_n = 0.0; tape_t = -1.0; _pre_build()
	for a in OS.get_cmdline_user_args():   # check stills: the tape from this count on (N230 = 2:30)
		if a.begins_with("--ch11n="): night_n = float(a.substr(8))
	note_lb.text = ""
	print("STORY ch11 play room_t=%.1f" % room_t)

func _end_tape():
	_tape_close()
	st = ENDED; end_t2 = float(get_meta("endat", 0.0))
	_clear_page(); cur = {}
	print("STORY ch11 tape end t=%.1f" % tape_t)

# ================================================================ what the night does on the tape
func _do4(what: String):
	match what:
		"strike", "strike2":
			if not _swing_rec().is_empty(): return   # the record's own blows are on their way (_tape_queue)
			tswing = 0.0; tswings += 1; tswing_what = "head"
		"end": _end_tape()
		"after": post = true; print("STORY ch11 after t=%.1f" % tape_t)
		_: super._do4(what)

# Mio is under the camera, out of its frame. The tripod is in her hands from the second she took it up in 第4章;
# what the tape has of her is the tripod coming into the frame, twice.
# the night as she played it: her swings at 3:30 (fps.gd rec_swings), placed so her first blow to the head comes when
# the script's first strike does. Nothing kept (a chapter reached from the menu): the two strikes of the script.
func _swing_rec() -> Array:
	var r = get_flag("swing_0330", null)
	if not (r is Array) or r.is_empty(): return []
	var first := -1
	for i in r.size():
		if String(r[i][1]) == "head": first = i; break
	return r if first >= 0 else []

var tqueue_made := false
func _tape_queue():
	if tqueue_made: return
	tqueue_made = true
	var r := _swing_rec()
	if r.is_empty(): return
	var t0 := 0.0
	for e in r:
		if String(e[1]) == "head": t0 = float(e[0]); break
	var strike_at := 46.0 + NIGHT_AT
	for e in LINES:
		if e.size() > 2 and e[1] == "do" and e[2] == "strike": strike_at = float(e[0]); break
	# 2026-11-21 (review): the night's gaps squeezed into the tape's minute: at most three swings before her first blow
	# to the head, within 2.4 s of it, the rest within 4 s after it, never before she has the tripod (TAPE_TAKE);
	# fewer than two blows to the head (a record cut short): the script's second strike stands in
	var before := []; var after := []
	for e in r: (before if float(e[0]) < t0 else after).append(e)
	before = before.slice(maxi(0, before.size() - 3))
	var span_a := 0.0
	for e in after: span_a = maxf(span_a, float(e[0]) - t0)
	var ka := 1.0 if span_a <= 4.0 else 4.0 / span_a
	var span_b := 0.0
	for e in before: span_b = maxf(span_b, t0 - float(e[0]))
	var kb := 1.0 if span_b <= 2.4 else 2.4 / span_b
	for e in before: tqueue.append([maxf(TAPE_TAKE + 0.3, strike_at - (t0 - float(e[0])) * kb), String(e[1])])
	var heads := 0
	for e in after:
		tqueue.append([strike_at + (float(e[0]) - t0) * ka, String(e[1])])
		if String(e[1]) == "head": heads += 1
	if heads < 2: tqueue.append([strike_at + 1.2, "head"]); tqueue.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	print("STORY ch11 swings from the night: ", tqueue.size())

func _tape_swing(dt: float):
	_tape_queue()
	if not tqueue.is_empty() and tswing < 0.0 and clock >= float(tqueue[0][0]):
		tswing = 0.0; tswings += 1; tswing_what = String(tqueue[0][1]); tqueue.pop_front()
	if clock < TAPE_TAKE: return   # 2026-11-14: she takes it up only after Natsuki has caught her sleeve and her hand has hit it
	if weapon.get_parent() != main:
		weapon.get_parent().remove_child(weapon); main.add_child(weapon)
	var hands := gp(TAPE_MIO[0] + 0.12, TAPE_MIO[1] - 0.25, 1.18)
	var tgt := gp(NPATH[-1][0], NPATH[-1][1], 1.5) if nstate == "out" else _nhead()
	var dir := tgt - hands; dir.y = 0.0; dir = dir.normalized()
	var ang := -0.22                       # held upright against her shoulder
	if tswing >= 0.0:
		tswing += dt
		var k := tswing / 0.9
		if k < 0.3: ang = lerp(-0.22, -0.75, smoothstep(0.0, 0.3, k))
		elif k < 0.5: ang = lerp(-0.75, 1.55, pow((k - 0.3) / 0.2, 2.0))
		else: ang = lerp(1.55, -0.22, smoothstep(0.5, 1.0, k))
		if k >= 0.44 and not swing_hit:
			swing_hit = true
			if tswing_what != "miss": _blow(tswing_what == "head")
		if k >= 1.0: tswing = -1.0; swing_hit = false
	var axis := Vector3.UP.cross(dir).normalized()
	weapon.global_transform = Transform3D(Basis(axis, ang) * Basis(Vector3.UP, atan2(dir.x, dir.z)), hands) * Transform3D(Basis(), Vector3(0, -0.42, 0))

func _blow(head: bool):
	if not head or head_hits >= 2:   # to the body she rocks; once she is down, the tripod comes down on the boards beside her
		Sound.one(self, "hit", -9.0, _nhead())
		print("STORY ch11 blow %s tape_t=%.1f" % ["body" if not head else "again", tape_t])
		return
	head_hits += 1
	nap.pause(); nwalk = false
	if head_hits == 1: hit_base = Transform3D(Basis(Vector3.UP, nrig.global_rotation.y), nrig.global_position)
	nbase = hit_base
	if head_hits == 1: _capture(); nstate = "reel"; reel_t = 0.0
	else: reel_pose = last_pose.duplicate(true); nstate = "down"; fall_t = 0.0
	print("STORY ch11 blow %d tape_t=%.1f" % [head_hits, tape_t])

# ================================================================ the words, as far as the tracking lets them through
func _event(e: Array):
	match e[1]:
		"do": _do4(e[2])
		"note":
			_tape_close()
			if demo11: print("SAY %.1f %s" % [tape_t, e[2]])
			_line_row("", T(e[2]) if _err() < 0.45 else T("（雑音）"), 26, "note")
		"say":
			_tape_close()
			named.erase(e[2]); last_who = ""          # every line of a tape's transcript carries who says it
			var r = _line_row(e[2], "")
			tline = {"lb": r[1], "who": e[2], "text": Tw(e[3]), "written": 0.0, "n": 0, "n_all": 0, "n_clear": 0}
			rrow = {"segs": []}

func _typing(dt: float):
	if not tline.has("lb") or not is_instance_valid(tline.lb): return
	var text: String = tline.text
	if tline.n >= text.length(): return
	tline.written += dt * 9.0             # as it is said, not as a transcript is typed
	var e := _err()
	while tline.n < int(tline.written) and tline.n < text.length():
		var ch := text[tline.n]; tline.n += 1
		if ch == ZW: _seg("ok", ch); continue
		# the tracking, moment by moment: the dropouts come in clumps, as the radio's did
		var wob := 0.5 + 0.5 * sin(tape_t * 4.7 + 2.0 * sin(tape_t * 1.9)) * sin(tape_t * 0.83 + 1.0)
		var clear: bool = (1.0 - e) + 0.25 * (wob - 0.5) > 0.72
		if ch in "、。……？！　『』": _seg("ok" if clear or e < 0.6 else "gap", ch if clear or e < 0.6 else ""); continue
		tline.n_all += 1
		if clear: tline.n_clear += 1; _seg("ok", ch)
		elif e > 0.75: _seg("noise", "")
		else: _seg("gap", "")
	(tline.lb as Label).text = _wrap_row(_segs_text(rrow.segs))

func _tape_close():
	if tline.has("lb"):
		heard_all += tline.n_all; heard_clear += tline.n_clear
		print("SAY %.1f %s：%s  (clear %d/%d)" % [tape_t, tline.who, String(tline.text).replace(ZW, ""), tline.n_clear, tline.n_all])
	tline = {}

# ================================================================ her hands
func _unhandled_input(e):
	if card11.visible or st in [ENDED, BLACK]: return
	if st == ROOM_WAIT:
		var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		if press and note_lb.text != "": _play()
		return
	if st == PLAYING and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E and post:
		_end_tape(); return   # 2026-11-20: she may stop it once the 3:30 minute has played (2026-11-21: not before it, or the chapter ended without it)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT: on_knob = e.pressed
	elif e is InputEventMouseMotion and on_knob and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		trk = clampf(trk + e.relative.x * 0.0006, 0.0, 1.0)
	elif on_knob and e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		trk = clampf(trk + (0.004 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -0.004), 0.0, 1.0)

# stills: the tape at t seconds
func _tape_jump(t: float):
	jumped = true; night_n = N330 + t
	_play()
	player.pitch = deg_to_rad(-7.0)   # 試作220：the chapter starts looking down at the deck; a still of the tape is of the picture
	trk = float(get_meta("trk", _target_trk(t)))
	var placed_n := false
	var place = func():
		var j := 0
		for i in range(NPATH.size() - 1):
			if t + NIGHT_AT > float(NPATH[i][3]) + 3.0: j = i + 1
		ni = j + 1
		var at := gp(NPATH[j][0], NPATH[j][1], NPATH[j][2])
		var m := _mio_eye() - at
		nrig.global_transform = Transform3D(Basis(Vector3.UP, atan2(m.x, m.z) if j >= 2 else 0.0), at)
		_drops_upto(j)
		nap.play("walk/walk"); nap.seek(0.3, true); nap.pause(); nstate = "stand"
	while li < LINES.size() and float(LINES[li][0]) <= t + NIGHT_AT:
		clock = float(LINES[li][0]); tape_t = clock - NIGHT_AT
		var e: Array = LINES[li]; li += 1
		if e[1] == "do" and e[2] in ["strike", "strike2"]:
			if not placed_n: place.call(); placed_n = true
			if t >= tape_t + HIT_LAG: _blow(true); reel_t = 9.0; fall_t = 9.0 if head_hits > 1 else -1.0
			else: tswing = t - tape_t
			continue
		_event(e)
		if tline.has("lb"): tline.written = 999.0; _typing(0.0)
	if door_t >= 0.0: door_t = 10.0
	if nstate in ["stand", "walk"] and not placed_n: place.call()
	tape_t = t; clock = t + NIGHT_AT

# the unattended run: her hand goes to the knob when the picture tears, and finds the place
func _demo11(dt: float):
	demo_ff = (night_n < N230 - 3.0) or (night_n > N230 + 72.0 and night_n < N330 - 4.0) or (post and night_n < N400 - 3.0) or (post and night_n > N400 + 12.0)
	var want := _target_trk(tape_t)
	var off := absf(trk - want)
	if off > 0.05 and held_since < 0.0 and room_t - play_room_t > 3.0: held_since = room_t
	on_knob = held_since >= 0.0 and room_t - held_since > 1.2
	if on_knob:
		trk = move_toward(trk, want, dt * 0.09)
		if absf(trk - want) < 0.004: held_since = -1.0; on_knob = false
