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
##   ラジオ：手に持って点いているとき。3局（音楽594・ニュース1017・外国語1350）、近いとこもって唸り、合うと雑音が引く。ダイヤルは回す速さで擦れて刻む（cut_radio.py）
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
var rain_in := -1.0
var lit_was := false
var step_was := 0
var y_was := 0.0
var steps_n := 0
var g_was := {}
# the three stations (2026-11-13): kHz and strength, as the recipe has them; the dB are where the mix sits in the game (仮)
const RADIO := {"music": [594.0, 0.75], "news": [1017.0, 0.85], "foreign": [1350.0, 0.6]}
const RADIO_DB := -4.0
const STEPS := false
const STATIC_DB := -11.0   # 2026-11-14（ユーザー「ノイズ、もう少しだけ抑える」）: -8 から -3dB
var best_s := 0.0
var khz_was := -1.0
var dial_v := 0.0
var dial_trav := 0.0

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
	if storm:
		var r := _loop("rain", -10.0)
		# 2026-11-14 第2章の20時は、停電の直後の「ひどい雨になっていました」と一緒に雨が大きくなる（ユーザー「雨の音が急に鳴る」）
		if r and main.get("ch2_house"): r.set("volume_db", -40.0); rain_in = 0.0
	gen_was = _gen_running()
	lit_was = _lit()
	if main.player: step_was = int(floor(main.player.step_phase)); y_was = main.player.global_position.y

# 第1章's lights (the key through the window, the lamps): the power cut puts them out (main.power_cut)
func _lit() -> bool:
	for k in ["fresnel_key", "lamp", "fres_d"]:
		if main.lights.has(k) and main.lights[k] is Light3D and (main.lights[k] as Light3D).visible: return true
	return false

# the engine runs: the house's circuit (main.gen_on) or, in 第2章 before the change-over, the engine itself
# 2026-11-13 (ユーザー「発電機の音がするのは発電機がついてから」): in 第2章 at 20:00 only the engine itself counts, not the circuit
func _gen_running() -> bool:
	var st = main.story
	if st != null and is_instance_valid(st) and "gen" in st and "house" in st and st.house: return bool(st.gen.get("run", false))
	return main.gen_on

# 2026-11-13 (ユーザー「局を合わせたあとも嵐の雑音が波のように何度もかぶる」、選局の通し_3局_v3_嵐の雑音_作り方.py): swells of the storm's
# static, 0.5-1.3 s long, 1-3.5 s apart, strength 0.5-1; the place names the bulletin loses are two of many of these
var sw_t := 0.5; var sw_d := 0.0; var sw_a := 0.0; var sw_in := -1.0
func _swell(dt: float) -> float:
	if sw_in >= 0.0:
		sw_in += dt
		if sw_in >= sw_d: sw_in = -1.0; sw_t = randf_range(1.0, 3.5)
		else: return sw_a * pow(sin(PI * sw_in / sw_d), 0.6)
		return 0.0
	sw_t -= dt
	if sw_t <= 0.0: sw_in = 0.0; sw_d = randf_range(0.5, 1.3); sw_a = randf_range(0.5, 1.0)
	return 0.0

func _gen_at() -> Vector3:
	return Vector3(9.45 - 4.8, -2.0, 6.3 - 6.3)   # story.gd GEN_P, GEN_Y (plan) on the cellar floor, in Godot

func _process(dt):
	if main == null: return
	if rain_in >= 0.0 and loops.has("rain"):
		rain_in += dt
		loops["rain"].set("volume_db", lerpf(-40.0, -10.0, clampf((rain_in - 1.0) / 4.0, 0.0, 1.0)))
		if rain_in > 5.0: rain_in = -1.0
	var pl = main.player
	# the generator, from the cellar; upstairs only its low hum comes through the floors
	if main.SCENE == "house" and main.TIME != "dusk":
		var st = main.story
		if st != null and is_instance_valid(st) and "gen" in st:   # 第2章: the cord, the cough, the catch
			var g: Dictionary = st.gen
			# the cord (ユーザー「小さい音2回、のあとに大きい音1回」): the pulls that do not catch are small, the one that catches is big
			if int(g.get("fails", 0)) > int(g_was.get("fails", 0)): one(self, "gen_pull", -18.0, _gen_at())
			if int(g.get("fails_c", 0)) > int(g_was.get("fails_c", 0)): one(self, "gen_cough", -15.0, _gen_at())
			if bool(g.get("run", false)) and not bool(g_was.get("run", false)): one(self, "gen_start", 0.0, _gen_at())
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
	# her steps (in socks: small), now and then a board that gives; the stairs creak. Off (ユーザー 2026-11-13「足音、大げさすぎる。ナシにしようかな」)
	if pl and STEPS:
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
	# the radio in her hand: as the recipe for the dial (/mnt/project-files/音/ラジオ加工_2026-11-13/選局の通し_トークなし_ダイヤル音つき_作り方.py):
	# near a station it hums, muffled; on it, it comes clear and the static draws back. The dial rustles and ticks as it turns.
	var st = main.story
	if st != null and is_instance_valid(st) and "holding_radio" in st:
		if st.holding_radio and st.radio_on:
			var f: float = st._khz()
			var best := 0.0
			var sw := _swell(dt)
			for k in RADIO:
				var off: float = f - float(RADIO[k][0])
				var g := exp(-pow(off / 4.5, 2.0))
				var amp: float = exp(-pow(off / 9.0, 2.0)) * float(RADIO[k][1]) * (1.0 + 0.25 * sin(TAU * 0.13 * Time.get_ticks_msec() / 1000.0 + float(RADIO[k][0])))
				var c := _loop("radio_" + k, -80.0); var m := _loop("radio_" + k + "_muf", -80.0)
				var duck := 1.0 - 0.55 * sw   # the storm's swell takes the station under for a moment
				if c: c.set("volume_db", maxf(-80.0, linear_to_db(maxf(amp * g * duck, 1e-4)) + RADIO_DB))
				if m: m.set("volume_db", maxf(-80.0, linear_to_db(maxf(amp * (1.0 - g) * duck, 1e-4)) + RADIO_DB))
				best = maxf(best, g * float(RADIO[k][1]))
			best_s = lerpf(best_s, best, minf(1.0, dt * 20.0))
			var nz := _loop("radio_static", -80.0)
			if nz: nz.set("volume_db", linear_to_db(maxf((0.9 - 0.55 * best_s) + 0.9 * sw * best_s, 1e-4)) + STATIC_DB)
			var cr := _loop("radio_crackle", -80.0)
			if cr: cr.set("volume_db", linear_to_db(maxf(0.3 + sw, 1e-4)) + STATIC_DB - 4.0)
			# the dial, in the room
			var v: float = absf(f - khz_was) / maxf(dt, 1e-3) if khz_was > 0.0 else 0.0
			dial_v = lerpf(dial_v, v, minf(1.0, dt * 30.0))
			var ru := _loop("dial_rustle", -80.0)
			if ru: ru.set("volume_db", maxf(-80.0, linear_to_db(maxf(clampf(dial_v / 40.0, 0.0, 1.5), 1e-4)) - 22.0))
			dial_trav += absf(f - khz_was) if khz_was > 0.0 else 0.0
			if dial_trav >= 3.0: dial_trav = fmod(dial_trav, 3.0); one(self, "dial_tick", randf_range(-22.0, -16.0))
			khz_was = f
		else:
			for k in RADIO: _stop("radio_" + k); _stop("radio_" + k + "_muf")
			_stop("radio_static"); _stop("radio_crackle"); _stop("dial_rustle"); khz_was = -1.0
	# the deck (第11章)
	if st != null and is_instance_valid(st) and "st" in st and "tape_t" in st:
		var s: int = st.st
		if s != tape_was:
			if s == 1: one(self, "tape_clunk", -6.0); _loop("tape_hiss", -19.0)        # PLAYING（2026-11-14 ユーザー「ノイズの音、少し抑える」：-16 から）
			elif tape_was == 1: _stop("tape_hiss"); one(self, "tape_clunk", -8.0)     # ENDED
			tape_was = s

