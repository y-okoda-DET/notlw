## ステップ E：仮の音（ユーザー決定 2026-11-10「仮の音はEでやります」。雨・ノック・ラジオ・テープ、と発電機・車・扉）。
## 音は godot/sound/ の物：雨・発電機・雷・足音・停電はユーザーが選んだ素材から切った物（cut_materials.py、2026-11-13）、
## ノック・ラジオの雑音はユーザーの収録（cut_recordings.py）、ほか（車、扉、テープ、ラジオの声）は数式で作った物（make_sounds.py）。
## 本番の音は段階4。良し悪しはユーザーが聞いて決める。
## main.gd が子として1つ作る。ほかのスクリプトには手を入れず、場面の状態を毎フレーム見て鳴らす：
##   雨　　：家の20時〜3時半（嵐）。窓越し（高い音は切り出しのときに落としてある）
##   雷　　：嵐のあいだ、ときどき1つ（35〜80秒おき）
##   発電機：地下の発電機の位置から（main.gen_on、第2章では綱を引く・咳・かかる＝story.gd の gen）。上の階では遠い唸り
##   停電　：第1章の明かりが落ちるとき、ブレーカーの「パチッ」
##   足音　：澪の一歩ごと（player.gd の step_phase）。靴下の小さい音、ときどききしむ。階段はきしむ音
##   ノック：玄関の扉が揺れたら（main.gd の knocks、ch0.gd の knock は扉を数ミリ動かす）1回ずつ
##   ラジオ：手に持って点いているとき。局に合うほど声、外れるほど雑音（story.gd _reception）
##   テープ：第11章のデッキ（tape.gd st）
## 場面だけの音（第0章の車、扉）は、その場面のスクリプトが Sound.one() で鳴らす。
extends Node

const DIR := "res://sound/%s.wav"
var main
var loops := {}            # name -> AudioStreamPlayer(3D)
var door_was := 0.0
var knock_cool := 0.0
var gen_was := true
var tape_was := -1
var thunder_t := 20.0
var storm := false
var lit_was := false
var step_was := 0
var y_was := 0.0
var steps_n := 0
var g_was := {}

static func stream(name: String, loop := false) -> AudioStream:
	var p := DIR % name
	if not ResourceLoader.exists(p): p = p.replace(".wav", ".ogg")
	if not ResourceLoader.exists(p): return null
	var s = load(p)
	if s is AudioStreamOggVorbis and loop: s = s.duplicate(); (s as AudioStreamOggVorbis).loop = true
	if s is AudioStreamWAV and loop:
		s = s.duplicate(); (s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(s as AudioStreamWAV).loop_end = int((s as AudioStreamWAV).get_length() * (s as AudioStreamWAV).mix_rate)
	return s

## one sound, once: at a place (Vector3) or everywhere (null)
static func one(parent: Node, name: String, db := 0.0, at = null) -> Node:
	var s := stream(name)
	if s == null: return null
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new(); p3.stream = s; p3.volume_db = db; p3.unit_size = 3.0; p3.max_db = 3.0
		parent.add_child(p3); p3.global_position = at; p = p3
	else:
		var p2 := AudioStreamPlayer.new(); p2.stream = s; p2.volume_db = db; parent.add_child(p2); p = p2
	p.call("play")
	p.connect("finished", p.queue_free)
	if not (name.begins_with("step") or name.begins_with("creak")): print("SOUND one %s %.1f" % [name, db])
	return p

func _loop(name: String, db: float, at = null) -> Node:
	if loops.has(name): return loops[name]
	var s := stream(name, true)
	if s == null: return null
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new(); p3.stream = s; p3.unit_size = 2.5; p3.max_db = 0.0
		add_child(p3); p3.global_position = at; p = p3
	else:
		p = AudioStreamPlayer.new(); (p as AudioStreamPlayer).stream = s; add_child(p)
	p.set("volume_db", db); p.call("play")
	print("SOUND loop %s %.1f" % [name, db])
	loops[name] = p
	return p

func _stop(name: String):
	if loops.has(name): loops[name].queue_free(); loops.erase(name)

func setup(m):
	main = m
	if "--nosound" in OS.get_cmdline_user_args(): set_process(false); return
	storm = main.SCENE == "night" or (main.SCENE == "house" and main.TIME in ["t20", "t23", "t02", "t0330"])
	if storm: _loop("rain", -10.0)
	gen_was = main.gen_on
	lit_was = _lit()
	if main.player: step_was = int(floor(main.player.step_phase)); y_was = main.player.global_position.y

# 第1章's lights (the key through the window, the lamps): the power cut puts them out (main.power_cut)
func _lit() -> bool:
	for k in ["fresnel_key", "lamp", "fres_d"]:
		if main.lights.has(k) and main.lights[k] is Light3D and (main.lights[k] as Light3D).visible: return true
	return false

# the engine runs: the house's circuit (main.gen_on) or, in 第2章 before the change-over, the engine itself
func _gen_running() -> bool:
	if main.gen_on: return true
	var st = main.story
	return st != null and is_instance_valid(st) and "gen" in st and bool(st.gen.get("run", false))

func _gen_at() -> Vector3:
	return Vector3(9.45 - 4.8, -2.0, 6.3 - 6.3)   # story.gd GEN_P, GEN_Y (plan) on the cellar floor, in Godot

func _process(dt):
	if main == null: return
	var pl = main.player
	# the generator, from the cellar; upstairs only its low hum comes through the floors
	if main.SCENE == "house" and main.TIME != "dusk":
		var st = main.story
		if st != null and is_instance_valid(st) and "gen" in st:   # 第2章: the cord, the cough, the catch
			var g: Dictionary = st.gen
			if int(g.get("fails", 0)) > int(g_was.get("fails", 0)): one(self, "gen_pull", -6.0, _gen_at())
			if int(g.get("fails_c", 0)) > int(g_was.get("fails_c", 0)): one(self, "gen_cough", -5.0, _gen_at())
			if bool(g.get("run", false)) and not bool(g_was.get("run", false)): one(self, "gen_start", -4.0, _gen_at())
			g_was = g.duplicate()
		var on := _gen_running()
		if on:
			var near := _loop("generator", -6.0, _gen_at())
			var far := _loop("generator_far", -60.0)
			if pl and near and far:
				var y: float = pl.global_position.y
				var cellar := y < -1.0
				near.set("volume_db", lerpf(near.get("volume_db"), -6.0 if cellar else -40.0, minf(1.0, dt * 3.0)))
				far.set("volume_db", lerpf(far.get("volume_db"), -60.0 if cellar else (-18.0 if y < 1.5 else -28.0), minf(1.0, dt * 3.0)))
		elif gen_was:
			_stop("generator"); _stop("generator_far"); one(self, "generator_stop", -5.0, _gen_at())
		gen_was = on
	# the power cut (第1章): the breaker
	var lit := _lit()
	if lit_was and not lit: one(self, "breaker", -4.0)
	lit_was = lit
	# thunder now and then while the storm lasts
	if storm:
		thunder_t -= dt
		if thunder_t <= 0.0:
			thunder_t = randf_range(35.0, 80.0)
			one(self, "thunder%d" % randi_range(1, 3), randf_range(-12.0, -5.0))
	# her steps (in socks: small), now and then a board that gives; the stairs creak
	if pl:
		var sp := int(floor(pl.step_phase))
		if sp != step_was:
			var y2: float = pl.global_position.y
			var feet: Vector3 = pl.global_position
			if absf(y2 - y_was) > 0.08: one(self, "stair%d" % randi_range(1, 2), -12.0, feet)
			else:
				steps_n += 1
				if main.SCENE == "house" and steps_n % 7 == 0: one(self, "creak%d" % randi_range(1, 4), -16.0, feet)
				else: one(self, "step%d" % randi_range(1, 10), -14.0, feet)
			y_was = y2
		step_was = sp
	# a knock: the front door jumps in its frame
	knock_cool = maxf(0.0, knock_cool - dt)
	if main.door_pivot and main.S.has("door_rest") and not main.has_meta("knock_by_scene"):
		var d: float = (main.door_pivot.position - main.S.door_rest).length()
		if d > 0.003 and door_was <= 0.003 and knock_cool <= 0.0:
			one(self, "knock1", -2.0, main.door_pivot.global_position); knock_cool = 0.25
		door_was = d
	# the radio in her hand
	var st = main.story
	if st != null and is_instance_valid(st) and "holding_radio" in st:
		if st.holding_radio and st.radio_on:
			var q: float = st._reception()[1]
			_loop("radio_static", -60.0); _loop("radio_voice", -60.0)
			loops.radio_static.volume_db = lerpf(-9.0, -32.0, clampf(q * 1.3, 0.0, 1.0))
			loops.radio_voice.volume_db = lerpf(-45.0, -7.0, clampf(q, 0.0, 1.0))
		else:
			_stop("radio_static"); _loop_stop_voice()
	# the deck (第11章)
	if st != null and is_instance_valid(st) and "st" in st and "tape_t" in st:
		var s: int = st.st
		if s != tape_was:
			if s == 1: one(self, "tape_clunk", -6.0); _loop("tape_hiss", -16.0)        # PLAYING
			elif tape_was == 1: _stop("tape_hiss"); one(self, "tape_clunk", -8.0)     # ENDED
			tape_was = s

func _loop_stop_voice():
	_stop("radio_voice")
