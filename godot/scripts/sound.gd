## ステップ E：仮の音（ユーザー決定 2026-11-10「仮の音はEでやります」。雨・ノック・ラジオ・テープ、と発電機・車・扉）。
## 音は godot/sound/make_sounds.py が数式で作った物（外の素材なし）。本番の音は段階4。良し悪しはユーザーが聞いて決める。
## main.gd が子として1つ作る。ほかのスクリプトには手を入れず、場面の状態を毎フレーム見て鳴らす：
##   雨　　：家の20時〜3時半（嵐）。家の中なので遠く、こもらせる
##   発電機：地下の発電機の位置から（main.gen_on）。止まる瞬間に止まる音
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

static func stream(name: String, loop := false) -> AudioStream:
	var p := DIR % name
	if not ResourceLoader.exists(p): return null
	var s = load(p)
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
	print("SOUND one %s %.1f" % [name, db])
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
	var storm: bool = main.SCENE == "night" or (main.SCENE == "house" and main.TIME in ["t20", "t23", "t02", "t0330"])
	if storm: _loop("rain", -13.0)
	gen_was = main.gen_on

func _gen_at() -> Vector3:
	return Vector3(9.45 - 4.8, -2.0, 6.3 - 6.3)   # story.gd GEN_P, GEN_Y (plan) on the cellar floor, in Godot

func _process(dt):
	if main == null: return
	# the generator, from the cellar
	if main.SCENE == "house" and main.TIME != "dusk":
		if main.gen_on: _loop("generator", -4.0, _gen_at())
		elif gen_was:
			_stop("generator"); one(self, "generator_stop", -4.0, _gen_at())
		gen_was = main.gen_on
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
