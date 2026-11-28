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
# 2026-11-14（ユーザー「居間、みんな内側を向いて会話している感じに。スマホなし」）：低い机を囲む。桐生と大河はソファ（西向き、
# 机の方）に座り、真琴は机の南西、夏希は北（映写機のそば。ユーザー「夏希、上映の準備を進めているように」）に立つ。
# 大河の [2.85, 0.95] はソファの肘掛けの中だった
const AT21 := {"kiryu": [3.1, 2.25], "makoto": [1.2, 1.05], "taiga": [3.1, 1.3], "natsuki": [1.95, 2.8]}
const FACE21 := [1.9, 1.85]                    # the middle of the low table (the lantern, the projector)
const SIT21 := {"kiryu": "talk/sit_b", "taiga": "talk/sit_a"}   # facing the table (west), they do not turn
const SIT_Z := 0.0                              # how far the sitters' root is lifted (the seat's height against Mixamo's chair)
# standing: what each does while another speaks, and while speaking
const LISTEN := {"makoto": "talk/think", "natsuki": "talk/idle", "kiryu": "talk/idle", "taiga": "talk/idle"}
const SPEAK := {"makoto": "talk/talk_c", "natsuki": "talk/talk_a", "kiryu": "talk/talk_d", "taiga": "talk/talk_b"}
# 試作176 A10（ユーザー「夏希が歩く道を開けておいてあげたいので、澪の立ち位置を変えましょう」）: at 3.45, 3.25 she stood 0.2 m off
# Natsuki's way to the hall (NAT_CAM_ROUTE 2.7, 2.8 -> 3.6, 3.7); by the north wall, 0.45 m off it, still looking in
const MIO21 := [3.0, 3.72]
# 試作277（ユーザー「大河が階段にのめり込んでる」、22時）: 5.05, 3.45 is inside the stair (the --ch3map). A step up the hall, past Kiryu
const AT22 := {"kiryu": [4.40, 3.20], "makoto": [3.55, 3.55], "taiga": [4.70, 4.00], "natsuki": [4.80, 1.75]}
const MIO22 := [4.55, 2.75]
const NAT_DOOR := [4.95, 0.55, 0.0]                 # inside the front door, where she stops and turns to Mio
const NAT_OUT := [[5.15, 0.55, 0.0], [5.05, -0.6, 0.0], [6.2, -1.1, 0.0], [6.7, -1.15, 0.0]]   # 試作176 A11（ユーザー「扉開けて出ていくアニメーションが変」）: from where the door left her, straight out through the open side as Kiryu goes in 第3章 (ch3 _kiryu_out); she cut across from 5.47, 1.22 to the hinge side   # 試作125 (ユーザー「扉が閉まる前に夏希が消える」): out and to the right along the porch, behind the wall, before she is put away

var part := 21
var card: Control
var card_t := 1.5   # 半分に（ユーザー 2026-11-14）
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
	# 2026-11-13 (ユーザー「この場面はスマホライトなしでOK」): the phones' torches off; the lantern and the bulbs light the room
	for e in main.torches:
		if is_instance_valid(e[0]): (e[0] as Node3D).visible = false
	main.phones(false)   # 2026-11-14（ユーザー「スマホは持たない」）
	_table_radio()
	if not "--nocandle" in OS.get_cmdline_user_args(): _table_candle()
	demo21 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	demo_on = demo21
	for a in OS.get_cmdline_user_args():
		if a == "--h22": part = 22
	_set_part(part)

# 試作282（ユーザー「テーブルにラジオを置いてうっすらラジオの音声を流しておく」）: the radio from 20時, on the low table's
# end by the projector (furnish.py furn_ltable: x 1.55〜2.3, y 1.25〜2.45, top .40), its dial lit, on the news, low and muffled:
# they are waiting for the bulletin to come round again
var table_radio_snd: AudioStreamPlayer3D
func _table_radio():
	_radio()
	if radio == null: return
	tune = (1017.0 - AM_LO) / (AM_HI - AM_LO); _set_dial()
	radio.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), gp(1.78, 2.28, 0.40))
	_radio_power(true)
	var s := Sound.stream("radio_news_muf", true)
	if s == null or "--nosound" in OS.get_cmdline_user_args(): return
	table_radio_snd = AudioStreamPlayer3D.new(); table_radio_snd.stream = s; table_radio_snd.volume_db = -16.0
	table_radio_snd.unit_size = 1.6; table_radio_snd.max_db = -6.0
	add_child(table_radio_snd); table_radio_snd.global_position = radio.global_position + Vector3(0, 0.1, 0)
	table_radio_snd.play()

# 試作297（赤字 #9/#10「机の上にロウソクか何か置いて、もうちょっとだけ明るく」「#110で足した明かりがこっちにも多少届くように」）:
# a candle on a saucer on the low table, the projector end away from the radio; a little more energy and reach than
# ch3's hand-held one, so the sofa side and the #120 view both catch some of it
var tcandle_light: OmniLight3D
var tcandle_flame: Node3D
func _table_candle():
	var c := Node3D.new(); c.name = "ch2_table_candle"
	var stick := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.012; cm.bottom_radius = 0.013; cm.height = 0.10
	stick.mesh = cm; var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.92, 0.9, 0.84); wm.roughness = 0.6
	stick.material_override = wm; stick.position.y = 0.055; c.add_child(stick)
	var saucer := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.05; sm.bottom_radius = 0.045; sm.height = 0.01
	saucer.mesh = sm; var sw := StandardMaterial3D.new(); sw.albedo_color = Color(0.85, 0.84, 0.8); saucer.material_override = sw
	saucer.position.y = 0.005; c.add_child(saucer)
	tcandle_flame = Node3D.new(); tcandle_flame.position.y = 0.105; c.add_child(tcandle_flame)
	var f := MeshInstance3D.new(); var fm := SphereMesh.new(); fm.radius = 0.007; fm.height = 0.028
	f.mesh = fm; f.position.y = 0.013
	var fmat := StandardMaterial3D.new(); fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.78, 0.4); fmat.emission_enabled = true; fmat.emission = Color(1.0, 0.7, 0.3); fmat.emission_energy_multiplier = 4.0
	f.material_override = fmat; f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; tcandle_flame.add_child(f)
	tcandle_light = OmniLight3D.new(); tcandle_light.light_color = Color(1.0, 0.66, 0.34); tcandle_light.light_energy = 0.12
	tcandle_light.omni_range = 3.8; tcandle_light.omni_attenuation = 1.3; tcandle_light.shadow_enabled = true
	tcandle_light.light_volumetric_fog_energy = 0.2; tcandle_light.position.y = 0.15
	c.add_child(tcandle_light)
	add_child(c)
	c.global_position = gp(2.18, 2.0, 0.40)
	# (#120, the hall) what the candle gives through the open living-room door: a faint warm spill on the hall's floor and
	# its near wall (the candle itself, behind the wall, cannot reach there in the engine's light: one bounce, stood in for)
	var sp := OmniLight3D.new(); sp.light_color = Color(1.0, 0.7, 0.4); sp.light_energy = 0.05; sp.omni_range = 2.6
	sp.omni_attenuation = 1.6; sp.shadow_enabled = false; sp.light_volumetric_fog_energy = 0.0; sp.light_specular = 0.0
	add_child(sp); sp.global_position = gp(4.25, 3.5, 0.8)   # the hall end of the table: it reaches out of the door a little (#120)

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

# the 20:00 bodies looked along their rig's -z (試作111 の確認); the Mixamo clips they play here now (export_talk.py,
# 2026-11-14) look along +z, like the walk
func _face(from: Array, to: Array) -> float:
	return atan2(to[0] - from[0], to[1] - from[1])

func _put(k: String, at: Array, yaw: float):
	if main.S.has(k + "_node"): main.place_person(k, [at[0] - 4.8, 6.3 - at[1], 0.0], yaw)

func _set_part(p: int):
	part = p
	main.clock_at(21 if p == 21 else 22, 0)
	_clear_page(); _set_mission("")
	if p == 21:
		for k in AT21:
			_put(k, AT21[k], _face(AT21[k], [1.0, AT21[k][1]] if SIT21.has(k) else FACE21))
			if SIT21.has(k): main._rig_of(k).global_position.y += SIT_Z
			main.set_stand(k, SIT21.get(k, LISTEN[k]), 0.0)
		player.global_position = gp(MIO21[0], MIO21[1], 0.0)
	else:
		for k in AT22: _put(k, AT22[k], _face(AT22[k], MIO22)); main.set_stand(k, LISTEN[k], 0.0)
		player.global_position = gp(MIO22[0], MIO22[1], 0.0)
	_look_from(MIO21 if p == 21 else MIO22, FACE21 if p == 21 else AT22.natsuki)
	if card: card.queue_free()
	card = main.make_card(self, [[D.lines("二十一.カード" if p == 21 else "二十二.カード")[0], 52, 0]], Type.card())
	card_t = 1.5; stage = ""
	print("STORY h%d" % p)

# 2026-11-13 (ユーザー「会話しているように見せたい。せめて夏希は喋ってる相手を向く」): whoever is not speaking turns to the one who is;
# the speaker turns to the one she or he speaks to (Natsuki's「……澪。」to Mio), else to the middle of the group
var yaw_to := {}
func _turn_to_speaker(dt: float):
	if stage == "out" or out_t >= 0.0: return
	var who: String = cur.get("who_key", "") if mode == TALK else ""
	var at: Dictionary = AT21 if part == 21 else AT22
	var mio := [player.global_position.x + 4.8, player.global_position.z + 6.3]
	for k in at:
		if main.walkers.has(k): continue
		if part == 21 and SIT21.has(k): continue
		var rig: Node3D = main._rig_of(k)
		if rig == null or not rig.visible: continue
		# 試作125 (ユーザー「同じモーションが繰り返されて気持ち悪い」、22時の廊下): standing in the hall, the speaker's gesture
		# came round again every few seconds. At 22:00 they only stand and turn
		main.set_stand(k, SPEAK[k] if who == k and part == 21 else LISTEN[k])
		var me := [rig.global_position.x + 4.8, rig.global_position.z + 6.3]
		var target: Array
		if who == "" or who == "mio":
			target = FACE21 if part == 21 else mio
		elif who == k:
			var txt := String(cur.get("text", ""))
			if txt.contains("澪") or k == "natsuki" and part == 22: target = mio
			else:
				var c := [0.0, 0.0]; var n := 0
				for o in at:
					if o == k: continue
					var r2: Node3D = main._rig_of(o)
					if r2: c[0] += r2.global_position.x + 4.8; c[1] += r2.global_position.z + 6.3; n += 1
				target = [c[0] / maxf(n, 1), c[1] / maxf(n, 1)] if n > 0 else FACE21
		else:
			var sr: Node3D = main._rig_of(who)
			target = [sr.global_position.x + 4.8, sr.global_position.z + 6.3] if sr else FACE21
		var y1 := _face(me, target)
		var y0 := rig.global_rotation.y
		var y := y0 + wrapf(y1 - y0, -PI, PI) * minf(1.0, dt * 2.5)
		rig.global_transform = Transform3D(Basis(Vector3.UP, y), rig.global_position)

# Mio's view from a to b (plan points)
func _look_from(a: Array, b: Array):
	var to := gp(b[0], b[1], 1.3) - gp(a[0], a[1], 1.52)
	player.yaw = atan2(-to.x, -to.z); player.pitch = deg_to_rad(-6.0)

func _process(dt):
	t_now += dt
	if tcandle_light:
		tcandle_flame.basis = Basis(Vector3.RIGHT, 0.05 * sin(t_now * 13.0))
		tcandle_light.light_energy = 0.12 + 0.015 * sin(t_now * 17.0) + 0.01 * sin(t_now * 5.3)
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
	_turn_to_speaker(dt)
	player.move_enabled = (mode == FREE) and stage in ["see_off", "lock", "window"]
	main.talk_now = cur.get("who_key", "") if mode == TALK and cur.has("who") and typed < float(String(cur.text).length()) else ""
	main.story_talking = (mode == TALK)
	if stage == "see_off":
		see_t += dt
		var nat: Node3D = main._rig_of("natsuki")
		var near: bool = nat and Vector2(player.global_position.x - nat.global_position.x, player.global_position.z - nat.global_position.z).length() < 1.7
		if mode == FREE and (near or see_t > 25.0) and not main.walkers.has("natsuki"):
			stage = "door_talk"; _start(B("二十二.玄関"))
		if demo21 and mode == FREE: _demo_walk(dt)
	if stage == "lock" and mode == FREE:
		lock_t += dt
		if demo21 and lock_t > 1.5: _lock_now()
	if out_t >= 0.0: _out_tick(dt)
	if stage == "window": _window_tick(dt)
	_cam_tick()

# ---------------------------------------------------------------- 22時、鍵のあと（2026-11-20）：玄関わきの細い窓
# The slit by the front door is not boarded. Through it, in the storm, the car's dome light: her door opens and shuts (the
# slit brightens once), it stays on a while, then it goes away down the slope. The camera is not taken: E on the slit, when
# she has turned to it, and on to 23時.
const SLIT := [4.18, 0.0, 1.1]
var win_t := 0.0
var win_dome: OmniLight3D
var win_flash: OmniLight3D
var win_car := Vector3.ZERO
func _window22():
	stage = "window"; win_t = 0.0
	var cars: Array = main.S.env_node.find_children("ext_car*", "MeshInstance3D", true, false)
	win_car = gp(6.4, -8.0, -0.3)
	if not cars.is_empty():
		var bb := AABB()
		for i in cars.size():
			var b: AABB = (cars[i] as MeshInstance3D).global_transform * (cars[i] as MeshInstance3D).get_aabb()
			bb = b if i == 0 else bb.merge(b)
		win_car = bb.get_center()
	win_dome = OmniLight3D.new(); win_dome.light_color = Color(1.0, 0.74, 0.42); win_dome.light_energy = 0.0
	win_dome.omni_range = 6.0; win_dome.omni_attenuation = 1.0; win_dome.shadow_enabled = false; win_dome.light_specular = 0.2
	main.add_child(win_dome); win_dome.global_position = win_car + Vector3(0, 0.75, 0)
	win_flash = OmniLight3D.new(); win_flash.light_color = Color(1.0, 0.78, 0.5); win_flash.light_energy = 0.0
	win_flash.omni_range = 1.6; win_flash.omni_attenuation = 1.5; win_flash.shadow_enabled = false; win_flash.light_specular = 0.0
	main.add_child(win_flash); win_flash.global_position = gp(SLIT[0], SLIT[1] - 0.25, SLIT[2])
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func(): Sound.one(self, "car_door", -20.0, win_car))
	tw.tween_property(win_dome, "light_energy", 3.2, 0.25)
	tw.parallel().tween_property(win_flash, "light_energy", 0.9, 0.25)
	tw.tween_property(win_flash, "light_energy", 0.25, 1.2)
	tw.tween_interval(1.0)
	tw.tween_callback(func(): Sound.one(self, "car_door", -22.0, win_car))
	tw.tween_property(win_dome, "light_energy", 1.4, 0.4)
	tw.parallel().tween_property(win_flash, "light_energy", 0.12, 0.4)
	tw.tween_interval(9.0)
	# it goes down the slope: the drive (ch8.gd DRIVE)
	for q in [[6.4, -5.5], [8.6, -11.0], [10.6, -16.5]]:
		tw.tween_property(win_dome, "global_position", gp(q[0], q[1], 0.5), 3.0)
	tw.parallel().tween_property(win_dome, "light_energy", 0.0, 3.0)
	tw.parallel().tween_property(win_flash, "light_energy", 0.0, 3.0)

func _slit_looked() -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := gp(SLIT[0], SLIT[1], SLIT[2]) - cam.global_position
	return to.length() < 2.6 and (-cam.global_basis.z).angle_to(to) < deg_to_rad(22.0)

func _window_tick(dt: float):
	win_t += dt
	note_lb.text = T(String(D.lines("二十二.細い窓")[0])) if mode == FREE and _slit_looked() else ""
	if demo21 and mode == FREE and win_t > 4.0:
		var cam: Camera3D = player.get_node("Head/Camera")
		var to := gp(SLIT[0], SLIT[1], SLIT[2]) - cam.global_position
		var k := 1.0 - exp(-dt * 5.0)
		player.auto_path = []   # (a walk left over from before sets the view each frame)
		player.yaw = lerp_angle(player.yaw, atan2(-to.x, -to.z), k)
		player.pitch = lerpf(player.pitch, asin(clampf(to.normalized().y, -1.0, 1.0)), k)
		if win_t > 7.0 and _slit_looked(): _window_seen()
		elif win_t > 14.0: DEMO_FAILS += 1; print("DEMO FAIL h21: cannot look at the slit from ", player.global_position, " look=", rad_to_deg(player.yaw), "/", rad_to_deg(player.pitch), " to=", to); _window_seen()

func _window_seen():
	if stage != "window": return
	stage = "window_seen"; note_lb.text = ""
	var q: Array = B("二十二.細い窓"); q.remove_at(0)
	_start(q)

# 試作125: Taiga asks her to lock it; she goes to the door and does
var lock_t := 0.0
func _near_door() -> bool:
	var d: Vector3 = gp(5.0, 0.0, 0.0); var p: Vector3 = player.global_position
	return Vector2(p.x - d.x, p.z - d.z).length() < 1.8
func _lock_now():
	if stage != "lock": return
	stage = "locked"; _set_mission("")
	main.set_meta("front_locked", true)   # doors.gd: from now on the front door only rattles on its lock
	if main.has_meta("front_lock"): main.remove_meta("front_lock")
	_start(B("二十二.鍵"))

func _unhandled_input(e):
	if card_t > 0.0: return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if mode == TALK:
		if cur.has("choose") and e is InputEventKey and e.pressed and e.keycode in [KEY_W, KEY_UP, KEY_A, KEY_LEFT]: _move_choice(-1); return
		if cur.has("choose") and e is InputEventKey and e.pressed and e.keycode in [KEY_S, KEY_DOWN, KEY_D, KEY_RIGHT]: _move_choice(1); return
		if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and cur.has("choose"):
			_move_choice(-1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1); return
		if press: get_viewport().set_input_as_handled(); _advance()   # 2026-11-17 夜（ユーザー「扉を締めたあとに扉が開く」）: the E that went on to the line also reached doors.gd and swung the locked door open
	elif stage == "lock" and mode == FREE:
		if press and _near_door(): get_viewport().set_input_as_handled(); _lock_now()   # 試作127: handled, or doors.gd then swung the door open (the lock's callback was gone)
	elif stage == "window" and mode == FREE:
		if press and _slit_looked(): get_viewport().set_input_as_handled(); _window_seen()

# the choice waits for her; in the unattended run she says what the memory keeps her saying anyway: the first one
func _talk_tick(dt):
	if demo21 and cur.has("choose") and not cur.get("chosen", false):
		read_t += dt
		if read_t > 2.0: read_t = 0.0; choice_idx = 0; _show_choice(); _choose()
		return
	super._talk_tick(dt)

func _do(what: String):
	if _flag_do(what): return   # 2026-11-20 the night's record (story.gd FLAG_DOS)
	print("STORY h21 do %s t=%.1f" % [what, t_now])
	match what:
		"later", "listen":   # 2026-11-20 12時31分③: what she chose stands (the strike-through of 2026-11-14 is gone)
			var keep: Array = B("二十一.あとで" if what == "later" else "二十一.聞く") + B("二十一.あと")
			for i in range(keep.size() - 1, -1, -1): script_q.push_front(keep[i])
		"after21":
			pass
		"siren_far":   # 12時31分②: far off, once, not coming nearer (another accident, near; the game does not say)
			# 試作277（ユーザー「救急車の音、フェードインからフェードアウトで」）：遠くから寄って、また遠のく（音の長さに合わせて）
			var sp = Sound.one(self, "siren_far", -40.0)
			if sp:
				var ln: float = (sp as AudioStreamPlayer).stream.get_length()
				var tw := create_tween(); tw.tween_property(sp, "volume_db", -10.0, ln * 0.4).set_trans(Tween.TRANS_SINE)
				tw.tween_property(sp, "volume_db", -42.0, ln * 0.55).set_trans(Tween.TRANS_SINE)
		"window22":
			script_q.clear(); mode = FREE
			_window22()
		"to22":
			script_q.clear(); mode = FREE
			get_tree().create_timer(2.5).timeout.connect(func(): _set_part(22))
		"natsuki_cam":
			_natsuki_cam()
		"cam_back":
			_cam_back()
		"natsuki_door":
			stage = "see_off"; see_t = 0.0
			main.walk_to("natsuki", [[4.85, 1.2, 0.0], NAT_DOOR], Callable(), _face(NAT_DOOR, MIO22))
			# 試作232（ユーザー「夏希が暗すぎる」、22時の玄関）: in the genkan she was a shape against the black door. The lobby's
			# light on her face and front (a soft fill that goes with her; out of the door it goes with her too)
			var r: Node3D = main._rig_of("natsuki")
			if r and r.get_node_or_null("see_off_fill") == null:
				var f := OmniLight3D.new(); f.name = "see_off_fill"; f.light_color = Color(1.0, 0.86, 0.68); f.light_energy = 0.0
				f.omni_range = 1.7; f.omni_attenuation = 1.6; f.shadow_enabled = false; f.light_specular = 0.08
				# 試作282（ユーザー「ここ、なにの光源が夏希にあたっている？ここで照らされるなら後ろ姿が照らされてもいい気が」）: it
				# came from in front of her, where nothing shines. Now from behind and above, as the lobby's bulb would: her back,
				# her hair and shoulders lit, her face toward Mio in its shadow
				r.add_child(f); f.position = Vector3(-0.1, 2.0, -0.85)
				# 試作233: it lit the genkan wall beside her into a blown orange patch: it lights her alone (her meshes on layer 20)
				f.light_cull_mask = 1 << 19
				for m in r.find_children("*", "VisualInstance3D", true, false): (m as VisualInstance3D).layers |= 1 << 19
				create_tween().tween_property(f, "light_energy", 0.55, 1.5)
		"natsuki_out":
			# 2026-11-13 (ユーザー「扉開いて出るアニメーション、もう少しきれいに」): she opens it, waits for it, goes through, and it shuts
			# behind her once she is out of sight (not while she is in the doorway)
			# 試作127（ユーザー「夏希が扉を開けていると感じられる動きにしたい。いまは謎に扉が開く→夏希が振り返る→外へ出る」）:
			# she turns from Mio to the door and steps up to it first; only then does it open, as she is at the handle
			var at := [4.97, 0.42, 0.0]
			# 2026-11-17 夜（ユーザー「扉に手をかけて扉を開けるアニメーション入れられるか？」）: her hand on the knob, the door comes
			# to her and she steps back with it (story.gd _front_open_by); then out, and it shuts behind her once she is gone
			# 試作281（ユーザー「ここまだアニメーションが変。夏希が扉を開けて、出て、閉めるように」）: through the door and one step out,
			# she turns back to it, takes the knob and pulls it shut on herself; the shut is heard as it shuts. The script (the
			# 「扉の閉まる音」 and Taiga's line) waits for it
			var held := script_q.duplicate(); script_q.clear()
			_front_open_by("natsuki", func(rest: float):
				main.walk_to("natsuki", [NAT_OUT[0], NAT_OUT[1]], func():
					var rig: Node3D = main._rig_of("natsuki")
					var rc := _reach("natsuki", _front_knob(rig.global_position + Vector3.UP), gp(5.3, 0.3, 1.0))
					var tw := create_tween()
					tw.tween_property(rc, "w", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
					tw.tween_property(main.door_pivot, "rotation:y", rest, 0.9).set_trans(Tween.TRANS_SINE)
					tw.tween_callback(func():
						Sound.one(self, "door_close", -8.0, gp(5.0, 0.0, 1.0))
						rc.queue_free()
						rig.visible = false   # behind the shut door: put away
						if main.S.has("natsuki_col"): (main.S.natsuki_col as Node3D).global_position = Vector3(0, -50, 0)
						_start(held)), _face([5.05, -0.6], [5.0, 0.2])), 0.0)
		"lock_ask":
			script_q.clear(); mode = FREE; stage = "lock"; lock_t = 0.0
			main.set_meta("front_lock", _lock_now)
		"lock":
			Sound.one(self, "lock", -8.0, gp(5.0, 0.0, 1.0))   # 試作127: the key turned in the lock (音の取捨選択 2026-11-17: strachszydlo)
		"to23":
			script_q.clear(); mode = FREE; stage = "to23"
			get_tree().create_timer(3.5).timeout.connect(func():
				if demo21: print("DEMO h21 t=%.1f fails=%d" % [t_now, DEMO_FAILS])
				if demo21 and "--demoquit" in OS.get_cmdline_user_args() and "--h21only" in OS.get_cmdline_user_args(): print("DEMO DONE h21"); get_tree().quit(); return
				main.to_night(true))
		_: super._do(what)

# ---------------------------------------------------------------- 21時: Natsuki fetches Kiryu's camera (2026-11-17 夜)
# She gets up, goes out to the hall, takes the camcorder off its tripod at the stair's foot, brings it back and sets it
# by the projector; the line about it comes once it is there. The talk waits for her (the queue is put by and taken up).
var cam_parts := []        # [mesh, its parent, its global transform on the tripod]
var cam_holder: Node3D
var cam_carry := false
const NAT_CAM_ROUTE := [[2.7, 2.8, 0.0], [3.6, 3.7, 0.0], [4.25, 3.65, 0.0]]
func _natsuki_cam():
	var rest_q := script_q.duplicate(); script_q.clear()
	cam_parts = []
	var bb := AABB(); var first := true
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"):
			cam_parts.append([mi, mi.get_parent(), (mi as Node3D).global_transform])
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			bb = b if first else bb.merge(b); first = false
	if cam_parts.is_empty(): _start(rest_q); return
	var cam_c := bb.get_center()
	var cpl := [cam_c.x + 4.8, cam_c.z + 6.3]
	# where she stands: 0.5 m from it on the way she came
	var last: Array = NAT_CAM_ROUTE[-1]
	var dv := Vector2(last[0] - cpl[0], last[1] - cpl[1]); dv = dv.normalized() * 0.5 if dv.length() > 0.01 else Vector2(0.0, 0.5)
	var stand := [cpl[0] + dv.x, cpl[1] + dv.y, 0.0]
	main.set_stand("natsuki", "talk/idle", 0.3)
	var route := NAT_CAM_ROUTE.duplicate(); route.append(stand)
	main.walk_to("natsuki", route, func():
		var rc := _reach("natsuki", null, cam_c)
		var tw := create_tween()
		tw.tween_property(rc, "w", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func():
			Sound.one(self, "dial_tick", -10.0, cam_c)   # the shoe's catch
			cam_holder = Node3D.new(); main.add_child(cam_holder)
			cam_holder.global_position = cam_c   # the camera's middle: _cam_tick puts this in her hand
			for c in cam_parts:
				var gt: Transform3D = c[2]
				(c[0] as Node3D).get_parent().remove_child(c[0]); cam_holder.add_child(c[0]); (c[0] as Node3D).global_transform = gt
			cam_carry = true)
		tw.tween_property(rc, "w", 0.0, 0.4)
		tw.tween_callback(func():
			rc.queue_free()
			var back := NAT_CAM_ROUTE.duplicate(); back.reverse(); back.append([AT21.natsuki[0], AT21.natsuki[1], 0.0])
			main.walk_to("natsuki", back, func():
				# set down by the projector
				cam_carry = false
				var proj := Vector3.INF
				for mi in main.S.env_node.find_children("furn_proj*", "MeshInstance3D", true, false):
					var pb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
					proj = Vector3(pb.get_center().x + 0.32, pb.end.y, pb.get_center().z)
				# 試作176 A10（ユーザー「カメラが浮いている。机に置こうか」）: beside the projector it hung at the projector's top
				# height; it sits on the low table (furnish.py furn_ltable, top .40 m)
				for mi in main.S.env_node.find_children("furn_ltable*", "MeshInstance3D", true, false):
					if proj == Vector3.INF: continue
					var tb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
					proj.y = tb.end.y
					# 2026-11-28（ユーザー試作298 #19「カメラ、机の上に置こうかな」）: 0.32 m past the projector was over the table's edge.
					# On the top, a hand's width in from its edges
					proj.x = clampf(proj.x, tb.position.x + 0.1, tb.end.x - 0.1); proj.z = clampf(proj.z, tb.position.z + 0.1, tb.end.z - 0.1)
				if proj != Vector3.INF:
					var lo := INF
					for c in cam_parts: lo = minf(lo, ((c[0] as MeshInstance3D).global_transform * (c[0] as MeshInstance3D).get_aabb()).position.y)
					cam_holder.global_position += Vector3(proj.x - cam_holder.global_position.x, proj.y - lo, proj.z - cam_holder.global_position.z)
				Sound.one(self, "dial_tick", -12.0, cam_holder.global_position)
				main.set_stand("natsuki", LISTEN.natsuki, 0.3)
				_start(rest_q), _face(AT21.natsuki, FACE21))))

func _cam_tick():
	if not cam_carry or cam_holder == null: return
	var sk: Skeleton3D = main.S.natsuki_node.find_children("*", "Skeleton3D", true, false)[0]
	var hb := sk.find_bone("hand_r")
	if hb < 0: return
	var hand: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
	cam_holder.global_position = hand + Vector3(0, -0.05, 0)

func _cam_back():
	for c in cam_parts:
		if not is_instance_valid(c[0]): continue
		(c[0] as Node3D).get_parent().remove_child(c[0]); (c[1] as Node).add_child(c[0]); (c[0] as Node3D).global_transform = c[2]
	if cam_holder: cam_holder.queue_free(); cam_holder = null
	cam_parts = []

# the front door: it opens (1.0 s), stays open while she goes through, and shuts 0.6 s after she is gone
var out_gone := -1.0
func _out_tick(dt: float):
	out_t += dt
	if main.door_pivot == null: return
	var k := smoothstep(0.0, 1.0, out_t)
	if out_gone >= 0.0: k *= 1.0 - smoothstep(out_gone + 0.6, out_gone + 1.6, out_t)
	main.door_pivot.rotation.y = door_rest + deg_to_rad(80.0) * k
	if out_gone >= 0.0 and out_t > out_gone + 1.7: out_t = -1.0

# the unattended run: walk after her to the genkan
func _demo_walk(dt: float):
	if player.auto_path.size() > 0: return
	var to := gp(NAT_DOOR[0], NAT_DOOR[1] + 1.1, 0.0)
	var p: Vector3 = player.global_position
	var d := to - p
	player.auto_path = [[0.0, p.x, p.z, rad_to_deg(player.yaw), -6.0], [d.length() / 0.9 + 0.3, to.x, to.z, rad_to_deg(atan2(-d.x, -d.z)), -6.0]]
	player.auto_t = 0.0
