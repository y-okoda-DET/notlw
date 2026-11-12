## ステップ E：第2章の残り、21時「話がある」と22時「車へ」（docs/企画書.md）。台詞は story/ch2_21.txt。
## 家まるごとの20時の光（発電機の電球、板の窓、居間のランタン）で動く。地下の窓を塞いだあと（story.gd の ch2_cut）に
## main.gd が play="h21" で作り、終わると23時の扉（door.gd）へ。
##
## 21時、居間。みんながランタンのまわりにいる。桐生の映画の話のあとで、夏希が「話したいことがある」と言い、桐生が
## 止め、夏希が澪を見る。澪の答えは二つ出るが、書き起こしに残るのは「あとでにしよう」だけ（「聞くよ」を選んでも、
## それは二重線で消える。選べたはずの言葉を、記憶の版が書き直す。Claude の判断、ユーザーの OK 待ち）。
## 22時、廊下。夏希は車のラジオを聞きに出ると言う。澪は玄関まで見送り、夏希は「戻ったら、さっきの話」と言って出ていく。
## 大河が鍵を閉める。それが23時の扉になる。
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")

# where they are (plan metres: x east, y north from the front door) and whom they face
const AT21 := {"kiryu": [1.05, 2.35], "makoto": [1.15, 0.95], "taiga": [2.85, 0.95], "natsuki": [2.35, 2.35]}
const FACE21 := [1.85, 1.6]                    # the lantern on the low table
const MIO21 := [3.45, 3.25]                    # by the living room's door, looking in
const AT22 := {"kiryu": [4.40, 3.20], "makoto": [3.55, 3.55], "taiga": [5.05, 3.45], "natsuki": [4.80, 1.75]}
const MIO22 := [4.55, 2.75]
const NAT_DOOR := [4.95, 0.55, 0.0]                 # inside the front door, where she stops and turns to Mio
const NAT_OUT := [[5.0, 0.0, 0.0], [5.0, -1.3, 0.0]]

var part := 21
var card: Control
var card_t := 3.0
var stage := ""                                # "" | talk | see_off | out | to23
var see_t := 0.0
var out_t := -1.0
var door_rest := 0.0
var demo21 := false

func _ready():
	player = main.player
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = ["ラジオ"]
	fps_load("ch2_21")
	_page()
	_lookers()
	main.generator(true)
	demo21 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	demo_on = demo21
	for a in OS.get_cmdline_user_args():
		if a == "--h22": part = 22
	_set_part(part)

static func fps_load(file: String):
	D.load_all()
	if D.blocks.has("@" + file): return
	D.blocks["@" + file] = []
	var p := "res://story/%s.txt" % file
	if not FileAccess.file_exists(p): print("SCRIPT ERROR 台本: no file ", p); return
	var key := ""
	for raw in FileAccess.get_file_as_string(p).split("\n"):
		var ln := String(raw).strip_edges()
		if ln == "" or ln.begins_with("//"): continue
		if ln.begins_with("【") and ln.ends_with("】"): key = ln.substr(1, ln.length() - 2); D.blocks[key] = []
		elif key != "": D.blocks[key].append(String(raw).rstrip(" \t\r"))

# the 20:00 bodies look along their rig's -z (the first try had them all turn their backs: 試作111 の確認)
func _face(from: Array, to: Array) -> float:
	return atan2(to[0] - from[0], to[1] - from[1]) + PI

func _put(k: String, at: Array, yaw: float):
	if main.S.has(k + "_node"): main.place_person(k, [at[0] - 4.8, 6.3 - at[1], 0.0], yaw)

func _set_part(p: int):
	part = p
	_clear_page(); _set_mission("")
	if p == 21:
		for k in AT21: _put(k, AT21[k], _face(AT21[k], FACE21))
		player.global_position = gp(MIO21[0], MIO21[1], 0.0)
	else:
		for k in AT22: _put(k, AT22[k], _face(AT22[k], MIO22))
		player.global_position = gp(MIO22[0], MIO22[1], 0.0)
	_look_from(MIO21 if p == 21 else MIO22, FACE21 if p == 21 else AT22.natsuki)
	if card: card.queue_free()
	card = main.make_card(self, [[D.lines("二十一.カード" if p == 21 else "二十二.カード")[0], 52, 0]], Type.card())
	card_t = 3.0; stage = ""
	print("STORY h%d" % p)

# Mio's view from a to b (plan points)
func _look_from(a: Array, b: Array):
	var to := gp(b[0], b[1], 1.3) - gp(a[0], a[1], 1.52)
	player.yaw = atan2(-to.x, -to.z); player.pitch = deg_to_rad(-6.0)

func _process(dt):
	t_now += dt
	if card_t > 0.0:
		card_t -= dt
		card.visible = true; player.move_enabled = false; player.look_enabled = false
		if card_t <= 0.0:
			card.visible = false; player.look_enabled = true
			stage = "talk"
			_start(B("二十一.会話" if part == 21 else "二十二.会話"))
		return
	if mode == TALK: _talk_tick(dt)
	_update_looks()
	player.move_enabled = (mode == FREE) and stage == "see_off"
	main.talk_now = cur.get("who_key", "") if mode == TALK and cur.has("who") and typed < float(String(cur.text).length()) else ""
	main.story_talking = (mode == TALK)
	if stage == "see_off":
		see_t += dt
		var nat: Node3D = main._rig_of("natsuki")
		var near: bool = nat and Vector2(player.global_position.x - nat.global_position.x, player.global_position.z - nat.global_position.z).length() < 1.7
		if mode == FREE and (near or see_t > 25.0) and not main.walkers.has("natsuki"):
			stage = "door_talk"; _start(B("二十二.玄関"))
		if demo21 and mode == FREE: _demo_walk(dt)
	if out_t >= 0.0: _out_tick(dt)

func _unhandled_input(e):
	if card_t > 0.0: return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if mode == TALK:
		if cur.has("choose") and e is InputEventKey and e.pressed and e.keycode in [KEY_W, KEY_UP, KEY_A, KEY_LEFT]: _move_choice(-1); return
		if cur.has("choose") and e is InputEventKey and e.pressed and e.keycode in [KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT]: _move_choice(1); return
		if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and cur.has("choose"):
			_move_choice(-1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1); return
		if press: _advance()

# the choice waits for her; in the unattended run she says what the memory keeps her saying anyway: the first one
func _talk_tick(dt):
	if demo21 and cur.has("choose") and not cur.get("chosen", false):
		read_t += dt
		if read_t > 2.0: read_t = 0.0; choice_idx = 0; _show_choice(); _choose()
		return
	super._talk_tick(dt)

func _do(what: String):
	print("STORY h21 do %s t=%.1f" % [what, t_now])
	match what:
		"later":
			# what she chose goes too: the transcript has her say the other
			var lb: Label = choice_lbs[choice_idx]
			var s := Strike.new(); s.u = u
			s.w = font.get_string_size(lb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(SAY_SIZE * u)).x
			s.size = lb.size; s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lb.add_child(s)
			var keep: Array = B("二十一.残る")
			for i in range(keep.size() - 1, -1, -1): script_q.push_front(keep[i])
		"to22":
			script_q.clear(); mode = FREE
			get_tree().create_timer(2.5).timeout.connect(func(): _set_part(22))
		"natsuki_door":
			stage = "see_off"; see_t = 0.0
			main.walk_to("natsuki", [[4.85, 1.2, 0.0], NAT_DOOR], Callable(), _face(NAT_DOOR, MIO22))
		"natsuki_out":
			out_t = 0.0
			door_rest = main.door_pivot.rotation.y if main.door_pivot else 0.0
			Sound.one(self, "door_open", -4.0, gp(5.0, 0.0, 1.0))
			main.walk_to("natsuki", NAT_OUT, func(): main._rig_of("natsuki").visible = false)
		"lock":
			Sound.one(self, "knock1", -14.0, gp(5.0, 0.0, 1.0))   # the latch (a placeholder: there is no lock sound yet)
		"to23":
			script_q.clear(); mode = FREE; stage = "to23"
			get_tree().create_timer(3.5).timeout.connect(func():
				if demo21: print("DEMO h21 t=%.1f fails=%d" % [t_now, DEMO_FAILS])
				if demo21 and "--demoquit" in OS.get_cmdline_user_args() and "--h21only" in OS.get_cmdline_user_args(): print("DEMO DONE h21"); get_tree().quit(); return
				main.to_night(true))
		_: super._do(what)

# the front door: open while she goes through, shut behind her
func _out_tick(dt: float):
	out_t += dt
	if main.door_pivot == null: return
	var k := smoothstep(0.0, 1.2, out_t) * (1.0 - smoothstep(4.2, 5.2, out_t))
	main.door_pivot.rotation.y = door_rest + deg_to_rad(70.0) * k
	if out_t > 5.4: out_t = -1.0

# the unattended run: walk after her to the genkan
func _demo_walk(dt: float):
	if player.auto_path.size() > 0: return
	var to := gp(NAT_DOOR[0], NAT_DOOR[1] + 1.1, 0.0)
	var p: Vector3 = player.global_position
	var d := to - p
	player.auto_path = [[0.0, p.x, p.z, rad_to_deg(player.yaw), -6.0], [d.length() / 0.9 + 0.3, to.x, to.z, rad_to_deg(atan2(-d.x, -d.z)), -6.0]]
	player.auto_t = 0.0
