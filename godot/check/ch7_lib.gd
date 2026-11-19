extends SceneTree
# 第7章：export_ch7.py の mio_talk.glb と <名前>_c7.glb（PEOPLE=1）から、動きだけの AnimationLibrary を作る（talk_lib.gd と同じ）。
#   mio_talk.res（澪の "talk"）、kiryu_c7.res・taiga_c7.res・natsuki_c7.res（この章だけの "c7"：座る、笑う、飲む、指す、驚く）
# godot --headless --path <プロジェクト> -s res://check/ch7_lib.gd
const ONCE := ["startle", "react", "point", "sit", "drink"]   # 一度きりの動き（繰り返さず、最後の形で止まる）
func _initialize():
	for e in [["mio", "talk"], ["kiryu", "c7"], ["taiga", "c7"], ["natsuki", "c7"]]:
		var k: String = e[0]; var kind: String = e[1]
		var p := "res://assets/dusk/%s_%s.glb" % [k, kind]
		if not ResourceLoader.exists(p): print("NO ", p); continue
		var tv: Node = (load(p) as PackedScene).instantiate()
		var tsrc: AnimationPlayer = tv.find_children("*", "AnimationPlayer", true, false)[0]
		var tlib := AnimationLibrary.new()
		for nm in tsrc.get_animation_list():
			var clip := String(nm).get_slice("_rig_", 1)
			if clip == "": continue
			var an: Animation = tsrc.get_animation(nm).duplicate(true)
			an.loop_mode = Animation.LOOP_NONE if clip in ONCE else Animation.LOOP_LINEAR
			tlib.add_animation(clip, an)
		print("SAVE ", k, " ", kind, " ", tlib.get_animation_list(), " ", ResourceSaver.save(tlib, "res://assets/dusk/%s_%s.res" % [k, kind]))
		tv.free()
	quit()
