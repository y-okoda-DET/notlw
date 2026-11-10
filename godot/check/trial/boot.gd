extends Node
# the night-print trial: the exported pack with this folder's shader over it (files here win: replace_files=false)
# --dodge= --dodgemax= set the print's uniforms once the game's own scene is up
func _ready():
	var p := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--basepack="): p = a.substr(11)
	print("BOOT pack ", p, " ", ProjectSettings.load_resource_pack(p, false))
	var m: Node = load("res://main.tscn").instantiate()
	if FileAccess.file_exists("res://trial_main.gd"): m.set_script(load("res://trial_main.gd")); print("BOOT trial_main")
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dodge="): m.riso.set_shader_parameter("dodge", float(a.substr(8)))
		if a.begins_with("--dodgemax="): m.riso.set_shader_parameter("dodge_max", float(a.substr(11)))
	print("BOOT riso ", m.riso)
