## ステップ F：第5章「地下」 4時（docs/資料/第5章の設計_2026-11-17.md）。台詞は story/ch5.txt。
## 家まるごとの3時半の光（main の t0330）で動く。main.gd が play="ch5" で作り、終わると次の章へ（第6章がまだ無いので第11章）。
##
## 四時：第4章の終わりのまま。廊下に夏希が倒れ、三脚が澪の足もとにある。澪は歩けない（見るだけ）。真琴が二階から下りて、
##   「……冷たい」。三脚を一度見て、「……風。どこから」。
## 勝手口：真琴について台所へ。裂けたテープ、低い所の血の手形。真琴が一つずつ数え直し、「ゾンビなんて、いない」。
##   そのあとで手形に手を重ねる。ろうそくを澪に渡し、「来ないで」と地下へ。
## 四時十分：澪はろうそくを持って一階を回り、0時半に貼ったテープを、どこからでもはがす（試作176。前は貼った順）。
##   はがすたびに風の音が戻り、炎が傾く。下からの音と声は、はがした数で進む（何もしないで90秒でも一段）。
##   勝手口・玄関・地下の扉は、近づけば Ｅ が出るが、澪はどれもしない。勝手口だけ、数える沈黙。
## 終わり：廊下。夏希の肩の毛布が、勝手口からの風で揺れる。章の問いが戻る。
extends "res://scripts/story.gd"
const Sound = preload("res://scripts/sound.gd")
const FPS = preload("res://scripts/fps.gd")

const F2 := 2.75
const ZBASE := -2.45
const NAT_AT := [4.75, 3.9]           # where she stood when the second blow came (fps.gd NPATH_GAME's end, a metre short of Mio on the kitchen side; 2026-11-17 夜: one place in every chapter)
const MIO_AT := [4.55, 3.0]           # Mio, as 第4章 leaves her (fps.gd MIO_AT)
const TRIPOD_AT := [4.24, 3.75]       # dropped at her feet (its feet; it lies south from here)
const MAKOTO_DOWN := [[5.0, 6.3, F2], [5.5, 5.7, F2], [5.5, 2.55, 0.0]]
# plan points of the house as 第3章 has them (ch3.gd GAPS): the tape over each, and what Mio calls the place
const GAPS := [
	{"key": "g1", "at": [2.6, 0.13, 1.45], "n": [0, 1], "name": "居間の窓", "snd": "ch3_gap1"},
	{"key": "g2", "at": [0.13, 6.2, 1.5], "n": [1, 0], "name": "食堂の窓", "snd": "ch3_gap2"},
	{"key": "g3", "at": [7.4, 7.87, 1.5], "n": [0, -1], "name": "台所の窓", "snd": "ch3_gap3"},
	{"key": "g4", "at": [9.87, 6.2, 1.55], "n": [-1, 0], "name": "換気口", "snd": "ch3_gap4"},
	{"key": "g5", "at": [9.96, 5.30, 1.0], "n": [-1, 0], "name": "勝手口", "snd": "ch3_gap5"},   # 試作127: on the latch side's seam, as 第3章 puts it
]
const FRONT_GAP := [5.0, 0.08, -0.1]
const FRONT_DOOR := [5.0, 0.03, 1.0]
const BACK_DOOR := [9.87, 4.88, 1.0]
const CELLAR_DOOR := [5.5, 5.62, 1.0]
const BACK_STAND := [9.25, 4.95]      # where Mio stops before the back door (the talk starts)
const MK_BACK := [9.4, 4.62]          # Makoto at the back door, on its hinge side, her light on it (Mio sees the latch side past her). 2026-11-17 夜（ユーザー「真琴が冷蔵庫にのめり込んでいる」）: y 4.3 was in the fridge (its front is at 4.325)
const MK_THINK := [8.6, 5.6]          # two steps in, where she puts it together
# the hand on the inside wall beside the back door's latch side, low: pushed, to get up off the threshold.
# (2026-11-17: it was on the hinge side's jamb, y 4.42, where the jamb's face runs along the light: it printed as black
# streaks. The door opens outward on hinges at y 4.40; its opening runs to y 5.25)
const HAND_AT := [9.865, 5.42, 0.45]
const MK_GEN := [8.45, 6.3]            # 試作176: Makoto at the generator in the cellar (its panel faces west at x 9.45)
const MK_HAND := [9.5, 5.85]          # where Makoto goes down on her knee to lay her hand on it (Mio at the door sees both)
const IDLE_STEP := 90.0               # nothing done for this long: the cellar goes on one step
# the cellar's steps, by the tapes peeled: 1 → 地下.一, 3 → 地下.三, 4 → 地下.四, 5 → 地下.五
# 試作276 の感想（点検1、ユーザー OK 2026-11-23）: she falls at the third board outside, always (地下.四 inside came at the fourth
# tape, and if the tapes went first her voice at the boards was never heard). The fall is in 外.板.三 now
const BELOW := [[1, "地下.一"], [3, "地下.三"], [5, "地下.五"]]

var stage := "card"     # card | t4 | follow | back | peel | done | end
var card: Control
var card_t := 0.0
var card_next := ""
var t_stage := 0.0
var hold := false              # a line waits for someone to get where they are going
var dn
var nat: Node3D
var nsk: Skeleton3D
var gaps := []                 # {key, at, n, name, player, peeled, tape, tape2}
var order: Array = []          # the order she put them on (第3章), and so takes them off
var peeled_n := 0
var candle: Node3D
var flame: Node3D
var candle_light: OmniLight3D
var gen_fore: AudioStreamPlayer
var gen_db := -40.0
var gen_want := -40.0
var below_i := 0               # the next of BELOW to sound
var below_q: Array = []        # [[t, entry]] the timed lines from below
var below_t := 0.0
var idle_t := 0.0
var said := {}
var silence_t := -1.0
var silence_lb: Label
var silence_len := 9.0
var blanket: MeshInstance3D
var lantern: OmniLight3D
var wind_in := {}              # gap key -> fading in (s)
var tripod: Node3D
var page_clear_t := -1.0
var end_wait := -1.0
var look_k := ""
var demo5 := false
# 2026-11-22（筋のスレッド、人物表・決定事項 5時8分）: by the kitchen window's board, the player is the one who sees it
var wb_t := -1.0               # >= 0: waiting for her to look at the board (＞wait_board)
var wb_at := Vector3.ZERO
var wb_gen0 := -40.0
var wb_done := false
var mk_palm: Node = null       # Makoto's hand on the board (reach.gd)
var demo_hold := false
var stair_t := -1.0
var demo_steps: Array = []
var ds := 0
var dwait := 0.0
var start_at := "t4"

func _ready():
	player = main.player
	if not ("--keepflags" in OS.get_cmdline_user_args()):
		for fk in ["went_out", "went_out_4am", "hands_cut"]: if get_flag(fk, null) != null: set_flag(fk, null)   # 2026-11-21 (review): this chapter played again keeps none of its last run
	font = Type.say()
	u = get_viewport().get_visible_rect().size.y / 1080.0
	offscreen = ["真琴（下から）"]
	FPS.load_story("ch5")
	_page()
	for k in ["kiryu", "taiga", "natsuki", "mio", "yota"]: _hide(k)
	_natsuki()
	_borrow_clips()
	_lookers()
	_makoto_look()
	main.phones(false)
	main.TALK = {}
	_tripod()
	_lantern()
	_gaps()
	_candle()
	_gen_fore()
	call_deferred("_doors")
	demo5 = "--demo" in OS.get_cmdline_user_args() or DEMO_HOUSE
	demo_on = demo5
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ch5at="): start_at = a.substr(8)   # check stills and a part's playthrough: t4 | back | peel | end
	var c: Array = D.lines("五.カード")
	card = main.make_card(self, [[c[0], 46, 40], [c[1], 150, 90], [c[2], 36, 0]], Type.card())
	card_t = 2.75; card_next = "t4card"
	if start_at != "t4": card_t = 0.3; card_next = start_at
	_place_for(start_at)
	print("STORY ch5 start=", start_at, " order=", ",".join(order))

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

func _looking_at(p: Vector3, reach: float, deg: float) -> bool:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := p - cam.global_position
	return _aim_ok(to, reach, deg)   # 試作281 (story.gd)

var fall_mio := Vector3.INF
# after 第4章: Mio a step back from where she stood, looking at her (once she is laid: _natsuki awaits a frame)
func _from_fall():
	for i in 3: await get_tree().process_frame
	if fall_mio == Vector3.INF: return
	player.global_position = Vector3(fall_mio.x, 0.0, fall_mio.z); player.velocity = Vector3.ZERO
	print("CH5 mio from the fall %s" % [_plan_of(player)])
	var c := _nat_chest(); var a := [fall_mio.x + 4.8, fall_mio.z + 6.3]
	_look_from(a, [c.x + 4.8, c.z + 6.3], 1.52, 0.2)

func _place_for(st: String):
	_hide("makoto")
	match st:
		"t4":
			# a step back from where she stood: she has backed off from her (and not looked away)
			player.global_position = gp(4.8, 3.55, 0.0)
			_look_from([4.8, 3.55], [4.45, 2.2], 1.52, 0.2)
			if not FPS.LAST_FALL.is_empty(): _from_fall.call_deferred()
		"back":
			player.global_position = gp(8.3, 5.2, 0.0)
			_look_from([8.3, 5.2], BACK_STAND)
			_put("makoto", [8.9, 5.5], _face([8.9, 5.5], MK_BACK)); main.set_stand("makoto", "talk/idle", 0.0)
			main.phones(true, ["makoto"])
		"peel", "end":
			player.global_position = gp(MK_THINK[0] + 0.3, MK_THINK[1] - 0.5, 0.0)
			_look_from([MK_THINK[0] + 0.3, MK_THINK[1] - 0.5], [7.4, 7.6])
			_blanket_on()
			_gen_loud()
			_put("makoto", MK_GEN, _face(MK_GEN, [9.45, 6.3]), ZBASE); main.set_stand("makoto", _kneel_anim(), 0.0)
			main.phones(true, ["makoto"])
			if st == "end":
				for gq in gaps: _peel(gq, true)
				below_i = BELOW.size()

# the doors as the night left them: the back door ajar (she came in by it), its "locked" gone; the cellar's top door shut
func _doors():
	await get_tree().physics_frame; await get_tree().physics_frame
	dn = main.get_node_or_null("Doors")
	if not dn: return
	for k in dn.doors.keys():
		var s: Dictionary = dn.doors[k]
		if s.key == "door_back": s.locked = ""
		if s.key == "door_barred": s.locked = "開かない。"
	dn.open_key("door_kitchen")
	dn.open_key("door_back")
	for k in dn.doors.keys():
		var s: Dictionary = dn.doors[k]
		if s.key == "door_back": (s.pivot as Node3D).rotation.y = lerpf(float(s.rest), float(s.open), 0.28)   # ajar: a hand's width more than a person
		if s.key == "door_back":
			var bb := AABB(); var f := true
			for mi in (s.pivot as Node3D).find_children("*", "MeshInstance3D", true, false):
				var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb(); bb = a if f else bb.merge(a); f = false
			print("CH5 door_back pivot %s rest %.2f open %.2f leaf %s" % [_plan_of(s.pivot), float(s.rest), float(s.open), bb])
		if s.key == "door_cellar" and s.is_open: dn.toggle(k)
	if start_at in ["peel", "end"] and not _sixth():   # (checking from the tape: Makoto is already down)
		_cellar_ajar(); _cellar_lock("……先に、テープ。" if start_at == "peel" else "下りませんでした。真琴ちゃんが、来ないでって。")
	# 試作127（ユーザー「一度勝手口から外に出て…家の中に戻れなくなった」）: the door stands ajar, but she never goes out (rule 1):
	# an unseen wall in the doorway. The door's look and 「［Ｅ　外に出る］」→ the silence stay as they were (they go by where she looks)
	# 2026-11-20: until she goes out (_go_out takes it away and opens the door all the way)
	var sb := StaticBody3D.new(); back_wall = sb; sb.name = "back_doorway"; var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
	bx.size = Vector3(0.30, 2.2, 0.95); cs.shape = bx; sb.add_child(cs); main.add_child(sb)
	sb.global_position = gp(10.0, 4.83, 1.1)
	if start_at in ["peel", "end"]: get_tree().create_timer(0.8).timeout.connect(_cellar_ajar)

# Makoto had only her two talk clips (main.gd TALK_CLIPS): until the house is written with her own kneel and stand, the
# crouch is Taiga's (the cellar window, 20時), the plain stand Natsuki's. The bones are the same rig's; the clips turn them only, so they sit on her
func _borrow_clips():
	if not main.S.has("makoto_node"): return
	for ap in main.S.makoto_node.find_children("*", "AnimationPlayer", true, false):
		if not (ap as AnimationPlayer).has_animation_library("talk"): continue
		var lib: AnimationLibrary = (ap as AnimationPlayer).get_animation_library("talk")
		# 2026-11-17: her own kneel (Mixamo Kneel, export_talk.py kneel / kneel_up) and stand, once the house is written with them.
		# The kneel goes down and stays down: it does not loop
		for nm in ["kneel", "kneel_up"]:
			if lib.has_animation(nm): lib.get_animation(nm).loop_mode = Animation.LOOP_NONE
		for c in [["taiga", "crouch"], ["natsuki", "idle"]]:
			var tp := "res://assets/dusk/%s_talk.res" % c[0]
			if lib.has_animation(c[1]) or (c[1] == "crouch" and lib.has_animation("kneel")) or not ResourceLoader.exists(tp): continue
			var src: AnimationLibrary = load(tp)
			if src.has_animation(c[1]):
				var an: Animation = src.get_animation(c[1]).duplicate()
				for ti in range(an.get_track_count() - 1, -1, -1):   # the hips' place is his: keep her own
					if an.track_get_type(ti) == Animation.TYPE_POSITION_3D and not String(an.track_get_path(ti)).ends_with("pelvis"): an.remove_track(ti)
				# the tracks name his skeleton's path: put hers in their place
				var own: Animation = lib.get_animation(lib.get_animation_list()[0])
				var mine := String(own.track_get_path(0)).get_slice(":", 0)
				for ti in an.get_track_count():
					var tp2 := String(an.track_get_path(ti))
					an.track_set_path(ti, NodePath(mine + ":" + tp2.get_slice(":", 1)))
				lib.add_animation(c[1], an)
				print("CH5 borrowed %s/%s %s -> %s" % [c[0], c[1], String(src.get_animation(c[1]).track_get_path(0)), mine])

# she left the cellar's top door standing a little open behind her (wide, it lies across the way to the kitchen)
# 試作176 A18（ユーザー「テープを剥がす前に、地下であれこれあるとプレイヤーは地下に向かいたくなる。いけないようにすればいいか」）:
# once Makoto has gone down, the cellar door does not open for Mio: first the tape, and after it she does not go down
# 試作176 A17（ユーザー「真琴の顔の歪み、これ」、第5章の勝手口）: she has no reflector here, and turned to Mio by 60° in three
# bones (spine 40%, neck 25%, head 35%): 21° in the head over the neck's 15° twisted her jaw and cheek. The turn is spread
# down four bones, the head's share the least, and stops at 45° (the eyes do the rest)
func _makoto_look():
	if not looks.has("makoto"): return
	var lm: Look = looks.makoto
	lm.props = []; lm.carry = -1
	lm.chain = [["spine_02", 0.3], ["spine_03", 0.3], ["neck_01", 0.25], ["head", 0.15]]; lm.max_yaw = 0.8
	var sk: Skeleton3D = lm.get_skeleton()
	var fwd := sk.global_basis * Vector3(0, 0, 1); fwd.y = 0.0
	lm.setup(fwd.normalized())

func _sixth() -> bool: return false   # ch6.gd rides on this stage: its doors are its own

func _cellar_lock(say: String):
	if not dn: return
	for k in dn.doors.keys():
		if dn.doors[k].key == "door_cellar": dn.doors[k].locked = say

func _cellar_ajar():
	if not dn: return
	for k in dn.doors.keys():
		var s: Dictionary = dn.doors[k]
		if s.key != "door_cellar": continue
		s.is_open = true
		create_tween().tween_property(s.pivot, "rotation:y", lerpf(float(s.rest), float(s.open), 0.12), 0.8).set_trans(Tween.TRANS_SINE)

# Natsuki where she fell (第4章's second blow, at its end: on her knees and then forward, a little onto her right side)
func _natsuki():
	main._load_scene("res://assets/natsuki.glb", "natsuki")
	nat = main.S.natsuki_node
	main._faces()
	main._walk_anims("natsuki", nat)
	nsk = nat.find_children("*", "Skeleton3D", true, false)[0]
	var nrig := nsk.get_parent() as Node3D
	var nap: AnimationPlayer = nat.find_children("*", "AnimationPlayer", true, false)[0]
	for ba in nsk.find_children("nphone*", "BoneAttachment3D", true, false): (ba as Node3D).visible = false
	nap.play("walk/walk"); nap.seek(0.35, true); nap.pause()
	await get_tree().process_frame
	nap.stop(false)
	# fps.gd _pose with the night's numbers: the first blow's reel at 1.2 s (when the second came), the fall at its end
	var rec := 0.569; var kn := 0.38 * rec
	var reel := {"head": [0.30 * rec, 0.0, 0.42 * rec], "neck_01": [0.20 * rec, 0.0, 0.26 * rec], "spine_03": [0.20 * rec, 0.0, 0.12], "spine_02": [0.14 * rec, 0.0, 0.08],
		"spine_01": [0.08, 0.0, 0.0], "thigh_l": [-kn, 0.0, 0.0], "calf_l": [2.0 * kn, 0.0, 0.0], "foot_l": [-kn, 0.0, 0.0],
		"thigh_r": [-kn * 0.8, 0.0, 0.0], "calf_r": [1.6 * kn, 0.0, 0.0], "foot_r": [-kn * 0.8, 0.0, 0.0], "upperarm_r": [0.0, 0.0, -0.22]}
	var down := {"head": [-0.25, -0.75, 0.0], "neck_01": [0.0, -0.3, 0.0], "spine_03": [-0.06, 0.0, 0.10], "spine_02": [0.0, 0.0, 0.06], "spine_01": [0.0, 0.0, 0.0],
		"thigh_l": [-0.05, 0.0, 0.0], "calf_l": [0.65, 0.0, 0.0], "foot_l": [0.7, 0.0, 0.0], "thigh_r": [0.07, 0.0, 0.0], "calf_r": [0.9, 0.0, 0.0], "foot_r": [0.7, 0.0, 0.0],
		"upperarm_l": [-0.75, 0.0, 0.25], "lowerarm_l": [-0.3, 0.0, 0.0], "upperarm_r": [0.2, 0.0, -0.30], "lowerarm_r": [-0.35, 0.0, 0.0]}
	var pose0 := {}
	for i in nsk.get_bone_count():
		var par := nsk.get_bone_parent(i)
		pose0[nsk.get_bone_name(i)] = [nsk.get_bone_pose_rotation(i), nsk.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()]
	for nm in pose0:
		if not (down.has(nm) or reel.has(nm)): continue
		var e: Array = down.get(nm, [0.0, 0.0, 0.0]).duplicate()
		if reel.has(nm): e = [e[0] + reel[nm][0] * 0.4, e[1] + reel[nm][1] * 0.4, e[2] + reel[nm][2] * 0.4]
		var bi := nsk.find_bone(nm)
		var pg: Basis = pose0[nm][1]
		var r := Basis(Vector3.UP, e[1]) * Basis(Vector3.BACK, e[2]) * Basis(Vector3.RIGHT, e[0])
		nsk.set_bone_pose_rotation(bi, (pg.inverse() * r * pg).get_rotation_quaternion() * (pose0[nm][0] as Quaternion))
	var b0 := Basis(Vector3.UP, PI)   # facing Mio, toward the door (she came down the hall from the kitchen)
	var base := gp(NAT_AT[0], NAT_AT[1], 0.0)
	var thk := 0.05 + kn * 0.4; var cfk := 0.65 + 2.0 * kn * 0.4
	var feet := base + b0 * Vector3(0, 0, -1) * 0.24 + b0 * Vector3(-1, 0, 0) * 0.10
	var rb := b0 * Basis(Vector3.BACK, 0.26) * Basis(Vector3.RIGHT, 1.43)
	var knee_l := Vector3(0.0, 0.74 - 0.33 * cos(thk), 0.33 * sin(thk))
	var knee_w := feet + b0 * Vector3(0.0, 0.0, 0.33 * sin(0.45)) + Vector3(0, 0.045, 0)
	nrig.global_transform = Transform3D(rb, knee_w - rb * knee_l)
	# 試作127（ユーザー「倒れ込む場所、倒れた場所と揃える」）: after 第4章 she lies where and as she came to rest there
	if not FPS.LAST_FALL.is_empty():
		var rot: Dictionary = FPS.LAST_FALL.rot
		for nm in rot:
			var bi := nsk.find_bone(nm)
			if bi >= 0: nsk.set_bone_pose_rotation(bi, rot[nm])
		nrig.global_transform = FPS.LAST_FALL.xf
		var mio: Vector3 = FPS.LAST_FALL.mio
		var away := Vector3(mio.x - nrig.global_position.x, 0.0, mio.z - nrig.global_position.z)
		if away.length() > 0.01: mio += away.normalized() * 0.55   # a step back from her (as _place_for "t4")
		fall_mio = mio
	# 試作127（ユーザー「このめり込み、どうにかしたいな」）: nothing of her under the boards
	nrig.global_position.y += FPS.floor_lift(nsk, 0.0)
	for mi in nat.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).extra_cull_margin = 3.0
	nat.visible = true
	print("CH5 natsuki head %s chest %s rig %s" % [_nat_head(), _nat_chest(), nrig.global_position])
	if main.S.has("natsuki_col"): (main.S.natsuki_col as Node3D).global_position = Vector3(0, -50, 0)
	# the wound: fps.gd's own overlay, carried once (she does not move again)
	var sh := Shader.new(); sh.code = FPS.BLOOD_SHADER
	for mi in nat.find_children("natsuki_*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new(); m.shader = sh
		var is_head := String(mi.name).contains("head")
		m.set_shader_parameter("part", 0 if is_head else 1)
		m.set_shader_parameter("dbg", 0.0)
		(mi as MeshInstance3D).material_overlay = m
		var bi2 := nsk.find_bone("head" if is_head else "spine_03")
		var carry: Transform3D = nsk.global_transform * nsk.get_bone_global_pose(bi2) * nsk.get_bone_global_rest(bi2).affine_inverse()
		m.set_shader_parameter("inv", Projection(carry.affine_inverse()))
	# what has run from her head in half an hour, dark on the boards
	var hp := _nat_head()
	var pool := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.17; cm.bottom_radius = 0.17; cm.height = 0.002; cm.radial_segments = 20; cm.rings = 1
	pool.mesh = cm
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.16, 0.006, 0.006); pm.roughness = 0.1; pm.metallic_specular = 0.8
	pool.material_override = pm; pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; pool.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(pool); pool.global_position = Vector3(hp.x + 0.05, 0.003, hp.z); pool.scale = Vector3(1.0, 1.0, 1.35)
	_nat_heights()   # what the blanket will lie over (once: she does not move again)
	nat_ready = true
	if want_blanket: _blanket_on()

func _nat_head() -> Vector3:
	var bi := nsk.find_bone("head")
	return nsk.global_transform * nsk.get_bone_global_pose(bi).origin

func _nat_chest() -> Vector3:
	var bi := nsk.find_bone("spine_03")
	return nsk.global_transform * nsk.get_bone_global_pose(bi).origin

# the tripod, where it fell from her hands
func _tripod():
	var parts: Array = []
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.begins_with("vcam_") or nm == "lcd" or nm.begins_with("lcd_") or nm.begins_with("recled"): (mi as Node3D).visible = false; continue
		if nm.begins_with("tpd_"): parts.append(mi)
	if parts.is_empty(): return
	var bb := AABB(); var first := true
	for mi in parts:
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		bb = a if first else bb.merge(a); first = false
	tripod = Node3D.new(); tripod.name = "tripod5"; main.add_child(tripod)
	tripod.global_position = Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	for mi in parts:
		var gt: Transform3D = (mi as Node3D).global_transform
		mi.get_parent().remove_child(mi); tripod.add_child(mi); (mi as Node3D).global_transform = gt
		(mi as MeshInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		(mi as MeshInstance3D).extra_cull_margin = 2.0
	if main.lights.has("rec_light"): (main.lights.rec_light as Light3D).visible = false
	# the three leg locks came out of the house's file 1.5 m above the head (seen in 第6章, where she holds it up: three
	# small things in the air, and the tripod measured 2.28 m for 1.44). Each back on its collar, on the outside
	var cols: Array = []
	for mi in parts:
		if String(mi.name).begins_with("tpd_collar"): cols.append(mi)
	for mi in parts:
		if not String(mi.name).begins_with("tpd_lock") or cols.is_empty(): continue
		var lc: Vector3 = ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).get_center()
		var best: Vector3 = lc
		for c in cols:   # tpd_lock_001 is tpd_collar_001's (where they came out, the nearest collar was the same one for all three)
			if String(c.name).trim_prefix("tpd_collar") == String(mi.name).trim_prefix("tpd_lock"):
				best = ((c as MeshInstance3D).global_transform * (c as MeshInstance3D).get_aabb()).get_center()
		var out := Vector3(best.x - tripod.global_position.x, 0.0, best.z - tripod.global_position.z).normalized()
		(mi as Node3D).global_position += best + out * 0.018 - lc
	# on its side on the boards, its head toward her
	# on the boards where it fell from her hands: its feet by hers, its head toward Natsuki's, along the hall's west side
	tripod.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(8.0)) * Basis(Vector3.RIGHT, deg_to_rad(-87.0)), gp(TRIPOD_AT[0], TRIPOD_AT[1], 0.06))
	print("CH5 tripod bb %s h %.2f up %s parts %d" % [bb, bb.size.y, tripod.global_basis.y, parts.size()])
	# the crew's light on its stand in the middle of the hall (C-stand, since 23時): it went over when she fell against
	# it (第4章). Down, out of the way: a pole straight up in front of every picture of her
	var cs := Vector2.INF
	for mi in main.S.env_node.find_children("cscol*", "MeshInstance3D", true, false):
		var c0: Vector3 = ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).get_center()
		if c0.x + 4.8 > 4.0 and c0.x + 4.8 < 5.4 and c0.z + 6.3 > 2.5 and c0.z + 6.3 < 4.2: cs = Vector2(c0.x, c0.z)
	if cs != Vector2.INF:
		for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
			var bb3: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			var c3 := bb3.get_center()
			if Vector2(c3.x, c3.z).distance_to(cs) < 0.5 and bb3.size.x < 0.9 and bb3.size.z < 0.9 and c3.y > -0.2 and c3.y < 2.4 and not String(mi.name).begins_with("door") and not String(mi.name).begins_with("stair") and not String(mi.name).begins_with("wall"):
				(mi as Node3D).visible = false; print("CH5 stand down ", mi.name)
		for k in main.lights:
			var l = main.lights[k]
			if l is Light3D and Vector2((l as Node3D).global_position.x, (l as Node3D).global_position.z).distance_to(cs) < 0.6: print("CH5 stand light ", k)

# the crew's lantern under the handrail camera, as 第4章 hung it (fps.gd _lantern)
func _lantern():
	var src: Light3D = main.lights.get("lantern_stair")
	# 試作176 A20（ユーザー「ランタンが浮いている」、第6章の二階）: the house of 4:30 has no lantern_stair light; from was the origin,
	# and the copy went up by the whole of "to", into the room over the genkan. Where the plans put it (times.py CREW, the light's place)
	var from := gp(5.75, 4.56, 2.05)
	if src: from = src.global_position
	var to := gp(FPS.LANTERN_AT[0], FPS.LANTERN_AT[1], FPS.LANTERN_AT[2] + 0.154)
	for mi in main.S.env_node.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if not (nm.begins_with("crew_lantern_stair") or nm.begins_with("lampshade_lantern_stair")): continue
		var c := mi.duplicate() as MeshInstance3D
		c.name = "d_" + nm; mi.get_parent().add_child(c)
		c.global_transform = (mi as MeshInstance3D).global_transform.translated(to - from)
		(mi as MeshInstance3D).visible = false   # one lantern: she moved it
		c.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lantern = OmniLight3D.new(); lantern.light_color = Color(1.0, 0.74, 0.50); lantern.light_energy = 0.30
	lantern.omni_range = 5.0; lantern.omni_attenuation = 1.3; lantern.shadow_enabled = true
	lantern.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID; lantern.shadow_blur = 2.0
	lantern.light_volumetric_fog_energy = 0.2; lantern.light_specular = 0.2
	main.add_child(lantern); lantern.global_position = to

# ---------------------------------------------------------------- the tape, still on (0時半), and the wind behind it
func _gaps():
	var c3 = load("res://scripts/ch3.gd")
	order = (c3.SEAL_ORDER as Array).duplicate() if c3 and not (c3.SEAL_ORDER as Array).is_empty() else ["g1", "g2", "g3", "g4", "g5"]
	var front := AudioStreamPlayer3D.new(); front.stream = Sound.stream("ch3_gapfront", true); front.unit_size = 1.6; front.max_db = 0.0
	front.volume_db = -8.0; add_child(front); front.global_position = gp(FRONT_GAP[0], FRONT_GAP[1], FRONT_GAP[2] + 0.1)
	if front.stream: front.play()
	for gd in GAPS:
		var p := AudioStreamPlayer3D.new(); p.stream = Sound.stream(gd.snd, true); p.unit_size = 1.4; p.max_db = 0.0
		p.volume_db = -60.0; p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p); p.global_position = gp(gd.at[0], gd.at[1], gd.at[2])
		var gq := {"key": gd.key, "at": gp(gd.at[0], gd.at[1], gd.at[2]), "n": gd.n, "name": gd.name, "player": p, "peeled": false, "tape": null, "tape2": null}
		_tape(gq)
		gaps.append(gq)
		if gd.key == "g5":   # torn from outside: the storm is in at the back door already
			p.volume_db = -3.0
			if p.stream: p.play(randf() * 4.0)

func _tape_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.62, 0.62, 0.6); m.roughness = 0.55; m.metallic = 0.1
	return m

func _tape(gq: Dictionary):
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new()
	var along_x: bool = gq.n[0] == 0
	bm.size = Vector3(0.34 if along_x else 0.004, 0.05, 0.004 if along_x else 0.34)
	var off := Vector3(gq.n[0] * 0.006, 0.0, gq.n[1] * 0.006)
	if gq.key == "g5":
		# 試作127（ユーザー「テープも手形も変。どうにかする。手形はなしでもいいんじゃない？」、B8 手形はなし、テープは作り直す）:
		# 0時半 it ran down the seam on the latch side (第3章: on the leaf's face and on the jamb, 1.86 m). The door was pushed
		# in from outside: the leaf's strip tore across at the height of a hand. The top stays on, its lower end ragged; the
		# rest hangs from the jamb's strip, peeled off the leaf and curled out into the room. No hand
		var m := _tape_mat()
		mi.mesh = bm; bm.size = Vector3(0.003, 0.80, 0.065); mi.material_override = m; mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; add_child(mi)
		mi.global_position = gp(9.977, 5.318, 1.50)
		for k in 4:   # the torn edge: four short tongues of different lengths
			var tg := MeshInstance3D.new(); var tb := BoxMesh.new(); tb.size = Vector3(0.003, [0.05, 0.022, 0.07, 0.035][k], 0.016); tg.mesh = tb
			tg.material_override = m; tg.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; mi.add_child(tg)
			tg.position = Vector3(0, -0.40 - float(tb.size.y) * 0.5, -0.024 + 0.016 * k)
		var jamb := MeshInstance3D.new(); var jb := BoxMesh.new(); jb.size = Vector3(0.05, 1.86, 0.003); jamb.mesh = jb
		jamb.material_override = m; jamb.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; add_child(jamb)
		jamb.global_position = gp(9.958, 5.348, 0.97)
		var lo := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(0.003, 0.62, 0.06); lo.mesh = lb
		lo.material_override = m; lo.gi_mode = GeometryInstance3D.GI_MODE_DISABLED; add_child(lo)
		# hinged at the jamb's edge 1.0 m up, turned out into the kitchen (about the vertical) and sagging
		lo.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-55.0)) * Basis(Vector3.RIGHT, deg_to_rad(12.0)), gp(9.90, 5.33, 0.66))
		gq.tape2 = jamb
		gq.tape = mi
		gq["tape3"] = lo
		return
	mi.mesh = bm; mi.material_override = _tape_mat(); mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	mi.global_position = gq.at + off
	mi.rotation.z = randf_range(-0.06, 0.06)
	gq.tape = mi

# the hand on the back door's frame, low, from outside: a palm and fingers pressed flat to push up off the step.
# Drawn here (no new picture file).
# 2026-11-17（ユーザー「低い所の血の手形が読みにくい」）: the first one was a blot the size of a fist on the hinge side, behind
# the jamb's edge. Now a hand's outline a hand's size (palm, four fingers apart, the thumb out to the side) on the wall by the
# latch side, in the torch. Dark (dried blood): the night print makes a dark surface blue whatever its hue, and the torch makes
# the wall around it paper, so it prints as a blue hand on white. (Under the torch even a dark red, 0.26, came out light enough to go to paper
# with the wall: tried, 試作150. Nearly black, as old blood is in a strong light)
# Below it, where the hand slid as it pushed, three drags.
const HAND_PX := 256
func _hand_img() -> Image:
	var img := Image.create(HAND_PX, HAND_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new(); rng.seed = 405
	var cov := PackedFloat32Array(); cov.resize(HAND_PX * HAND_PX)   # how much blood: 0..1
	var put := func(x: int, y: int, v: float):
		if x < 0 or y < 0 or x >= HAND_PX or y >= HAND_PX: return
		cov[y * HAND_PX + x] = maxf(cov[y * HAND_PX + x], v)
	# a capsule from a to b, radius r (a finger, the thumb)
	var caps := func(ax: float, ay: float, bx: float, by: float, r: float):
		var a2 := Vector2(ax, ay); var b2 := Vector2(bx, by)
		for y in range(int(minf(ay, by) - r) - 1, int(maxf(ay, by) + r) + 2):
			for x in range(int(minf(ax, bx) - r) - 1, int(maxf(ax, bx) + r) + 2):
				var p := Vector2(x, y); var ab := b2 - a2
				var t := clampf((p - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var d := p.distance_to(a2 + ab * t) / r
				if d < 1.0: put.call(x, y, 1.0 - d * d * 0.3)
	# the palm: a rounded block, wider at the knuckles (y up the picture is up the wall)
	for y in range(118, 210):
		var f := float(y - 118) / 92.0
		var half := lerpf(46.0, 36.0, f * f)
		for x in range(int(128 - half), int(128 + half)):
			var edge := minf(absf(x - 128) / half, 1.0)
			put.call(x, y, 1.0 - 0.3 * edge * edge)
	caps.call(92.0, 120.0, 70.0, 40.0, 10.0)     # little finger, apart
	caps.call(112.0, 116.0, 104.0, 22.0, 11.0)   # ring
	caps.call(134.0, 116.0, 138.0, 14.0, 11.5)   # middle
	caps.call(156.0, 120.0, 172.0, 30.0, 11.0)   # index
	caps.call(166.0, 186.0, 214.0, 132.0, 13.0)  # the thumb, out to the side
	for i in 3:   # where it slid down as she pushed up
		var x0 := 104.0 + i * 22.0 + rng.randf_range(-3, 3)
		caps.call(x0, 205.0, x0 + rng.randf_range(-4, 4), 236.0 + rng.randf_range(0, 14), 4.0 - i * 0.6)
	# what a hand leaves: skin lines and gaps where it did not touch, heavier at the rim where it dried
	for y in HAND_PX:
		for x in HAND_PX:
			var v: float = cov[y * HAND_PX + x]
			if v <= 0.0: continue
			var n := 0
			for o in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(0, 3)]:
				var xx: int = x + o.x; var yy: int = y + o.y
				if xx < 0 or yy < 0 or xx >= HAND_PX or yy >= HAND_PX or cov[yy * HAND_PX + xx] <= 0.0: n += 1
			var rim := n > 0
			# few gaps: a hand full of blood leaves a solid print (with more, the print read it as a grey outline)
			var gap := rng.randf() < (0.03 if rim else 0.05)
			if gap: continue
			var c := Color(0.035, 0.004, 0.003, 1.0) if rim else Color(0.06, 0.006, 0.004, 1.0)
			img.set_pixel(x, y, c)
	return img

func _hand():
	var tex := ImageTexture.create_from_image(_hand_img())
	var dc := Decal.new(); dc.texture_albedo = tex; dc.size = Vector3(0.22, 0.4, 0.26)
	dc.albedo_mix = 1.0; dc.cull_mask = 1; dc.upper_fade = 0.05; dc.lower_fade = 0.05
	dc.normal_fade = 0.5   # the wall's face only, not the jamb's side running along it
	add_child(dc)
	dc.global_position = gp(HAND_AT[0], HAND_AT[1], HAND_AT[2])
	# projects along its -Y into the jamb (plan +x); the picture's up is the wall's up
	dc.global_basis = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)).orthonormalized()

func _peel(gq: Dictionary, quiet := false):
	if gq.peeled: return
	gq.peeled = true
	if gq.key != "g5":
		if is_instance_valid(gq.tape): (gq.tape as Node3D).queue_free()
		var p: AudioStreamPlayer3D = gq.player
		if p.stream: p.play(randf() * 4.0)
		if quiet: p.volume_db = -6.0
		else: wind_in[gq.key] = 0.0; Sound.one(self, "tape_rip", -3.0, gq.at)   # 試作127: peeled off (kai_audio duct-tape-rip)

func _wind_tick(dt: float):
	for k in wind_in.keys():
		wind_in[k] += dt
		for gq in gaps:
			if gq.key == k: (gq.player as AudioStreamPlayer3D).volume_db = lerpf(-40.0, -6.0, clampf(wind_in[k] / 1.4, 0.0, 1.0))
		if wind_in[k] > 1.5: wind_in.erase(k)

# ---------------------------------------------------------------- the candle (Makoto lights it, Mio holds it)
func _candle():
	candle = Node3D.new(); candle.name = "ch5_candle"
	var stick := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.011; cm.bottom_radius = 0.012; cm.height = 0.12
	stick.mesh = cm; var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.92, 0.9, 0.84); wm.roughness = 0.6
	stick.material_override = wm; stick.position.y = 0.06; candle.add_child(stick)
	var saucer := MeshInstance3D.new(); var sm := CylinderMesh.new(); sm.top_radius = 0.045; sm.bottom_radius = 0.04; sm.height = 0.01
	saucer.mesh = sm; var sw := StandardMaterial3D.new(); sw.albedo_color = Color(0.85, 0.84, 0.8); saucer.material_override = sw; candle.add_child(saucer)
	# its rim: the dark line of an enamel dish (in the print the pale saucer and the pale hand under it were one shape. 第6章, 2026-11-18)
	var rim := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.0425; tm.outer_radius = 0.0475; tm.rings = 32; tm.ring_segments = 6
	rim.mesh = tm; var rw := StandardMaterial3D.new(); rw.albedo_color = Color(0.05, 0.07, 0.16); rw.roughness = 0.5; rim.material_override = rw
	rim.name = "nocol_rim"; rim.position.y = 0.0045; rim.scale = Vector3(1.0, 0.6, 1.0); candle.add_child(rim)
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
	candle.visible = false
	add_child(candle)

var candle_held := false
func _candle_tick(dt: float):
	if not candle.visible: return
	if candle_held:
		var cam: Camera3D = player.get_node("Head/Camera")
		# low in her right hand, before her: it keeps upright whatever she looks at
		var p: Vector3 = cam.global_position + Basis(Vector3.UP, player.yaw) * Vector3(0.2, -0.36, -0.42)
		candle.global_transform = Transform3D(Basis(), p)
	var lean := Vector3.ZERO; var best := 99.0
	for gq in gaps:
		if not gq.peeled and gq.key != "g5": continue
		var d: float = (gq.at as Vector3).distance_to(candle.global_position)
		if d < best: best = d; lean = (gq.at as Vector3) - candle.global_position
	var fr := gp(FRONT_GAP[0], FRONT_GAP[1], FRONT_GAP[2])
	if fr.distance_to(candle.global_position) < best: best = fr.distance_to(candle.global_position); lean = fr - candle.global_position
	var k := clampf((2.2 - best) / 1.5, 0.0, 1.0)
	lean.y = 0.0
	var tilt := 0.9 * k + 0.05 * sin(t_now * 13.0) * (0.3 + k)
	# 試作281（ユーザー「ろうそくの火をなびかせる案」）: outside, the gust lays the flame over along the wall and draws it long and
	# thin, flickering, the light shaking with it: the moment to pull is seen as well as heard (gust_k, the board's lift)
	var g := gust_k if outside else 0.0
	if g > 0.01:
		var wind := gp(1.0, 0.0, 0.0) - gp(0.0, 0.0, 0.0); wind.y = 0.0
		lean = lean.normalized().lerp(wind.normalized(), g) if lean.length() > 0.001 else wind
		tilt = lerpf(tilt, 1.35 + 0.2 * sin(t_now * 31.0) + 0.1 * sin(t_now * 47.0), g)
	flame.scale = Vector3(1.0 - 0.3 * g, 1.0 + 1.8 * g + 0.4 * g * sin(t_now * 23.0), 1.0 - 0.3 * g)   # drawn out to near three times its length
	if lean.length() > 0.001:
		var ax := Vector3.UP.cross(lean.normalized()).normalized()
		flame.basis = (Basis(ax, tilt) if ax.length() > 0.5 else Basis()).scaled(flame.scale)
	candle_light.light_energy = 0.26 + 0.04 * sin(t_now * 17.0) + 0.025 * sin(t_now * 5.3) - 0.07 * k * absf(sin(t_now * 9.0)) - 0.16 * g * absf(sin(t_now * 19.0))

# ---------------------------------------------------------------- the generator: heard all night, now heard as the cause
func _gen_fore():
	gen_fore = AudioStreamPlayer.new(); gen_fore.stream = Sound.stream("generator_far", true)
	gen_fore.volume_db = -60.0; add_child(gen_fore)
	if gen_fore.stream: gen_fore.play()

func _gen_tick(dt: float):
	gen_db = move_toward(gen_db, gen_want, dt * (7.0 if wb_t >= 0.0 else 2.5))
	gen_fore.volume_db = gen_db

func _gen_loud():
	gen_want = -9.0

# ---------------------------------------------------------------- the blanket over her shoulders (after the answer)
# 2026-11-17（ユーザー「毛布が平たい板に見える」）: a sheet laid on her, not a board above her. A height field over her body as she
# lies (her skinned vertices, posed), the cloth taken down from it at a cloth's slope, to the boards on either side; folds where
# it hangs, a few soft ridges where it lies on the floor, the hem curled. Built once (_nat_heights at the start), then only the
# loose edge moves in the draught from the back door.
const BL_W := 1.1        # across her (m): the hall is narrow (wider, it ran into the wall and over the step)
const BL_L := 1.0        # from her shoulders toward her feet (m)
const BL_NU := 36
const BL_NV := 32
var bl_frame := Transform3D()      # the blanket's own frame: x across her, z from her shoulders down, y up; origin its top middle
var bl_h := PackedFloat32Array()   # the cloth's height above the boards, per grid point
var bl_free := PackedFloat32Array() # 0 where it rests on her or on the boards' middle, 1 at the loose hem
var bl_body := PackedFloat32Array() # her height under it (−1: nothing)
var bl_t := 0.0
var bl_lim_p := PackedFloat32Array()   # per row: how far across (+x) before a wall
var bl_lim_n := PackedFloat32Array()

func _nat_heights():
	var c := _nat_chest(); var h := _nat_head()
	var along := Vector3(c.x - h.x, 0.0, c.z - h.z).normalized()   # head to feet
	var across := along.cross(Vector3.UP).normalized()
	var top := c - along * 0.08                                      # the top edge just over her shoulders: her face stays bare
	var fy := 0.003   # the hall's boards (her pool of blood lies at this height too)
	bl_frame = Transform3D(Basis(across, Vector3.UP, along), Vector3(top.x, fy, top.z))
	var inv := bl_frame.affine_inverse()
	var nu := BL_NU + 1; var nv := BL_NV + 1
	bl_body = PackedFloat32Array(); bl_body.resize(nu * nv); bl_body.fill(-1.0)
	var sk_t := nsk.global_transform
	var n_v := 0
	for mi in nat.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.skin == null or not m.visible: continue
		var nm := String(m.name)
		if nm.contains("phone") or nm.contains("_scr"): continue
		var binds := []
		for j in m.skin.get_bind_count():
			var bn := m.skin.get_bind_name(j)
			var bi := nsk.find_bone(bn) if bn != "" else m.skin.get_bind_bone(j)
			binds.append(sk_t * nsk.get_bone_global_pose(bi) * m.skin.get_bind_pose(j))
		for si in m.mesh.get_surface_count():
			var arr: Array = m.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bs = arr[Mesh.ARRAY_BONES]; var ws = arr[Mesh.ARRAY_WEIGHTS]
			if bs == null or ws == null or (bs as Array).is_empty(): continue
			var per: int = (bs as Array).size() / vs.size()
			for vi in range(0, vs.size(), 2):   # every other vertex is plenty for a 3 cm grid
				var p := Vector3.ZERO
				for q in per:
					var w: float = ws[vi * per + q]
					if w <= 0.0: continue
					p += (binds[bs[vi * per + q]] as Transform3D) * vs[vi] * w
				var l := inv * p
				var iu := int(round((l.x / BL_W + 0.5) * BL_NU)); var iv := int(round(l.z / BL_L * BL_NV))
				if iu < 0 or iv < 0 or iu >= nu or iv >= nv: continue
				var k := iv * nu + iu
				if l.y > bl_body[k]: bl_body[k] = l.y
				n_v += 1
	# the cloth: under a sheet laid over her, each point is as high as the highest of her nearby less a cloth's fall
	# (steep near her, flattening as it reaches the boards), smoothed, and never into her or into the floor
	var du := BL_W / BL_NU; var dv := BL_L / BL_NV
	bl_h = PackedFloat32Array(); bl_h.resize(nu * nv); bl_free = PackedFloat32Array(); bl_free.resize(nu * nv)
	var R := 9
	for iv in nv:
		for iu in nu:
			var best := 0.004
			for jv in range(maxi(0, iv - R), mini(nv, iv + R + 1)):
				for ju in range(maxi(0, iu - R), mini(nu, iu + R + 1)):
					var hb: float = bl_body[jv * nu + ju]
					if hb <= 0.0: continue
					var d := Vector2((ju - iu) * du, (jv - iv) * dv).length()
					var drop := 1.9 * d + 2.2 * d * d   # the hang: steep off her, out to the boards
					best = maxf(best, hb + 0.025 - drop)
			bl_h[iv * nu + iu] = best
	for it in 3:   # soften the tent's ridges into a cloth's roundness
		var sm := bl_h.duplicate()
		for iv in range(1, nv - 1):
			for iu in range(1, nu - 1):
				var k := iv * nu + iu
				sm[k] = 0.4 * bl_h[k] + 0.15 * (bl_h[k - 1] + bl_h[k + 1] + bl_h[k - nu] + bl_h[k + nu])
		bl_h = sm
	var rng := RandomNumberGenerator.new(); rng.seed = 1704
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	for iv in nv:
		for iu in nu:
			var k := iv * nu + iu
			var x := (float(iu) / BL_NU - 0.5) * BL_W; var z := float(iv) / BL_NV * BL_L
			var hb: float = bl_body[k]
			var on_her := hb > 0.0 and bl_h[k] < hb + 0.06
			var hang := clampf((bl_h[k] - 0.01) / 0.12, 0.0, 1.0) * (0.0 if on_her else 1.0)
			var flat := 1.0 - clampf(bl_h[k] / 0.02, 0.0, 1.0)
			# folds that run down off her (along the slope: across her, they run from her toward the boards)
			var fold := sin(z * 23.0 + ph[0] + 2.0 * sin(x * 3.0)) * 0.6 + sin(z * 41.0 + ph[1]) * 0.25
			var ridge := sin(x * 17.0 + z * 9.0 + ph[2]) * sin(z * 13.0 - x * 5.0)   # soft heaps where it lies on the boards
			var e := 0.022 * hang * fold + 0.012 * flat * maxf(ridge, 0.0)
			# the hem: the last few centimetres turn up a little; the top edge folded back once over her shoulders
			var edge := minf(minf(iu, BL_NU - iu), minf(iv, BL_NV - iv))
			if edge <= 1: e += 0.006
			if iv <= 2: e += 0.012 * (1.0 - iv / 2.0)
			bl_h[k] = maxf(bl_h[k] + e, (hb + 0.012) if hb > 0.0 else 0.003)
			bl_free[k] = clampf(1.0 - edge / 6.0, 0.0, 1.0) * (1.0 if not on_her else 0.15)
	# 2026-11-17 夜（ユーザー「毛布が壁を通り抜けてしまっている」）: where she lies by a wall (the cellar stair's side, the
	# hall's boarding) the sheet stops at the wall and goes up it a little, not through it. Per row, how far it can go each side
	bl_lim_p = PackedFloat32Array(); bl_lim_n = PackedFloat32Array(); bl_lim_p.resize(nv); bl_lim_n.resize(nv)
	var ss := get_viewport().world_3d.direct_space_state
	for iv in nv:
		var zc := float(iv) / BL_NV * BL_L
		for sd in [1.0, -1.0]:
			var lim := BL_W * 0.5
			for hh in [0.06, 0.25]:
				var a0: Vector3 = bl_frame * Vector3(0.0, hh, zc)
				var a1: Vector3 = bl_frame * Vector3(sd * BL_W * 0.5, hh, zc)
				var q := PhysicsRayQueryParameters3D.create(a0, a1)
				q.exclude = [player.get_rid()]
				var hit := ss.intersect_ray(q)
				if not hit.is_empty(): lim = minf(lim, maxf(0.05, a0.distance_to(hit.position) - 0.025))
			if sd > 0.0: bl_lim_p[iv] = lim
			else: bl_lim_n[iv] = lim
	print("CH5 blanket body verts %d floor %.3f" % [n_v, fy])

func _blanket_mesh() -> ArrayMesh:
	var nu := BL_NU + 1; var nv := BL_NV + 1
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the draught comes up the hall from the kitchen end: the loose hem on that side lifts and settles
	var gust := 0.5 + 0.5 * sin(bl_t * 1.3) * sin(bl_t * 0.47 + 1.0)
	var ys := PackedFloat32Array(); ys.resize(nu * nv)
	for iv in nv:
		for iu in nu:
			var k := iv * nu + iu
			var x := (float(iu) / BL_NU - 0.5) * BL_W; var z := float(iv) / BL_NV * BL_L
			ys[k] = bl_h[k] + bl_free[k] * gust * (0.012 + 0.006 * sin(bl_t * 4.1 + x * 6.0 + z * 4.0))
	var du := BL_W / BL_NU; var dv := BL_L / BL_NV
	for iv in nv:
		for iu in nu:
			var k := iv * nu + iu
			var x := (float(iu) / BL_NU - 0.5) * BL_W; var z := float(iv) / BL_NV * BL_L
			var y: float = ys[k]
			if bl_lim_p.size() == nv:   # against a wall: it stops there and goes up it by what was left over
				var lim: float = bl_lim_p[iv] if x > 0.0 else bl_lim_n[iv]
				if absf(x) > lim: y = maxf(y, 0.003) + minf(absf(x) - lim, 0.12); x = signf(x) * lim
			# the normal from the heights around (SurfaceTool.generate_normals left it unlit: black)
			var dx: float = (ys[iv * nu + mini(iu + 1, BL_NU)] - ys[iv * nu + maxi(iu - 1, 0)]) / (du * float(mini(iu + 1, BL_NU) - maxi(iu - 1, 0)))
			var dz: float = (ys[mini(iv + 1, BL_NV) * nu + iu] - ys[maxi(iv - 1, 0) * nu + iu]) / (dv * float(mini(iv + 1, BL_NV) - maxi(iv - 1, 0)))
			st.set_normal(Vector3(-dx, 1.0, -dz).normalized())
			st.set_uv(Vector2(float(iu) / BL_NU * 3.7, float(iv) / BL_NV * 3.3))   # a check about 15 cm
			st.add_vertex(Vector3(x, y, z))
	for iv in BL_NV:
		for iu in BL_NU:
			var a := iv * nu + iu
			st.add_index(a); st.add_index(a + nu); st.add_index(a + 1)   # wound so its normals face up (the other way it was lit from below: black)
			st.add_index(a + 1); st.add_index(a + nu); st.add_index(a + nu + 1)
	return st.commit()

var nat_ready := false
var want_blanket := false
func _blanket_on():
	if blanket: return
	if not nat_ready: want_blanket = true; return   # she is not laid down yet (a start part-way): after _natsuki
	blanket = MeshInstance3D.new()
	blanket.mesh = _blanket_mesh()
	# Mio's own blanket: a worn wool plaid (the bedroom blanket's material is the house's atlas, wood where this grid's
	# UVs fall). The checks follow the folds, which is most of what makes it read as cloth in the print
	var dm := StandardMaterial3D.new()
	dm.albedo_texture = ImageTexture.create_from_image(_plaid())
	dm.roughness = 1.0; dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	dm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	blanket.material_override = dm
	blanket.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	main.add_child(blanket)
	blanket.global_transform = bl_frame

func _plaid() -> Image:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var base := Color(0.50, 0.30, 0.17)    # a faded rust
	var band := Color(0.20, 0.17, 0.14)    # dark brown bands
	var thin := Color(0.72, 0.62, 0.42)    # a pale thin line
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for y in n:
		for x in n:
			var bx := (x % 128) < 34; var by := (y % 128) < 34
			var tx := absi(x % 128 - 80) < 3; var ty := absi(y % 128 - 80) < 3
			var c := base
			if bx and by: c = band.darkened(0.25)
			elif bx or by: c = base.lerp(band, 0.7)   # a woven check: half where one band crosses the ground
			if tx or ty: c = c.lerp(thin, 0.6)
			c = c.darkened(rng.randf_range(0.0, 0.12) + (0.06 if (x + y) % 4 < 2 else 0.0))   # the twill and the wool
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img

func _blanket_tick(dt: float):
	if blanket == null: return
	bl_t += dt
	if Engine.get_process_frames() % 2 == 0: blanket.mesh = _blanket_mesh()

# ---------------------------------------------------------------- cards and the clock
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
	_wb_tick(dt)
	_gen_tick(dt)
	_blanket_tick(dt)
	_torch()
	main.talk_now = cur.get("who_key", "") if mode == TALK and cur.has("who") and typed < float(String(cur.get("text", "")).length()) else ""
	main.story_talking = (mode == TALK)
	player.move_enabled = (mode == FREE and stage in ["follow", "peel", "done"]) or (stage == "back" and not cur.has("silence"))   # 2026-11-20: she follows Makoto through the talk
	match stage:
		"follow": _follow_tick()
		"peel", "done": _peel_tick(dt)
		"end_wait": pass
	_below_tick(dt)
	if page_clear_t >= 0.0:
		page_clear_t -= dt
		if page_clear_t < 0.0 and mode == FREE: _clear_page()
	if demo5: _demo_tick(dt)

func _begin(st: String):
	t_stage = 0.0
	print("STORY ch5 %s t=%.1f" % [st, t_now])
	match st:
		"t4card":
			_card(D.lines("四時.カード")[0], "t4")
		"t4":
			stage = "t4"
			_start(B("四時.会話"))
		"back":
			stage = "back"; talk_with = "makoto"   # (the view goes down to the door with the light: makoto_light)
			_start(B("四時.勝手口"))
		"peel":
			stage = "peel"; candle.visible = true; candle_held = true; main.clock_at(4, 10)
			_below_start()
		"end":
			_end_scene()

# a line that waits for someone to arrive
func _next():
	if cur.has("silence") and silence_t >= 0.0: return   # the counted silence holds the talk (story._next goes straight on after a ＞)
	if hold: cur = {}; return
	super._next()
	if cur.has("text") and cur.has("who"): _voice(String(cur.who), String(cur.text))

# ---------------------------------------------------------------- Makoto's voice (2026-11-17, waiting on the recording)
# The lines are numbered as on the sheet the user records from (/mnt/project-files/ステップF/第5章_仕上げ/真琴の声_録る台詞.md).
# A take goes in as godot/sound/voice/makoto_05_NN.wav (or .ogg); until it is there the line is text only, as before.
# In the room her voice is at her mouth; from below it comes up the cellar stair, the highs gone under the floor.
# While she speaks, the line waits for her (it does not run on after the reading time).
# 2026-11-17（ユーザー「ミニマムにしたほうがいい」）: only the voices from out of sight and the one line the chapter turns on
const VOICE5 := {"ゾンビなんて、いない。": 1, "……大河さん？": 2, "開いてた。……閂、外してある。": 3, "大河さん！": 4,
	"澪さん、……板、外せましたか。": 5, "澪さん、……止め方、……つまみ、……どれ。": 6}
var voice_p: Node = null

func _voice(who: String, text: String):
	if not who.begins_with("真琴"): return
	var key := text.replace("\n", "").strip_edges()
	var n: int = VOICE5.get(key, 0)
	if n == 0:
		for k in VOICE5:   # the shown text may be wrapped or translated: find it by its words
			if Tw(String(k)).replace("\n", "") == key: n = VOICE5[k]; break
	if n == 0: return
	var name := "voice/makoto_05_%02d" % n
	if Sound.stream(name) == null: return
	var below := who.contains("下から")
	var at: Vector3 = gp(5.5, 4.2, ZBASE + 1.2) if below else (_mk_face() if main.S.has("makoto_node") else player.global_position)
	if is_instance_valid(voice_p): voice_p.queue_free()
	voice_p = Sound.one(self, name, -4.0 if below else 0.0, at)
	if voice_p is AudioStreamPlayer3D:
		var p3 := voice_p as AudioStreamPlayer3D
		p3.unit_size = 4.0 if below else 2.0
		if below: p3.attenuation_filter_cutoff_hz = 900.0; p3.attenuation_filter_db = -24.0   # through the floor and up the stair

func _voice_on() -> bool:
	return is_instance_valid(voice_p) and voice_p.call("is_playing")

func _release():
	hold = false
	if mode == TALK: _next()

func _do(what: String):
	if _flag_do(what): return   # 2026-11-20 the night's record (story.gd FLAG_DOS)
	print("STORY ch5 do %s t=%.1f" % [what, t_now])
	match what:
		"makoto_down":
			_put("makoto", [5.0, 6.6], PI, F2); main.set_stand("makoto", "talk/idle", 0.0)
			main.phones(true, ["makoto"])
			hold = true
			main.walk_to("makoto", MAKOTO_DOWN, func(): _release(), _face([5.5, 2.55], [MIO_AT[0], MIO_AT[1]]))
		"makoto_see":
			talk_with = "makoto"
			_turn_to(_mk_face(), 1.0)
		"makoto_kneel":
			# beside her, by her shoulder, facing her: she goes down on her heels
			var c := _nat_chest()
			# (the kneel carries her hips 0.2 m forward: she stops a step short)
			# 2026-11-17 夜（ユーザー「真琴が座る場所、変」）: the side of her with room (east of her was the stair's side when she
			# lay at the stair's foot): the one the boards are clear on for 0.85 m
			var side := 1.0
			var ss := get_viewport().world_3d.direct_space_state
			var room := {}
			for sd in [1.0, -1.0]:
				var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, 0.45, c.z), Vector3(c.x + sd * 0.95, 0.45, c.z))
				q.exclude = [player.get_rid()]
				var hit := ss.intersect_ray(q)
				room[sd] = 0.95 if hit.is_empty() else Vector3(c.x, 0.45, c.z).distance_to(hit.position)
			if room[-1.0] > room[1.0] + 0.05: side = -1.0
			var at := [c.x + 4.8 + 0.62 * side, c.z + 6.3 - 0.05]
			hold = true
			main.stand_anim["makoto"] = "talk/idle"
			main.walk_to("makoto", [[5.3, 2.4, 0.0], [at[0], at[1], 0.0]], func():
				_kneel(); get_tree().create_timer(1.6).timeout.connect(_release), _face(at, [c.x + 4.8, c.z + 6.3 + 0.2]))
			_turn_to(Vector3(c.x + 0.25, 0.35, c.z), 1.6)
		"makoto_tripod":
			var r := _rig("makoto")
			var to := gp(TRIPOD_AT[0], TRIPOD_AT[1], 0.0) - r.global_position
			var tw := create_tween()
			tw.tween_property(r, "global_rotation:y", r.global_rotation.y + wrapf(atan2(to.x, to.z) - r.global_rotation.y, -PI, PI) * 0.6, 1.2).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(1.4)
			# 試作277（ユーザー「真琴、廊下の方を一回見るアニメーションを追加」）: then once down the hall, to its far end (the wind)
			var hall := gp(5.4, 6.2, 0.0) - r.global_position
			tw.tween_property(r, "global_rotation:y", r.global_rotation.y + wrapf(atan2(hall.x, hall.z) - r.global_rotation.y, -PI, PI) * 0.8, 1.1).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(1.6)
			tw.tween_property(r, "global_rotation:y", r.global_rotation.y, 1.0).set_trans(Tween.TRANS_SINE)
		"makoto_back":
			talk_with = ""
			stage = "follow"
			# 試作277（ユーザー「真琴が立って移動するとき、澪に一度ぶつかるのやめる」）: Mio stood in the one-body gap of the hall
			# (x 4.3, y 3.0〜3.2 on the --ch3map) that Makoto goes through. She steps back out of it, west, as Makoto gets up
			var mp: Vector3 = player.global_position
			if Vector2(mp.x + 4.8 - MIO_AT[0], mp.z + 6.3 - MIO_AT[1]).length() < 0.7:
				var aside := gp(3.75, 3.55, 0.0); aside.y = mp.y
				create_tween().tween_property(player, "global_position", aside, 1.3).set_trans(Tween.TRANS_SINE)
			_stand_up(func(): main.walk_to("makoto", [[5.2, 2.3, 0.0], [4.45, 2.95, 0.0], [4.3, 3.1, 0.0], [4.2, 3.3, 0.0], [4.2, 3.8, 0.0], [4.3, 3.9, 0.0], [4.3, 5.2, 0.0], [5.0, 5.9, 0.0], [5.5, 5.9, 0.0], [5.8, 6.2, 0.0], [8.1, 6.2, 0.0], [MK_BACK[0], MK_BACK[1], 0.0]],
				Callable(), _face(MK_BACK, [BACK_DOOR[0], BACK_DOOR[1]])))
		"makoto_light":
			# the light goes low, onto the torn tape and the hand under it, and Mio's eyes go with it (2026-11-17: the first
			# time the light was on the door at chest height, and the hand never came into the picture)
			# 試作127: no hand any more: the light on the torn tape (the seam, plan y 5.32) at the tear's height
			torch_at = gp(9.95, 5.30, 1.05)
			_turn_to(gp(9.95, 5.30, 1.05), 1.4)
		"shake":
			_nod(0.07, true)
		"nod":
			_nod(0.08, false)
		"makoto_temple":
			torch_at = Vector3.ZERO
			get_tree().create_timer(1.6).timeout.connect(func(): _turn_to(_mk_face(), 1.2))
			# 試作127（ユーザー「距離が近いのとモデルが歪む」、B8 真琴との間を 1.2m に）: MK_THINK was 0.4 m from where Mio
			# stood. She stops 1.2 m from Mio, toward the middle of the kitchen
			var mio := Vector2(player.global_position.x + 4.8, player.global_position.z + 6.3)
			var mk := mio + (Vector2(7.7, 5.9) - mio).normalized() * 1.2
			mk.x = clampf(mk.x, 6.9, 9.0); mk.y = clampf(mk.y, 4.6, 6.9)
			main.walk_to("makoto", [[mk.x, mk.y, 0.0]], func(): main.set_stand("makoto", "talk/think"); _mk_shift(), _face([mk.x, mk.y], [mio.x, mio.y]))
			gen_want = -30.0
			# 試作232（ユーザー「真琴の顔がゆがんでる」、3時半）: the look turned her up to 60° about the world's up, through a body
			# bent over the hand at her temple (think): the neck and jaw sheared. Here she already faces Mio: a little turn, and
			# the spine takes most of it
			if looks.has("makoto"):
				(looks.makoto as Look).max_yaw = 0.35
				var lm: Look = looks.makoto
				lm.chain = [["spine_03", 0.6], ["neck_01", 0.25], ["head", 0.15]]
				lm.bones = []
				for c in lm.chain: lm.bones.append([lm.get_skeleton().find_bone(c[0]), c[1]])
		"makoto_hand":
			hold = true
			main.stand_anim["makoto"] = "talk/idle"
			torch_at = gp(HAND_AT[0], HAND_AT[1], HAND_AT[2])
			_turn_to(gp(HAND_AT[0], HAND_AT[1], HAND_AT[2] + 0.2), 1.6)
			main.walk_to("makoto", [[MK_HAND[0], MK_HAND[1], 0.0]], func():
				_kneel()
				get_tree().create_timer(4.6).timeout.connect(func():
					_stand_up(func():
						torch_at = Vector3.ZERO
						get_tree().create_timer(0.8).timeout.connect(_release))), _face(MK_HAND, [HAND_AT[0], HAND_AT[1]]))
		# 2026-11-20（12時35分 A「真琴を動かす」）: she talks as she goes, back door → the kitchen window → the sink → the hall
		# (the blanket) → the cellar door; the generator a step louder with each (gen_up)
		"gen_up":
			gen_want = minf(gen_want + 4.0, -14.0)
		"makoto_palm_board":
			# she steps up to the board and lays her palm flat on it, and waits (no line)
			var b := _kitchen_window()
			var bp := [b.x + 4.8, b.z + 6.3]
			var r0: Vector3 = _rig("makoto").global_position
			var v0 := Vector2(r0.x + 4.8 - bp[0], r0.z + 6.3 - bp[1])
			v0 = v0.normalized() if v0.length() > 0.05 else Vector2(0.0, -1.0)
			var at0 := [bp[0] + v0.x * 0.34, bp[1] + v0.y * 0.34]
			var pb := _board_near(Vector3(b.x, 1.2, b.z)) + Vector3(v0.x, 0.0, v0.y) * 0.035   # on one board's face, not in a gap
			main.stand_anim["makoto"] = "talk/idle"
			main.walk_to("makoto", [[at0[0], at0[1], 0.0]], func():
				main.set_stand("makoto", "talk/idle", 0.6)
				var r := _rig("makoto")
				if is_instance_valid(mk_palm): mk_palm.queue_free()
				mk_palm = _palm(r, pb), _face(at0, bp))
		"wait_board":
			hold = true; talk_with = ""
			wb_at = _kitchen_window(); wb_t = 0.0; wb_gen0 = gen_want; wb_done = false
		"makoto_walk_window":
			torch_at = Vector3.ZERO
			main.stand_anim["makoto"] = "talk/idle"
			var w := _kitchen_window()
			var wp := [w.x + 4.8, w.z + 6.3]
			var v := (Vector2(8.0, 6.0) - Vector2(wp[0], wp[1])).normalized()
			var at := [wp[0] + v.x * 0.55, wp[1] + v.y * 0.55]
			main.walk_to("makoto", [[at[0], at[1], 0.0]], func(): main.set_stand("makoto", "talk/think"); _mk_shift(), _face(at, wp))
			_mk_look_spine()
		"makoto_sink":
			_palm_off()
			main.stand_anim["makoto"] = "talk/idle"
			# 試作277（ユーザー「この直前、真琴が壁をすり抜けていく」）: from the window straight to (7.6, 6.9) went through the wall's
			# end at x 7.8〜8.0, y 6.4〜6.7 (the --ch3map). Round it on the open side
			main.walk_to("makoto", [[7.5, 6.3, 0.0], [7.5, 6.9, 0.0], [MK_SINK[0], MK_SINK[1], 0.0]], func(): main.set_stand("makoto", "talk/think", 0.6), _face(MK_SINK, [7.42, 7.78]))
		"makoto_cellar_door":
			hold = true; talk_with = ""
			main.stand_anim["makoto"] = "talk/idle"
			main.walk_to("makoto", [[4.3, 5.2, 0.0], [5.0, 5.9, 0.0], [5.35, 5.95, 0.0]], func():
				if dn: dn.open_key("door_cellar")
				Sound.one(self, "creak3", -12.0, gp(5.5, 5.9, 1.0))
				get_tree().create_timer(0.7).timeout.connect(_release), _face([5.35, 5.95], [5.5, 4.5]))
		"face_makoto":
			# 試作291: the candle Mio holds, at the top of the cellar stairs, on Makoto's face as she turns
			_line_face("makoto", candle, Color(1.0, 0.68, 0.36), 1.1, 3.0)
		"makoto_step":
			# two steps down, and she turns: her eyes on Mio's
			hold = true; mk_at_cellar = true; talk_with = "makoto"
			main.walk_to("makoto", [[5.5, 5.75, 0.0], [5.5, 5.55, 0.0], [5.5, 5.0, _ramp_z(5.0)]], func():
				get_tree().create_timer(0.5).timeout.connect(_release), _face([5.5, 5.0], _plan_of(player)))
		"go_out":
			pass
		"board_off":
			pass
		"makoto_candle":
			# a candle from the kitchen, lit, into her hand: the light on Mio's hands first
			candle.visible = true; candle_held = true
			Sound.one(self, "ch3_blanket", -18.0, player.global_position)
		"makoto_go":
			hold = true
			get_tree().create_timer(1.0).timeout.connect(func(): _turn_to(gp(7.3, 6.15, 1.4), 1.5))
			main.walk_to("makoto", [[8.1, 5.6, 0.0], [7.3, 6.15, 0.0]], func(): _release(), _face([7.3, 6.15], [player.global_position.x + 4.8, player.global_position.z + 6.3]))
		"makoto_blanket":
			# 2026-11-20: in the hall, on the way to the cellar door, the blanket over her shoulders (no line)
			hold = true; talk_with = ""
			main.stand_anim["makoto"] = "talk/idle"
			main.walk_to("makoto", [[7.4, 6.8, 0.0], [6.6, 6.42, 0.0], [5.75, 6.42, 0.0], [5.5, 5.9, 0.0], [5.0, 5.9, 0.0], [4.3, 5.2, 0.0], [MK_BLANKET[0], MK_BLANKET[1], 0.0]], func():
				_kneel()
				get_tree().create_timer(0.9).timeout.connect(func():
					_blanket_on(); Sound.one(self, "ch3_blanket", -10.0, gp(NAT_AT[0], NAT_AT[1], 0.3))
					get_tree().create_timer(1.4).timeout.connect(func(): _stand_up(func(): _release()))), _face(MK_BLANKET, NAT_AT))
		"makoto_cellar":
			talk_with = ""
			if mk_at_cellar:
				_cellar_lock("……先に、テープ。")
				get_tree().create_timer(4.0).timeout.connect(_cellar_ajar)
				main.walk_to("makoto", [[5.5, 2.6, ZBASE], [5.5, 2.15, ZBASE], [6.8, 2.2, ZBASE], [8.2, 4.6, ZBASE], [MK_GEN[0], MK_GEN[1], ZBASE]], func():
					main.set_stand("makoto", _kneel_anim(), 0.4), _face(MK_GEN, [9.45, 6.3]))
			else: main.walk_to("makoto", [[5.8, 6.2, 0.0], [5.5, 5.9, 0.0]], func():
				if dn: dn.open_key("door_cellar")
				_cellar_lock("……先に、テープ。")
				get_tree().create_timer(4.0).timeout.connect(_cellar_ajar)
				# 試作176 A18（ユーザー「真琴は下に行っているはずなのに、誰も居ない」）: she goes on down to the generator and
				# kneels at its panel (Taiga's way at 20:00, story.gd TAIGA_PATH), her phone's light on it
				main.walk_to("makoto", [[5.5, 5.75, 0.0], [5.5, 5.55, 0.0], [5.5, 2.6, ZBASE], [5.5, 2.15, ZBASE], [6.8, 2.2, ZBASE], [8.2, 4.6, ZBASE], [MK_GEN[0], MK_GEN[1], ZBASE]], func():
					main.set_stand("makoto", _kneel_anim(), 0.4), _face(MK_GEN, [9.45, 6.3])))
			_blanket_on()
			get_tree().create_timer(1.5).timeout.connect(func(): _begin("peel"))
		"gen_loud":
			_gen_loud()
		"push":
			pass
		"silence":
			_silence_open()
		"end":
			script_q.clear()
			get_tree().create_timer(1.5).timeout.connect(_end_card)
		_: super._do(what)

# her eyes go to what the talk is about (the view turns by itself; she may look away again)
# down on one knee (her own kneel; Taiga's crouch on a house written before it) and up again
func _kneel_anim() -> String:
	var ap := _mk_ap()
	return "talk/kneel" if ap and ap.has_animation("talk/kneel") else "talk/crouch"

func _mk_ap() -> AnimationPlayer:
	if not main.S.has("makoto_node"): return null
	return main.S.makoto_node.find_children("*", "AnimationPlayer", true, false)[0]

func _kneel():
	main.set_stand("makoto", _kneel_anim(), 0.3)

# up off her knee, then done (the walk, the next line)
func _stand_up(done := Callable()):
	var ap := _mk_ap()
	if ap and main.stand_of("makoto") == "talk/kneel" and ap.has_animation("talk/kneel_up"):
		main.set_stand("makoto", "talk/kneel_up", 0.2)
		main.stand_anim["makoto"] = "talk/idle"
		get_tree().create_timer(ap.get_animation("talk/kneel_up").length - 0.25).timeout.connect(func():
			main.set_stand("makoto", "talk/idle", 0.3)
			if done.is_valid(): done.call())
		return
	main.set_stand("makoto", "talk/idle", 0.6); main.stand_anim["makoto"] = "talk/idle"
	if done.is_valid(): get_tree().create_timer(0.6).timeout.connect(done)

func _turn_to(at: Vector3, dur := 1.2):
	var cam: Camera3D = player.get_node("Head/Camera")
	var to := at - cam.global_position
	var y1: float = player.yaw + wrapf(atan2(-to.x, -to.z) - player.yaw, -PI, PI)
	var p1 := asin(clampf(to.normalized().y, -1.0, 1.0))
	if turn_tw and turn_tw.is_valid(): turn_tw.kill()   # a new look takes over (two at once: the first one won)
	turn_tw = create_tween().set_parallel(true)
	turn_tw.tween_property(player, "yaw", y1, dur).set_trans(Tween.TRANS_SINE)
	turn_tw.tween_property(player, "pitch", p1, dur).set_trans(Tween.TRANS_SINE)
var turn_tw: Tween

func _mk_face() -> Vector3:
	return _rig("makoto").global_position + Vector3(0, 1.45 if not main.stand_of("makoto") in ["talk/crouch", "talk/kneel"] else 0.95, 0)

# her head: a shake (no) or a nod (yes), the view itself moving
func _nod(a: float, shake: bool):
	var tw := create_tween()
	if shake:
		var y0: float = player.yaw
		for i in 2:
			tw.tween_property(player, "yaw", y0 + a, 0.16).set_trans(Tween.TRANS_SINE)
			tw.tween_property(player, "yaw", y0 - a, 0.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player, "yaw", y0, 0.16)
	else:
		var p0: float = player.pitch
		tw.tween_property(player, "pitch", p0 - a * 2.0, 0.25).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player, "pitch", p0, 0.3).set_trans(Tween.TRANS_SINE)

# Makoto's light: down ahead of her feet as main.gd aims it, or on what she looks at
var torch_at := Vector3.ZERO
func _torch():
	if not main.S.has("makoto_node"): return
	var sk: Skeleton3D = main.S.makoto_node.find_children("*", "Skeleton3D", true, false)[0]
	if torch_at == Vector3.ZERO:
		for e in main.torches:   # back to its own strength (main.gd aims it again)
			if e[1] == sk and is_instance_valid(e[0]) and (e[0] as Node).has_meta("e0"): (e[0] as SpotLight3D).light_energy = float((e[0] as Node).get_meta("e0"))
		return
	for e in main.torches:
		if e[1] != sk or not is_instance_valid(e[0]): continue
		var sp: SpotLight3D = e[0]
		sp.global_basis = Basis.looking_at((torch_at - sp.global_position).normalized(), Vector3.UP)
		# close up (the back door's frame is a metre off) a phone's torch burns the wall out to bare paper, and the dark
		# hand on it with it (試作150). Held near, it is a softer pool: the energy falls with the square of the nearness
		if not sp.has_meta("e0"): sp.set_meta("e0", sp.light_energy)
		var dist := sp.global_position.distance_to(torch_at)
		sp.light_energy = float(sp.get_meta("e0")) * clampf(pow(dist / 1.6, 2.0), 0.3, 1.0)

# ---------------------------------------------------------------- following her to the kitchen
func _follow_tick():
	if mode != FREE: return
	var p: Vector3 = player.global_position
	if Vector2(p.x - gp(BACK_STAND[0], BACK_STAND[1], 0).x, p.z - gp(BACK_STAND[0], BACK_STAND[1], 0).z).length() < 1.0 and not main.walking("makoto"):
		_begin("back")

# ---------------------------------------------------------------- 四時十分: taking the tape off
func _next_key() -> String:
	for k in order:
		for gq in gaps:
			if gq.key == k and not gq.peeled: return k
	return ""

func _gap(k: String) -> Dictionary:
	for gq in gaps: if gq.key == k: return gq
	return {}

func _near_tape() -> Dictionary:
	var cam: Camera3D = player.get_node("Head/Camera")
	var best := {}; var ba := 99.0
	for gq in gaps:
		if gq.peeled: continue
		var to: Vector3 = (gq.at as Vector3) - cam.global_position
		var a := (-cam.global_basis.z).angle_to(to)
		# 試作281（ユーザー「テープ剥がすアクションが表示されない」）: the gaps under the doors lie by the floor, 1.3 m under the
		# eye, and 1.6 m straight made her stand over them. The height counts for less, and a low one takes a wider look (ch6.gd)
		var dist := Vector3(to.x, to.y * 0.45, to.z).length()
		var deg := 32.0 + (8.0 if to.y < -0.8 else 0.0)
		if dist < 1.9 and a < deg_to_rad(deg) and a < ba: ba = a; best = gq
	return best

func _what_looked() -> String:
	var gq := _near_tape()
	if not gq.is_empty(): return "tape"
	if _looking_at(gp(BACK_DOOR[0], BACK_DOOR[1], BACK_DOOR[2]), 1.9, 30.0): return "back"
	# 地下の扉には Ｅ を出さない（2026-11-17 ユーザー「E 降りる はいらないよね？」）。下りないことは【五.終わり】の証言だけで言う
	if _looking_at(gp(FRONT_DOOR[0], FRONT_DOOR[1], FRONT_DOOR[2]), 2.4, 25.0): return "front"
	return ""

func _peel_tick(dt: float):
	idle_t += dt
	if idle_t > IDLE_STEP and below_i < BELOW.size() and below_q.is_empty() and stage == "peel":
		idle_t = 0.0; _below_step()
	_out_tick(dt)
	if stage == "done" and end_wait >= 0.0 and not outside:
		end_wait += dt
		if end_wait > 40.0 and mode == FREE: _begin("end"); return
	if mode != FREE: note_lb.text = ""; return
	look_k = _what_looked()
	if outside: look_k = "board" if boards_off < 4 and _looking_at(gp(CWIN[0], CWIN[1], CWIN[2]), 2.6, 35.0) else ""
	match look_k:
		"board": note_lb.text = T(String(D.lines("外.板.案内")[0]))
		"tape": note_lb.text = T(String(D.lines("はがす.案内")[0]))
		"back": note_lb.text = ""   # 試作277: no Ｅ at the back door: she walks out (_out_tick)
		"cellar": note_lb.text = T(String(D.lines("しない.地下")[0]))
		"front": note_lb.text = T(String(D.lines("しない.玄関")[0]))
		_: note_lb.text = ""

func _press_peel():
	if not stage in ["peel", "done"]: return
	match look_k:
		"tape":
			var gq := _near_tape()
			idle_t = 0.0
			# 試作175 A19（ユーザー「剥がす順番はどこからでもよくない？」）: whichever she looks at comes off
			_peel(gq)
			peeled_n += 1
			# 試作231（ユーザー「テープ、最後に勝手口そばを剥がさないと次に進まない」）: the back door's is torn already, so the
			# other four end it. Looked at before then, it is one line; when the four are off, it counts as off too
			var four := true
			for g4 in gaps: if g4.key != "g5" and not g4.peeled: four = false
			var auto5: bool = four and not _gap("g5").is_empty() and not _gap("g5").peeled
			if auto5: _peel(_gap("g5"), true); peeled_n = 5
			var q: Array = []
			if gq.key == "g5": q = B("はがす.勝手口.最後" if peeled_n == 5 else "はがす.勝手口")
			elif peeled_n == 1: q = B("はがす.一つ目")
			if auto5: q.append_array(B("はがす.勝手口.最後"))
			if peeled_n == 5:
				q.append_array(B("はがす.五つ目"))
				_cellar_lock("下りませんでした。真琴ちゃんが、来ないでって。")
				stage = "done"; end_wait = 0.0
			if not q.is_empty(): _start(q)
			while below_i < BELOW.size() and int(BELOW[below_i][0]) <= _progress(): _below_step()
		"back":
			if boards_off < 4 and not has_flag("went_out_4am"): _go_out()   # 2026-11-21 (review): once out, the door is a door (no second 【外.出る】)
		"cellar", "front":
			var key: String = {"cellar": "しない.地下", "front": "しない.玄関"}[look_k]
			var e: Array = B(key).slice(1)   # the first line is the key's own prompt
			if said.has(key): e = e.filter(func(x): return x.has("do"))   # once: the testimony; again, only the silence
			said[key] = true
			if e.is_empty(): return
			_start(e)
			if stage == "done": end_wait = maxf(end_wait, 22.0)

# ---------------------------------------------------------------- 2026-11-20（12時35分 B）: out by the back door, the cellar window's boards by hand
# Standing before the back door, the seconds count (the chapter's one counted silence) until she goes out or steps away.
# Outside, under the porch stair: the four boards she nailed at 20:00, off with her fingers (Ｅ held while the wind pushes the board out: 手の遊び③ below; let go
# and it stays where it was). Makoto's voice comes through the window, weaker with each. The cellar's steps count the
# tapes and the boards together; out there, the window's lines take the place of the stair's.
const CWIN := [10.28, 6.45, -1.4]   # the boards' face (rooms2.boards: x 10 + 0.28, y 6.45, z -1.66..-1.15)
const MK_SINK := [7.42, 7.28]
const MK_BLANKET := [4.35, 4.55]
const BOARD_SEC := 3.4
# 手の遊び③（決定事項 2026-11-23 7時33分）：風に合わせて引く。風が板を外へ押す間（約1秒、2.6〜4秒おき）に Ｅ を
# 押さえていれば、板が浮く。風のない間に引いても、釘が持って動かない（乾いたきしみだけ）。ゲージも文字も出さない。
# 風は、板のがたつき（ch3_rattle）と、板の端が壁から浮くのとで分かる。一枚に二回の風ほど。
const GUST_PULL := 1.7       # s of pulling inside gusts per board
var gust_k := 0.0            # 0..1: how hard the wind pushes now
var gust_next := 2.0
var gust_left := 0.0
func _gust_tick(dt: float):
	if gust_left > 0.0:
		gust_left -= dt
		gust_k = move_toward(gust_k, 1.0, dt * 6.0)
	else:
		gust_k = move_toward(gust_k, 0.0, dt * 3.0)
		gust_next -= dt
		if gust_next <= 0.0:
			gust_left = randf_range(1.0, 1.3); gust_next = randf_range(2.6, 4.0); gust_knock = 0.0
			Sound.one(self, "ch8_wind", -4.0, gp(CWIN[0] + 0.6, CWIN[1], CWIN[2] + 0.6))   # 試作281: the gust itself, heard coming
	# 試作281（ユーザー「風が吹いて板ががたつく間だけ…感じられなかった」）: the board knocks against its nails all through the gust,
	# not once at its start, and its free end lifts far enough to see (.07 → .15 rad, shaking)
	if gust_left > 0.0:
		gust_knock -= dt
		if gust_knock <= 0.0:
			gust_knock = randf_range(0.16, 0.26)
			Sound.one(self, "ch3_rattle", -9.0 + gust_k * 4.0, gp(CWIN[0], CWIN[1], CWIN[2]))
var gust_knock := 0.0
var mk_at_cellar := false
var mk_fell := false
var outside := false
var boards5 := []
var boards_off := 0
var board_k := 0.0
var board_creak := 0.0
var cwin_light: OmniLight3D
var back_sil := false
var sil_counted := false   # 2026-11-21 (review): the counted silence is once (each walk back added a row and a rattle)
var back_wall: StaticBody3D
var back_sil_t := 0.0
var back_sil_lb: Label

func _progress() -> int: return peeled_n + boards_off

func _ramp_z(y: float) -> float: return ZBASE * clampf((5.6 - y) / 3.15, 0.0, 1.0)

func _mk_look_spine():
	if not looks.has("makoto"): return
	var lm: Look = looks.makoto
	lm.max_yaw = 0.35
	lm.chain = [["spine_03", 0.6], ["neck_01", 0.25], ["head", 0.15]]
	lm.bones = []
	for c in lm.chain: lm.bones.append([lm.get_skeleton().find_bone(c[0]), c[1]])

# ---------------------------------------------------------------- the kitchen window's board (＞wait_board)
# Makoto's palm on it, and she says nothing. While Mio stands at it the generator is louder (through the wall, from
# below); away from it, as before. Ｅ on it goes on; after 60 s Mio reaches for it herself (the same next line).
func _palm(r: Node3D, at: Vector3) -> Node:
	if not main.S.has("makoto_node"): return null
	var sk: Skeleton3D = main.S.makoto_node.find_children("*", "Skeleton3D", true, false)[0]
	var rc: Node = load("res://scripts/reach.gd").new()
	rc.side = "l"   # (the phone, its light on, is in her right)
	var b := r.global_basis
	rc.target = at
	rc.pole = b * Vector3(1.0, -1.0, 0.2)
	sk.add_child(rc)
	create_tween().tween_property(rc, "w", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	return rc

func _board_near(to: Vector3) -> Vector3:
	var best := to; var bd := 99.0
	for mi in main.S.env_node.find_children("board_*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("board_cellar"): continue
		var c: Vector3 = ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).get_center()
		var d := c.distance_to(to)
		if d < bd: bd = d; best = c
	return best

func _palm_off():
	if not is_instance_valid(mk_palm): return
	var rc := mk_palm; mk_palm = null
	var tw := create_tween()
	tw.tween_property(rc, "w", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(rc.queue_free)

func _wb_near() -> bool:
	# (review: from where she stands at the back door the board was in reach, and the E that moves the lines on ended
	# the wait before she ever stood at it and heard the generator): only up at the board
	var p: Vector3 = player.global_position
	return Vector2(p.x - wb_at.x, p.z - wb_at.z).length() < WB_CLOSE and _looking_at(wb_at, 1.8, 40.0)
const WB_CLOSE := 1.15

func _wb_tick(dt: float):
	if wb_t < 0.0: return
	wb_t += dt
	var p: Vector3 = player.global_position
	var close := Vector2(p.x - wb_at.x, p.z - wb_at.z).length() < WB_CLOSE + 0.1
	if not wb_done:
		gen_want = -8.0 if close else wb_gen0
		note_lb.text = T(String(D.lines("台所.板.案内")[0])) if _wb_near() else ""
		if demo5 and wb_t > 2.5 and not "--ch5wb60" in OS.get_cmdline_user_args(): _wb_end(false)     # the unattended run: one Ｅ (--ch5wb60: it waits, as a player who does nothing)
		elif wb_t > 60.0: _wb_end(true)

func _wb_end(by_herself: bool):
	wb_done = true; note_lb.text = ""
	print("STORY ch5 board %s t=%.1f" % ["herself" if by_herself else "E", t_now])
	_turn_to(wb_at + Vector3(0.0, -0.05, 0.0), 1.2)
	get_tree().create_timer(1.6).timeout.connect(func():
		wb_t = -1.0; gen_want = wb_gen0; talk_with = "makoto"
		_release())

func _kitchen_window() -> Vector3:
	var pts := []
	for mi in main.S.env_node.find_children("board_*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("board_cellar"): continue
		var q: Vector3 = (mi as Node3D).global_position
		if q.x + 4.8 < 6.2 or q.x + 4.8 > 10.2 or q.z + 6.3 < 4.3 or q.z + 6.3 > 8.3: continue
		pts.append(q)
	if pts.is_empty(): return gp(8.6, 8.0, 1.3)
	var mk: Vector3 = _rig("makoto").global_position
	pts.sort_custom(func(a, b): return a.distance_to(mk) < b.distance_to(mk))
	var c := Vector3.ZERO; var n := 0
	for q in pts:
		if (q as Vector3).distance_to(pts[0]) < 0.7: c += q; n += 1
	return c / n

func _back_near() -> bool:
	var p: Vector3 = player.global_position; var b := gp(BACK_DOOR[0], BACK_DOOR[1], 0.0)
	return Vector2(p.x - b.x, p.z - b.z).length() < 1.5 and not outside

func _out_tick(dt: float):
	outside = player.global_position.x + 4.8 > 10.05
	# the counted silence before the back door
	if not back_sil and not sil_counted and mode == FREE and boards_off < 4 and _back_near() and stage in ["peel", "done"] and not has_flag("went_out_4am"):
		back_sil = true; back_sil_t = 0.0; sil_counted = true
		var r = _line_row("澪", "（沈黙）"); back_sil_lb = r[1]; page_clear_t = -1.0
		Sound.one(self, "ch3_rattle", -10.0, gp(BACK_DOOR[0], BACK_DOOR[1], 1.0))   # the draught moves it on its hinge
		if below_i == 0: _below_step()   # the voice from below, if it has not come yet: she counts with it in her ears
		if stage == "done": end_wait = maxf(end_wait, 22.0)
	# 試作277（ユーザー「ここ、Eじゃなくて、普通に外に出られるように」）: walking on into the doorway takes her out (no Ｅ)
	if mode == FREE and boards_off < 4 and stage in ["peel", "done"] and not has_flag("went_out_4am") and not outside:
		var pp: Vector3 = player.global_position; var bd := gp(BACK_DOOR[0], BACK_DOOR[1], 0.0)
		if Vector2(pp.x - bd.x, pp.z - bd.z).length() < 0.75: _go_out()
	if back_sil:
		back_sil_t += dt
		if is_instance_valid(back_sil_lb): back_sil_lb.text = T("（沈黙・%s秒）") % num(int(back_sil_t))
		if not _back_near(): _back_sil_close()
	# out there: crouched to the low window while she looks at it, the boards under her fingers while Ｅ is held
	if outside:
		var crouch := look_k == "board" and mode == FREE
		player.eye_height = move_toward(player.eye_height, 1.0 if crouch else 1.52, dt * 1.6)
		var held := mode == FREE and look_k == "board" and (Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or demo_hold)
		_gust_tick(dt)
		var b = _board_now()
		var lift := gust_k * (0.15 + 0.035 * sin(t_now * 27.0))   # the gust pushes the board's free end out from the wall (seen, and heard as the rattle)
		if held and gust_k > 0.5:
			board_k += dt / GUST_PULL
			board_creak -= dt
			if board_creak <= 0.0: board_creak = randf_range(0.25, 0.45); Sound.one(self, "creak3", -10.0 + board_k * 6.0, gp(CWIN[0], CWIN[1], CWIN[2]))
			if b: (b as Node3D).rotation.x = (b as Node3D).get_meta("rx", 0.0) + lift + board_k * 0.06 + sin(t_now * 31.0) * 0.01
			if board_k >= 1.0: _board_off()
		elif held:
			# against the nails, between gusts: it does not move. A dry squeak now and then, the board trembles
			board_creak -= dt
			if board_creak <= 0.0: board_creak = randf_range(0.7, 1.1); Sound.one(self, "creak3", -22.0, gp(CWIN[0], CWIN[1], CWIN[2]))
			if b: (b as Node3D).rotation.x = (b as Node3D).get_meta("rx", 0.0) + lift + board_k * 0.06 + sin(t_now * 43.0) * 0.004
		else:
			if b: (b as Node3D).rotation.x = (b as Node3D).get_meta("rx", 0.0) + lift + board_k * 0.06
	elif player.eye_height < 1.52 and stage in ["peel", "done"]:
		player.eye_height = move_toward(player.eye_height, 1.52, dt * 1.6)

func _back_sil_close():
	back_sil = false
	page_clear_t = 6.0

func _go_out():
	_back_sil_close()
	set_flag("went_out_4am", true)   # (went_out — 外に出て、板を外した — is set at the first board: _board_off)
	if dn:
		for k in dn.doors.keys():
			var s: Dictionary = dn.doors[k]
			if s.key != "door_back": continue
			s.is_open = true
			create_tween().tween_property(s.pivot, "rotation:y", float(s.open), 0.9).set_trans(Tween.TRANS_SINE)
	Sound.one(self, "creak3", -6.0, gp(BACK_DOOR[0], BACK_DOOR[1], 1.0))
	_cwin_ready()
	if is_instance_valid(back_wall): back_wall.queue_free()
	_start(B("外.出る"))

func _cwin_ready():
	if not boards5.is_empty() or cwin_light: return
	for mi in main.S.env_node.find_children("board_cellar*", "MeshInstance3D", true, false):
		(mi as Node3D).visible = true
		(mi as Node3D).set_meta("rx", (mi as Node3D).rotation.x)
		boards5.append(mi)
	boards5.sort_custom(func(a, b): return (a as Node3D).global_position.y > (b as Node3D).global_position.y)   # the top one first
	# the bulb by the generator, through the window as the boards come off
	cwin_light = OmniLight3D.new(); cwin_light.light_color = Color(1.0, 0.78, 0.5); cwin_light.light_energy = 0.0
	cwin_light.omni_range = 3.2; cwin_light.shadow_enabled = true
	main.add_child(cwin_light); cwin_light.global_position = gp(CWIN[0] - 0.9, CWIN[1], CWIN[2] - 0.1)

func _board_now():
	return boards5[boards_off] if boards_off < boards5.size() else null

func _board_off():
	board_k = 0.0
	var b = _board_now()
	boards_off += 1
	set_flag("went_out", true)
	var at := gp(CWIN[0], CWIN[1], CWIN[2])
	Sound.one(self, "ch3_thud", -6.0, at); Sound.one(self, "creak3", -2.0, at)
	if b:
		var n := b as Node3D
		var tw := create_tween()
		tw.tween_property(n, "global_position", n.global_position + Vector3(0.22, 0.05, 0.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(n, "rotation:z", n.rotation.z + 0.9, 0.5)
		tw.tween_property(n, "global_position", n.global_position + Vector3(0.45, -0.32, 0.12), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): Sound.one(self, "ch3_thud", -16.0, n.global_position))
	# her fingers on the wood: blood on the next one (from the second it shows)
	var nb = _board_now()
	if nb and boards_off >= 1: _blood_on(nb as Node3D, boards_off)
	gen_want = minf(gen_want + 4.0, -6.0)
	if cwin_light: create_tween().tween_property(cwin_light, "light_energy", 0.35 * boards_off, 0.6)
	# out here the window's lines are the cellar's: the stair's steps go by unheard
	while below_i < BELOW.size() and int(BELOW[below_i][0]) <= _progress(): below_i += 1
	if boards_off >= 4: below_i = BELOW.size()
	var q: Array = B("外.板." + ["一", "二", "三", "四"][boards_off - 1])
	if boards_off == 3: get_tree().create_timer(3.6).timeout.connect(func(): gen_want = -7.0; mk_fell = true)   # (the fall at the end of 外.板.三)
	if mk_fell: q = q.filter(func(e): return not String(e.get("who", "")).begins_with("真琴") and not String(e.get("note", "")).contains("咳"))   # she fell already (地下.四): only the generator
	_start(q)

func _blood_on(n: Node3D, k: int):
	var m := MeshInstance3D.new(); var bx := BoxMesh.new()
	bx.size = Vector3(0.026, 0.05 + 0.03 * k, 0.02 + 0.012 * k); m.mesh = bx
	var mt := StandardMaterial3D.new(); mt.albedo_color = Color(0.32, 0.03, 0.03, 0.55 + 0.12 * k); mt.roughness = 0.35
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mt
	n.add_child(m)   # 2026-11-21 (review): on the board, so it goes with the board when that comes off
	m.global_position = n.global_position + Vector3(0.008, 0.035, randf_range(-0.12, 0.12))

# ---------------------------------------------------------------- the cellar: heard, not seen
func _below_start():
	below_q = []
	for e in B("地下.扉"):
		if e.has("t"): below_q.append(e)
	below_t = -9.0   # she is still on her way down

func _below_step():
	var k: String = BELOW[below_i][1]; below_i += 1
	print("STORY ch5 below %s peeled=%d t=%.1f" % [k, peeled_n, t_now])
	var t0 := below_t
	var i := 0
	for e in B(k):
		var e2: Dictionary = e.duplicate(); e2["t"] = t0 + 0.8 + i * 3.2; i += 1
		below_q.append(e2)
	if k == "地下.四": gen_want = -7.0; mk_fell = true

func _below_tick(dt: float):
	if below_q.is_empty() and stage != "peel" and stage != "done": return
	below_t += dt
	while not below_q.is_empty() and below_t >= float(below_q[0].t):
		if mode == TALK and not cur.has("silence") and not below_q[0].has("do"): below_t = float(below_q[0].t); break   # after what she is saying
		var e: Dictionary = below_q.pop_front()
		if e.has("if") and not has_flag(String(e["if"])): continue
		if e.has("do"):
			match String(e.do):
				"push": Sound.one(self, "creak3", -6.0, gp(5.5, 2.6, ZBASE + 1.0))
				"gen_loud": _gen_loud()
			continue
		if e.has("note"):
			var n := String(e.note)
			if n.contains("止まる"): Sound.one(self, "ch3_thud", -10.0, gp(5.5, 2.6, ZBASE + 1.0))
			if n.contains("肩で"): Sound.one(self, "ch3_thud", -12.0, gp(5.5, 2.6, ZBASE + 1.0))
			if n.contains("咳"): Sound.one(self, "ch3_cough", -9.0, gp(5.5, 4.0, ZBASE + 1.0))
			if n.contains("倒れる"): Sound.one(self, "ch3_thud", -7.0, gp(8.5, 6.0, ZBASE + 0.5))
			if mode == FREE: _line_row("", n, 22, "note"); page_clear_t = 7.0
			continue
		_voice(String(e.get("who", "")), String(e.get("text", "")))   # heard whether or not the line can be shown now
		if mode == FREE or cur.has("silence"):
			var r = _line_row(String(e.who), Tw(String(e.text)), SAY_SIZE, "say")
			page_clear_t = 8.0

# the silence at the back door, counted (the one in this chapter)
func _silence_open():
	var r = _line_row("澪", "（沈黙）")
	silence_lb = r[1]; silence_t = 0.0
	cur = {"silence": true}

func _talk_tick(dt):
	if cur.has("silence"):
		silence_t += dt
		if is_instance_valid(silence_lb): silence_lb.text = T("（沈黙・%s秒）") % num(int(silence_t))
		if silence_t >= silence_len: silence_t = -1.0; _next()
		return
	if cur.is_empty() and hold: return
	if _voice_on() and typed >= float(String(cur.get("text", "")).length()): read_t = 0.0   # she is still saying it
	super._talk_tick(dt)

func _advance():
	if cur.has("silence") or hold: return
	super._advance()

# ---------------------------------------------------------------- the end: back in the hall
func _end_scene():
	stage = "end"
	note_lb.text = ""; _set_mission("")
	var black := ColorRect.new(); black.color = Color(0, 0, 0, 0); black.set_anchors_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := CanvasLayer.new(); bl.layer = 12; add_child(bl); bl.add_child(black)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 0.8)
	tw.tween_callback(func():
		# by her: the blanket, the shut front door, the cellar's open door behind; the generator
		# down on her knees by her head, the candle on the boards beside her
		var at := [4.85, 3.05]
		player.global_position = gp(at[0], at[1], 0.0); player.velocity = Vector3.ZERO
		player.eye_height = 0.95; player.get_node("Head").position.y = 0.95
		var h := _nat_chest()
		_look_from(at, [h.x + 4.8, h.z + 6.3 - 0.25], 0.95, 0.1)
		candle_held = true)
	tw.tween_interval(0.6)
	tw.tween_property(black, "color:a", 0.0, 1.2)
	tw.tween_callback(func(): _start(B("五.終わり")))

func _end_card():
	stage = "fin"
	_clear_page(); note_lb.text = ""
	if card: card.queue_free()
	card = main.make_card(self, [[String(D.lines("五.カード")[2]), 64, 0]], Type.card(), false)
	card.visible = true
	get_tree().create_timer(5.0 if demo5 else 8.0).timeout.connect(func():
		if demo5: print("DEMO ch5 t=%.1f fails=%d" % [t_now, DEMO_FAILS]); DEMO_HOUSE = true
		if demo5 and "--ch5only" in OS.get_cmdline_user_args(): print("DEMO DONE ch5"); get_tree().quit(); return
		main.to_chapter("ch6" if ResourceLoader.exists("res://scripts/ch6.gd") else "ch11"))   # 第5章の終わり → 第6章「片づけ」

# ---------------------------------------------------------------- input
func _unhandled_input(e):
	if card_t > 0.0 or stage in ["end_card", "fin"]: return
	if _choice_input(e): return
	var press: bool = (e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_E) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if not press: return
	if wb_t >= 0.0:
		if not wb_done and _wb_near(): _wb_end(false)
		return
	if mode == TALK: _advance(); return
	if stage in ["peel", "done"]: _press_peel()

# ---------------------------------------------------------------- the unattended playthrough (--demo)
func _demo_script() -> Array:
	var st := []
	# 試作168: the kitchen door is in the wall x 6, y 6.0..6.85: through its middle (y 6.42). At y 6.2 she scraped its
	# south jamb, and when a leg ran late the timed path cut the corner into the wall (stuck at 5.77, 6.0)
	st.append(["wait_stage", "follow"]); st.append(["wait_free"])
	st.append(["walk", [[4.4, 3.0], [4.3, 3.1], [4.2, 3.3], [4.2, 3.8], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.75, 6.42], [8.1, 6.2], [8.7, 5.4], [BACK_STAND[0], BACK_STAND[1]]]])
	st.append(["wait_stage", "peel"]); st.append(["wait_free"])
	# the kitchen's own window first (any order is taken, 試作176), then the rest
	var routes := {
		"g1": [[6.6, 6.42], [5.75, 6.42], [5.5, 5.9], [5.0, 5.9], [4.8, 5.7], [4.8, 4.4], [4.1, 3.7], [3.6, 3.7], [2.7, 2.8], [2.7, 0.8], [2.6, 0.7]],
		"g2": [[2.6, 3.5], [0.7, 5.4], [0.7, 6.0], [0.5, 6.2]],
		"g3": [[0.5, 5.6], [0.9, 5.2], [1.6, 5.2], [3.1, 3.7], [4.1, 3.7], [4.3, 3.9], [4.3, 5.2], [5.0, 5.9], [5.5, 5.9], [5.75, 6.42], [6.5, 6.42], [7.4, 7.1]],
		"g4": [[7.4, 6.8], [7.9, 6.3], [9.4, 6.3], [9.5, 6.2]],
		"g5": [[9.5, 5.0], [9.4, 4.9]]}
	if order[0] != "g3":
		st.append(["walk", [[8.4, 6.3], [7.6, 6.9], [7.4, 7.1]]]); st.append(["tape", "g3"]); st.append(["wait_free"])
	st.append(["walk", [[7.4, 6.8], [6.6, 6.42]]])
	for k in ["g1", "g2", "g3", "g4", "g5"]:
		st.append(["walk", routes[k]]); st.append(["tape", k]); st.append(["wait_free"])
	st.append(["walk", [[8.2, 4.9], [6.6, 6.42], [5.7, 6.42], [5.5, 6.1]]]); st.append(["aim", gp(CELLAR_DOOR[0], CELLAR_DOOR[1], CELLAR_DOOR[2])]); st.append(["press"]); st.append(["wait_free"])
	st.append(["walk", [[5.75, 6.42], [8.0, 6.2], [9.3, 4.9]]]); st.append(["aim", gp(BACK_DOOR[0], BACK_DOOR[1], BACK_DOOR[2])]); st.append(["wait", 2.5])
	if not "--ch5stay" in OS.get_cmdline_user_args():   # 2026-11-20: out, and the four boards (--ch5stay: she stays in, the seconds count)
		st.append(["press"]); st.append(["wait_free"])
		st.append(["walk", [[10.55, 4.9], [10.88, 5.8], [10.88, 8.5], [10.88, 8.95], [10.25, 8.7], [10.45, 7.75]]])
		for i in 4: st.append(["board"]); st.append(["wait_free"])
		for w in [[[10.25, 8.7], [10.88, 8.95], [10.88, 8.5]], [[10.88, 7.2]], [[10.88, 5.6]], [[10.6, 5.0], [9.9, 4.9]], [[9.3, 4.9], [8.4, 5.4]]]: st.append(["walk", w])   # up the porch stair a leg at a time (slower up it than the timed path)
	st.append(["wait_stage", "end"])
	return st

func _demo_tick(dt):
	if "--ch5stair" in OS.get_cmdline_user_args():   # (a test: up the back porch stair)
		if t_now > 6.0 and stair_t < 0.0:
			stair_t = 0.0; player.global_position = gp(10.88, 7.2, -0.9); player.velocity = Vector3.ZERO
			var p0: Vector3 = player.global_position
			player.auto_path = [[0.0, p0.x, p0.z, 0.0, 0.0], [3.0, p0.x, gp(0, 4.9, 0).z, 0.0, 0.0]]; player.auto_t = 0.0
		if stair_t >= 0.0:
			stair_t += dt
			if fmod(stair_t, 0.25) < dt:
				print("STAIR t=%.2f plan=%s y=%.3f floor=%s vel=%s" % [stair_t, _plan_of(player), player.global_position.y, player.is_on_floor(), player.velocity])
				for i in player.get_slide_collision_count():
					var kc: KinematicCollision3D = player.get_slide_collision(i)
					print("  HIT ", (kc.get_collider() as Node).get_path() if kc.get_collider() is Node else "", " n=", kc.get_normal(), " at=", kc.get_position() + Vector3(4.8, 0, 6.3))
			if stair_t > 2.6 and stair_t < 2.65:
				for dv in [Vector3(0, 0, -0.1), Vector3(0, 0.05, -0.1), Vector3(0, 0.15, 0)]:
					var r := KinematicCollision3D.new()
					var hit: bool = player.test_move(player.global_transform, dv, r)
					print("TEST ", dv, " hit=", hit, " ", (r.get_collider() as Node).get_path() if hit and r.get_collider() is Node else "", " n=", r.get_normal() if hit else Vector3.ZERO, " at=", (r.get_position() + Vector3(4.8, 0, 6.3)) if hit else Vector3.ZERO)
			if stair_t > 5.0: get_tree().quit()
		return
	if demo_steps.is_empty():
		demo_steps = _demo_script(); ds = 0
		if start_at == "peel":
			while ds < demo_steps.size() and not (demo_steps[ds][0] == "wait_stage" and demo_steps[ds][1] == "peel"): ds += 1
	if ds >= demo_steps.size() or card_t > 0.0: return
	var s: Array = demo_steps[ds]
	if stage in ["end", "fin"] and s[0] != "wait_stage": ds += 1; return
	dwait += dt
	var done := false
	match String(s[0]):
		"wait_stage":
			done = stage == s[1]
			if dwait > 400.0: _dfail("never reached stage %s (at %s)" % [s[1], stage]); done = true
		"wait_free":
			done = mode == FREE and dwait > 0.5 and not hold
			if dwait > 150.0: _dfail("the talk did not end"); done = true
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
				var last: Array = s[1][-1]
				var at: Vector3 = gp(last[0], last[1], 0.0)
				var off := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
				if off > 0.3 and player.auto_t < float(s[2]) + 12.0: return
				if off > 0.6:
					_dfail("walk: stuck at %s on the way to %s" % [_plan_of(player), last])
					for i in player.get_slide_collision_count():
						var kc: KinematicCollision3D = player.get_slide_collision(i)
						print("C5HIT ", (kc.get_collider() as Node).get_path() if kc.get_collider() is Node else "", " n=", kc.get_normal(), " at=", kc.get_position() + Vector3(4.8, 0, 6.3), " y=", player.global_position.y)
				player.auto_path = []; done = true
		"aim":
			var cam: Camera3D = player.get_node("Head/Camera")
			var to: Vector3 = (s[1] as Vector3) - cam.global_position
			var k := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to.x, -to.z), k)
			player.pitch = lerpf(player.pitch, asin(clampf(to.normalized().y, -1.0, 1.0)), k)
			done = (-cam.global_basis.z).angle_to(to) < deg_to_rad(4.0) or dwait > 4.0
		"press":
			if mode == FREE: _press_peel(); done = true
		"wait":
			done = dwait > float(s[1])
		"board":
			var cam3: Camera3D = player.get_node("Head/Camera")
			var to3: Vector3 = gp(CWIN[0], CWIN[1], CWIN[2]) - cam3.global_position
			var k3 := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to3.x, -to3.z), k3)
			player.pitch = lerpf(player.pitch, asin(clampf(to3.normalized().y, -1.0, 1.0)), k3)
			if s.size() < 2: s.append(boards_off)
			demo_hold = dwait > 1.0 and mode == FREE and gust_k > 0.3   # it pulls with the wind, as asked of the player
			if boards_off > int(s[1]): demo_hold = false; done = true
			if dwait > 40.0: demo_hold = false; _dfail("board: not coming off (Mio %s, looking %s)" % [_plan_of(player), look_k]); done = true
		"tape":
			var gq := _gap(s[1])
			if gq.peeled and s.size() < 3: ds += 1; dwait = 0.0; return   # taken off already (any order)
			var cam2: Camera3D = player.get_node("Head/Camera")
			var to2: Vector3 = (gq.at as Vector3) - cam2.global_position
			var k2 := 1.0 - exp(-dt * 6.0)
			player.yaw = lerp_angle(player.yaw, atan2(-to2.x, -to2.z), k2)
			player.pitch = lerpf(player.pitch, asin(clampf(to2.normalized().y, -1.0, 1.0)), k2)
			if dwait > 1.2 and mode == FREE and s.size() < 3:
				var was := peeled_n
				_press_peel(); s.append(was)
			if s.size() >= 3: done = true
			if dwait > 20.0: _dfail("tape %s: cannot reach (Mio %s, looking %s)" % [s[1], _plan_of(player), look_k]); done = true
	if done: ds += 1; dwait = 0.0

func _dfail(what: String):
	DEMO_FAILS += 1
	print("DEMO FAIL ch5: %s t=%.1f" % [what, t_now])


# 試作232（ユーザー「同じ動きを続けるのも変」、3時半の真琴）: the think loop ran on the whole talk. She goes between the hand
# at her temple and standing (idle), each for a few seconds, while the talk lasts
func _mk_shift():
	if mode != TALK or not main.S.has("makoto_node"): return
	var cur: String = main.stand_of("makoto")
	if not cur in ["talk/think", "talk/idle"]: return
	get_tree().create_timer(randf_range(5.0, 8.0)).timeout.connect(func():
		if mode != TALK or main.walking("makoto") or not main.stand_of("makoto") in ["talk/think", "talk/idle"]: return
		if is_instance_valid(mk_palm): _mk_shift(); return   # her palm on the board: she keeps still
		main.set_stand("makoto", "talk/idle" if main.stand_of("makoto") == "talk/think" else "talk/think", 0.8)
		_mk_shift())


func _exit_tree():
	if is_instance_valid(mk_palm): mk_palm.queue_free()   # (on Makoto's own skeleton, which outlives the chapter)
