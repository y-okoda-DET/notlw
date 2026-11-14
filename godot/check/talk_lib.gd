extends SceneTree
# export_talk.py の <k>_talk.glb から、動きだけの AnimationLibrary（<k>_talk.res）を作る。godot --headless --path godot -s res://check/talk_lib.gd
func _initialize():
	for k in ["kiryu", "taiga", "natsuki", "makoto"]:
		var tv: Node = (load("res://assets/dusk/%s_talk.glb" % k) as PackedScene).instantiate()
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
