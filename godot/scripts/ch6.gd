## ステップ F：第6章「片づけ」 4時20分〜5時（docs/資料/第6章の設計_2026-11-18.md）。台詞は story/ch6.txt。
## 家まるごとの4時半の光（main の t0430）で動く。main.gd が play="ch6" で作る。第5章（ch5.gd）の舞台をそのまま使う：
## 倒れた夏希と肩までの毛布、足もとの三脚、はがし終えた一階のテープ、少し開いた地下の扉、澪の手のろうそく。
##
## 澪は一言も言わない。調べる（Ｅ）と、ふつうの物はいまの一行（【見る.＊】）。合わない物（カメラ、夏希、袖）は、
## 前の章の行が時刻の見出しと一緒に、線なしでページに戻ってくる（↩）。もう一度 Ｅ で手が動き、終わると、戻ってきた
## 行に線が引かれ（×）、代わりに残る行が出る。三脚には戻る行が無い。箱は片づけられない。
## 片づけの手を一つ終えるたびに、夜が一段明ける（＞dawn）。袖のあと、座る（序章の最初の画と同じ場所）。そこから
## 結び：発電機が止まり、車が来て、ノック、澪が自分の手で扉を開ける（序章の続き。ch0.gd の車と警察官を、ここに同じ形で持つ）。
extends "res://scripts/ch5.gd"

func _sixth() -> bool: return true
const SIT6 := [4.42, 3.42]            # ch0.gd SIT_AT: where the game's first picture finds her
const SIT_EYE6 := 0.86
const STAND_EYE6 := 1.52
const KNEEL_EYE := 0.95
const TAP := [7.42, 7.78, 1.02]       # the kitchen's tap (plan), over the sink
const BAG_AT := [4.18, 4.55]          # the tripod's bag, with the crew's things by the stair's foot
const FRONT6 := [5.0, 0.02, 1.05]
const OPEN_DEG6 := 74.0
const DAWN_EXP := [0.56, 0.64, 0.72, 0.80, 0.90, 1.0]   # the eye's exposure by the tidying done (the house's light is 4:30's)
# what she can look at (してもしなくてもよい): key, the node in env.glb (its place; the plan point if not found), plan point, name, block
const LOOKS := [
	["shoes", "", [5.1, 0.75, 0.05], "靴", "見る.靴"],
	["mark", "", [5.15, 2.2, 0.0], "床のテープ", "見る.床のテープ"],
	["cellar", "", [5.5, 5.62, 1.0], "地下の扉", "見る.地下の扉"],
	["radio", "", [4.30, 2.42, 0.27], "ラジオ", "見る.ラジオ"],
	["screen", "furn_screen", [0.42, 2.0, 1.3], "スクリーン", "見る.スクリーン"],
	["back", "", [9.87, 4.88, 1.0], "勝手口", "見る.勝手口"],
	["peeled", "", [6.6, 7.55, 0.93], "テープ", "見る.はがしたテープ"],
	["lantern", "", [4.97, 3.50, 1.50], "ランタン", "見る.ランタン"],
	["hoodie", "natsuki_hoodie", [1.25, 0.6, F2 + 0.66], "上着", "見る.上着"],
	["bag_n", "bag_natsuki", [2.75, 0.55, F2 + 0.15], "鞄", "見る.夏希の鞄"],
	["window", "", [1.5, 0.06, F2 + 1.3], "窓", "見る.窓"],
	["makeup", "makeup_box", [3.6, 5.0, F2 + 0.78], "道具箱", "見る.メイク道具"],
	["case", "case_cam", [2.6, 4.65, F2 + 0.18], "ケース", "見る.カメラのケース"],
	["shiori", "bag_taiga", [1.0, 6.15, F2 + 0.28], "鞄", "見る.しおり"],
	["food", "crew_crate", [2.55, 6.05, F2 + 0.22], "箱", "見る.食料"],
	["torch", "torch_kiryu", [2.85, 4.75, F2 + 0.36], "懐中電灯", "見る.懐中電灯"],
	["bed_m", "bed3_blanket", [7.6, 1.2, F2 + 0.55], "ベッド", "見る.真琴のベッド"],
	["sweets", "bag_makoto", [7.3, 0.5, F2 + 0.2], "鞄", "見る.お菓子"],
	["reflector", "makoto_reflector", [9.9, 3.75, F2 + 0.33], "レフ板", "見る.レフ板"],
]

var done6 := {}                # tripod, cam, batt, phone, box, sleeve, uptape: the hands' work that is finished
var act := ""                  # the hands' work now ("" = she walks and looks)
var step := 0
var act_t := 0.0
var targets: Array = []        # {k, pos, reach, deg, ok: Callable, name: Callable, press: Callable}
var tgt := {}
var looked := {}
var dawn_n := 0
var exp_now := 0.56
var exp_want := 0.56
var candle_off := Vector3(0.2, -0.36, -0.42)
var candle_out := false
var eye_tw: Tween
var rig6: Node3D               # rides the camera: her hands, and what they hold
var hand_l: Node3D
var hand_r: Node3D
var demo6 := false
var hold_demo := false         # the unattended run holds Ｅ
var start6 := ""
var flow: Array = []           # a timed block running: [[t, entry]]
var flow_t := 0.0
var flow_done: Callable
var phone_st := 0               # 0 not looked at | 1 the lines are back | 2 found, flat (in her pocket) | 8 done
var has_pack := false          # Mio's spare battery, from her bag upstairs
var can_stand := false
var stand_t := -1.0
var up_air := 0.0              # 0..1: the bad air upstairs (the tape Kiryu put on is still there)
var lp: AudioEffectLowPassFilter
var lp_i := -1

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = ["警察官"]
	FPS.load_story("ch6")
	_page()
	_ret_page()
	for k in ["kiryu", "taiga", "natsuki", "mio", "yota", "makoto"]: _hide(k)
	_natsuki()
	main.phones(false)
	main.TALK = {}
	_tripod()
	_lantern()
	if lantern: lantern.light_energy = 0.2   # its battery nearly gone (ch0.gd LANTERN_E)
	_gaps()
	for gq in gaps: _peel(gq, true)          # 第5章: she took them all off downstairs
	_candle()
	candle.visible = true; candle_held = true
	_gen_fore(); _gen_loud(); gen_db = -9.0
	_blanket_on()
	start_at = "end"                         # ch5._doors: the cellar's door left ajar behind Makoto
	call_deferred("_doors")
	_rail_camera()
	_hands()
	_props6()
	_targets6()
	_body_shadow()
	_board(); has_board = true   # 試作175 B4: Kiryu's board from 第1章, its margin keeps what is left of the first three (Tab)
	_air_bus()
	demo6 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	demo5 = false; demo_on = demo6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch6at="): start6 = a.substr(8)   # check stills and a part's playthrough (see _jump6)
		if a == "--c6names": call_deferred("_names_dbg")
		if a == "--c6grip" or a == "--c6fit": grip6 = a.substr(4)   # check only: scripts/grip_lab.gd
		if a.begins_with("--c6bench="): _after(3.0, _bench.bind(a.substr(10)))   # check only: try grips of the things she holds, one by one (scripts/grip_lab.gd)
		if a.begins_with("--c6probe="): probe6 = a.substr(10)   # check only: look at the hands from the side (does a finger pass through what it holds)
	var c: Array = D.lines("六.カード")
	card = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	card_t = 2.75; card_next = "t420card"
	if start6 != "": card_t = 0.3; card_next = "jump"
	stage = "card"
	# where 第5章 left her: on her knees by Natsuki's head; she gets up when the chapter starts
	player.global_position = gp(4.6, 3.3, 0.0); player.velocity = Vector3.ZERO
	_look_from([4.6, 3.3], [4.5, 2.4], STAND_EYE6, 0.2)
	if main.env: main.env.tonemap_exposure = exp_now
	print("STORY ch6 start=", start6)

func _names_dbg():
	await get_tree().physics_frame
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		var c := bb.get_center()
		print("C6NAME %s plan(%.2f, %.2f, %.2f) size(%.2f, %.2f, %.2f) vis=%s" % [mi.name, c.x + 4.8, c.z + 6.3, c.y, bb.size.x, bb.size.z, bb.size.y, (mi as Node3D).is_visible_in_tree()])

# ---------------------------------------------------------------- the stage's own things
func _eye(h: float, dur := 0.0):
	if eye_tw and eye_tw.is_valid(): eye_tw.kill()
	if dur <= 0.0:
		player.eye_height = h; player.get_node("Head").position.y = h; return
	eye_tw = create_tween()
	eye_tw.tween_method(func(v: float): player.eye_height = v; player.get_node("Head").position.y = v, player.eye_height, h, dur).set_trans(Tween.TRANS_SINE)

func _cam() -> Camera3D:
	return player.get_node("Head/Camera")

# the small camera on the handrail (第1章: she set it; 0時: she changed its tape). Its lamp has burned all night
func _rail_camera():
	_fixed_cam()
	var ta := _target_angles()
	var tf := Transform3D(Basis.from_euler(Vector3(ta[1], ta[0], 0.0), EULER_ORDER_YXZ), g([TARGET_POS[0], TARGET_POS[1], _rail_z(TARGET_POS[1]) + 0.065]))
	if PLACED.has("pos"): tf = Transform3D(PLACED.basis, PLACED.pos)
	fixed_cam.global_transform = tf
	_lamp6(true)

func _lamp6(on: bool):
	(fixed_cam.get_node("rec") as OmniLight3D).light_energy = 0.6 if on else 0.0
	var dm := (fixed_cam.get_node("recdot") as MeshInstance3D).material_override as StandardMaterial3D
	dm.emission_energy_multiplier = 6.0 if on else 0.0
	(fixed_cam.get_node("recdot2") as MeshInstance3D).material_override = dm

func _air_bus():
	lp = AudioEffectLowPassFilter.new(); lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, lp); lp_i = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, lp_i, false)

func _exit_tree():
	if lp_i >= 0 and lp_i < AudioServer.get_bus_effect_count(0): AudioServer.remove_bus_effect(0, lp_i)

# ---------------------------------------------------------------- the candle (ch5's, with the hand it is in and the dawn)
func _candle_tick(dt: float):
	if not candle.visible: return
	if candle_held:
		var cam := _cam()
		var p: Vector3 = cam.global_position + Basis(Vector3.UP, player.yaw) * candle_off_now
		candle.global_transform = Transform3D(Basis(), p)
	candle_off_now = candle_off_now.lerp(candle_off, 1.0 - exp(-dt * 5.0))
	var lean := Vector3.ZERO; var best := 99.0
	for gq in gaps:
		var d: float = (gq.at as Vector3).distance_to(candle.global_position)
		if d < best: best = d; lean = (gq.at as Vector3) - candle.global_position
	var k := clampf((2.2 - best) / 1.5, 0.0, 1.0)
	lean.y = 0.0
	var tilt := 0.9 * k + 0.05 * sin(t_now * 13.0) * (0.3 + k)
	if lean.length() > 0.001:
		var ax := Vector3.UP.cross(lean.normalized()).normalized()
		flame.basis = Basis(ax, tilt) if ax.length() > 0.5 else Basis()
	flame.visible = not candle_out
	# the eye opens as the night goes: the flame is the same flame (its light is not dimmed with the rest)
	var e := 0.26 + 0.04 * sin(t_now * 17.0) + 0.025 * sin(t_now * 5.3) - 0.07 * k * absf(sin(t_now * 9.0))
	candle_light.light_energy = 0.0 if candle_out else e * 0.56 / maxf(exp_now, 0.3)
var candle_off_now := Vector3(0.2, -0.36, -0.42)

func _candle_down(at: Vector3):
	candle_held = false; c_block = null
	var tw := create_tween()
	tw.tween_property(candle, "global_position", at, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		if c_hand and not candle_held:
			var h := c_hand; c_hand = null; _hand_layer(h, 2); _ang_set(h, HAND_OPEN); _hand_away(h, 0.4))

# the hand under its saucer (user 2026-11-18: 「蝋燭の皿を下から持つようにしよう」): the palm up, the saucer on it, the
# fingers round its rim. The hand on the side the candle is held; it goes with the candle (found with --c6bench)
var c_hand: Node3D = null
var c_block: Node3D = null       # a hand that was given something else while it held the candle
var c_k := 0.0
const CANDLE_IN_HAND := Vector3(0.0, -0.0245, -0.098)
const HAND_OPEN := [-0.30, -0.22, -0.12, -0.30, -0.22, -0.12, -0.30, -0.22, -0.12, -0.30, -0.22, -0.12, -0.35, -0.10, -0.10, 0.0]   # flat, the thumb out to the side in the palm's plane: it goes in under the saucer whole
func _candle_hand_tick(dt: float):
	if candle_held and candle.visible:
		var want: Node3D = hand_l if candle_off_now.x < 0.0 else hand_r
		if want != c_hand and want != c_block:
			if c_hand: var old := c_hand; c_hand = null; _hand_layer(old, 2); _ang_set(old, HAND_OPEN); _hand_away(old, 0.3)
			_hand_claim(want); c_hand = want; c_k = 0.0; want.visible = true; _hand_layer(want, 4)
	if c_hand == null: return
	# in under it from her side, the fingers flat and the thumb lifted; then they close on its rim (from below, the thumb came up through the saucer)
	if c_k < 1.0:
		c_k = minf(1.0, c_k + dt / 0.45)
		var ck := smoothstep(0.55, 1.0, c_k); var a := []
		var g: Array = GRIPS["candle_r" if c_hand == hand_r else "candle"]
		for i in 16: a.append(lerpf(HAND_OPEN[i], g[i], ck))
		_ang_set(c_hand, a)
	else: _ang_set(c_hand, GRIPS["candle_r" if c_hand == hand_r else "candle"])   # (what the hand did last left its fingers as they were)
	var in_hand := Transform3D(Basis(Vector3.FORWARD, PI), Vector3(CANDLE_IN_HAND.x * (-1.0 if c_hand == hand_r else 1.0), CANDLE_IN_HAND.y, CANDLE_IN_HAND.z))
	var yb := Basis(Vector3.UP, player.yaw)
	c_hand.visible = true
	# (her forearm comes in from her side, not from her eye: from her eye it hid the saucer it holds)
	var deg := lerpf(35.0, 62.0, smoothstep(-0.30, -0.18, candle_off_now.y))   # held up before her, her elbow is out: across, and the saucer's near rim is clear of her hand
	var turn := Basis(Vector3.UP, deg_to_rad(deg if c_hand == hand_r else -deg))
	c_hand.global_transform = Transform3D(yb * turn, candle.global_position + yb * turn * Vector3(0.0, 0.0, 0.11) * (1.0 - smoothstep(0.0, 0.6, c_k))) * in_hand.affine_inverse()

func _candle_up():
	candle_held = true; c_block = null
	candle_off_now = _cam().global_basis.inverse() * (candle.global_position - _cam().global_position)
	candle_off_now = Basis(Vector3.UP, player.yaw).inverse() * (candle.global_position - _cam().global_position)

# ---------------------------------------------------------------- the page: the lines that come back
var ret_box: VBoxContainer
var ret_rows := {}             # the line as written -> {row, lb, struck, s}
var ret_key := ""
var ret_q: Array = []          # [[t, Callable]]
var ret_t := 0.0
var ret_hold := -1.0
var ret_tw: Tween
var struck6 := {}              # lines she has put a line through (they stay struck if the page comes back)
var type_q: Array = []         # [{lb, text, n}] lines being typed in on the page

class Strike6 extends Control:
	var w := 0.0
	var x0 := 0.0
	var u := 1.0
	var k := 0.0: set = _set_k
	var col := Color(0.945, 0.925, 0.875, 0.9)
	func _set_k(v: float): k = v; queue_redraw()
	func _draw():
		var y := size.y * 0.52
		var k1 := clampf(k * 2.0, 0.0, 1.0); var k2 := clampf(k * 2.0 - 1.0, 0.0, 1.0)
		var xa := x0 - 4 * u; var xb := x0 + w + 4 * u
		if size.y > 60 * u: y = 17 * u      # a wrapped row: the line goes through its first line
		if k1 > 0.0: draw_line(Vector2(xa, y - 4 * u), Vector2(lerpf(xa, xb, k1), y - 4 * u - u * k1), col, 2.0 * u)
		if k2 > 0.0: draw_line(Vector2(xa, y + 3 * u), Vector2(lerpf(xa, xb, k2), y + 3 * u - u * k2), col, 2.0 * u)

func _ret_page():
	ret_box = VBoxContainer.new()
	ret_box.anchor_left = 0.075; ret_box.anchor_right = 0.70; ret_box.anchor_top = 0.0; ret_box.anchor_bottom = 0.0
	ret_box.offset_top = 150 * u
	ret_box.add_theme_constant_override("separation", int(10 * u))
	page.add_child(ret_box)

func _ret_clear():
	if ret_tw and ret_tw.is_valid(): ret_tw.kill()
	_clear_box(ret_box); ret_rows = {}; ret_q = []; ret_hold = -1.0; ret_box.modulate.a = 1.0; type_q = []; ret_key = ""

# one row of the page. body: 「澪＊：…」(her answer: the short rule) | 「名前：…」 | 「（…）」
func _ret_row(body: String, typed := false) -> Dictionary:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", int(14 * u))
	var text := body; var tes := false
	var c := body.find("：")
	if body.begins_with("（"): pass
	elif c > 0:
		var who := body.substr(0, c); text = body.substr(c + 1)
		if who.ends_with("＊"): tes = true
		else:
			var w := _label(23); w.text = T(who) + "　"; w.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; row.add_child(w)
	if tes:
		var rule := ColorRect.new(); rule.color = Color(paper.r, paper.g, paper.b, 0.85)
		rule.custom_minimum_size = Vector2(26 * u, 2 * u); rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rule)
	else:
		var pad := Control.new(); pad.custom_minimum_size = Vector2(26 * u, 2 * u); row.add_child(pad); row.move_child(pad, 0)
	var sz := 22.0 if body.begins_with("（") else 26.0
	var lb := _label(sz); lb.text = _wrap_row(Tw(text), sz)
	lb.add_theme_constant_override("line_spacing", int(6 * u))
	row.add_child(lb)
	ret_box.add_child(row)
	var r := {"row": row, "lb": lb, "sz": sz}
	ret_rows[body] = r
	if typed:
		lb.visible_characters = 0; type_q.append({"lb": lb, "n": 0.0})
	else:
		row.modulate.a = 0.0
		create_tween().tween_property(row, "modulate:a", 1.0, 0.7)
	for k in struck6.keys(): _ret_strike(String(k), 0.0)   # what she has crossed out stays crossed out
	if demo6: print("PAGE %s" % body)
	return r

func _ret_head(text: String):
	var lb := Label.new()
	lb.add_theme_font_override("font", Type.card()); lb.add_theme_font_size_override("font_size", int(34 * u))
	lb.add_theme_color_override("font_color", paper); Type.soft(lb, u)
	lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lb.text = T(text)
	ret_box.add_child(lb)
	lb.modulate.a = 0.0
	create_tween().tween_property(lb, "modulate:a", 1.0, 0.7)
	if demo6: print("PAGE 見出し %s" % text)

# the earlier chapter's lines come back, unstruck, under the hour they were said in
func _ret_open(key: String):
	_ret_clear()
	ret_key = key
	_clear_page()
	var t := 0.2; var first := true
	for ln in D.lines(key):
		var s0 := _flag_line(String(ln))
		if s0.begins_with("澪＊："): ret_q.append([t, _ret_row.bind(s0, true)]); t += s0.length() / 18.0 + 1.0; continue
		if not s0.begins_with("↩"): continue
		var body := s0.substr(1)
		if first: first = false; ret_q.append([t, _ret_head.bind(body)]); t += 0.9
		else: ret_q.append([t, _ret_row.bind(body)]); t += 0.8
	ret_t = 0.0
	Sound.one(self, "ch3_blanket", -22.0)

# the row a line (or a part of one) is on: [row's dictionary, the text before it in that row]
func _ret_find(body: String) -> Array:
	if ret_rows.has(body): return [ret_rows[body], ""]
	var c := body.find("：")
	if c < 0: return []
	var head := body.substr(0, c + 1); var part := body.substr(c + 1)
	for k in ret_rows:
		if not String(k).begins_with(head): continue
		var whole := String(k).substr(c + 1)
		var at := whole.find(part)
		if at >= 0: return [ret_rows[k], whole.substr(0, at)]
	return []

func _ret_strike(body: String, dur := 1.2):
	var f := _ret_find(body)
	if f.is_empty():
		if dur > 0.0: print("SCRIPT ERROR ch6: no line on the page to strike: ", body)
		return
	var r: Dictionary = f[0]
	struck6[body] = true
	if not r.has("strikes"): r["strikes"] = {}
	if (r.strikes as Dictionary).has(body): return
	var lb: Label = r.lb
	var fs := int(float(r.sz) * u)
	var part := body.substr(body.find("：") + 1) if f[1] != "" or not ret_rows.has(body) else lb.text.split("\n")[0]
	if ret_rows.has(body): part = lb.text.split("\n")[0]
	var s := Strike6.new(); s.u = u
	s.x0 = font.get_string_size(T(String(f[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if f[1] != "" else 0.0
	s.w = font.get_string_size(T(part), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE; s.set_anchors_preset(Control.PRESET_FULL_RECT)
	lb.add_child(s); r.strikes[body] = s; r["s"] = s
	if dur <= 0.0: s.k = 1.0
	elif dur < 90.0: create_tween().tween_property(s, "k", 1.0, dur)
	(r.row as Control).modulate.a = 1.0
	if demo6 and dur > 0.0: print("PAGE × %s" % body)

# what the hands' work leaves on the page: × a line through, ↩ one more that comes back, 澪＊ what stays instead
func _ret_after(key: String, hold := 8.0):
	if ret_rows.is_empty() and ret_key == "": pass
	var t := ret_t + 0.4
	if not ret_q.is_empty(): t = float(ret_q[-1][0]) + 0.8
	for ln in D.lines(key):
		var s := _flag_line(String(ln))
		if s.begins_with("×"): ret_q.append([t, _ret_strike.bind(s.substr(1))]); t += 1.5
		elif s.begins_with("↩"): ret_q.append([t, _ret_row.bind(s.substr(1))]); t += 1.4
		elif s.begins_with("＞"): ret_q.append([t, _do.bind(s.substr(1).strip_edges())]); t += 0.6
		elif s.begins_with("◇"): ret_q.append([t, _set_mission.bind(s.substr(1).strip_edges())]); t += 0.3
		elif s.begins_with("澪＊："):
			ret_q.append([t, _ret_row.bind(s, true)]); t += s.length() / 18.0 + 1.3
	ret_q.append([t, func(): ret_hold = hold])

# 2026-11-20 the night's record: "［flag］ line" is the line when the flag is set, nothing when not
func _flag_line(s: String) -> String:
	if not s.begins_with("［"): return s
	var c := s.find("］")
	if c < 2: return s
	var nm := s.substr(1, c - 1)
	var flag_ok := true
	for ch in nm: if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"): flag_ok = false
	if not flag_ok or c >= s.length() - 1: return s
	return s.substr(c + 1).strip_edges() if has_flag(nm) else ""

func _ret_tick(dt: float):
	ret_t += dt
	while not ret_q.is_empty() and ret_t >= float(ret_q[0][0]):
		var c: Callable = ret_q.pop_front()[1]; c.call()
	for e in type_q:
		if not is_instance_valid(e.lb): continue
		var lb: Label = e.lb
		e.n = minf(float(lb.text.length()), float(e.n) + dt * 18.0); lb.visible_characters = int(e.n)
	type_q = type_q.filter(func(e): return is_instance_valid(e.lb) and e.n < float((e.lb as Label).text.length()))
	if ret_hold >= 0.0 and ret_q.is_empty():
		ret_hold -= dt
		if ret_hold < 0.0:
			ret_tw = create_tween(); ret_tw.tween_property(ret_box, "modulate:a", 0.0, 1.8)
			ret_tw.tween_callback(_ret_clear)
	# the mission line steps aside while the page has lines on it (story.gd does this for tes_box)
	if mission_box and ret_box.get_child_count() > 0 and ret_box.offset_top < 140 * u: mission_box.visible = false

func _ret_busy() -> bool:
	return not ret_q.is_empty() or not type_q.is_empty()

# ---------------------------------------------------------------- what she can look at, and what her hands can do
func _add_target(k: String, pos: Vector3, reach: float, deg: float, ok: Callable, name: Callable, press: Callable):
	targets.append({"k": k, "pos": pos, "reach": reach, "deg": deg, "ok": ok, "name": name, "press": press})

func _target(k: String) -> Dictionary:
	for t in targets: if t.k == k: return t
	return {}

func _prompt(key: String) -> String:
	return T(String(D.lines(key)[0]))

func _looks6():
	# 試作231（ユーザー「このなつきのテープなくす」）: the crew's floor mark is hidden at 4時半 (main.gd _house_state), and with
	# it 【見る.床のテープ】
	for it in LOOKS:
		if it[0] == "mark": continue
		var pos: Vector3 = gp(it[2][0], it[2][1], it[2][2])
		if it[1] != "":
			var found: Array = main.S.env_node.find_children(String(it[1]) + "*", "MeshInstance3D", true, false)
			if not found.is_empty():
				var mi := found[0] as MeshInstance3D
				var bb: AABB = mi.global_transform * mi.get_aabb()
				pos = bb.get_center() + Vector3(0, bb.size.y * 0.3, 0)
			else: print("CH6 look %s: no node %s, at the plan point" % [it[0], it[1]])
		var k: String = it[0]; var nm: String = it[3]; var block: String = it[4]
		var reach := 2.4 if k in ["screen", "window", "back", "cellar"] else 1.9
		_add_target(k, pos, reach, 24.0, func(): return true, func(): return "［%s］" % T(nm), _look_press.bind(k, block))

func _look_press(k: String, block: String):
	var b := block
	if k == "bag_n" and phone_st >= 2 and not has_pack: b = "見る.夏希の鞄.差す所"
	looked[k] = true
	if k == "makeup" and done6.has("lid"): _start(B(b).filter(func(e): return not e.has("do")).slice(0, 1) + B(b).slice(2)); return
	_start(B(b))

func _full_hands_at() -> bool:
	var cam := _cam()
	for k in ["nat", "cam", "box", "sink", "bag_m"]:
		var t := _target(k)
		if t.is_empty(): continue
		var to: Vector3 = (t.pos as Vector3) - cam.global_position
		if to.length() < float(t.reach) and (-cam.global_basis.z).angle_to(to) < deg_to_rad(float(t.deg)): return true
	return false

func _pick_target() -> Dictionary:
	var cam := _cam()
	var best := {}; var ba := 99.0
	for t in targets:
		if not (t.ok as Callable).call(): continue
		var to: Vector3 = (t.pos as Vector3) - cam.global_position
		var a := (-cam.global_basis.z).angle_to(to)
		if to.length() < float(t.reach) and a < deg_to_rad(float(t.deg)) and a < ba: ba = a; best = t
	return best

# ---------------------------------------------------------------- the night going: one step for each thing put right
func _dawn():
	dawn_n = mini(dawn_n + 1, DAWN_EXP.size() - 1)
	exp_want = DAWN_EXP[dawn_n]
	print("STORY ch6 dawn %d exp %.2f t=%.1f" % [dawn_n, exp_want, t_now])

func _dawn_tick(dt: float):
	exp_now = move_toward(exp_now, exp_want, dt * 0.012)
	if main.env: main.env.tonemap_exposure = exp_now
	var snd = main.get_node_or_null("Sound")
	if snd and (snd.loops as Dictionary).has("rain") and is_instance_valid(snd.loops["rain"]):
		var rp = snd.loops["rain"]
		rp.set("volume_db", move_toward(float(rp.get("volume_db")), -10.0 - 2.5 * dawn_n, dt * 0.5))

# the air upstairs: nothing is said of it. The view sways a little and the ears close
func _air_tick(dt: float):
	var up: bool = player.global_position.y > 1.6 and not done6.has("uptape")
	up_air = move_toward(up_air, 1.0 if up else 0.0, dt * (0.12 if up else 0.5))
	var cam := _cam()
	cam.rotation.z = 0.02 * up_air * sin(t_now * 0.7) + 0.008 * up_air * sin(t_now * 1.9)
	cam.rotation.x = 0.012 * up_air * sin(t_now * 0.53 + 1.0)
	if lp_i >= 0:
		AudioServer.set_bus_effect_enabled(0, lp_i, up_air > 0.02)
		lp.cutoff_hz = lerpf(20000.0, 1400.0, pow(up_air, 0.5))

var grip6 := ""
var grip_key := ""
var grip_t := 0.0
var grip_n := 0
func _grip_tick(dt: float):
	var key := "%s/%d" % [act, step]
	if key != grip_key: grip_key = key; grip_t = 1.6; grip_n = 0
	grip_t -= dt
	if grip_t > 0.0: return
	grip_n += 1; grip_t = 2.0
	var GL = load("res://scripts/grip_lab.gd")
	var sh := Basis(Vector3.UP, player.yaw)
	for h in [hand_l, hand_r]:
		if h == null or not h.visible or not h.has_meta("sk"): continue
		var tag := "%s#%d" % [key, grip_n]
		# her skin against everything near (what rides this hand, the other hand, the things of the house)
		GL.verify(h, main, [h.get_child(0)], tag)
		# the elbow, from the shoulder (the upper arm is about 0.28 m; reaching, the shoulder comes forward some 0.08)
		var el: Vector3 = h.global_transform * Vector3(0, 0, 0.25)
		var shd: Vector3 = _cam().global_position + sh * Vector3(-0.17 if h == hand_l else 0.17, -0.21, 0.03)
		print("ELBOW %s %s 肩から %.2fm" % [tag, h.name, el.distance_to(shd)])

# check only. A json list of {name, hand: "l"/"r", obj: phone/pack/cas/case, rot: [deg YXZ, the thing in the hand's frame], off: [x, z],
# objpose: [[pos in the rig], [deg]] (where the thing is held up; the hand follows)}. Writes <json>.out/<name>_<view>.png and prints SEAT / FIT / VERIFY
func _bench(path: String):
	var GL = load("res://scripts/grip_lab.gd")
	var list: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var out := path + ".out"; DirAccess.make_dir_recursive_absolute(out)
	set_process(false); player.move_enabled = false; player.look_enabled = false
	var bc := Camera3D.new(); bc.fov = 30.0; bc.near = 0.02; main.add_child(bc)
	var objs := {"phone": phone, "pack": pack, "cas": cas1, "case": case6, "candle": candle}
	for e in list:
		var h: Node3D = hand_l if e.hand == "l" else hand_r
		var o: Node3D = objs[e.obj]
		for k in objs: (objs[k] as Node3D).visible = false
		hand_l.visible = false; hand_r.visible = false; h.visible = true
		if o.get_parent() != h: o.get_parent().remove_child(o); h.add_child(o)
		o.visible = true
		var r: Array = e.rot
		o.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(r[0]), deg_to_rad(r[1]), deg_to_rad(r[2])), EULER_ORDER_YXZ), Vector3(e.off[0], 0.0, e.off[1]))
		GL.set_angles(h, GL.open_angles())
		h.transform = Transform3D(Basis(), Vector3(0, -0.1, -0.3))
		await get_tree().process_frame
		if e.has("y"): o.position.y = e.y
		else: GL.seat_obj(h, o, e.name)
		var ang: Array = GL.fit(h, main, [h.get_child(0)], e.name, [o], true, e.get("side", -9.0), e.get("thumb", []))
		ang = GL.refine(h, main, [h.get_child(0)], e.name, ang, [o], o)
		GL.verify(h, main, [h.get_child(0)], e.name, [o])
		var op: Array = e.objpose    # [the hand's old place, its old turn, the thing's old place in it]: the thing stays where it was seen
		var ob := Transform3D(Basis.from_euler(Vector3(deg_to_rad(op[1][0]), deg_to_rad(op[1][1]), deg_to_rad(op[1][2])), EULER_ORDER_YXZ), Vector3(op[0][0], op[0][1], op[0][2])) * Transform3D(Basis(), Vector3(op[2][0], op[2][1], op[2][2]))
		print("BENCH %s obj in hand: rot %s pos %s" % [e.name, r, o.position.snappedf(0.0005)])
		h.transform = ob * o.transform.affine_inverse()
		var el: Vector3 = h.global_transform * Vector3(0, 0, 0.25)
		var shd: Vector3 = _cam().global_position + Basis(Vector3.UP, player.yaw) * Vector3(-0.17 if h == hand_l else 0.17, -0.21, 0.03)
		print("BENCH %s hand pos %s deg %s  ひじは肩から %.2fm" % [e.name, h.position.snappedf(0.001), (h.basis.get_euler(EULER_ORDER_YXZ) * 180.0 / PI).snappedf(0.5), el.distance_to(shd)])
		_cam().make_current()
		for i in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_eye.png" % [out, e.name])
		var views := {"palm": [Vector3(0, -0.34, -0.08), Vector3(0, 0, -1)], "side": [Vector3(0.34, -0.02, -0.08), Vector3(0, 1, 0)], "tip": [Vector3(0, -0.02, -0.44), Vector3(0, 1, 0)], "back": [Vector3(0, 0.34, -0.08), Vector3(0, 0, -1)]}
		for v in views:
			bc.global_transform = h.global_transform * Transform3D(Basis(), views[v][0]).looking_at(Vector3(0, -0.02, -0.08), views[v][1])
			bc.make_current()
			for i in 2: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, e.name, v])
	print("BENCH done"); get_tree().quit()

# check only (--c6fit): when the hand has come to a thing that stands by itself, bring the palm onto it, close the fingers on it,
# and print the hand's place and the angles (to write into the hand's target and GRIPS). In play this does nothing
func _fit_dev(h: Node3D, key: String, only: Array, delay: float, at = null, seat := true, fit := true, side := -9.0, done := false):
	if grip6 != "fit" or (done and not OS.get_cmdline_user_args().has("--c6refit")): return
	_after(delay, func():
		var GL = load("res://scripts/grip_lab.gd")
		var p0 := h.position
		if at != null: h.position = at; p0 = at
		var keep: Array = (h.get_meta("ang") as Array).duplicate()
		if fit: GL.set_angles(h, GL.open_angles())
		if seat:
			GL.seat_hand(h, main, key, only, not fit)
			print("FITDEV %s hand moved by %s (rig), now %s" % [key, (h.position - p0).snappedf(0.0005), h.position.snappedf(0.0005)])
		if fit:
			var ang: Array = GL.fit(h, main, [h], key, only, true, side)
			ang = GL.refine(h, main, [h], key, ang, only, null, 0.0012, side > -5.0)
			h.set_meta("ang", ang)
		else: _ang_set(h, keep)
		GL.verify(h, main, [h], key, only))

# a step nearer, if the thing is farther than her arm (the eye within `reach` of it, level)
func _step_near(target: Vector3, reach := 0.45, dur := 0.7):
	var d := target - _cam().global_position; d.y = 0.0
	var far := d.length() - reach
	if far <= 0.02: return
	var mv := d.normalized() * far
	for i in 6:
		if not player.test_move(player.global_transform, mv): break
		mv *= 0.75
	var went := 0.0
	if not player.test_move(player.global_transform, mv):
		went = mv.length()
		create_tween().tween_property(player, "global_position", player.global_position + mv, dur).set_trans(Tween.TRANS_SINE)
	# and what her feet cannot do (the rail is in the way), her body does: she leans to it
	var lean := clampf(far - went, 0.0, 0.34)
	if lean > 0.02:
		lean_on = true
		create_tween().tween_property(_cam(), "position", Vector3(0, 0, -lean), dur).set_trans(Tween.TRANS_SINE)
var lean_on := false

var probe6 := ""
var probe_cam: Camera3D
func _probe_tick():
	if probe_cam == null:
		probe_cam = Camera3D.new(); probe_cam.fov = 38.0; probe_cam.near = 0.02; _cam().add_child(probe_cam)
		var at := Vector3(0.06, -0.12, -0.32)
		var from: Vector3 = {"right": Vector3(0.55, -0.02, -0.30), "left": Vector3(-0.50, -0.02, -0.30), "top": Vector3(0.06, 0.42, -0.30), "under": Vector3(0.06, -0.62, -0.26), "front": Vector3(0.06, -0.02, -0.86)}.get(probe6, Vector3(0.55, -0.02, -0.30))
		probe_cam.transform = Transform3D(Basis(), from).looking_at(at, Vector3.FORWARD if absf(from.y - at.y) > 0.3 else Vector3.UP)
		for o in [Vector3(0.5, 0.4, -0.1), Vector3(-0.4, -0.3, -0.6)]:
			var pl := OmniLight3D.new(); pl.omni_range = 2.0; pl.light_energy = 0.8; pl.shadow_enabled = false; pl.position = o; _cam().add_child(pl)
	if not probe_cam.current: probe_cam.make_current()

# ---------------------------------------------------------------- the clock
# 試作176 A21（ユーザー「影、手だけが写る」）: her hands threw a shadow and nothing else. 第4章's body for the lantern and the
# candle to throw (fps.gd _mio_shadow: a column, the shoulders and a head that only cast), lower as her eye is (sitting)
var body_sh: Node3D
func _body_shadow():
	body_sh = Node3D.new(); body_sh.name = "MioShadow"; main.add_child(body_sh)
	var mat := StandardMaterial3D.new()
	for spec in [[CapsuleMesh.new(), Vector3(0, 0.70, 0), Vector3(0.36, 1.40, 0.24)], [SphereMesh.new(), Vector3(0, 1.50, 0), Vector3(0.21, 0.24, 0.22)], [CapsuleMesh.new(), Vector3(0, 1.26, 0), Vector3(0.44, 0.30, 0.22)]]:
		var mi := MeshInstance3D.new(); mi.mesh = spec[0]; mi.material_override = mat
		if mi.mesh is CapsuleMesh: (mi.mesh as CapsuleMesh).radius = 0.5; (mi.mesh as CapsuleMesh).height = 1.0 if spec[2].y < 0.5 else 2.0
		mi.position = spec[1]; mi.scale = spec[2] if not (mi.mesh is CapsuleMesh) else Vector3(spec[2].x, spec[2].y / (1.0 if spec[2].y < 0.5 else 2.0), spec[2].z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		body_sh.add_child(mi)

func _process(dt):
	t_now += dt; t_stage += dt
	if body_sh:
		body_sh.global_position = player.global_position; body_sh.rotation.y = player.yaw
		body_sh.scale = Vector3(1.0, clampf(player.eye_height / 1.52, 0.5, 1.0), 1.0)
	# while her hands are at a thing, a door in front of her is not offered (E was both: the tripod was held toward a door)
	var dn6 = main.get_node_or_null("Doors")
	if dn6 and dn6.is_processing() != (act == ""):
		dn6.set_process(act == ""); dn6.set_process_unhandled_input(act == "")
		if act != "": dn6.label.text = ""
	if probe6 != "": _probe_tick()
	if lean_on and act != "cam" and act != "batt":
		lean_on = false; create_tween().tween_property(_cam(), "position", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_SINE)
	if card_t > 0.0:
		card_t -= dt
		card.visible = true; player.move_enabled = false; player.look_enabled = false
		if card_t <= 0.0:
			card.visible = false; player.look_enabled = true
			_begin(card_next)
		return
	if mode == TALK: _talk_tick(dt)
	_candle_tick(dt)
	_candle_hand_tick(dt)
	if grip6 != "": _grip_tick(dt)   # (check only; after the hands and the candle are where this frame draws them)
	_wind_tick(dt)
	_gen_tick(dt)
	_blanket_tick(dt)
	_dawn_tick(dt)
	_air_tick(dt)
	_ret_tick(dt)
	_flow_tick(dt)
	_act_tick(dt)
	_end_tick6(dt)
	_board6_tick()
	main.talk_now = ""
	main.story_talking = (mode == TALK)
	player.move_enabled = mode == FREE and act == "" and stage in ["free", "call", "peek", "peek2"]
	if stage in ["call", "call_talk", "peek", "peek2", "down"]: _start6_tick(dt)
	if page_clear_t >= 0.0:
		page_clear_t -= dt
		if page_clear_t < 0.0 and mode == FREE: _clear_box(lines_box)
	# what she is looking at
	tgt = {}
	if mode == FREE and act == "" and stage == "free":
		tgt = _pick_target()
		note_lb.text = String((tgt.name as Callable).call()) if not tgt.is_empty() else ""
		# 試作175（ユーザー「夏希を選択できなかった」）: with the tripod in her arms nothing else could be taken, and nothing
		# said so. Looking at what her hands would need, she is told they are full (the bag is the one place it goes)
		if tgt.is_empty() and carrying and _full_hands_at(): note_lb.text = T("［両手がふさがっている］")
	elif act == "" and stage != "end5": note_lb.text = ""
	if demo6: _demo6_tick(dt)

func _begin(st: String):
	t_stage = 0.0
	print("STORY ch6 %s t=%.1f" % [st, t_now])
	match st:
		"t420card":
			_card(D.lines("四時二十分.カード")[0], "start")
		"start":   # 2026-11-20 12時39分①: the first minute is not tidying. She calls Natsuki; the cellar from the top of its stair; the click
			stage = "call"
			_cellar_shoe()
		"jump":
			_jump6(start6)

# ---------------------------------------------------------------- 2026-11-20 始まり：夏希を呼ぶ、地下を見下ろす
func _nat_looked() -> bool:
	var t := _target("nat")
	if t.is_empty(): return false
	var to: Vector3 = (t.pos as Vector3) - _cam().global_position
	return to.length() < 2.6 and (-_cam().global_basis.z).angle_to(to) < deg_to_rad(30.0)

const CELLAR_FOOT := [5.5, 2.6, -2.35]   # the foot of the cellar stair (plan, height): Makoto's torch on the floor, Taiga's shoe past it
func _cellar_looked(deg := 18.0) -> bool:
	var to: Vector3 = gp(CELLAR_FOOT[0], CELLAR_FOOT[1], CELLAR_FOOT[2]) - _cam().global_position
	var p: Vector3 = player.global_position
	return player.global_position.y > -0.4 and to.length() < 6.2 and (-_cam().global_basis.z).angle_to(to) < deg_to_rad(deg) and Vector2(p.x - gp(5.5, 5.9, 0.0).x, p.z - gp(5.5, 5.9, 0.0).z).length() < 1.4

var shoe6: MeshInstance3D
var cel_torch6: SpotLight3D
func _cellar_shoe():
	if shoe6: return
	var dn = main.get_node_or_null("Doors")
	if dn: dn.open_key("door_cellar")
	# her torch, rolled to the foot of the stair, lighting the ceiling (第5章: she went down with it)
	cel_torch6 = SpotLight3D.new(); cel_torch6.light_color = Color(0.92, 0.95, 1.0); cel_torch6.light_energy = 2.6; cel_torch6.spot_range = 4.0
	cel_torch6.spot_angle = 22.0; cel_torch6.spot_attenuation = 0.8; cel_torch6.shadow_enabled = true; main.add_child(cel_torch6)
	cel_torch6.look_at_from_position(gp(5.42, 2.45, -2.4), gp(5.9, 1.4, -0.2), Vector3.UP)
	var body := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.022; cy.bottom_radius = 0.022; cy.height = 0.17; body.mesh = cy
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.1, 0.1, 0.11); bm.roughness = 0.5; body.material_override = bm
	main.add_child(body); body.global_position = gp(5.45, 2.52, -2.42); body.rotation = Vector3(PI / 2, 0.4, 0)
	# one of Taiga's shoes, at the edge of its light
	shoe6 = MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(0.1, 0.09, 0.28); shoe6.mesh = sb
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.08, 0.08, 0.09); sm.roughness = 0.6; shoe6.material_override = sm
	main.add_child(shoe6); shoe6.global_position = gp(5.75, 1.95, -2.4); shoe6.rotation.y = 0.5

func _start6_tick(_dt: float):
	if mode != FREE: return
	match stage:
		"call":
			note_lb.text = T(String(D.lines("六.始まり")[0])) if _nat_looked() else ""
			if demo6: _demo_aim6((_target("nat").pos as Vector3) if not _target("nat").is_empty() else player.global_position, func(): _press6())
		"call_talk":
			stage = "peek"
		"peek":
			note_lb.text = ""
			if _cellar_looked():
				stage = "peek2"
				_tes6(String(B("六.地下.見下ろす")[0].text))
			elif demo6: _demo_cellar()
		"peek2":
			note_lb.text = T(String(D.lines("六.地下.下りる")[0])) if _cellar_looked(30.0) else ""
			if demo6 and _cellar_looked(30.0): _after(1.5, func(): if stage == "peek2": _press6())

var demo_pk := 0.0
func _demo_aim6(at: Vector3, then: Callable):
	var to := at - _cam().global_position
	player.yaw = lerp_angle(player.yaw, atan2(-to.x, -to.z), 0.15)
	player.pitch = lerpf(player.pitch, asin(clampf(to.normalized().y, -1.0, 1.0)), 0.15)
	demo_pk += get_process_delta_time()
	if demo_pk > 1.5: demo_pk = 0.0; then.call()

func _demo_cellar():
	var tgt_p := gp(5.5, 5.95, 0.0)
	var p: Vector3 = player.global_position
	if Vector2(p.x - tgt_p.x, p.z - tgt_p.z).length() > 0.3:
		if player.auto_path.is_empty():
			var path := [[0.0, p.x, p.z, rad_to_deg(player.yaw), -10.0]]
			var t := 0.3; var prev := p
			for q in [[4.8, 4.2], [4.8, 5.7], [5.1, 6.05], [5.5, 5.95]]:
				var to3: Vector3 = gp(q[0], q[1], 0.0); var d := Vector2(to3.x - prev.x, to3.z - prev.z)
				t += d.length() / 1.1 + 0.2; path.append([t, to3.x, to3.z, rad_to_deg(atan2(-d.x, -d.y)), -10.0]); prev = to3
			player.auto_path = path; player.auto_t = 0.0
		return
	player.auto_path = []
	var to := gp(CELLAR_FOOT[0], CELLAR_FOOT[1], CELLAR_FOOT[2]) - _cam().global_position
	player.yaw = lerp_angle(player.yaw, atan2(-to.x, -to.z), 0.15)
	player.pitch = lerpf(player.pitch, asin(clampf(to.normalized().y, -1.0, 1.0)), 0.15)

# ---------------------------------------------------------------- 2026-11-20（「お〜」の画の六つ目）: she sits; the first sun through the slit by the door
func _dawn_ray():
	var sl := SpotLight3D.new(); sl.light_color = Color(1.0, 0.86, 0.66); sl.light_energy = 0.0; sl.spot_range = 9.0
	sl.spot_angle = 3.2; sl.spot_attenuation = 0.4; sl.spot_angle_attenuation = 0.3; sl.shadow_enabled = true
	sl.light_volumetric_fog_energy = 1.2
	main.add_child(sl)
	sl.look_at_from_position(gp(3.7, -2.6, 0.9), gp(4.6, 3.6, 0.0), Vector3.UP)   # low, from the east-south-east, through the slit (x 4.08..4.28) to the genkan floor and the blanket
	create_tween().tween_property(sl, "light_energy", 9.0, 6.0).set_trans(Tween.TRANS_SINE)

# a block with seconds at the head of its lines (＞ do, （ ） note, ◇ mission, the rest said)
func _flow_start(key: String, done := Callable()):
	flow = []
	for e in B(key): flow.append([float(e.get("t", 0.0)), e])
	flow_t = 0.0; flow_done = done

func _flow_tick(dt: float):
	if flow.is_empty(): return
	flow_t += dt
	while not flow.is_empty() and flow_t >= float(flow[0][0]):
		var e: Dictionary = flow.pop_front()[1]
		if e.has("if") and not has_flag(String(e["if"])): continue
		if demo6: print("SAY %.1f %s" % [flow_t, str(e.get("do", e.get("note", e.get("mission", e.get("text", "")))))])
		if e.has("do"): _do(String(e.do))
		elif e.has("note"): _line_row("", T(String(e.note)), 22, "note"); page_clear_t = 5.0
		elif e.has("mission"): _set_mission(String(e.mission))
		elif e.has("text"):
			if e.get("testimony", false): _tes6(String(e.text))
			else: _line_row(String(e.get("who", "")), Tw(String(e.text)), SAY_SIZE, "say"); page_clear_t = 7.0
		if flow.is_empty() and flow_done.is_valid(): flow_done.call()

# her answer, typed in at the top left without holding her (the talk's own testimony holds the talk)
func _tes6(text: String):
	_clear_box(tes_box); tes_box.modulate.a = 1.0
	var r = _line_row("", text, 26, "testimony")
	var lb: Label = r[1]
	lb.visible_characters = 0; type_q.append({"lb": lb, "n": 0.0})

func _do(what: String):
	if _flag_do(what): return   # 2026-11-20 the night's record (story.gd FLAG_DOS)
	print("STORY ch6 do %s t=%.1f" % [what, t_now])
	match what:
		"cam_stop":
			_lamp6(false)
			Sound.one(self, "tape_clunk", -6.0, fixed_cam.global_position)
		"dawn": _dawn()
		"shake_natsuki":
			Sound.one(self, "ch3_blanket", -10.0, (_target("nat").pos as Vector3) if not _target("nat").is_empty() else player.global_position)
		"step_down":   # one step down the cellar stair; the breath in, and the cough (the body stops her)
			var to: Vector3 = player.global_position + (gp(5.5, 4.9, -0.45) - player.global_position) * Vector3(1, 0, 1).normalized() * 0.0
			var dst: Vector3 = gp(5.5, 5.3, -0.25); dst.y = player.global_position.y - 0.22
			set_meta("down_from", player.global_position)
			create_tween().tween_property(player, "global_position", Vector3(dst.x, player.global_position.y, dst.z), 0.6).set_trans(Tween.TRANS_SINE)
			_after(0.7, func(): Sound.one(self, "ch3_cough", 2.0))
		"step_back":
			var back: Vector3 = get_meta("down_from", player.global_position)
			var tw := create_tween(); tw.tween_interval(0.9)
			tw.tween_property(player, "global_position", back, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_callback(func(): stage = "tape0"; _flow_start("六.テープ", func(): stage = "free"))
		"dawn_ray":
			_dawn_ray()
		"lid":
			done6["lid"] = true
			Sound.one(self, "lock", -14.0, _target("makeup").pos)
		_: _do6(what)

func _unhandled_input(e):
	if card_t > 0.0 or stage in ["fin"]: return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_TAB: board_up = not board_up; return
	if e is InputEventKey and e.pressed and not e.echo:
		if mode == TALK and cur.has("choose") and e.keycode in [KEY_W, KEY_UP]: _move_choice(-1); return
		if mode == TALK and cur.has("choose") and e.keycode in [KEY_S, KEY_DOWN]: _move_choice(1); return
		if e.keycode in [KEY_W, KEY_UP] and stage == "end5" and can_stand and stand_t < 0.0: _get_up(); return
	if e is InputEventMouseButton and e.pressed and mode == TALK and cur.has("choose"):
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: _move_choice(-1); return
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _move_choice(1); return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if press: _press6()

func _press6():
	if mode == TALK: _advance(); return
	if stage == "end5": _press_end(); return
	if act != "": _act_press(); return
	if stage == "free" and not tgt.is_empty(): (tgt.press as Callable).call()
	if stage == "call" and _nat_looked(): stage = "call_talk"; note_lb.text = ""; _start(B("六.始まり").slice(1))
	elif stage == "peek2" and _cellar_looked(30.0): stage = "down"; note_lb.text = ""; _start(B("六.地下.下りる").slice(1))

func _holding() -> bool:
	return hold_demo or Input.is_key_pressed(KEY_E) or (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


# ================================================================ her hands (ユーザー OK 2026-11-18: 手と袖は出す。体と顔は出さない)
# Built here from a few rounded pieces: under the print a hand is its outline and its light side. Each hand's own frame:
# the fingers point to -Z, the palm faces -Y, the forearm (the sleeve) runs back to +Z. They ride the camera (rig6).
const SKIN := Color(0.74, 0.58, 0.49)
const CUFF_Z := 0.02
const POLICE_HEAD_K := 0.44
const POLICE_HEAD_Z := 0.0
const CLOTH := Color(0.62, 0.60, 0.56)
const SLEEVE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 cloth : source_color = vec3(0.62, 0.60, 0.56);
uniform float stain = 0.0;     // 1: the left sleeve, where she was caught at half past three
uniform float wash = 0.0;      // 0 as it dried; 1 washed: the fingers are gone, a brown ring is left
uniform float wet = 0.0;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) { vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float cap(vec2 p, vec2 a, vec2 b, float r) { vec2 pa = p - a; vec2 ba = b - a; float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return 1.0 - length(pa - ba * t) / r; }
void fragment() {
	// metres on the cloth: x round the arm (0.26 round), y along it from the cuff (0.34 long)
	vec2 q = vec2(fract(UV.x + 0.875) * 0.26, clamp(UV.y * 2.0, 0.0, 1.0) * 0.34);   // the fingers lie on the back of the arm
	float m = -6.0;   // (-1 here put the halo's brown over the whole sleeve, and the ring was lost in it)
	for (int i = 0; i < 4; i++) {            // four fingers laid round the forearm, a hand's width
		float y = 0.085 + 0.023 * float(i) + 0.004 * sin(float(i) * 2.3);
		float len = 0.100 - 0.016 * abs(float(i) - 1.3) + 0.008 * sin(float(i) * 4.1);
		m = max(m, cap(q, vec2(0.050 + 0.006 * sin(float(i) * 1.7), y + 0.007 * float(i)), vec2(0.050 + len, y - 0.003), 0.0100));
	}
	m = max(m, cap(q, vec2(0.022, 0.100), vec2(0.040, 0.150), 0.020) * 0.8);   // the heel of the hand, where the fingers start
	m = max(m, cap(q, vec2(0.215, 0.105), vec2(0.245, 0.14), 0.012));   // the thumb, on the other side
	m = max(m, cap(q, vec2(0.0, 0.105), vec2(0.02, 0.118), 0.012));
	float n = vn(q * 220.0) * 0.6 + vn(q * 600.0) * 0.4;
	float blood = smoothstep(0.0, 0.3, m + (n - 0.5) * 0.9) * stain;
	float mm = m + (n - 0.5) * 0.4;
	float halo = smoothstep(-1.1, -0.3, mm) * stain;
	float ring = smoothstep(-1.2, -0.8, mm) * (1.0 - smoothstep(-0.55, -0.15, mm)) * stain;   // the edge the water carried it to
	vec3 c = cloth * (0.92 + 0.08 * vn(q * vec2(900.0, 90.0)));
	c = mix(c, c * 0.62, wet * halo);
	c = mix(c, vec3(0.40, 0.27, 0.19), halo * wash * 0.45);
	c = mix(c, vec3(0.13, 0.065, 0.04), ring * wash * 0.95);
	c = mix(c, vec3(0.17, 0.012, 0.012), blood * (1.0 - smoothstep(0.15, 0.95, wash)));
	ALBEDO = c; ROUGHNESS = 0.95; SPECULAR = 0.15;   // (wet cloth with a gloss took the light by her eye and went white: the stain was gone from the picture)
}
"""
# her own arm (blender/export_mio_arms.py: props/mio_arm_l.glb, mio_arm_r.glb): the model's cloth and skin, and on the
# left sleeve the same stain, laid round the forearm from where the vertex is in the hand's frame
const ARM_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap;
uniform bool has_nrm = false;
uniform mat4 to_hand;
uniform float cuff = 0.02;     // metres up the arm from the wrist where the cloth starts
uniform float stain = 0.0;
uniform float wash = 0.0;
uniform float wet = 0.0;
varying vec3 hp;
float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 x) { vec2 i = floor(x); vec2 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y); }
float cap(vec2 p, vec2 a, vec2 b, float r) { vec2 pa = p - a; vec2 ba = b - a; float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return 1.0 - length(pa - ba * t) / r; }
void vertex() { hp = (to_hand * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	if (has_nrm) NORMAL_MAP = texture(nrm, UV).rgb;
	float on = stain * step(cuff, hp.z);
	vec2 q = vec2(fract(atan(hp.x, hp.y) / TAU + 0.30) * 0.26, hp.z - cuff);
	float m = -6.0;
	for (int i = 0; i < 4; i++) {
		float y = 0.085 + 0.023 * float(i) + 0.004 * sin(float(i) * 2.3);
		float len = 0.100 - 0.016 * abs(float(i) - 1.3) + 0.008 * sin(float(i) * 4.1);
		m = max(m, cap(q, vec2(0.050 + 0.006 * sin(float(i) * 1.7), y + 0.007 * float(i)), vec2(0.050 + len, y - 0.003), 0.0100));
	}
	m = max(m, cap(q, vec2(0.022, 0.100), vec2(0.040, 0.150), 0.020) * 0.8);
	m = max(m, cap(q, vec2(0.215, 0.105), vec2(0.245, 0.14), 0.012));
	m = max(m, cap(q, vec2(0.0, 0.105), vec2(0.02, 0.118), 0.012));
	float n = vn(q * 220.0) * 0.6 + vn(q * 600.0) * 0.4;
	float blood = smoothstep(0.0, 0.3, m + (n - 0.5) * 0.9) * on;
	float mm = m + (n - 0.5) * 0.4;
	float halo = smoothstep(-1.1, -0.3, mm) * on;
	float ring = smoothstep(-1.2, -0.8, mm) * (1.0 - smoothstep(-0.55, -0.15, mm)) * on;
	c = mix(c, c * 0.62, wet * halo);
	c = mix(c, c * vec3(0.62, 0.42, 0.30), halo * wash * 0.45);
	c = mix(c, c * vec3(0.30, 0.15, 0.10), ring * wash * 0.95);
	c = mix(c, vec3(0.035, 0.006, 0.006), blood * (1.0 - smoothstep(0.15, 0.95, wash)));   // dried, on dark grey wool: near black (a rust was the lit sleeve's own tone in the print, and was not seen)
	ALBEDO = c; ROUGHNESS = 0.92; SPECULAR = 0.15;
}
"""
var sleeve_l: ShaderMaterial
var tri_fill: OmniLight3D
var fill6: OmniLight3D           # the candle's light on what she holds up to her eye (her own hands stood black against it)

func _hands():
	rig6 = Node3D.new(); rig6.name = "rig6"; _cam().add_child(rig6)
	hand_l = _mk_hand(true); hand_r = _mk_hand(false)
	rig6.add_child(hand_l); rig6.add_child(hand_r)
	hand_l.visible = false; hand_r.visible = false
	fill6 = OmniLight3D.new(); fill6.light_color = Color(1.0, 0.82, 0.62); fill6.light_energy = 0.0; fill6.omni_range = 0.8; fill6.omni_attenuation = 1.6
	fill6.shadow_enabled = false; fill6.light_specular = 0.1; fill6.position = Vector3(0.0, 0.06, 0.04); fill6.light_cull_mask = 0xFFFFF & ~4; rig6.add_child(fill6)
	# the tripod is black metal on a dark floor: a light of its own (layer 2), or it is not seen in her hands at all
	tri_fill = OmniLight3D.new(); tri_fill.light_color = Color(1.0, 0.84, 0.66); tri_fill.light_energy = 0.0; tri_fill.omni_range = 2.6; tri_fill.omni_attenuation = 0.8
	tri_fill.shadow_enabled = false; tri_fill.light_cull_mask = 2; tri_fill.position = Vector3(0.0, 0.12, -0.05); rig6.add_child(tri_fill)
	hand_l.position = Vector3(-0.2, -0.6, -0.3); hand_r.position = Vector3(0.2, -0.6, -0.3)

func _mk_arm(left: bool) -> Node3D:
	var h := Node3D.new(); h.name = "hand_l" if left else "hand_r"
	var inst: Node3D = (load("res://props/mio_arm_%s.glb" % ("l" if left else "r")) as PackedScene).instantiate()
	h.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = ARM_SHADER; sm.shader = sh
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var src := m.mesh.surface_get_material(0) as BaseMaterial3D
		if src:
			sm.set_shader_parameter("tex", src.albedo_texture)
			if src.normal_enabled and src.normal_texture: sm.set_shader_parameter("nrm", src.normal_texture); sm.set_shader_parameter("has_nrm", true)
		# the vertex in the hand's frame (the wrist at the origin, the sleeve up +Z)
		var rel := Transform3D(); var nd: Node3D = m
		while nd != h: rel = nd.transform * rel; nd = nd.get_parent()
		sm.set_shader_parameter("to_hand", Projection(rel))
		m.material_override = sm; m.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; m.extra_cull_margin = 0.6
		m.layers = 2    # the tripod's own light falls on the hands that hold it; the phone's glow (layer 1 only) does not: it burnt the hand that holds it to a white shape
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sm.set_shader_parameter("stain", 1.0 if left else 0.0); sm.set_shader_parameter("cuff", CUFF_Z)
	if left: sleeve_l = sm
	# the fingers: each joint bends about the axis across the finger and the palm (the palm faces -Y here)
	var fb := []
	var to_h := Transform3D(); var nd2: Node3D = sk
	while nd2 != h: to_h = nd2.transform * to_h; nd2 = nd2.get_parent()
	for f in ["index", "middle", "ring", "pinky", "thumb"]:
		for j in 3:
			var bi := sk.find_bone("%s_0%d_%s" % [f, j + 1, "l" if left else "r"])
			if bi < 0: continue
			var gb: Basis = (to_h * sk.get_bone_global_rest(bi)).basis.orthonormalized()
			var ax: Vector3 = (gb.y.cross(Vector3.DOWN)).normalized()
			if f == "thumb":   # the thumb closes across the palm, toward the root of the middle finger (about the fingers' axis it pointed straight down)
				var o: Vector3 = (to_h * sk.get_bone_global_rest(bi)).origin
				ax = gb.y.cross((Vector3(0.0, -0.035, -0.075) - o).normalized()).normalized()
			fb.append({"i": bi, "ax": (gb.inverse() * ax).normalized(), "thumb": f == "thumb", "j": j})
	# the thumb also swings out of the palm's plane (to come down on what lies in the hand): about the fingers' axis, at its root
	var tb: Dictionary = fb[12]
	var tgb: Basis = (to_h * sk.get_bone_global_rest(tb.i)).basis.orthonormalized()
	var zax := tgb.y.cross(Vector3.DOWN).normalized()   # (it lies along the fingers at rest: about their axis it would only roll)
	if (Basis(zax, 0.5) * tgb.y).y > tgb.y.y: zax = -zax     # the way that takes its tip to the palm's side (−Y)
	tb["ab"] = (tgb.inverse() * zax).normalized()
	# and away from the forefinger in the palm's plane (about the palm's normal): to lie up the edge of a thing held across the hand
	# (user 2026-11-18: 「親指はスマホの淵に沿って上を向く」). The 17th angle, where a grip has one
	var to: Vector3 = (to_h * sk.get_bone_global_rest(tb.i)).origin
	var yax := Vector3.UP
	if (Basis(yax, 0.5) * tgb.y).x * signf(to.x) < tgb.y.x * signf(to.x): yax = -yax
	tb["rad"] = (tgb.inverse() * yax).normalized()
	h.set_meta("sk", sk); h.set_meta("fb", fb); h.set_meta("curl", 0.0)
	var cf := Node3D.new(); cf.name = "cuff"; h.add_child(cf)
	_curl(h, 0.25)
	return h

func _mk_hand(left: bool) -> Node3D:
	if ResourceLoader.exists("res://props/mio_arm_l.glb") and not OS.get_cmdline_user_args().has("--boxhands"): return _mk_arm(left)
	var h := Node3D.new(); h.name = "hand_l" if left else "hand_r"
	var skin := StandardMaterial3D.new(); skin.albedo_color = SKIN; skin.roughness = 0.75
	var tx := 1.0 if left else -1.0
	var mk := func(mesh: Mesh, mat: Material, pos: Vector3, par: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.rotation = rot
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; mi.extra_cull_margin = 0.5
		par.add_child(mi); return mi
	var palm := BoxMesh.new(); palm.size = Vector3(0.078, 0.024, 0.088)
	mk.call(palm, skin, Vector3(0, 0, -0.048), h)
	var heel := CapsuleMesh.new(); heel.radius = 0.013; heel.height = 0.078
	mk.call(heel, skin, Vector3(0, 0, -0.092), h, Vector3(0, 0, PI / 2.0))       # the knuckles' round
	mk.call(heel, skin, Vector3(0, 0, -0.006), h, Vector3(0, 0, PI / 2.0))       # the wrist's round
	var kn := []; var jn := []
	var lens := [0.068, 0.076, 0.070, 0.056]
	for i in 4:
		var L: float = lens[i]
		var k := Node3D.new(); k.position = Vector3(tx * (0.0285 - 0.019 * i), 0.0, -0.094); h.add_child(k)
		var c1 := CapsuleMesh.new(); c1.radius = 0.0088; c1.height = L * 0.58
		mk.call(c1, skin, Vector3(0, 0, -L * 0.27), k, Vector3(PI / 2.0, 0, 0))
		var j := Node3D.new(); j.position = Vector3(0, 0, -L * 0.52); k.add_child(j)
		var c2 := CapsuleMesh.new(); c2.radius = 0.0082; c2.height = L * 0.54
		mk.call(c2, skin, Vector3(0, 0, -L * 0.23), j, Vector3(PI / 2.0, 0, 0))
		kn.append(k); jn.append(j)
	var tb := Node3D.new(); tb.position = Vector3(tx * 0.036, -0.004, -0.028); tb.rotation.y = -tx * 0.75; h.add_child(tb)
	var t1 := CapsuleMesh.new(); t1.radius = 0.0105; t1.height = 0.052
	mk.call(t1, skin, Vector3(0, 0, -0.024), tb, Vector3(PI / 2.0, 0, 0))
	var tj := Node3D.new(); tj.position = Vector3(0, 0, -0.046); tb.add_child(tj)
	var t2 := CapsuleMesh.new(); t2.radius = 0.0098; t2.height = 0.040
	mk.call(t2, skin, Vector3(0, 0, -0.016), tj, Vector3(PI / 2.0, 0, 0))
	var wr := CylinderMesh.new(); wr.top_radius = 0.027; wr.bottom_radius = 0.025; wr.height = 0.05
	mk.call(wr, skin, Vector3(0, 0, 0.02), h, Vector3(PI / 2.0, 0, 0))
	var sm := ShaderMaterial.new(); var sh := Shader.new(); sh.code = SLEEVE_SHADER; sm.shader = sh
	sm.set_shader_parameter("stain", 1.0 if left else 0.0)
	if left: sleeve_l = sm
	var sl := CylinderMesh.new(); sl.top_radius = 0.052; sl.bottom_radius = 0.036; sl.height = 0.34; sl.radial_segments = 20; sl.cap_bottom = false; sl.cap_top = false
	var slm: MeshInstance3D = mk.call(sl, sm, Vector3(0, 0, 0.03 + 0.17), h, Vector3(PI / 2.0, 0, 0))
	slm.name = "sleeve"
	var cuff := CylinderMesh.new(); cuff.top_radius = 0.0375; cuff.bottom_radius = 0.0375; cuff.height = 0.022; cuff.radial_segments = 20
	var cm := StandardMaterial3D.new(); cm.albedo_color = CLOTH.darkened(0.12); cm.roughness = 0.95; cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cf: MeshInstance3D = mk.call(cuff, cm, Vector3(0, 0, 0.04), h, Vector3(PI / 2.0, 0, 0)); cf.name = "cuff"
	h.set_meta("kn", kn); h.set_meta("jn", jn); h.set_meta("tb", tb); h.set_meta("tj", tj)
	_curl(h, 0.25)
	return h

# what she holds: the thing's place in the hand [turn about the hand's Y (deg), place], and each finger's joints bent until they touch it
# (15 joints: index, middle, ring, little, thumb, three each, then the thumb's swing out of the palm). Found and checked with
# scripts/grip_lab.gd (--c6bench): her skin is nowhere more than 1.5 mm into the thing (flesh gives that much)
const HOLDS := {
	"phone": [90.0, Vector3(-0.025, -0.033, -0.095), -35.0],   # across the hand: its right edge in the root of the thumb, the fingers hooked on its left edge, the thumb straight up its right edge (user 2026-11-18: 「スマホを持つ手、再検討して」「親指はスマホの淵に沿って上を向く」. The screen is cut where the hand is before it: PhoneMask)
	"cas": [60.0, Vector3(0.003, -0.017, -0.098)],      # across the fingers, the thumb on its lower corner (the label stays seen)
	"pack": [-60.0, Vector3(-0.005, -0.021, -0.098)],
	"case": [-15.0, Vector3(-0.020, -0.014, -0.100)],   # cradled, the thumb beside it (the lid must open)
}
const GRIPS := {
	"phone": [-0.06, 0.44, 0.32, 0.25, 0.5, 0.36, 0.42, 0.72, 0.27, 0.42, 0.72, 0.51, -0.2, 0.0, 0.0, 0.0, 1.2],   # (the 17th: the thumb out from the forefinger)
	"cas": [-0.3, 0.74, 1.2, 0.24, -0.22, -0.09, 0.48, -0.22, -0.12, 1.02, -0.19, -0.12, 0.0, 0.08, 0.95, -0.02],
	"pack": [-0.3, -0.22, 0.18, 0.18, -0.22, -0.12, 0.51, -0.22, -0.12, 1.02, -0.19, -0.12, 0.0, -0.1, 0.95, 0.04],
	"case": [-0.3, -0.22, -0.12, 0.21, -0.22, -0.06, 0.48, -0.22, -0.12, 1.02, -0.22, -0.12, -0.3, 0.13, 0.15, 0.23],
	# things that stand by themselves (the hand's place was brought onto them too: --c6fit)
	"tri_l": [0.56, 0.91, 0.64, 0.59, 0.95, 0.66, 0.64, 1.01, 0.7, 0.64, 1.01, 0.7, 0.0, 0.03, 0.95, 0.64],
	"tri_r2": [0.42, 0.72, 0.74, 0.54, 0.88, 0.62, 0.56, 0.91, 0.49, 0.56, 0.91, 0.64, 0.0, -0.07, 0.95, 0.46],
	"tri_l2": [0.56, 0.91, 0.64, 0.59, 0.95, 0.66, 0.64, 1.01, 0.7, 0.64, 1.01, 0.7, 0.0, 0.03, 0.95, 0.64],
	"cam_out": [0.37, 0.66, 0.47, 0.44, 0.76, 0.53, 0.54, 0.88, 0.62, 0.54, 0.88, 0.62, 0.0, -0.1, -0.1, 1.38],
	"cam_batt": [-0.3, -0.22, -0.12, -0.3, -0.22, -0.12, -0.13, 0.0, -0.12, -0.13, 0.0, 0.03, 0.07, -0.01, -0.04, 0.3],
	"candle": [-0.2, -0.09, -0.04, -0.01, 0.16, 0.13, 0.18, 0.41, 0.24, 0.18, 0.41, 0.3, 0.0, -0.1, -0.08, 0.28],
	"candle_r": [-0.18, -0.06, -0.02, 0.01, 0.19, 0.15, 0.23, 0.47, 0.04, 0.23, 0.47, 0.34, 0.0, -0.1, -0.08, 0.35],
	"wash": [0.52, 0.85, 0.59, 0.61, 0.98, 0.68, 0.61, 0.98, 0.68, 0.61, 0.98, 0.68, 0.0, -0.1, -0.1, -0.22],
	"lid": [-0.3, 1.1, 0.76, 0.35, 0.63, 0.45, 0.54, 0.88, 0.62, 0.54, 0.88, 0.62, 0.0, -0.1, 0.13, 1.03],
}

func _ang_set(h: Node3D, ang: Array):
	var sk: Skeleton3D = h.get_meta("sk"); var fb: Array = h.get_meta("fb")
	for k in fb.size():
		var b = fb[k]
		var q: Quaternion = sk.get_bone_rest(b.i).basis.get_rotation_quaternion()
		if b.has("rad") and ang.size() > 16: q = q * Quaternion(b.rad, ang[16])
		if b.has("ab") and ang.size() > 15: q = q * Quaternion(b.ab, ang[15])
		sk.set_bone_pose_rotation(b.i, q * Quaternion(b.ax, ang[k]))
	h.set_meta("ang", ang)

# close the fingers on a thing as found for it
func _grip(h: Node3D, key: String, dur := 0.4):
	if not h.has_meta("sk"): _curl(h, 0.3); return
	var a0: Array = h.get_meta("ang"); var a1: Array = GRIPS[key]
	create_tween().tween_method(func(k: float):
		var a := []
		for i in maxi(a0.size(), a1.size()): a.append(lerpf(a0[i] if i < a0.size() else 0.0, a1[i] if i < a1.size() else 0.0, k))
		_ang_set(h, a), 0.0, 1.0, maxf(dur, 0.01))

func _held(key: String) -> Transform3D:
	var e: Array = HOLDS[key]   # [the turn about the palm's normal, the place in the hand, (the tilt about its own length)]
	return Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(e[0]), deg_to_rad(e[2] if e.size() > 2 else 0.0)), EULER_ORDER_YXZ), e[1])

# where the hand must be for the thing to be where it was shown before (the hand at pos/deg with the thing at `was` in it)
func _hold_xf(key: String, pos: Vector3, deg: Vector3, was: Vector3) -> Transform3D:
	var old := Transform3D(Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)), EULER_ORDER_YXZ), pos) * Transform3D(Basis(), was)
	return old * _held(key).affine_inverse()

func _hold_to(h: Node3D, key: String, pos: Vector3, deg: Vector3, was: Vector3, dur := 0.6) -> Tween:
	_hand_claim(h)
	var x := _hold_xf(key, pos, deg, was)
	h.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(h, "position", x.origin, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "quaternion", x.basis.get_rotation_quaternion(), dur).set_trans(Tween.TRANS_SINE)
	return tw

# the fingers' curl: 0 flat, 1.3 a fist
func _curl(h: Node3D, a: float, thumb := -1.0):
	if h.has_meta("sk"):
		var t2 := a * 0.6 if thumb < 0.0 else thumb
		h.set_meta("curl", a)
		var ang := []
		for b in h.get_meta("fb"): ang.append((t2 * [0.30, 0.55, 0.40][b.j]) if b.thumb else (a * [0.80, 1.05, 0.70][b.j]))
		ang.append(0.0)
		_ang_set(h, ang)
		return
	for k in h.get_meta("kn"): (k as Node3D).rotation.x = -a
	for j in h.get_meta("jn"): (j as Node3D).rotation.x = -a * 1.15
	var t := a * 0.6 if thumb < 0.0 else thumb
	(h.get_meta("tj") as Node3D).rotation.x = -t
	(h.get_meta("tb") as Node3D).rotation.z = (1.0 if h == hand_l else -1.0) * t * 0.5

func _curl_to(h: Node3D, a: float, dur := 0.4):
	var a0: float = h.get_meta("curl") if h.has_meta("sk") else -((h.get_meta("kn")[0]) as Node3D).rotation.x
	create_tween().tween_method(func(v: float): _curl(h, v), a0, a, dur)

# the hand under the candle is lit by the candle itself (the saucer's shadow on it), not by the fill that stands for the
# candle on her other hand: in the print the lit hand and the saucer were one pale shape, and the saucer was not seen
func _hand_layer(h: Node3D, v: int):
	for mi in h.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).layers = v

func _hand_claim(h: Node3D):
	# a hand that is given something to do lets the candle go (and an older move of it stops)
	if h == c_hand:
		c_hand = null; _hand_layer(h, 2)
		if candle_held: c_block = h; print("CANDLEHAND taken from the candle: %s act=%s step=%d" % [h.name, act, step])
	if h.has_meta("tw") and (h.get_meta("tw") as Tween).is_valid(): (h.get_meta("tw") as Tween).kill()

func _hand_to(h: Node3D, pos: Vector3, deg: Vector3, dur := 0.6) -> Tween:
	_hand_claim(h)
	h.visible = true
	var q := Quaternion(Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)), EULER_ORDER_YXZ))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(h, "position", pos, dur).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "quaternion", q, dur).set_trans(Tween.TRANS_SINE)
	h.set_meta("tw", tw)
	return tw

# onto a thing from off it (not through it): first to a point 5 cm off along the back of the hand, then down
func _hand_onto(h: Node3D, pos: Vector3, deg: Vector3, dur := 0.7):
	var b := Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z)), EULER_ORDER_YXZ)
	_hand_claim(h)
	h.visible = true
	var tw := create_tween()
	tw.tween_property(h, "position", pos + b.y * 0.05, dur * 0.7).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(h, "quaternion", Quaternion(b), dur * 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "position", pos, dur * 0.3).set_trans(Tween.TRANS_SINE)

func _hand_away(h: Node3D, dur := 0.6):
	var side := -1.0 if h == hand_l else 1.0
	var tw := _hand_to(h, Vector3(0.22 * side, -0.62, -0.25), Vector3(30, 0, 0), dur)
	tw.chain().tween_callback(func(): h.visible = false)

# where a point of the world is in the camera's frame
func _in_rig(p: Vector3) -> Vector3:
	return rig6.global_transform.affine_inverse() * p

func _after(sec: float, c: Callable):
	get_tree().create_timer(sec).timeout.connect(c)

# kneel (or stand) at a plan point, looking at a point
func _go(at: Array, eye: float, look: Vector3, dur := 1.1):
	var p := gp(at[0], at[1], 0.0); p.y = player.global_position.y
	var tw := create_tween()
	tw.tween_property(player, "global_position", p, dur).set_trans(Tween.TRANS_SINE)
	player.velocity = Vector3.ZERO
	_eye(eye, dur)
	var from: Vector3 = Vector3(p.x, p.y + eye, p.z)
	var to := look - from
	var y1: float = player.yaw + wrapf(atan2(-to.x, -to.z) - player.yaw, -PI, PI)
	if turn_tw and turn_tw.is_valid(): turn_tw.kill()
	turn_tw = create_tween().set_parallel(true)
	turn_tw.tween_property(player, "yaw", y1, dur).set_trans(Tween.TRANS_SINE)
	turn_tw.tween_property(player, "pitch", asin(clampf(to.normalized().y, -1.0, 1.0)), dur).set_trans(Tween.TRANS_SINE)

# ================================================================ the things this chapter brings
var bag6: Node3D
var bag_full := Vector3.ONE
var cas1: Node3D               # the first tape (her hand: 「定点」)
var cas2: Node3D               # the second (blank)
var phone: Node3D
var pack: Node3D
var cable: MeshInstance3D
var case6: Node3D              # the 「上映用」 box, in her hands
var case_lid: Node3D
var box_env: Array = []
var water: MeshInstance3D
var basin: MeshInstance3D
var basin_mat: StandardMaterial3D
var tri_blood: MeshInstance3D
var tripod_h := 1.44
var up_tape: MeshInstance3D
var peeled_balls: Node3D

func _box_mesh(size: Vector3, col: Color, rough := 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough; mi.material_override = m
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mi

func _text3(text: String, px: float, col: Color, fs := 48) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font = Type.say(); l.font_size = fs; l.pixel_size = px
	l.modulate = col; l.outline_size = 0; l.shaded = false; l.double_sided = false
	l.no_depth_test = false; l.render_priority = 1
	return l

func _cassette(label: String) -> Node3D:
	# lies on her fingers: its face is its -Y side, its top edge to -Z
	var c := Node3D.new()
	var body := _box_mesh(Vector3(0.066, 0.012, 0.048), Color(0.16, 0.16, 0.17), 0.4); c.add_child(body)
	var win := _box_mesh(Vector3(0.040, 0.0005, 0.012), Color(0.42, 0.40, 0.36), 0.2); c.add_child(win); win.position = Vector3(0, -0.0062, 0.012)
	var lab := _box_mesh(Vector3(0.054, 0.0005, 0.018), Color(0.93, 0.92, 0.88), 0.9); c.add_child(lab); lab.position = Vector3(0, -0.0062, -0.012)
	if label != "":
		var t := _text3(label, 0.00028, Color(0.08, 0.10, 0.2)); c.add_child(t)
		t.position = Vector3(0, -0.0068, -0.012); t.basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI / 2.0)
	c.visible = false
	return c

func _props6():
	# 試作231（ユーザー「ラジオないのに選択できる」）: the radio itself, where 【見る.ラジオ】 says it is (the house has it only in
	# 第1・2章, story.gd). Switched off: no dial lamp
	if ResourceLoader.exists("res://props/radio.glb"):
		var rd: Node3D = (load("res://props/radio.glb") as PackedScene).instantiate(); rd.name = "ch6_radio"
		for mi in rd.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		main.add_child(rd)
		var ra: Array = LOOKS[3][2]
		rd.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(200.0)), gp(ra[0], ra[1], ra[2] - 0.07))
	for mi in main.S.env_node.find_children("bed1b_blanket*", "MeshInstance3D", true, false): (mi as Node3D).visible = false   # it is over Natsuki
	# the tripod's bag, flat and open, where the crew's things are
	if ResourceLoader.exists("res://props/tripod_case.glb"):
		# the user's own case (Tripo, 2026-11-17): 0.98 long, lying along the wall; flat until the tripod is in it
		bag6 = (load("res://props/tripod_case.glb") as PackedScene).instantiate()
		for mi in bag6.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		main.add_child(bag6)
		bag6.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), gp(BAG_AT[0], BAG_AT[1], 0.0))
		bag6.scale = Vector3(1.0, 0.5, 1.0)
	else:
		var bmi := MeshInstance3D.new(); var cm := CapsuleMesh.new(); cm.radius = 0.10; cm.height = 0.98; bmi.mesh = cm
		var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.10, 0.11, 0.14); bm.roughness = 0.9; bmi.material_override = bm
		bmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		bag6 = bmi; main.add_child(bag6)
		bag6.global_transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3(1.0, 0.45, 1.0)), gp(BAG_AT[0], BAG_AT[1], 0.05))
		bag_full = Vector3(1.0, 0.85, 1.0)
	# what the blow left on the tripod's head
	if tripod:
		var bb := AABB(); var first := true
		for mi in tripod.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
			bb = a if first else bb.merge(a); first = false
			if OS.get_cmdline_user_args().has("--c6names"): print("TPD %s y %.2f..%.2f" % [mi.name, a.position.y, a.end.y])
		tripod_h = bb.end.y
		for mi in tripod.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).layers |= 2
		_tri_rig(bb)
		tri_blood = MeshInstance3D.new(); tri_blood.name = "nocol_blood"; var cy := CylinderMesh.new(); cy.top_radius = 0.075; cy.bottom_radius = 0.07; cy.height = 0.16; tri_blood.mesh = cy
		var rm := StandardMaterial3D.new(); rm.albedo_color = Color(0.13, 0.008, 0.008, 0.92); rm.roughness = 0.25; rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tri_blood.material_override = rm; tri_blood.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		tripod.add_child(tri_blood); tri_blood.position = Vector3(bb.get_center().x, tripod_h - 0.10, bb.get_center().z)
		print("CH6 tripod local bb %s" % bb)
	cas1 = _cassette("定点"); cas2 = _cassette("")
	add_child(cas1); add_child(cas2)
	_phone6()
	_case6()
	_sink6()
	# the tape she took off downstairs: five grey balls on the kitchen's counter
	peeled_balls = Node3D.new(); main.add_child(peeled_balls)
	var rng := RandomNumberGenerator.new(); rng.seed = 6
	for i in 5:
		var b := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.022 + rng.randf() * 0.008; sp.height = sp.radius * 1.5; b.mesh = sp
		b.material_override = _tape_mat(); b.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		peeled_balls.add_child(b); b.position = Vector3(rng.randf_range(-0.09, 0.09), 0.0, rng.randf_range(-0.05, 0.05)); b.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
	peeled_balls.global_position = _target("peeled").pos if not _target("peeled").is_empty() else gp(6.6, 7.55, 0.93)
	# Kiryu's tape on the bedroom window upstairs: still on
	up_tape = MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(0.9, 0.05, 0.004); up_tape.mesh = tb
	up_tape.material_override = _tape_mat(); up_tape.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(up_tape); up_tape.global_position = gp(1.5, 0.075, F2 + 0.92)

# ---------------------------------------------------------------- the targets of the hands' work
func _targets6():
	_looks6()
	if tripod:
		_add_target("tripod", gp(TRIPOD_AT[0], TRIPOD_AT[1] + 0.5, 0.1), 2.4, 30.0, func(): return not done6.has("tripod") and not carrying,
			func(): return _prompt("三脚.拾う"), _tripod_take)
	_add_target("bag", gp(BAG_AT[0], BAG_AT[1], 0.1), 3.2, 34.0, func(): return carrying, func(): return _prompt("三脚.袋"), _tripod_bag)
	_add_target("cam", fixed_cam.global_position, 2.3, 22.0, func(): return not carrying and not (done6.has("cam") and done6.has("batt")),
		func(): return "［%s］" % T("カメラ") if not looked.has("cam") else _prompt("カメラ.出す") if not done6.has("cam") else _prompt("カメラ.電池"), _cam_press)
	# 試作231（ユーザー「夏希を選択できない」）: she can be looked at all the time; between the phone's steps it is one line
	_add_target("nat", Vector3.ZERO, 2.3, 30.0, func(): return not carrying and act == "",
		func(): return _prompt("スマホ.取る") if phone_st == 1 else _prompt("スマホ.つなぐ") if (phone_st == 2 and has_pack) else "［%s］" % T("夏希"), _nat_press)
	_add_target("bag_m", gp(2.55, 3.85, F2 + 0.25), 1.9, 26.0, func(): return phone_st == 2 and not has_pack, func(): return _prompt("鞄.バッテリー"), _pack_take)
	_add_target("box", gp(2.15, 2.23, 0.43), 1.9, 24.0, func(): return box_st in [1, 3] and not carrying,
		func(): return _prompt("箱.開ける"), _box_press)
	_add_target("sink", gp(TAP[0], TAP[1], TAP[2] - 0.1), 1.9, 28.0, func(): return done6.has("box") and not done6.has("sleeve"),
		func(): return "［%s］" % T("流し"), _sleeve_press)
	_add_target("sit", gp(SIT6[0], SIT6[1], 0.25), 2.0, 40.0, func(): return done6.has("sleeve"), func(): return _prompt("座る"), _sit)
	_add_target("uptape", gp(1.5, 0.075, F2 + 0.92), 1.9, 20.0, func(): return looked.has("window") and not done6.has("uptape"),
		func(): return _prompt("二階.テープ"), _uptape)

func _nat_tick():
	if nat_ready:
		var t := _target("nat")
		if not t.is_empty(): t.pos = _nat_chest() + Vector3(0, 0.1, 0)

# ================================================================ Ａ 三脚
var carrying := false
var tri_close := 0.0           # the legs brought together (0 open as it stood, 1 shut)
var leg_in := [0.0, 0.0, 0.0]  # each leg's lower tube pushed up into the upper (0..1)
var tri_legs: Array = []       # {piv, low, ax, ang, dir}
var tri_spread: Array = []
const LEG_SLIDE := 0.56

# the legs as legs: each turns in at its hinge under the head, and its lower tube slides up into the upper one
# (it was the whole tripod squeezed by a scale: the head went flat with the legs)
func _tri_rig(bb: AABB):
	var parts := tripod.find_children("tpd_*", "MeshInstance3D", true, false)
	var box := func(mi: Node) -> AABB: return (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
	# the column's axis: the middle of the three feet (the box of the whole thing is pulled aside by the pan bar)
	var c := Vector3.ZERO; var nf := 0
	for mi in parts:
		if String(mi.name).begins_with("tpd_foot"): c += (box.call(mi) as AABB).get_center(); nf += 1
	c = Vector3(bb.get_center().x, 0.0, bb.get_center().z) if nf == 0 else Vector3(c.x / nf, 0.0, c.z / nf)
	for u in parts:
		if not String(u.name).begins_with("tpd_leg"): continue
		var ua: AABB = box.call(u)
		if ua.end.y < tripod_h * 0.75: continue            # an upper tube: it reaches the head
		var out := Vector3(ua.get_center().x - c.x, 0.0, ua.get_center().z - c.z).normalized()
		# the tube's own ends: the middle of its top and bottom vertices (the box's corners are not on a tube that leans)
		var hinge := Vector3.ZERO; var knee := Vector3.ZERO; var n1 := 0; var n2 := 0
		var um := u as MeshInstance3D
		for si in um.mesh.get_surface_count():
			for v in (um.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var q: Vector3 = um.transform * v
				if q.y > ua.end.y - 0.03: hinge += q; n1 += 1
				if q.y < ua.position.y + 0.03: knee += q; n2 += 1
		hinge /= maxf(n1, 1); knee /= maxf(n2, 1)
		var dir := (knee - hinge).normalized()
		var piv := Node3D.new(); tripod.add_child(piv); piv.position = hinge
		var low := Node3D.new(); piv.add_child(low)
		for mi in parts:
			var nm := String(mi.name)
			if not (nm.begins_with("tpd_leg") or nm.begins_with("tpd_collar") or nm.begins_with("tpd_lock") or nm.begins_with("tpd_foot")): continue
			if mi.get_parent() != tripod: continue
			var a: AABB = box.call(mi)
			var o := Vector3(a.get_center().x - c.x, 0.0, a.get_center().z - c.z)
			if o.length() < 0.01 or o.normalized().dot(out) < 0.8: continue
			var lower: bool = (nm.begins_with("tpd_leg") and a.end.y < tripod_h * 0.75) or nm.begins_with("tpd_foot")
			var t: Transform3D = (mi as Node3D).transform
			tripod.remove_child(mi); (low if lower else piv).add_child(mi)
			(mi as Node3D).transform = Transform3D(Basis(), -hinge) * t
		if OS.get_cmdline_user_args().has("--c6names"): print("LEG hinge %s knee %s ang %.1f up %s low %s" % [hinge, knee, rad_to_deg(dir.angle_to(Vector3.DOWN)), piv.get_children().map(func(n): return n.name), low.get_children().map(func(n): return n.name)])
		tri_legs.append({"piv": piv, "low": low, "ax": dir.cross(Vector3.DOWN).normalized(), "ang": dir.angle_to(Vector3.DOWN), "dir": dir})
	for mi in parts:
		if String(mi.name).begins_with("tpd_spread"): tri_spread.append(mi)
	print("CH6 tripod legs %d spread %d h %.2f" % [tri_legs.size(), tri_spread.size(), tripod_h])

func _tri_pose():
	for i in tri_legs.size():
		var L: Dictionary = tri_legs[i]
		(L.piv as Node3D).basis = Basis(L.ax, L.ang * tri_close)
		(L.low as Node3D).position = -(L.dir as Vector3) * LEG_SLIDE * float(leg_in[mini(i, 2)])
	for mi in tri_spread:
		(mi as Node3D).visible = tri_close < 0.5     # the spreader folds up between the legs

func _tri_len() -> float:
	var m := 0.0
	for v in leg_in: m = maxf(m, 1.0 - float(v))
	return tripod_h - LEG_SLIDE * (1.0 - m) * 0.98
var tri_head := Vector3(0.30, -0.16, -0.42)
var tri_axis := Vector3(-1.0, -0.03, -0.12)   # from its head to its feet, in her hands
var wipe := 0.0
var tri_back := 0.0
var wipe_snd := 0.0

func _tri_place():
	if not carrying and act != "tripod": return
	var ax := tri_axis.normalized()
	var y := -ax; var x := y.cross(Vector3.BACK).normalized(); var z := x.cross(y).normalized()
	_tri_pose()
	# under her arm it is drawn back from a wall or a thing in front of it (its feet went into them)
	var back_want := 0.0
	if carrying:
		var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
		var a: Vector3 = rig6.global_transform * (tri_head - ax * 0.25); var c: Vector3 = rig6.global_transform * (tri_head + ax * (_tri_len() + 0.06))
		var q := PhysicsRayQueryParameters3D.create(a, c); q.exclude = [player.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty(): back_want = c.distance_to(hit.position)
	tri_back = lerpf(tri_back, back_want, 0.25) if back_want < tri_back else back_want
	tripod.transform = Transform3D(Basis(x, y, z), tri_head + ax * (tripod_h - tri_back))

# the way to face with it across her hands: where its whole length is in the air (it stood through the stair's side.
# User 2026-11-18: 「三脚が階段を貫いてる？」). The nearest such turn from where she looks
func _tri_hits(yaw: float, pitch: float, head: Vector3, axis: Vector3, ln: float) -> bool:
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	var eye := _cam().global_position
	for off in [Vector3.ZERO, Vector3(0, 0.09, 0), Vector3(0, -0.09, 0), Vector3(0, 0, -0.10), Vector3(0, 0, 0.10)]:
		var a: Vector3 = eye + b * (head + off); var c: Vector3 = a + b * (axis.normalized() * ln)
		var q := PhysicsRayQueryParameters3D.create(a, c); q.exclude = [player.get_rid()]
		if not space.intersect_ray(q).is_empty(): return true
	return false

func _tri_clear_yaw() -> float:
	var pitch := atan2(-0.35, 1.0)
	for i in 25:
		var k := float((i + 1) / 2) * (1.0 if i % 2 == 1 else -1.0)
		var yaw: float = player.yaw + k * deg_to_rad(15.0)
		if not _tri_hits(yaw, pitch, tri_head, tri_axis, tripod_h + 0.12):
			print("TRIPOD clear to hold at a turn of %d deg" % int(k * 15.0)); return yaw
	print("TRIPOD no clear turn here"); return player.yaw

func _tripod_take():
	act = "tripod"; step = 0; note_lb.text = ""
	_turn_to(gp(TRIPOD_AT[0], TRIPOD_AT[1] + 0.6, 0.0), 0.8)
	var f := Basis(Vector3.UP, player.yaw)
	_candle_down(player.global_position + f * Vector3(0.45, 0.0, -0.35))
	_after(0.9, func():
		# into her hands: it comes up off the boards
		var gt := tripod.global_transform
		tripod.get_parent().remove_child(tripod); rig6.add_child(tripod); tripod.global_transform = gt
		var t0 := tripod.transform
		Sound.one(self, "tripod_bump", -14.0)
		var tw := create_tween()
		tw.tween_method(func(k: float):
			_tri_place(); tripod.transform = t0.interpolate_with(tripod.transform, k), 0.0, 1.0, 1.5).set_trans(Tween.TRANS_SINE)
		create_tween().tween_property(self, "tri_close", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
		_turn_to(_cam().global_position + Basis(Vector3.UP, _tri_clear_yaw()) * Vector3(0, -0.35, -1.0), 1.5)
		_hand_to(hand_l, tri_head + tri_axis.normalized() * 0.30 + Vector3(0.001, 0.008, 0.045), Vector3(25, -15, 0), 1.4); _grip(hand_l, "tri_l", 1.4)
		_fit_dev(hand_l, "tri_l", [tripod], 1.9, null, true, true, -9.0, true)
		_after(1.7, func(): step = 1; _show_prompt("三脚.拭く")))

func _show_prompt(key: String):
	note_lb.text = _prompt(key) if key != "" else ""

func _tripod_tick(dt: float):
	_tri_place()
	if step == 1:
		# her cuff pulled over her hand, along the head and back (her own hand's shadow over it)
		if _holding():
			if not hand_r.visible or wipe <= 0.0: _hand_to(hand_r, tri_head + Vector3(0.03, 0.025, 0.05), Vector3(25, 15, 0), 0.4); _curl(hand_r, 0.3); (hand_r.get_node("cuff") as Node3D).position.z = -0.03; (hand_r.get_node("cuff") as Node3D).scale = Vector3(1.25, 3.2, 1.25)
			if wipe <= 0.0:
				for kk in 3: _fit_dev(hand_r, "tri_w%d" % kk, [tripod], 0.5 + 0.02 * kk, tri_head + tri_axis.normalized() * (0.07 * kk) + Vector3(0.0, 0.035, 0.05), true, false, -9.0, true)
			wipe = minf(1.0, wipe + dt / 3.6)
			if wipe > 0.1:
				# (the hand rides the head's shape along the stroke: found at three points with --c6fit)
				var u := 1.0 + sin(t_now * 7.5)
				var dn: Vector3 = Vector3(-0.0015, -0.0105, -0.0045).lerp(Vector3(-0.0025, -0.0195, -0.009), u) if u < 1.0 else Vector3(-0.0025, -0.0195, -0.009).lerp(Vector3(-0.002, -0.016, -0.007), u - 1.0)
				hand_r.position = tri_head + tri_axis.normalized() * (0.07 * u) + Vector3(0.0, 0.035, 0.05) + dn
			wipe_snd -= dt
			if wipe_snd <= 0.0: wipe_snd = 0.55; Sound.one(self, "ch3_blanket", -20.0)
			(tri_blood.material_override as StandardMaterial3D).albedo_color.a = 0.92 * (1.0 - wipe)
			if wipe >= 1.0:
				tri_blood.visible = false; step = 2; legs_n = 0
				(hand_r.get_node("cuff") as Node3D).position.z = 0.04; (hand_r.get_node("cuff") as Node3D).scale = Vector3.ONE
				_hand_to(hand_r, tri_head + tri_axis.normalized() * 0.10 + Vector3(-0.0025, -0.003, 0.0395), Vector3(25, 15, 0), 0.6); _hand_to(hand_l, tri_head + tri_axis.normalized() * 0.72 + Vector3(0.0015, 0.008, 0.045), Vector3(25, -15, 0), 0.6)
				_grip(hand_r, "tri_r2", 0.6); _grip(hand_l, "tri_l2", 0.6)
				_fit_dev(hand_r, "tri_r2", [tripod], 0.8, null, true, true, -9.0, true); _fit_dev(hand_l, "tri_l2", [tripod], 0.85, null, true, true, -9.0, true)
				_show_prompt("三脚.脚")
var legs_n := 0

func _tripod_press():
	if step == 2 and legs_n < 3:
		legs_n += 1
		var li := legs_n - 1
		create_tween().tween_method(func(v: float): leg_in[li] = v, 0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUAD)
		# each lock is heard through the whole house
		Sound.one(self, "lock", 2.0)
		_after(0.28, func(): Sound.one(self, "lock", -13.0, gp(5.2, 6.4, F2 + 1.0)))
		# her hand at the lock: a turn of the wrist, and the tube runs in
		var hq := hand_l.quaternion
		var tw := create_tween()
		tw.tween_property(hand_l, "quaternion", hq * Quaternion(Vector3.FORWARD, 0.35), 0.12)
		tw.tween_property(hand_l, "quaternion", hq, 0.25)
		if legs_n == 3:
			step = 3; note_lb.text = ""
			_after(0.9, func():
				# under her arm; the candle in her other hand
				_hand_away(hand_l, 0.5); _hand_away(hand_r, 0.5)
				create_tween().tween_property(self, "tri_head", Vector3(0.34, -0.30, -0.25), 0.9).set_trans(Tween.TRANS_SINE)
				create_tween().tween_property(self, "tri_axis", Vector3(0.05, -0.38, -0.9), 0.9).set_trans(Tween.TRANS_SINE)
				candle_off = Vector3(-0.2, -0.36, -0.42); _candle_up()
				_after(1.0, func(): act = ""; carrying = true))

func _tripod_bag():
	carrying = false; act = "bag"; note_lb.text = ""
	_turn_to(gp(BAG_AT[0], BAG_AT[1], 0.1), 0.7)
	var gt := tripod.global_transform
	rig6.remove_child(tripod); main.add_child(tripod); tripod.global_transform = gt
	var ln := _tri_len()
	var to := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), gp(BAG_AT[0], BAG_AT[1] - tripod_h + ln * 0.5, 0.07))
	var tw := create_tween()
	tw.tween_property(tripod, "global_transform", to, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		Sound.one(self, "ch3_blanket", -12.0, gp(BAG_AT[0], BAG_AT[1], 0.1))
		tripod.visible = false
		bag6.scale = bag_full)   # full
	tw.tween_interval(0.8)
	tw.tween_callback(func():
		done6["tripod"] = true; act = ""
		candle_off = Vector3(0.2, -0.36, -0.42)
		_run_block("三脚.袋")
		# 2026-11-21 (review): its ［flag］ testimony was dropped by _run_block (it runs ＞ and ◇ only)
		var t := ret_t + 0.6
		for bl in D.lines("三脚.袋"):
			var fl := _flag_line(String(bl))
			if fl.begins_with("澪＊："): ret_q.append([t, _ret_row.bind(fl, true)]); t += fl.length() / 18.0 + 1.3)

# what a block does besides its prompt (＞ and ◇)
func _run_block(key: String):
	for e in B(key):
		if e.has("if") and not has_flag(String(e["if"])): continue
		if e.has("do"): _do(String(e.do))
		elif e.has("mission"): _set_mission(String(e.mission))

# ================================================================ Ｂ 定点のカメラ
func _cam_press():
	if not looked.has("cam"):
		looked["cam"] = true
		_ret_open("カメラ.見る"); return
	if not done6.has("cam"): _cam_out(); return
	_cam_batt()

func _cam_top() -> Vector3:
	return fixed_cam.global_position + fixed_cam.global_basis.y * 0.075

func _cam_out():
	act = "cam"; step = 0; note_lb.text = ""
	if ret_rows.is_empty(): _ret_open("カメラ.見る")
	ret_hold = -1.0
	_step_near(fixed_cam.global_position)
	_turn_to(fixed_cam.global_position + Vector3(0, -0.12, 0), 0.9)
	candle_off = Vector3(-0.10, -0.14, -0.30)     # held up to it
	_after(1.0, func():
		_grip(hand_r, "cam_out", 0.7)
		_hand_onto(hand_r, _in_rig(_cam_top()) + Vector3(0.0185, -0.055, 0.0825), Vector3(55, 10, 0), 0.7)
		_fit_dev(hand_r, "cam_out", [fixed_cam], 0.72, null, true, true, 0.3, true)
		_after(0.7, func():
			Sound.one(self, "tape_clunk", -8.0, fixed_cam.global_position)
			cas2.visible = true
			cas2.get_parent().remove_child(cas2); main.add_child(cas2)
			cas2.global_transform = Transform3D(fixed_cam.global_basis * Basis(Vector3.RIGHT, -PI / 2.0), _cam_top() - fixed_cam.global_basis.y * 0.03)
			var tw := create_tween()
			tw.tween_property(cas2, "global_position", _cam_top() + fixed_cam.global_basis.y * 0.012, 0.5)
			tw.tween_interval(0.3)
			tw.tween_callback(func():
				# onto her fingers, and down before her eye: nothing is written on it
				var gt := cas2.global_transform
				main.remove_child(cas2); hand_r.add_child(cas2); cas2.global_transform = gt
				create_tween().tween_property(cas2, "transform", _held("cas"), 0.5)
				_grip(hand_r, "cas", 0.5); _hold_to(hand_r, "cas", Vector3(0.04, -0.12, -0.24), Vector3(62, 6, 180), Vector3(0, -0.034, -0.075), 0.9)
				_after(1.6, func(): step = 1; _show_prompt("カメラ.入れる")))))

func _cam_in():
	step = 2; note_lb.text = ""
	# the second into her pouch; the first out of it
	var tw := _hand_to(hand_r, Vector3(0.24, -0.6, -0.2), Vector3(30, 0, 180), 0.6)
	tw.chain().tween_callback(func():
		cas2.visible = false
		hand_r.remove_child(cas2); add_child(cas2)
		cas1.get_parent().remove_child(cas1); hand_r.add_child(cas1); cas1.visible = true
		cas1.transform = _held("cas"); _grip(hand_r, "cas", 0.05)
		Sound.one(self, "ch3_blanket", -18.0)
		# up into the candle's light, tilted to it: 「定点」, in her own hand
		_hold_to(hand_r, "cas", Vector3(-0.01, -0.105, -0.215), Vector3(66, -12, 180), Vector3(0, -0.034, -0.075), 0.9)
		_after(2.6, func():
			_hand_to(hand_r, _in_rig(_cam_top()) + Vector3(0.02, -0.06, 0.10), Vector3(55, 10, 0), 0.9)
			_fit_dev(hand_r, "cam_in", [fixed_cam], 0.88, null, false, false)
			_after(0.9, func():
				var gt := cas1.global_transform
				hand_r.remove_child(cas1); main.add_child(cas1); cas1.global_transform = gt
				var tw2 := create_tween()
				tw2.tween_property(cas1, "global_transform", Transform3D(fixed_cam.global_basis * Basis(Vector3.RIGHT, -PI / 2.0), _cam_top() + fixed_cam.global_basis.y * 0.012), 0.4)
				tw2.tween_property(cas1, "global_position", _cam_top() - fixed_cam.global_basis.y * 0.035, 0.5)
				tw2.tween_callback(func():
					cas1.visible = false
					Sound.one(self, "cassette_in", -4.0, fixed_cam.global_position)
					_hand_away(hand_r, 0.7)
					done6["cam"] = true
					_ret_after("カメラ.あと", 9.0)
					_after(1.2, func(): act = ""; candle_off = Vector3(0.2, -0.36, -0.42))))))

# the battery (してもしなくてもよい): hers out, the first one back
func _cam_batt():
	act = "batt"; note_lb.text = ""
	if ret_rows.is_empty(): _ret_open("カメラ.見る")
	ret_hold = -1.0
	_step_near(fixed_cam.global_position)
	_turn_to(fixed_cam.global_position + Vector3(0, -0.12, 0), 0.7)
	candle_off = Vector3(-0.10, -0.14, -0.30)
	_after(0.8, func():
		_grip(hand_r, "cam_batt", 0.7)
		_hand_onto(hand_r, _in_rig(fixed_cam.global_position) + Vector3(0.029, -0.0635, 0.106), Vector3(50, 15, 0), 0.7)
		_fit_dev(hand_r, "cam_batt", [fixed_cam], 0.75, null, true, true, 0.3, true)
		_after(0.8, func(): Sound.one(self, "lock", -10.0, fixed_cam.global_position))
		_after(1.7, func(): Sound.one(self, "ch3_lock", -12.0, fixed_cam.global_position))
		_after(2.2, func():
			_hand_away(hand_r, 0.7)
			done6["batt"] = true
			_ret_after("カメラ.電池.あと", 7.0)
			_after(1.0, func(): act = ""; candle_off = Vector3(0.2, -0.36, -0.42))))

# ================================================================ the hands' work: one clock, one key
func _act_tick(dt: float):
	_nat_tick()
	tri_fill.light_energy = move_toward(tri_fill.light_energy, (1.1 * 0.56 / maxf(exp_now, 0.3)) if (act == "tripod" or carrying) and not candle_out else 0.0, dt * 1.2)
	fill6.light_energy = move_toward(fill6.light_energy, ((0.10 if act == "phone" else 0.26) * 0.56 / maxf(exp_now, 0.3)) if (hand_l.visible or hand_r.visible) and not candle_out else 0.0, dt * 1.2)
	if carrying or act == "tripod": _tripod_tick(dt)
	match act:
		"phone": _phone_tick(dt)
		"sleeve": _sleeve_tick(dt)
	_phone_ui_tick(dt)
	_box_tick()

func _act_press():
	match act:
		"tripod": _tripod_press()
		"cam":
			if step == 1: _cam_in()
		"phone": _phone_press()
		"box": _box_step()

# ================================================================ Ｃ 夏希のスマホ
# The screen is the one thing in the house that is not printed: bare paper, with small black type on it (ユーザー 2026-11-18
# 「携帯調べる時のビジュアル、新鮮な感じにしたい」). It is drawn over the print, where the phone's glass is; its light
# is paper-white on Natsuki's face. A deleted letter is un-printed. When the cord comes out the paper goes back under the ink.
const KN := [4.98, 2.20]              # on her knees beside her (plan): her pocket and her face both in reach
const PH_HOLD := Vector3(0.0, -0.085, -0.225)
const PH_DEG := Vector3(66, 0, 180)
var ph_mode := "off"           # off | dead | lock | chat
var ph_lit := 0.0
var ph_lit_want := 0.0
var ph_code := 0
var ph_chat: Array = []        # [[mine: bool, text]]
var ph_draft0 := ""
var ph_n := 0.0                # the draft's letters still there
var ph_ui: Control
var ph_light: OmniLight3D
var ph_glass: StandardMaterial3D
var ph_spot := Vector3.ZERO
var del_tick := 0

class PhoneMask extends Node2D:
	var st
	var cache := {}
	func _process(_dt): queue_redraw()
	func _draw():
		if st == null or st.phone == null or not st.phone.is_visible_in_tree() or st.ph_lit <= 0.01: return
		var cam := get_viewport().get_camera_3d()
		if cam == null: return
		var GL = load("res://scripts/grip_lab.gd")
		var pg: Transform3D = st.phone.global_transform
		var white := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
		for h in [st.hand_r, st.hand_l]:
			if h == null or not h.visible or not h.has_meta("sk"): continue
			if (h.global_position as Vector3).distance_to(pg.origin) > 0.3: continue
			var rel: Transform3D = pg.affine_inverse() * (h.global_transform as Transform3D)
			var key := [(h.get_meta("ang") as Array).duplicate(), rel.origin.snappedf(0.0005), rel.basis.get_euler().snappedf(0.003)]
			if not cache.has(h.name) or cache[h.name][0] != key:
				# her hand's triangles that are before the glass, in the phone's frame (found again only when the hold changes)
				var to_p: Transform3D = rel * GL.sk_to_h(h)
				var out := PackedVector3Array()
				for mi in h.find_children("*", "MeshInstance3D", true, false):
					if (mi as MeshInstance3D).skin == null: continue
					var F: PackedVector3Array = GL.skinned_faces(mi)
					for i in range(0, F.size(), 3):
						var a: Vector3 = to_p * F[i]; var b: Vector3 = to_p * F[i + 1]; var c: Vector3 = to_p * F[i + 2]
						if minf(a.y, minf(b.y, c.y)) > -0.0048: continue
						if absf(a.x) > 0.045 and absf(b.x) > 0.045 and absf(c.x) > 0.045: continue
						if absf(a.z) > 0.08 and absf(b.z) > 0.08 and absf(c.z) > 0.08: continue
						out.append(a); out.append(b); out.append(c)
				cache[h.name] = [key, out]
			var T: PackedVector3Array = cache[h.name][1]
			for i in range(0, T.size(), 3):
				var p0: Vector3 = pg * T[i]; var p1: Vector3 = pg * T[i + 1]; var p2: Vector3 = pg * T[i + 2]
				if cam.is_position_behind(p0) or cam.is_position_behind(p1) or cam.is_position_behind(p2): continue
				draw_primitive(PackedVector2Array([cam.unproject_position(p0), cam.unproject_position(p1), cam.unproject_position(p2)]), white, PackedVector2Array())

# 試作232（ユーザー「画面の表示がズレてる」、第6章のスマホ）: the screen was drawn with one flat (affine) map from three of
# its corners: held at a slant, the far end of the glass is narrower than the near (perspective) and the page stood off the
# glass by the difference (the lit glass showing beside it). The page is drawn once, flat, into its own small viewport, and
# laid on the glass as a grid of small quads whose corners are the glass's own points projected: it follows the glass
class PhoneUI extends Control:
	var st
	var sv: SubViewport
	const W := 310.0
	const H := 660.0
	const NX := 6
	const NY := 12
	func _process(_dt): queue_redraw()
	func _draw():
		if st == null or st.phone == null or not st.phone.is_visible_in_tree() or st.ph_lit <= 0.01: return
		var cam := get_viewport().get_camera_3d()
		if cam == null or sv == null: return
		var gt: Transform3D = st.phone.global_transform
		if (gt.basis * Vector3(0, -1, 0)).dot(cam.global_position - gt.origin) <= 0.0: return   # its back is to her
		var pts: Array = []
		for j in NY + 1:
			var row: Array = []
			for i in NX + 1:
				var q: Vector3 = gt * Vector3(lerpf(0.031, -0.031, float(i) / NX), -0.0052, lerpf(-0.066, 0.066, float(j) / NY))
				if cam.is_position_behind(q): return
				row.append(cam.unproject_position(q))
			pts.append(row)
		var tex := sv.get_texture()
		var col := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		for j in NY:
			for i in NX:
				var u0 := float(i) / NX; var u1 := float(i + 1) / NX; var v0 := float(j) / NY; var v1 := float(j + 1) / NY
				draw_primitive(PackedVector2Array([pts[j][i], pts[j][i + 1], pts[j + 1][i + 1], pts[j + 1][i]]), col,
					PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]), tex)

class PhoneDraw extends Control:
	var st
	const W := 310.0
	const H := 660.0
	func _process(_dt): queue_redraw()
	func _draw():
		if st == null or st.ph_lit <= 0.01: return
		var lit: float = st.ph_lit
		var paper := Color(0.965, 0.955, 0.93, lit)
		var ink := Color(0.06, 0.08, 0.14, lit)
		var f: Font = st.font
		draw_rect(Rect2(0, 0, W, H), paper)
		match String(st.ph_mode):
			"dead":
				draw_rect(Rect2(W / 2 - 52, H / 2 - 26, 104, 52), ink, false, 4.0)
				draw_rect(Rect2(W / 2 + 54, H / 2 - 10, 9, 20), ink)
				draw_rect(Rect2(W / 2 - 44, H / 2 - 18, 7, 36), Color(0.8, 0.25, 0.1, lit))
			"lock":
				draw_string(f, Vector2(W - 78, 40), st.T("圏外"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
				draw_string(f, Vector2(0, 190), st.T("8月14日"), HORIZONTAL_ALIGNMENT_CENTER, W, 50, ink)
				draw_line(Vector2(W / 2 - 60, 214), Vector2(W / 2 + 60, 214), ink, 2.0)
				for i in 4:
					var p := Vector2(W / 2 - 66 + 44 * i, 360)
					if i < int(st.ph_code): draw_circle(p, 11, ink)
					else: draw_arc(p, 11, 0, TAU, 24, ink, 2.5)
			"chat":
				draw_string(f, Vector2(0, 50), st.T("澪"), HORIZONTAL_ALIGNMENT_CENTER, W, 28, ink)
				draw_string(f, Vector2(W - 78, 40), st.T("圏外"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
				draw_line(Vector2(14, 68), Vector2(W - 14, 68), ink, 2.0)
				var y := 112.0
				for m in st.ph_chat:
					var text: String = st.T(String(m[1]))
					var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
					var x := (W - 22 - w) if m[0] else 22.0
					draw_rect(Rect2(x - 9, y - 27, w + 18, 38), ink, false, 1.6)
					draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
					y += 58.0
				# what she wrote and did not send (no signal): in the box at the foot, the cursor after it
				draw_rect(Rect2(14, 430, W - 28, 200), ink, false, 3.0)
				var d: String = st.T(st.ph_draft0)
				var n := int(ceil(st.ph_n)); var per := 10
				var shown := d.substr(0, n)
				var li := 0
				while li * per < maxi(shown.length(), 1):
					var seg := shown.substr(li * per, per)
					draw_string(f, Vector2(30, 474 + li * 40), seg, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, ink)
					li += 1
				var last := shown.length() % per if shown.length() % per != 0 or shown.length() == 0 else per
				var row := maxi(li - 1, 0)
				var cx := 30 + f.get_string_size(shown.substr(row * per, per), HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x + 3
				if fmod(st.t_now, 1.0) < 0.55: draw_rect(Rect2(cx, 474 + row * 40 - 24, 2.5, 29), ink)

func _phone6():
	phone = Node3D.new(); phone.name = "nat_phone"
	var body := _box_mesh(Vector3(0.070, 0.009, 0.146), Color(0.06, 0.06, 0.08), 0.3); phone.add_child(body)
	var glass := _box_mesh(Vector3(0.062, 0.0006, 0.132), Color(0.02, 0.02, 0.03), 0.1); phone.add_child(glass); glass.position.y = -0.0047
	ph_glass = glass.material_override
	ph_glass.emission_enabled = true; ph_glass.emission = Color(0.96, 0.95, 0.92); ph_glass.emission_energy_multiplier = 0.0
	ph_light = OmniLight3D.new(); ph_light.light_color = Color(0.96, 0.96, 0.94); ph_light.light_energy = 0.0
	ph_light.omni_range = 1.3; ph_light.omni_attenuation = 1.2; ph_light.shadow_enabled = false; ph_light.light_cull_mask = 1; ph_light.position = Vector3(0, -0.28, 0)   # out in front of the glass (at 6cm it burnt the hand that holds it white)
	phone.add_child(ph_light)
	add_child(phone); phone.visible = false
	pack = Node3D.new(); pack.add_child(_box_mesh(Vector3(0.066, 0.016, 0.105), Color(0.86, 0.86, 0.84), 0.5)); add_child(pack); pack.visible = false
	cable = MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.0022; cy.bottom_radius = 0.0022; cy.height = 1.0; cy.radial_segments = 6; cable.mesh = cy
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.9, 0.9, 0.88); cable.material_override = cm; add_child(cable); cable.visible = false
	var lay := CanvasLayer.new(); lay.layer = 11; add_child(lay)   # over the print (10), under the page (13)
	# the screen and, over it, the holes where her hand is in front of the glass: the two in one group, so the hole is cut
	# in the screen only and the printed hand under it shows (the screen is drawn over the print: a thumb on it was lost)
	var grp := CanvasGroup.new(); grp.fit_margin = 4000.0; grp.clear_margin = 4000.0; lay.add_child(grp)
	ph_ui = PhoneUI.new(); ph_ui.st = self; ph_ui.set_anchors_preset(Control.PRESET_FULL_RECT); ph_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph_ui.size = get_viewport().get_visible_rect().size
	var sv := SubViewport.new(); sv.size = Vector2i(int(PhoneUI.W) * 2, int(PhoneUI.H) * 2); sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS; sv.disable_3d = true; sv.size_2d_override = Vector2i(int(PhoneUI.W), int(PhoneUI.H)); sv.size_2d_override_stretch = true
	var pd := PhoneDraw.new(); pd.st = self; pd.size = Vector2(PhoneUI.W, PhoneUI.H); sv.add_child(pd)
	add_child(sv); ph_ui.sv = sv
	grp.add_child(ph_ui)
	var pm := PhoneMask.new(); pm.st = self
	var msh := Shader.new(); msh.code = "shader_type canvas_item;\nrender_mode blend_disabled;\nvoid fragment() { COLOR = vec4(0.0); }"
	var mm := ShaderMaterial.new(); mm.shader = msh; pm.material = mm
	grp.add_child(pm)
	for ln in D.lines("スマホ.画面"):
		var t := String(ln)
		if t.begins_with("（送る欄）"): ph_draft0 = t.substr(5)
		elif t.begins_with("夏希："): ph_chat.append([true, t.substr(3)])     # her own phone: what she sent is on the right
		elif t.begins_with("澪："): ph_chat.append([false, t.substr(2)])
	ph_n = float(ph_draft0.length())

func _phone_ui_tick(dt: float):
	ph_lit = move_toward(ph_lit, ph_lit_want, dt * (3.0 if ph_lit_want > ph_lit else 0.7))
	if ph_glass: ph_glass.emission_energy_multiplier = 1.6 * ph_lit
	if ph_light: ph_light.light_energy = 0.42 * ph_lit * 0.56 / maxf(exp_now, 0.3)
	if cable.visible and phone.visible and pack.visible:
		var a: Vector3 = phone.global_transform * Vector3(0, 0, 0.073); var b: Vector3 = pack.global_position
		var d := b - a
		if d.length() > 0.01:
			cable.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())).scaled(Vector3(1, d.length(), 1)), (a + b) * 0.5)

func _nat_hips() -> Vector3:
	var c := _nat_chest(); var h := _nat_head()
	var along := Vector3(c.x - h.x, 0.0, c.z - h.z).normalized()
	return Vector3(c.x, 0.2, c.z) + along * 0.42

func _nat_press():
	match phone_st:
		0:
			phone_st = 1; _ret_open("夏希.見る")
		1: _phone_find()
		2:
			if has_pack: _phone_plug()
			else: _start(B("見る.夏希.電池"))
		_: _start(B("見る.夏希"))

func _blanket_fold(k: float, dur := 0.9):
	if blanket == null: return
	create_tween().tween_property(blanket, "scale:z", k, dur).set_trans(Tween.TRANS_SINE)
	Sound.one(self, "ch3_blanket", -12.0, blanket.global_position)

func _phone_in_hand():
	if phone.get_parent() != hand_r:
		var gt := phone.global_transform
		phone.get_parent().remove_child(phone); hand_r.add_child(phone); phone.global_transform = gt
	create_tween().tween_property(phone, "transform", _held("phone"), 0.7).set_trans(Tween.TRANS_SINE)
	_grip(hand_r, "phone", 0.6)
	_hold_to(hand_r, "phone", PH_HOLD, PH_DEG, Vector3(0, -0.020, -0.082), 0.9)
	create_tween().tween_property(player, "pitch", -0.42, 0.9).set_trans(Tween.TRANS_SINE)

func _phone_find():
	act = "phone"; step = 0; note_lb.text = ""
	if ret_rows.is_empty(): _ret_open("夏希.見る")
	ret_hold = -1.0
	var hips := _nat_hips()
	_go(KN, KNEEL_EYE, hips)
	_candle_down(gp(5.32, 2.2, 0.0))
	_after(1.3, func():
		_blanket_fold(0.58)
		_curl(hand_r, 0.4)
		_hand_to(hand_r, _in_rig(hips) + Vector3(0.0, 0.10, 0.10), Vector3(-25, 0, 0), 1.0)
		_after(1.9, func():
			phone.visible = true
			phone.get_parent().remove_child(phone); hand_r.add_child(phone); phone.transform = _held("phone"); _ang_set(hand_r, GRIPS["phone"])
			_phone_in_hand()
			_after(1.3, func(): step = 1; _show_prompt("スマホ.押す"))))

func _phone_press():
	match step:
		1:
			# not broken: its battery is flat
			step = 2; note_lb.text = ""
			Sound.one(self, "dial_tick", -10.0)
			ph_mode = "dead"; ph_lit = 1.0; ph_lit_want = 1.0
			_after(1.3, func(): ph_lit_want = 0.0)
			var notes: Array = D.lines("スマホ.押す")
			if notes.size() > 1: _line_row("", T(String(notes[1])), 22, "note"); page_clear_t = 5.0
			_after(3.2, func():
				ph_mode = "off"
				_hand_away(hand_r, 0.7)
				_after(0.7, func(): phone.visible = false)
				_go(KN, STAND_EYE6, _nat_chest() + Vector3(0, 0.4, 0), 1.2)
				_after(1.3, func():
					_candle_up(); act = ""; phone_st = 2; ret_hold = 3.0))
		4: _phone_open()
		8:
			step = 80; note_lb.text = ""
			var hips := _nat_hips()
			_turn_to(hips, 0.8)
			_after(0.5, func():
				_hand_to(hand_r, _in_rig(hips) + Vector3(0.0, 0.10, 0.10), Vector3(-25, 0, 0), 1.0)
				_after(1.2, func():
					phone.visible = false; pack.visible = false
					Sound.one(self, "ch3_blanket", -16.0)
					_hand_away(hand_r, 0.8)
					_after(1.0, func(): step = 9; _show_prompt("毛布.かける"))))
		9:
			step = 90; note_lb.text = ""
			_turn_to(_nat_chest(), 0.8)
			_hand_to(hand_l, Vector3(-0.16, -0.24, -0.38), Vector3(-10, 10, 0), 0.6); _hand_to(hand_r, Vector3(0.16, -0.24, -0.38), Vector3(-10, -10, 0), 0.6)
			_curl(hand_l, 0.9); _curl(hand_r, 0.9)
			_after(0.6, func():
				_blanket_fold(1.0, 1.2)
				_after(1.4, func():
					_hand_away(hand_l, 0.7); _hand_away(hand_r, 0.7)
					_go(KN, STAND_EYE6, _nat_chest() + Vector3(0, 0.4, 0), 1.3)
					_after(1.4, func():
						_candle_up(); act = ""; phone_st = 8; done6["phone"] = true
						_run_block("毛布.かける"))))

func _pack_take():
	act = "pack"; note_lb.text = ""
	has_pack = true
	Sound.one(self, "ch3_blanket", -14.0)
	pack.get_parent().remove_child(pack); hand_l.add_child(pack); pack.visible = true
	pack.transform = _held("pack")
	hand_l.position = Vector3(-0.2, -0.6, -0.3); _grip(hand_l, "pack", 0.05)
	_hold_to(hand_l, "pack", Vector3(-0.05, -0.125, -0.27), Vector3(62, -8, 180), Vector3(0, -0.024, -0.085), 0.8)
	_after(2.0, func():
		_hand_away(hand_l, 0.7)
		_after(0.7, func(): pack.visible = false; act = ""))

func _phone_plug():
	act = "phone"; step = 3; note_lb.text = ""
	var h := _nat_head()
	ph_spot = Vector3(h.x + 0.33, 0.012, h.z - 0.04)
	var at := KN
	_go(at, KNEEL_EYE, ph_spot)
	_candle_down(gp(5.32, 2.2, 0.0))
	_after(1.3, func():
		# on the boards by her face, the cord to the spare battery (Mio's)
		for n in [phone, pack]:
			(n as Node3D).get_parent().remove_child(n); main.add_child(n); (n as Node3D).visible = true
		var yaw := atan2(gp(KN[0], KN[1], 0.0).x - ph_spot.x, gp(KN[0], KN[1], 0.0).z - ph_spot.z)
		phone.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, PI), ph_spot)
		pack.global_transform = Transform3D(Basis(Vector3.UP, yaw + 0.4), ph_spot + Vector3(0.17, 0.0, 0.11))
		cable.visible = true
		Sound.one(self, "lock", -16.0, ph_spot)
		_flow_start("スマホ.待つ", func(): step = 4; _show_prompt("スマホ.開ける")))

func _phone_open():
	step = 5; note_lb.text = ""
	_phone_in_hand()
	_after(1.1, func():
		for i in 4:
			_after(0.45 * i + 0.3, func(): ph_code += 1; Sound.one(self, "dial_tick", -12.0))
		_after(2.6, func():
			ph_mode = "chat"
			# she reads it. The half-heard voice of half past two comes back on the page, and the gaps in it fill
			_after(3.2, func():
				_ret_open("スマホ.読んだ")
				ret_q.append([(float(ret_q[-1][0]) + 0.8) if not ret_q.is_empty() else 0.8, func(): ret_hold = -1.0])
				step = 55)))

func _phone_tick(dt: float):
	if step == 55 and not _ret_busy():
		step = 6; _show_prompt("スマホ.消す")
	if step == 6:
		if _holding():   # 2026-11-20: the letters go from the end; the page keeps its lines (no strike)
			var was := int(ceil(ph_n))
			ph_n = maxf(0.0, ph_n - dt * 6.0)
			if int(ceil(ph_n)) != was:
				del_tick += 1
				if del_tick % 2 == 0: Sound.one(self, "dial_tick", -20.0)
			if ph_n <= 0.0:
				step = 7; note_lb.text = ""
				_ret_after("スマホ.あと", 9.0)
				_after(5.0, func():
					# the cord out: the flat battery's mark, and the paper goes back under the ink
					cable.visible = false
					Sound.one(self, "lock", -16.0)
					ph_mode = "dead"
					_after(1.2, func(): ph_lit_want = 0.0)
					_after(3.2, func(): ph_mode = "off"; step = 8; _show_prompt("スマホ.戻す")))

# ================================================================ Ｅ 「上映用」の箱
var box_st := 0                # 0 not yet | 1 the light is on the screen | 2 open | 3 to put back | 4 done
var screen_sp: SpotLight3D

func _case6():
	# in her left hand, on her fingers: its top is its -Y side; it opens like a book, the hinge on its +X edge
	case6 = Node3D.new()
	var card := Color(0.78, 0.74, 0.66)
	var bottom := _box_mesh(Vector3(0.112, 0.003, 0.078), card, 0.9); case6.add_child(bottom)
	for sp in [[Vector3(0.112, 0.014, 0.003), Vector3(0, -0.007, 0.0375)], [Vector3(0.112, 0.014, 0.003), Vector3(0, -0.007, -0.0375)],
			[Vector3(0.003, 0.014, 0.078), Vector3(0.0545, -0.007, 0)], [Vector3(0.003, 0.014, 0.078), Vector3(-0.0545, -0.007, 0)]]:
		var w := _box_mesh(sp[0], card.darkened(0.1), 0.9); case6.add_child(w); w.position = sp[1]
	var inner := _box_mesh(Vector3(0.104, 0.0006, 0.070), Color(0.90, 0.88, 0.82), 0.95); case6.add_child(inner); inner.position.y = -0.0018   # empty
	case_lid = Node3D.new(); case6.add_child(case_lid); case_lid.position = Vector3(0.056, -0.0155, 0)
	var lid := _box_mesh(Vector3(0.112, 0.003, 0.078), card, 0.9); case_lid.add_child(lid); lid.position = Vector3(-0.056, 0, 0)
	var lab := _box_mesh(Vector3(0.080, 0.0005, 0.030), Color(0.95, 0.94, 0.90), 0.9); case_lid.add_child(lab); lab.position = Vector3(-0.056, -0.0018, -0.008)
	var t := _text3("上映用", 0.00034, Color(0.08, 0.10, 0.2)); case_lid.add_child(t)
	t.position = Vector3(-0.056, -0.0023, -0.008); t.basis = Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI / 2.0)
	hand_l.add_child(case6); case6.transform = _held("case"); case6.visible = false
	for mi in main.S.env_node.find_children("tapebox*", "MeshInstance3D", true, false): box_env.append(mi)

func _box_tick():
	if box_st == 0 and done6.has("tripod") and done6.has("cam") and done6.has("phone") and act == "" and mode == FREE and not _ret_busy():
		box_st = 1; _run_block("箱.合図")
	if act == "box" and step == 1 and mode == FREE and box_talk:
		step = 2; box_st = 3; _show_prompt("箱.戻す")
var box_talk := false

func _box_press():
	act = "box"; step = 0; note_lb.text = ""; box_talk = false
	var bp: Vector3 = _target("box").pos
	_turn_to(bp, 0.8)
	_candle_down(bp + Vector3(0.22, -0.02, 0.05))
	_after(1.0, func():
		for mi in box_env: (mi as Node3D).visible = false
		case6.visible = true; case_lid.rotation.z = 0.0
		hand_l.transform = _hold_xf("case", _in_rig(bp), Vector3(10, 0, 180), Vector3(0, -0.020, -0.090)); _grip(hand_l, "case", 0.05)
		_hold_to(hand_l, "case", Vector3(-0.03, -0.115, -0.25), Vector3(64, -6, 180), Vector3(0, -0.020, -0.090), 1.0)
		create_tween().tween_property(player, "pitch", -0.5, 1.0).set_trans(Tween.TRANS_SINE)
		_after(2.2, func():
			# 夏希の字。her other hand lifts the lid
			_grip(hand_r, "lid", 0.6)
			_hand_to(hand_r, Vector3(0.0785, -0.0455, -0.235), Vector3(40, 30, -60), 0.6)
			_fit_dev(hand_r, "lid", [case6], 0.65, null, true, true, -9.0, true)
			_after(0.7, func():
				Sound.one(self, "ch3_blanket", -16.0)
				create_tween().tween_property(case_lid, "rotation:z", 2.45, 0.9).set_trans(Tween.TRANS_SINE)
				_hand_to(hand_r, Vector3(0.17, -0.15, -0.24), Vector3(40, 30, -60), 0.9); _curl_to(hand_r, 0.3, 0.6)
				_after(2.4, func():
					step = 1
					_start(B("箱.あと")); box_talk = true))))

func _box_step():
	if step != 2: return
	step = 3; note_lb.text = ""
	Sound.one(self, "ch3_blanket", -18.0)
	create_tween().tween_property(case_lid, "rotation:z", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	_hand_away(hand_r, 0.6)
	var bp: Vector3 = _target("box").pos
	_after(0.9, func():
		_hold_to(hand_l, "case", _in_rig(bp), Vector3(10, 0, 180), Vector3(0, -0.020, -0.090), 0.9)
		_after(0.9, func():
			case6.visible = false
			for mi in box_env: (mi as Node3D).visible = true
			_hand_away(hand_l, 0.6)
			_candle_up()
			done6["box"] = true; box_st = 4; act = ""
			_run_block("箱.戻す")
			_after(2.5, func(): _start(B("袖.目当て")))))

# ================================================================ Ｄ 袖
var wash := 0.0
var water_p: AudioStreamPlayer3D
var sleeve_wait := false

func _sink6():
	var tp := gp(TAP[0], TAP[1], TAP[2])
	water = MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.005; cy.bottom_radius = 0.007; cy.height = 0.26; water.mesh = cy
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.85, 0.9, 0.95, 0.8); wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; wm.roughness = 0.05
	water.material_override = wm; water.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; main.add_child(water)
	water.global_position = tp + Vector3(0, -0.15, -0.12); water.visible = false
	basin = MeshInstance3D.new(); var dc := CylinderMesh.new(); dc.top_radius = 0.17; dc.bottom_radius = 0.17; dc.height = 0.003; basin.mesh = dc
	basin_mat = StandardMaterial3D.new(); basin_mat.albedo_color = Color(0.5, 0.56, 0.6, 0.0); basin_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; basin_mat.roughness = 0.05
	basin.material_override = basin_mat; basin.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; main.add_child(basin)
	basin.global_position = tp + Vector3(0, -0.29, -0.12); basin.scale = Vector3(1.3, 1.0, 0.9); basin.visible = false
	water_p = AudioStreamPlayer3D.new(); water_p.stream = Sound.stream("rain", true); water_p.pitch_scale = 1.9; water_p.volume_db = -60.0; water_p.unit_size = 1.2
	add_child(water_p); water_p.global_position = tp

func _sleeve_press():
	act = "sleeve"; step = 0; note_lb.text = ""; sleeve_wait = true
	_go([TAP[0], TAP[1] - 0.72], STAND_EYE6, gp(TAP[0], TAP[1] - 0.1, TAP[2] - 0.25))
	_candle_down(gp(TAP[0] - 0.72, TAP[1] - 0.10, 0.895))
	_after(1.3, func():
		# before the water: she looks at it once. The blood has the shape of fingers
		hand_l.position = Vector3(-0.25, -0.6, -0.3); _curl(hand_l, 0.2)
		_hand_to(hand_l, Vector3(0.16, -0.10, -0.38), Vector3(15, -55, 0), 1.1)
		_after(1.4, func():
			_ret_open("袖.見る")
			step = 10))

func _water(on: bool):
	if water.visible == on: return
	water.visible = on
	if on and water_p.stream and not water_p.playing: water_p.play()
	Sound.one(self, "ch3_rattle", -22.0, water.global_position)

func _sleeve_tick(dt: float):
	if step == 10 and not _ret_busy():
		step = 1; _show_prompt("袖.洗う")
	if step == 1:
		var on := _holding()
		_water(on)
		water_p.volume_db = move_toward(water_p.volume_db, -16.0 if on else -60.0, dt * 80.0)
		if on:
			if wash <= 0.0:
				_hand_to(hand_l, Vector3(0.16, -0.12, -0.40), Vector3(15, -55, 0), 0.5)
				_hand_to(hand_r, Vector3(0.10, -0.09, -0.27) + Vector3(-0.0117, -0.0351, -0.0166), Vector3(30, 35, 0), 0.5); _grip(hand_r, "wash", 0.45)   # laid over the forearm, the fingers round it, the thumb beside
				for kk in 3: _fit_dev(hand_r, "wash%d" % kk, [hand_l], 0.6 + 0.02 * kk, Vector3(0.10, -0.09, -0.27) + Vector3(-0.82, 0.0, 0.57) * 0.03 * (kk - 1), true, false, -9.0, true)
			wash = minf(1.0, wash + dt / 6.5)
			if wash > 0.08:   # along her forearm and back, on the sleeve (it thickens to the elbow: found at three points with --c6fit)
				var sw := sin(t_now * 6.5)
				hand_r.position = Vector3(0.10, -0.09, -0.27) + Vector3(-0.82, 0.0, 0.57) * 0.03 * sw + Vector3(-0.0117, -0.0351, -0.0166) + Vector3(-0.00325, -0.010, -0.00475) * sw
			sleeve_l.set_shader_parameter("wash", wash); sleeve_l.set_shader_parameter("wet", clampf(wash * 4.0, 0.0, 1.0))
			# the water goes red, and then clear
			var red := smoothstep(0.0, 0.22, wash) * (1.0 - smoothstep(0.5, 0.95, wash))
			basin_mat.albedo_color = Color(0.5, 0.56, 0.6, 0.45).lerp(Color(0.42, 0.04, 0.04, 0.85), red)
			if wash >= 1.0:
				step = 3; note_lb.text = ""
				_water(false); water_p.volume_db = -60.0
				create_tween().tween_property(basin_mat, "albedo_color:a", 0.0, 3.0)
				_ret_after("袖.あと", 12.0)
				_hand_away(hand_r, 0.7); _hand_to(hand_l, Vector3(0.16, -0.10, -0.38), Vector3(15, -55, 0), 0.8)   # she looks at what is left
				_after(3.2, func():
					_hand_away(hand_l, 0.9)
					_candle_up()
					_after(1.0, func(): act = ""; done6["sleeve"] = true))

# a bird, once (no recording: three short falling notes, made here)
func _bird():
	var sr := 22050; var n := int(sr * 0.9)
	var data := PackedByteArray(); data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / sr
		var v := 0.0
		for k in 3:
			var t0 := 0.05 + 0.26 * k
			var x := (t - t0) / 0.13
			if x >= 0.0 and x <= 1.0:
				var fq := lerpf(4300.0 - 250.0 * k, 3100.0 - 150.0 * k, x * x)
				ph += TAU * fq / sr
				v = sin(ph) * sin(PI * x) * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = sr; w.data = data
	var p := AudioStreamPlayer3D.new(); p.stream = w; p.volume_db = -12.0; p.unit_size = 8.0; p.attenuation_filter_cutoff_hz = 6000.0
	add_child(p); p.global_position = gp(11.5, 5.0, 3.0); p.play()
	p.finished.connect(p.queue_free)

# the car's lamps cross the trees past the open back door, and stop at the bend of the road below
var sweep: SpotLight3D
func _lights():
	sweep = SpotLight3D.new(); sweep.light_color = Color(1.0, 0.95, 0.84); sweep.light_energy = 0.0
	sweep.spot_range = 40.0; sweep.spot_angle = 16.0; sweep.spot_attenuation = 0.3; sweep.shadow_enabled = true
	sweep.light_volumetric_fog_energy = 2.0
	main.add_child(sweep)
	var from := gp(14.5, -9.0, 0.4)
	var tw := create_tween()
	tw.tween_property(sweep, "light_energy", 4.0, 0.8)
	tw.parallel().tween_method(func(k: float): sweep.look_at_from_position(from, gp(lerpf(16.0, 11.2, k), lerpf(1.0, 8.5, k), lerpf(2.0, 1.2, k)), Vector3.UP), 0.0, 1.0, 4.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sweep, "light_energy", 1.2, 1.5)
	Sound.one(self, "car_arrive", -22.0, gp(13.0, -12.0, 0.5))

# 二階の窓のテープ（してもしなくてもよい）: the air comes in
func _uptape():
	done6["uptape"] = true
	Sound.one(self, "tape_rip", -3.0, up_tape.global_position)
	up_tape.queue_free()
	var p := AudioStreamPlayer3D.new(); p.stream = Sound.stream("ch3_gap1", true); p.unit_size = 1.4; p.volume_db = -8.0
	add_child(p); p.global_position = gp(1.5, 0.1, F2 + 0.92)
	if p.stream: p.play()
	gaps.append({"key": "up", "at": gp(1.5, 0.1, F2 + 0.92), "n": [0, 1], "name": "二階の窓", "player": p, "peeled": true, "tape": null, "tape2": null})
	_start(B("二階.テープ.あと"))

# ================================================================ Ｆ 座る、結び（序章の続き）
var stood := false
var opened_t := -1.0
var after_said := false
var car_t := -1.0
var car: Array = []
var car_body: Node3D
var police: Node3D
var door_light6: SpotLight3D
var door_rest6 := 0.0
var door_pos6 := Vector3.ZERO
var sil6 := {}
var torch6: SpotLight3D
const CAR_FROM := [13.0, -16.0, 0.75]
const CAR_TO := [7.4, -11.0, 0.72]
const LAMP_E := 2.6

func _sit():
	act = "sit"; note_lb.text = ""
	_go(SIT6, SIT_EYE6, gp(FRONT6[0] - 0.1, FRONT6[1], 0.25), 2.0)
	_candle_down(gp(SIT6[0] + 0.36, SIT6[1] - 0.12, 0.0))
	_car(); _front_door6()
	_after(2.6, func(): _run_block("座る"))

func _front_door6():
	var dn2 = main.get_node_or_null("Doors")
	if dn2:
		for k in dn2.doors.keys():
			if dn2.doors[k].pivot == main.door_pivot: dn2.doors.erase(k)
	if main.door_pivot:
		door_rest6 = float(main.S.get("door_rot", 0.0)); door_pos6 = main.S.get("door_rest", main.door_pivot.position)
		main.door_pivot.rotation.y = door_rest6; main.door_pivot.position = door_pos6
	door_light6 = SpotLight3D.new(); door_light6.light_color = Color(0.92, 0.94, 1.0); door_light6.light_energy = 0.0
	door_light6.spot_range = 9.0; door_light6.spot_angle = 26.0; door_light6.spot_angle_attenuation = 1.4; door_light6.spot_attenuation = 0.7
	door_light6.shadow_enabled = false; door_light6.light_volumetric_fog_energy = 0.6; door_light6.light_specular = 0.15
	main.add_child(door_light6)
	door_light6.look_at_from_position(gp(5.0, -2.6, 1.9), gp(4.8, 3.0, 0.2), Vector3.UP)

# ch0.gd's car and officer (the same shapes: the prologue is this scene's end)
func _car():
	for side in [-0.75, 0.75]:
		var l := SpotLight3D.new(); l.light_color = Color(1.0, 0.95, 0.84); l.light_energy = 0.0
		l.spot_range = 22.0; l.spot_angle = 22.0; l.spot_angle_attenuation = 1.6; l.spot_attenuation = 0.4
		l.shadow_enabled = true; l.light_volumetric_fog_energy = 3.0; l.light_specular = 0.3
		l.set_meta("side", side); l.set_meta("own_shadow", true)
		main.add_child(l); car.append(l)
		var lens := MeshInstance3D.new(); var sp := SphereMesh.new(); sp.radius = 0.09; sp.height = 0.12; lens.mesh = sp
		var lm := StandardMaterial3D.new(); lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; lm.albedo_color = Color(1, 0.97, 0.9)
		lens.material_override = lm; lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; l.add_child(lens); lens.position = Vector3(0, 0, -0.05)
	car_body = Node3D.new(); main.add_child(car_body)
	if ResourceLoader.exists("res://props/police_car.glb"):
		var pc: Node3D = (load("res://props/police_car.glb") as PackedScene).instantiate(); car_body.add_child(pc); pc.scale = Vector3.ONE * 4.7
	car_body.visible = false
	var fog := FogVolume.new(); fog.size = Vector3(3.2, 2.6, 4.0)
	var fm := FogMaterial.new(); fm.density = 0.012; fm.albedo = Color(1, 1, 1); fm.edge_fade = 0.4; fog.material = fm
	main.add_child(fog); fog.global_position = gp(FRONT6[0], FRONT6[1] + 1.6, 1.3)
	if ResourceLoader.exists("res://props/police_body.glb"):
		police = Node3D.new(); main.add_child(police)
		var with_head := ResourceLoader.exists("res://props/police_head.glb") and ResourceLoader.exists("res://props/police_body_nohead.glb")
		var pb: Node3D = (load("res://props/police_body_nohead.glb" if with_head else "res://props/police_body.glb") as PackedScene).instantiate(); police.add_child(pb)
		pb.scale = Vector3.ONE * 1.72
		var top := 0.0
		for mi in pb.find_children("*", "MeshInstance3D", true, false): top = maxf(top, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).end.y - police.global_position.y)
		if with_head:
			# the user's own head and cap for him (Tripo, 2026-11-17; the bust under the chin cut away in prep_props.py): over the
			# body cut at the chin (tripo/police_nohead.py), its cap's top 4 cm over where the body's crown was
			var ph: Node3D = (load("res://props/police_head.glb") as PackedScene).instantiate(); police.add_child(ph)
			ph.scale = Vector3.ONE * POLICE_HEAD_K
			ph.position = Vector3(0, 0.978 * 1.72 + 0.04 - 0.667 * POLICE_HEAD_K, POLICE_HEAD_Z)
		else:
			var navy := StandardMaterial3D.new(); navy.albedo_color = Color(0.06, 0.07, 0.12); navy.roughness = 0.6
			var cap := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.115; cy.bottom_radius = 0.105; cy.height = 0.085; cap.mesh = cy
			cap.material_override = navy; police.add_child(cap); cap.position = Vector3(0, 1.69, 0.005)
			var brim := MeshInstance3D.new(); var bm2 := CylinderMesh.new(); bm2.top_radius = 0.075; bm2.bottom_radius = 0.075; bm2.height = 0.01; brim.mesh = bm2
			brim.material_override = navy; police.add_child(brim); brim.position = Vector3(0, 1.655, -0.085); brim.scale = Vector3(1.4, 1.0, 1.0)
			if top > 1.0: cap.position.y = top - 0.02; brim.position.y = top - 0.055
		police.global_transform = Transform3D(Basis(Vector3.UP, PI - 0.2), gp(5.3, -0.95, 0.0))
		police.visible = false

func _car_tick(dt: float):
	if car_t < 0.0: return
	car_t += dt
	var k := clampf(car_t / 7.0, 0.0, 1.0); k = 1.0 - pow(1.0 - k, 2.2)
	var p := gp(CAR_FROM[0], CAR_FROM[1], CAR_FROM[2]).lerp(gp(CAR_TO[0], CAR_TO[1], CAR_TO[2]), k)
	var aim := gp(lerpf(-1.5, 5.0, k), lerpf(-1.0, 0.4, k), lerpf(0.4, 1.0, k))
	var fw := (aim - p); fw.y = 0.0; fw = fw.normalized()
	var right := fw.cross(Vector3.UP)
	for l in car:
		var lp2: Vector3 = p + right * float(l.get_meta("side"))
		l.look_at_from_position(lp2, aim + right * float(l.get_meta("side")) * 0.6, Vector3.UP)
		l.light_energy = LAMP_E * smoothstep(0.0, 1.5, car_t) + (2.0 * clampf((opened_t - 0.8) / 3.2, 0.0, 1.0) if opened_t >= 0.0 else 0.0)
	car_body.visible = true
	car_body.global_transform = Transform3D(Basis.looking_at(fw, Vector3.UP), p + Vector3(0, -0.72, 0) - fw * 2.2)

func _gen_off6():
	main.gen_on = false
	gen_want = -60.0; gen_db = -60.0; gen_fore.volume_db = -60.0
	Sound.one(self, "generator_stop", -6.0)
	for k in ["lamp_lobby", "lamp_cellar", "lamp_cellarw"]:
		if main.lights.has(k): main.lights[k].visible = false
	for mi in main.S.env_node.find_children("lampshade_*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.contains("lamp_lobby") or nm.contains("lamp_cellar")): continue
		for i in range(mi.get_surface_override_material_count()):
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m: m.emission_enabled = false; m.albedo_color = m.albedo_color * Color(0.3, 0.3, 0.3, 1.0)

func _do6(what: String):
	match what:
		"screen_light":
			# the first light through the boards of the living room's window, onto the screen: seen from the hall
			var sp: Vector3 = _target("screen").pos
			screen_sp = SpotLight3D.new(); screen_sp.light_color = Color(0.80, 0.88, 1.0); screen_sp.light_energy = 0.0
			screen_sp.spot_range = 8.0; screen_sp.spot_angle = 20.0; screen_sp.shadow_enabled = true; screen_sp.light_volumetric_fog_energy = 1.5
			main.add_child(screen_sp)
			screen_sp.look_at_from_position(gp(2.6, -0.4, 1.7), sp, Vector3.UP)
			create_tween().tween_property(screen_sp, "light_energy", 3.5, 6.0)
		"bird": _bird()
		"lights": _lights()
		"phone_on":
			ph_mode = "lock"; ph_lit_want = 1.0
			Sound.one(self, "dial_tick", -14.0, ph_spot)
		"to5":
			stage = "end5"; act = ""
			if sweep: create_tween().tween_property(sweep, "light_energy", 0.0, 2.0)
			_flow_start("結び.流れ")
		"genoff": _gen_off6()
		"car": car_t = 0.0; Sound.one(self, "car_arrive", -6.0)
		"knock":
			Sound.one(self, "knock", -2.0, gp(FRONT6[0], FRONT6[1], FRONT6[2]))
			main.set_meta("knock_by_scene", true)
		"silence":
			if mode == TALK: silence_len = 7.0; _silence_open()
			else:
				var r = _line_row("澪", "（沈黙）")
				sil6 = {"lb": r[1], "t": 0.0}
		"stand":
			can_stand = true; _show_prompt("結び.立つ")
		"candle_out":
			candle_out = true
			Sound.one(self, "ch3_gapfront", -6.0, gp(FRONT6[0], 0.3, 1.0))
		"police_light":
			# his torch, past her, down the hall she put in order: it stops on the blanket
			torch6 = SpotLight3D.new(); torch6.light_color = Color(1.0, 0.97, 0.9); torch6.light_energy = 0.0
			torch6.spot_range = 9.0; torch6.spot_angle = 13.0; torch6.spot_attenuation = 0.6; torch6.shadow_enabled = true; torch6.light_volumetric_fog_energy = 2.0
			main.add_child(torch6)
			var from := gp(5.25, -0.75, 1.25)
			var c := _nat_chest()
			var tw := create_tween()
			tw.tween_property(torch6, "light_energy", 5.0, 0.4)
			tw.parallel().tween_method(func(k: float): torch6.look_at_from_position(from, gp(5.2, 1.0, 0.9).lerp(gp(4.6, 5.2, 0.3), sin(k * PI)).lerp(c, smoothstep(0.55, 1.0, k)), Vector3.UP), 0.0, 1.0, 4.2).set_trans(Tween.TRANS_SINE)
			_turn_to(c, 3.5)
		"end":
			script_q.clear()
			_after(1.5, _end6)
		_: super._do(what)

func _get_up():
	stand_t = 0.0; note_lb.text = ""
	_eye(STAND_EYE6, 1.8)
	_after(1.8, func(): stood = true)
	print("STORY ch6 stand t=%.1f" % t_now)

func _end_tick6(dt: float):
	_car_tick(dt)
	if sil6.has("lb"):
		sil6.t += dt
		if is_instance_valid(sil6.lb): (sil6.lb as Label).text = T("（沈黙・%s秒）") % num(int(sil6.t))
	if stage != "end5": return
	player.move_enabled = stood and opened_t < 0.0 and mode == FREE
	if stood and opened_t < 0.0:
		var cam := _cam()
		var to := gp(FRONT6[0], FRONT6[1], FRONT6[2]) - cam.global_position
		var near := Vector2(to.x, to.z).length() < 1.7 and (-cam.global_basis.z).angle_to(to) < deg_to_rad(28.0)
		note_lb.text = _prompt("結び.扉") if near else ""
	if opened_t >= 0.0:
		opened_t += dt
		if main.door_pivot:
			var k := clampf((opened_t - 0.8) / 3.2, 0.0, 1.0); k = k * k * (3.0 - 2.0 * k)
			main.door_pivot.position = door_pos6
			main.door_pivot.rotation.y = door_rest6 + deg_to_rad(OPEN_DEG6) * k * float(main.S.get("door_sign", 1.0))
			door_light6.light_energy = 2.2 * k
			if police: police.visible = opened_t > 0.6
		if opened_t > 2.4 and not after_said:
			after_said = true
			_start(B("結び.あと"))

func _press_end():
	if stood and opened_t < 0.0 and note_lb.text != "":
		opened_t = 0.0; note_lb.text = ""; sil6 = {}
		Sound.one(self, "door_open", -3.0, gp(FRONT6[0], FRONT6[1], FRONT6[2]))
		print("STORY ch6 open t=%.1f" % t_now)

# the question comes back; under it, this once, her answer
func _end6():
	stage = "fin"
	_clear_page(); note_lb.text = ""; _set_mission(""); _ret_clear()
	var L: Array = D.lines("六.終わり")
	if card: card.queue_free()
	card = main.make_card(self, [[String(L[0]), 64, 0]], Type.card(), false)
	card.visible = true
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var y := vs.y * 0.5 + 90 * u; var t := 3.5
	for i in range(1, L.size()):
		var text := String(L[i]).substr(String(L[i]).find("：") + 1)
		var lb := Label.new(); lb.add_theme_font_override("font", Type.card()); lb.add_theme_font_size_override("font_size", int(40 * u))
		lb.add_theme_color_override("font_color", main.CARD_INK); lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lb.text = T(text); lb.visible_characters = 0
		lb.position = Vector2(420.0 / 1920.0 * vs.x, y); y += 74 * u
		card.add_child(lb)
		var tw := create_tween(); tw.tween_interval(t)
		tw.tween_property(lb, "visible_characters", lb.text.length(), lb.text.length() / 9.0)
		t += lb.text.length() / 9.0 + 2.2
		if demo6: print("SAY 答え %s" % text)
	_after(t + 5.0, func():
		if demo6: print("DEMO ch6 t=%.1f fails=%d batt=%s uptape=%s" % [t_now, DEMO_FAILS, done6.has("batt"), done6.has("uptape")]); DEMO_HOUSE = true
		if demo6 and "--ch6only" in OS.get_cmdline_user_args(): print("DEMO DONE ch6"); get_tree().quit(); return
		main.next_chapter("ch6"))   # 後半の並び（scripts/order.gd）：証言 一へ

# ================================================================ check stills, a part's playthrough (--ch6at=)
func _jump6(s: String):
	stage = "free"; _lamp6(false); _set_mission(String(B("六.始まり")[-1].get("mission", "")))
	var order6 := ["free", "cam", "phone", "plug", "box", "sleeve", "sit", "end"]
	var n := order6.find(s)
	if n < 0: print("SCRIPT ERROR ch6: --ch6at=", s); return
	var at := [4.3, 3.9]
	if n >= 1:
		tripod.visible = false; done6["tripod"] = true; bag6.scale = bag_full; _dawn()
	if n >= 2:
		done6["cam"] = true; looked["cam"] = true; _dawn(); struck6["澪＊：テープは、二本目にしました。"] = true
	if n == 3:
		phone_st = 2; has_pack = true; at = [5.1, 2.3]
		_after(0.5, func(): if blanket: blanket.scale.z = 0.58)
	if n >= 4:
		phone_st = 8; done6["phone"] = true; _dawn(); ph_n = 0.0
	if n >= 5:
		done6["box"] = true; box_st = 4; _dawn(); at = [7.4, 6.6]
		_set_mission("台所で、手を洗いました。")
	if n >= 6:
		done6["sleeve"] = true; wash = 1.0; sleeve_l.set_shader_parameter("wash", 1.0); at = [4.3, 3.9]
		_set_mission("夏希のそばに、座っていました。"); _dawn()
	exp_now = exp_want
	player.global_position = gp(at[0], at[1], 0.0)
	_look_from(at, [4.5, 2.4], STAND_EYE6, 0.3)
	if n == 7: _after(0.3, _sit)

# ================================================================ the unattended playthrough (--demo)
var d6: Array = []
var di := 0
var dw := 0.0
var d_choice := 0.0

func _aim_of(k: String) -> Vector3:
	return _target(k).pos

func _demo6_script() -> Array:
	var st := []
	var U := func(c: Callable, sec := 60.0): st.append(["until", c, sec])
	var P := func(k: String): st.append(["aim", k]); st.append(["press"])
	var W := func(pts: Array): st.append(["walk", pts])
	var free := func(): return mode == FREE and act == "" and not _ret_busy()
	st.append(["mark", "free"])
	U.call(func(): return stage == "free")
	W.call([[5.2, 6.0], [4.8, 5.6], [4.8, 4.4], [4.4, 3.6], [4.4, 3.0]])   # 2026-11-20: the free part starts at the cellar door now
	P.call("lantern"); U.call(free)
	# Ａ
	P.call("tripod"); U.call(func(): return step == 1)
	st.append(["hold", func(): return step == 2])
	for i in 3: st.append(["press"]); st.append(["wait", 0.9])
	U.call(func(): return carrying)
	W.call([[4.4, 3.0], [4.3, 3.1], [4.2, 3.3], [4.2, 3.8], [4.3, 4.1]]); P.call("bag"); U.call(func(): return done6.has("tripod") and act == "")
	st.append(["mark", "cam"])
	# Ｂ
	W.call([[4.25, 3.5]]); P.call("cam"); U.call(free); st.append(["wait", 1.5])
	P.call("cam"); U.call(func(): return step == 1 and act == "cam"); st.append(["wait", 1.0]); st.append(["press"])
	U.call(func(): return done6.has("cam") and free.call()); st.append(["wait", 2.0])
	P.call("cam"); U.call(func(): return done6.has("batt") and free.call())
	st.append(["mark", "phone"])
	# Ｃ
	W.call([[4.2, 3.3], [4.3, 3.1], [4.4, 3.0]]); P.call("nat"); U.call(free); st.append(["wait", 1.5])
	P.call("nat"); U.call(func(): return step == 1 and act == "phone"); st.append(["wait", 1.0]); st.append(["press"])
	U.call(func(): return phone_st == 2 and act == "")
	W.call([[5.2, 1.9], [5.5, 2.0], [5.5, 2.5]]); W.call([[5.5, 5.75], [5.5, 6.0]])
	W.call([[5.2, 6.0], [4.8, 5.6], [4.8, 4.4], [4.1, 3.7], [3.2, 3.7], [2.6, 3.1]])
	P.call("bag_m"); U.call(func(): return has_pack and act == "")
	W.call([[2.3, 3.1], [2.1, 2.9], [1.4, 2.9], [1.2, 2.7], [1.2, 1.6], [1.3, 1.5]]); P.call("hoodie"); U.call(free)
	W.call([[1.5, 1.5]]); P.call("window"); U.call(free); P.call("uptape"); U.call(free)
	W.call([[1.5, 1.7], [3.1, 3.3], [3.7, 3.3], [4.3, 3.9], [4.8, 4.4], [4.8, 5.6], [5.2, 6.0], [5.5, 6.0]]); W.call([[5.5, 5.6], [5.5, 2.4]]); W.call([[5.1, 2.2]])
	st.append(["mark", "plug"])
	P.call("nat"); U.call(func(): return step == 4, 60.0); st.append(["wait", 1.5]); st.append(["press"])
	U.call(func(): return step == 6, 40.0); st.append(["wait", 1.0])
	st.append(["hold", func(): return step != 6])
	U.call(func(): return step == 8, 40.0); st.append(["press"])
	U.call(func(): return step == 9); st.append(["press"])
	U.call(func(): return done6.has("phone") and act == "")
	st.append(["mark", "box"])
	# Ｅ
	U.call(func(): return box_st == 1); st.append(["wait", 5.0])
	W.call([[4.4, 3.0], [4.3, 3.1], [4.2, 3.3], [4.1, 3.7], [3.6, 3.7], [2.7, 2.8], [2.6, 2.7]]); P.call("box")
	U.call(func(): return step == 2 and act == "box", 60.0); st.append(["wait", 1.0]); st.append(["press"])
	U.call(func(): return done6.has("box")); st.append(["wait", 4.0]); U.call(free)
	st.append(["mark", "sleeve"])
	# Ｄ
	W.call([[2.7, 2.8], [3.6, 3.7], [4.1, 3.7], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.8, 6.2], [6.5, 6.2], [7.4, 6.8]])
	P.call("sink"); U.call(func(): return step == 1 and act == "sleeve", 40.0); st.append(["wait", 1.5])
	st.append(["hold", func(): return step != 1])
	U.call(func(): return done6.has("sleeve") and free.call(), 60.0)
	W.call([[7.9, 6.3], [9.2, 5.0]]); P.call("back"); U.call(free)
	st.append(["mark", "sit"])
	# Ｆ
	W.call([[8.2, 4.9], [6.9, 6.2], [5.8, 6.2], [5.5, 5.9], [5.0, 5.9], [4.3, 5.2], [4.3, 3.9], [4.2, 3.8]])
	P.call("sit")
	st.append(["mark", "end"])
	U.call(func(): return can_stand, 80.0); st.append(["wait", 6.0]); st.append(["getup"])
	U.call(func(): return stood)
	W.call([[4.30, 2.70], [4.30, 1.20], [4.80, 0.75]])
	st.append(["aimv", gp(FRONT6[0], FRONT6[1], FRONT6[2])]); st.append(["press_end"])
	U.call(func(): return stage == "fin", 200.0)
	return st

func _demo6_tick(dt: float):
	if d6.is_empty():
		d6 = _demo6_script(); di = 0
		if start6 != "":
			while di < d6.size() and not (d6[di][0] == "mark" and d6[di][1] == start6): di += 1
	# what she could say: the first, after a breath
	if mode == TALK and cur.has("choose") and not cur.get("chosen", false):
		d_choice += dt
		if d_choice > 2.0: d_choice = 0.0; _advance()
	if di >= d6.size() or card_t > 0.0: return
	var s: Array = d6[di]
	dw += dt
	var done := false
	match String(s[0]):
		"mark": done = true
		"wait": done = dw >= float(s[1])
		"until":
			done = (s[1] as Callable).call()
			if dw > float(s[2]): _dfail6("step %d: waited %.0f s (stage %s act %s step %d mode %d)" % [di, dw, stage, act, step, mode]); done = true
		"walk":
			if player.auto_path.is_empty() and s.size() < 3:
				if mode != FREE or act != "": return
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
				if off > 0.6:
					var hit := ""
					for ci in player.get_slide_collision_count():
						var kc: KinematicCollision3D = player.get_slide_collision(ci)
						hit += " %s@%s" % [(kc.get_collider() as Node).name if kc.get_collider() else "?", kc.get_position()]
					_dfail6("walk: stuck at %s (y %.2f) on the way to %s; against%s" % [_plan_of(player), player.global_position.y, last, hit])
				player.auto_path = []; done = true
		"aim", "aimv":
			var at2: Vector3 = _aim_of(s[1]) if s[0] == "aim" else s[1]
			var cam := _cam()
			var to2: Vector3 = at2 - cam.global_position
			var k := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to2.x, -to2.z), k)
			player.pitch = lerpf(player.pitch, asin(clampf(to2.normalized().y, -1.0, 1.0)), k)
			done = (-cam.global_basis.z).angle_to(to2) < deg_to_rad(3.0) or dw > 4.0
		"press":
			if mode == FREE and (act != "" or not tgt.is_empty()) and dw > 0.4:
				if act == "" : print("DEMO press %s 「%s」" % [tgt.k, note_lb.text])
				else: print("DEMO press (%s %d) 「%s」" % [act, step, note_lb.text])
				_press6(); done = true
			elif dw > 8.0: _dfail6("step %d: nothing to press (act %s step %d, at %s)" % [di, act, step, _plan_of(player)]); done = true
		"hold":
			hold_demo = true
			if (s[1] as Callable).call(): hold_demo = false; done = true
			elif dw > 40.0: hold_demo = false; _dfail6("step %d: held Ｅ 40 s (act %s step %d)" % [di, act, step]); done = true
		"getup": _get_up(); done = true
		"press_end":
			if note_lb.text != "": _press_end(); done = true
			elif dw > 6.0: _dfail6("cannot open the front door at %s" % [_plan_of(player)]); opened_t = 0.0; done = true
	if done: di += 1; dw = 0.0

func _dfail6(what: String):
	DEMO_FAILS += 1
	print("DEMO FAIL ch6: %s t=%.1f" % [what, t_now])


# 試作175 B4（ユーザー「6章をどう進めるか」）: in the board's margin (Tab), which of the first three is still as it was. Nothing on the
# screen itself; only the names, never what is to be done with them
func _board6_tick():
	if board_layer == null: return
	board_layer.visible = board_up and has_board and stage == "free"
	if not board_layer.visible: return
	_place_board()
	var left: Array = []
	if not done6.has("tripod"): left.append(T("三脚"))
	if not (done6.has("cam") and done6.has("batt")): left.append(T("定点のカメラ"))
	if not done6.has("phone"): left.append(T("夏希"))
	board_note.text = ("— " + "、".join(left)) if not left.is_empty() else ""
