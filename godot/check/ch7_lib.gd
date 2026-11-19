extends SceneTree
# 第7章：export_ch7.py の mio_talk.glb から、動きだけの AnimationLibrary（mio_talk.res）を作る（talk_lib.gd と同じ）。
# godot --headless --path <プロジェクト> -s res://check/ch7_lib.gd
func _initialize():
	for k in ["mio"]:
		var p := "res://assets/dusk/%s_talk.glb" % k
		if not ResourceLoader.exists(p): print("NO ", p); continue
		var tv: Node = (load(p) as PackedScene).instantiate()
		var tsrc: AnimationPlayer = tv.find_children("*", "AnimationPlayer", true, false)[0]
		var tlib := AnimationLibrary.new()
		for nm in tsrc.get_animation_list():
			var clip := String(nm).get_slice("_rig_", 1)
			if clip == "": continue
			var an: Animation = tsrc.get_animation(nm).duplicate(true)
			an.loop_mode = Animation.LOOP_LINEAR
			tlib.add_animation(clip, an)
		print("SAVE ", k, " ", ResourceSaver.save(tlib, "res://assets/dusk/%s_talk.res" % k))
		tv.free()
	quit()
