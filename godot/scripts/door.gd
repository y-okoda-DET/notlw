## 段階1の縦切り：第2章 23:00、扉の前の沈黙（docs/企画書.md「扉（第2章・23:00）」）。
## 夜の場面で、遊んでここまで来たとき（main.gd FROM_STORY）か --door のときだけ main.gd が作る。
##
## She is not asked to do anything. She stands in the hall, a few steps from the door Taiga is holding shut, and can
## look where she likes. Natsuki is on the other side. The transcript goes on as it did all evening, and where Mio
## should have said something it writes what the transcriber heard: （沈黙）, with the seconds counting up while the
## player stands there. W does not walk: the view leans half a step toward the door and comes back.
## When Natsuki has gone the interviewer's question comes back on a card, with the length of Mio's silences under it.
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")

# 試作278（ユーザー点検2、2026-11-23）: she stood on the hall's axis 2.6 m from the door (Blender 0.12, 3.80), the walls
# running to it. Now by the west wall of the genkan step, 1.55 m from the door and 22° off the axis: the door and Taiga
# against it seen from the side, the hall behind her
const MIO_AT := [-0.38, 4.85]         # Blender x, y of her feet (plan 4.42, 1.45; at 1.2 Taiga filled half the frame)
const DOOR_AT := [0.20, 6.30, 1.45]
# [seconds after the card, who, words, how] | [t, "silence"] | [t, "note", words] | [t, "leave"] | [t, "end"]
# written in story/ch2_23.txt 【扉.流れ】 (the times, the words, who they are said to), read in _ready
var LINES := []
var LIF := []                  # 2026-11-20: a line's ［flag］ (the night's record), judged when its second comes; "" for none
# E while she looks at the door (試作33「扉、調べられるようにしたい」): she does not speak in the hall (the silence goes on
# counting); what comes is her answer months later, set apart at the top of the page. One look each, in this order
# (【扉.見る1】…: a second line is the one for after Natsuki has gone).
var DOOR_LOOKS := []
var looked := 0
var dlook := {}                # the answer being typed: {lb, text, typed}
var li := 0
var silence := {}              # the open （沈黙） line: {lb, t0}
var silent_total := 0.0
var lean_tw: Tween
var end_card: Control
var ended := -1.0
var speaker := ""
var slip := Vector2.ZERO

func _ready():
	for e in B("扉.流れ"):
		LIF.append(String(e.get("if", "")))
		if e.has("do"): LINES.append([e.t, e.do])
		elif e.has("note"): LINES.append([e.t, "note", e.note])
		else: LINES.append([e.t, e.who, e.text, "testimony" if e.get("testimony", false) else {"澪": "to_mio", "扉": "to_door"}.get(e.get("to", ""), "")])
	# 試作282（ユーザー「このシーンで扉は選択できないようにする」）: the door is not looked at with E any more; only the lock
	# is reached for. 【扉.見る】 stays in the text, unread (--doorlooks brings it back for comparison)
	var n := 1
	while OS.get_cmdline_user_args().has("--doorlooks") and D.has("扉.見る%d" % n):
		var l: Array = D.lines("扉.見る%d" % n); DOOR_LOOKS.append(l[0] if l.size() == 1 else l); n += 1
	player = main.player
	font = Type.say()
	offscreen = ["ラジオ", "夏希"]   # behind the door
	u = get_viewport().get_visible_rect().size.y / 1080.0
	_page()
	_lookers()
	_night_cam()
	_end_card()
	call_deferred("_strike_walk")
	# 試作281（ユーザー「細い窓越しに見える腕が変。いっそのこと、ここに夏希の手を映さなくてもいいかもね」）: behind the door she is only
	# her light on the slit and her knocking; her body is not drawn (the node stays, its visible is the story's "she has gone")
	if main.S.has("natsuki_node"):
		for gi in (main.S.natsuki_node as Node).find_children("*", "GeometryInstance3D", true, false): (gi as GeometryInstance3D).visible = false
	get_tree().create_timer(0.5).timeout.connect(func(): _face_light("taiga", 0.3, "kiryu"))   # 点検3: Kiryu holds his phone up to him: his face against the door
	player.global_position = Vector3(MIO_AT[0], 0.0, -MIO_AT[1])
	var to := g(DOOR_AT) - Vector3(MIO_AT[0], 1.52, -MIO_AT[1])
	player.yaw = atan2(-to.x, -to.z); player.pitch = deg_to_rad(-3.0)
	# 試作282（レビュー 5-5「一点透視の廊下」）: not square on to the door down the hall: it stands at the left third, the
	# hall's wall and the stair's side cut across the frame. The player turns to it as before
	player.yaw += deg_to_rad(-17.0)
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--storystate=door_"): call_deferred("_jump", float(a2.substr(18)))
		if a2.begins_with("--doorlook="):   # stills: the n-th look at the door (0..2), typed out
			looked = int(a2.substr(11)); call_deferred("_look_door"); get_tree().create_timer(0.2).timeout.connect(func(): dlook.typed = 999.0; _type(dlook.lb, String(dlook.text), 999))
		if a2.begins_with("--yawpitch="):   # stills only: turn Mio's head (degrees, added to the default)
			var yp := a2.substr(11).split(",")
			player.yaw += deg_to_rad(float(yp[0])); player.pitch = deg_to_rad(float(yp[1]))

# the small camera she put on the handrail at the start of the evening, still recording (第11章's tape is this)
func _night_cam():
	_fixed_cam()
	if PLACED.has("pos"):
		fixed_cam.global_transform = Transform3D(PLACED.basis, PLACED.pos)
	else:
		var ta := _target_angles()
		fixed_cam.global_transform = Transform3D(Basis.from_euler(Vector3(ta[1], ta[0], 0.0), EULER_ORDER_YXZ), g([TARGET_POS[0], TARGET_POS[1], _rail_z(TARGET_POS[1]) + 0.065]))
	(fixed_cam.get_node("rec") as OmniLight3D).light_energy = 0.6
	var dm := (fixed_cam.get_node("recdot") as MeshInstance3D).material_override as StandardMaterial3D
	dm.emission_energy_multiplier = 6.0

func _end_card():
	pass

# not a chapter's door but the exchange: the question, and under it, in the transcript's rows, what she answered.
# It cuts in over the hall, as the chapter cards do.
func _show_end():
	end_card = main.make_card(self, [["「扉を開けなかったのは、なぜですか？」", 64, 60, ""],
		[T("（沈黙・%s秒）") % num(int(round(silent_total))), 52, 0, "澪"]], Type.card(), false)
	page.visible = false

func _process(dt):
	if main.card.visible: return
	t_now += dt
	player.move_enabled = false
	main.story_talking = true
	if ended >= 0.0:
		ended += dt
		# ステップ D: the question stays up, and then the night goes on at 3:30 (第4章). 第3章 is not made yet.
		if ended > (8.0 if OS.get_cmdline_user_args().has("--demo") else 14.0) and not demo_on:
			demo_on = true
			if OS.get_cmdline_user_args().has("--demo"): print("DEMO door t=%.1f fails=%d" % [t_now, DEMO_FAILS])
			if ResourceLoader.exists("res://scripts/ch3.gd"): main.to_chapter("ch3")   # ステップ F: 第3章（夜中）
			elif ResourceLoader.exists("res://scripts/fps.gd"): main.to_chapter("ch4")
			elif OS.get_cmdline_user_args().has("--demo"): print("DEMO DONE t=%.1f fails=%d" % [t_now, DEMO_FAILS]); get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--demo"): _demo_door(dt)
	if not unlock_q.is_empty() or unlock_hold > 0.0:
		t_now -= dt   # 2026-11-20: the night stands while she is at the lock
		_unlock_tick(dt)
	while li < LINES.size() and t_now >= float(LINES[li][0]):
		if LIF[li] == "" or has_flag(LIF[li]): _event(LINES[li])
		li += 1
	# the door she is looking at, and her answer about it being typed
	var cam: Camera3D = player.get_node("Head/Camera")
	var at_door := (-cam.global_basis.z).angle_to(g(DOOR_AT) - cam.global_position) < deg_to_rad(13.0)
	note_lb.text = T("［扉］") if at_door and looked < DOOR_LOOKS.size() else ""
	if _lock_open() and _lock_looked() and unlock_q.is_empty(): note_lb.text = T("［鍵｜Ｅ］")
	if dlook.has("lb") and dlook.typed < String(dlook.text).length():
		dlook.typed = min(float(String(dlook.text).length()), dlook.typed + dt * 20.0)
		_type(dlook.lb, String(dlook.text), int(dlook.typed))
	# the words being typed
	if cur.has("text") and typed < String(cur.text).length():
		typed = min(float(String(cur.text).length()), typed + dt * (20.0 if cur.get("testimony", false) else 15.0))
		_type(cur_lb, String(cur.text), int(typed))
	main.talk_now = cur.get("who_key", "") if cur.has("text") and typed < String(cur.text).length() else ""
	# the silence, counted; and while it lasts the print's blue plate slips off register, a pixel every two seconds
	# (her memory of the hall does not hold together there), and snaps back when someone speaks
	var want := Vector2.ZERO
	if silence.has("lb") and is_instance_valid(silence.lb):
		var secs := t_now - float(silence.t0)
		(silence.lb as Label).text = T("（沈黙・%s秒）") % num(int(secs))
		want = Vector2(-0.85, 0.53) * min(secs * 0.55, 9.0)
	slip = want if want.length() > slip.length() else slip.move_toward(want, dt * 40.0)
	if main.PRINT_V == 2 and main.riso: main.riso.set_shader_parameter("slip", slip)
	_update_looks()

# ---------------------------------------------------------------- 2026-11-20 12時28分（ユーザー「もう一つの形にする」）: the lock
# Between 8 and 68 s she can go to the lock and turn it (once). Taiga throws his weight on the door as it gives and locks it
# again, his hand left on the lock. Her hands could move; her mouth could not: no line of hers. Kept as "tried".
var unlock_done := false
var unlock_q: Array = []
var unlock_hold := 0.0
func _lock_open() -> bool:
	return not unlock_done and t_now >= 8.0 and t_now <= 68.0 and ended < 0.0

func _lock_at() -> Vector3:
	var k := _front_knob(g(DOOR_AT))
	if k: return ((k as MeshInstance3D).global_transform * (k as MeshInstance3D).get_aabb()).get_center()
	return g([DOOR_AT[0] + 0.32, DOOR_AT[1], 1.0])

func _lock_looked() -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := _lock_at() - cam.global_position
	var a := (-cam.global_basis.z).angle_to(to)
	return a < deg_to_rad(9.0) and a < (-cam.global_basis.z).angle_to(g(DOOR_AT) - cam.global_position)

func _unlock():
	unlock_done = true; note_lb.text = ""
	_close_silence()
	unlock_q = B("扉.開ける")
	# 試作282（ユーザー「鍵を開けようとしたあと視点が変。鍵を開けるまでいかなくていい。開けようとしたら諌められる位の流れで」）:
	# she does not walk to it (the eye was carried into the door and Taiga's arm). Her weight goes toward the lock, her hand is
	# on it; Taiga stops her before it turns. The eye stays where it was
	if lean_tw and lean_tw.is_valid(): lean_tw.kill()
	lean_tw = create_tween()
	lean_tw.tween_property(player, "lean", 0.09, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lean_tw.tween_interval(1.6)
	lean_tw.tween_property(player, "lean", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	unlock_hold = 0.5
	print("STORY door unlock t=%.1f" % t_now)

func _unlock_tick(dt: float):
	if cur.has("text") and typed < String(cur.text).length(): return
	unlock_hold -= dt
	if unlock_hold > 0.0 or unlock_q.is_empty(): return
	var e: Dictionary = unlock_q.pop_front()
	unlock_hold = 0.0
	if e.has("do"):
		match String(e.do):
			"touch":   # her fingers on the thumb-turn: it clicks against the latch, it does not turn
				Sound.one(self, "lock", -14.0, _lock_at())
				unlock_hold = 0.5
			"unlock":
				Sound.one(self, "lock", -4.0, _lock_at())
				var r0: float = main.S.get("door_rot", 0.0)
				var tw := create_tween()
				tw.tween_method(func(v: float): main.S["door_rot"] = v, r0, r0 + 0.16, 0.35).set_trans(Tween.TRANS_SINE).set_delay(0.3)
				main.set_meta("door_rot0", r0)
				Sound.one(self, "door_open", -6.0, g(DOOR_AT))
				unlock_hold = 0.7
			"taiga_lean":
				var r1: float = main.get_meta("door_rot0", 0.0)
				var tw2 := create_tween()
				tw2.tween_method(func(v: float): main.S["door_rot"] = v, float(main.S.get("door_rot", r1)), r1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				Sound.one(self, "body_fall", -4.0, g(DOOR_AT)); Sound.one(self, "door_close", 0.0, g(DOOR_AT))
				get_tree().create_timer(0.5).timeout.connect(func(): Sound.one(self, "lock", -6.0, _lock_at()))
				unlock_hold = 0.9
			_: _flag_do(String(e.do))
		return
	if e.has("note"):
		_line_row("", e.note, 22, "note"); cur = {}
		unlock_hold = 1.4
		return
	cur = {"who": e.who, "text": _wrap_row(Tw(String(e.text))), "who_key": WHO_KEY.get(e.who, ""), "testimony": e.get("testimony", false)}
	typed = 0.0
	var r = _line_row(String(e.who), "", SAY_SIZE, "say")
	cur_lb = r[1]
	unlock_hold = 0.8 + String(e.text).length() * 0.05

func _event(e: Array):
	if e.size() == 2 and _flag_do(String(e[1])): return
	if OS.get_cmdline_user_args().has("--demo"): print("SAY %.1f " % float(e[0]), "：".join(e.slice(1, 3)) if e.size() > 2 else "＞" + String(e[1]))
	match e[1]:
		"silence":
			_close_silence()
			var r = _line_row("澪", "（沈黙）")
			silence = {"lb": r[1], "t0": t_now}
			cur = {}
		"note":
			_close_silence()
			_line_row("", e[2], 22, "note"); cur = {}
		"leave":
			# she goes: the knocking stops, the door settles, her light leaves the glass
			main.S.erase("knocks")
			if main.door_pivot: main.door_pivot.position = main.S.door_rest; main.door_pivot.rotation.y = main.S.door_rot
			if main.lights.has("blue"): main.lights.blue.light_energy = 1.4
			if main.S.has("natsuki_node"): main.S.natsuki_node.visible = false
		"end":
			_close_silence()
			ended = 0.0
			_show_end()
		_:
			_close_silence()
			cur = {"who": e[1], "text": _wrap_row(Tw(e[2])), "who_key": WHO_KEY.get(e[1], ""), "testimony": e.size() > 3 and e[3] == "testimony"}
			typed = 0.0
			var r = _line_row(e[1], "", SAY_SIZE, "testimony" if cur.testimony else "say")
			cur_lb = r[1]
			speaker = cur.who_key
			if e.size() > 3 and e[3] in ["to_mio", "to_door"]: S_look = [cur.who_key, e[3]]
			print("STORY door t=%.1f %s" % [t_now, e[1]])

var S_look := ["", ""]

func _close_silence():
	if silence.has("lb"):
		var secs := t_now - float(silence.t0)
		silent_total += secs
		if is_instance_valid(silence.lb): (silence.lb as Label).text = T("（沈黙・%s秒）") % num(int(secs))
	silence = {}

# Kiryu turns to her when he says it to her, to the door when he says it through the door; the rest keep to their loops
func _update_looks():
	var eye: Vector3 = (player.get_node("Head/Camera") as Camera3D).global_position
	for k in looks:
		var lm: Look = looks[k]
		var on: bool = (S_look[0] == k) and cur.has("text") and cur.get("who_key", "") == k
		lm.want = 1.0 if on else 0.0
		lm.target = g(DOOR_AT) if S_look[1] == "to_door" else eye

func _unhandled_input(e):
	if main.card.visible or ended >= 0.0: return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if press and _lock_open() and _lock_looked() and unlock_q.is_empty(): _unlock(); return
	if press and note_lb.text != "" and unlock_q.is_empty(): _look_door(); return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_W, KEY_UP]:
		# the step she does not take: the weight goes forward and comes back
		if lean_tw and lean_tw.is_valid(): lean_tw.kill()
		lean_tw = create_tween()
		lean_tw.tween_property(player, "lean", 0.07, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		lean_tw.tween_property(player, "lean", 0.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# check stills: start the scene at t seconds (the lines before it already on the page)
func _jump(t: float):
	while li < LINES.size() and float(LINES[li][0]) <= t:
		t_now = float(LINES[li][0]); _event(LINES[li]); li += 1
		if cur.has("text"): typed = String(cur.text).length(); _type(cur_lb, String(cur.text), int(typed))
	t_now = t

# the unattended playthrough: she turns to the door three times and looks (E), as a player who tries the door would
const DEMO_LOOKS := [20.0, 60.0, 80.0]
func _demo_door(dt: float):
	if "--doortry" in OS.get_cmdline_user_args() and not unlock_done and t_now > 36.0:   # (the check of the other way: she goes to the lock)
		var cam0: Camera3D = player.get_node("Head/Camera")
		var to0 := _lock_at() - cam0.global_position
		var k0 := 1.0 - exp(-dt * 5.0)
		player.yaw = lerp_angle(player.yaw, atan2(-to0.x, -to0.z), k0)
		player.pitch = lerp(player.pitch, asin(clamp(to0.normalized().y, -1.0, 1.0)), k0)
		if _lock_looked(): _unlock()
		elif t_now > 46.0: DEMO_FAILS += 1; print("DEMO FAIL door: cannot look at the lock t=%.1f" % t_now); unlock_done = true
		return
	if looked >= DEMO_LOOKS.size() or looked >= DOOR_LOOKS.size() or t_now < DEMO_LOOKS[looked]: return
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := g(DOOR_AT) - cam.global_position
	var k := 1.0 - exp(-dt * 4.0)
	player.yaw = lerp_angle(player.yaw, atan2(-to.x, -to.z), k)
	player.pitch = lerp(player.pitch, asin(clamp(to.normalized().y, -1.0, 1.0)), k)
	if (-cam.global_basis.z).angle_to(to) < deg_to_rad(6.0): _look_door()
	elif t_now > DEMO_LOOKS[looked] + 6.0: DEMO_FAILS += 1; print("DEMO FAIL door: cannot look at the door  t=%.1f" % t_now); looked += 1

func _look_door():
	var l = DOOR_LOOKS[looked]
	var text: String = l if l is String else String(l[1] if main.S.has("natsuki_node") and not main.S.natsuki_node.visible else l[0])
	looked += 1
	if OS.get_cmdline_user_args().has("--demo"): print("SAY 澪＊：", text)
	text = _wrap_row(Tw(text))
	var r = _line_row("澪", "", SAY_SIZE, "testimony")
	dlook = {"lb": r[1], "text": text, "typed": 0.0}
	# she leans to it, as with W
	if lean_tw and lean_tw.is_valid(): lean_tw.kill()
	lean_tw = create_tween()
	lean_tw.tween_property(player, "lean", 0.05, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	lean_tw.tween_property(player, "lean", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	print("STORY door look %d t=%.1f" % [looked, t_now])


# the keys along the top: walking is there, struck through like the words she did not say
func _strike_walk():
	var f: Label = main.foot
	if f == null: return
	var fs := int(19 * u)
	var st := Strike.new(); st.u = u; st.col = Color(main.CARD_INK.r, main.CARD_INK.g, main.CARD_INK.b, 0.9)
	st.w = font.get_string_size(T("ＷＡＳＤ 歩く"), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	st.size = Vector2(st.w, font.get_height(fs)); st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(st)
