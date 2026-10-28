extends SceneTree
func _init():
	var v = VoxelGI.new(); var l = LightmapGI.new()
	print("VoxelGI.bake ", v.has_method("bake"))
	print("LightmapGI methods ", ClassDB.class_get_method_list("LightmapGI", true).map(func(m): return m.name).filter(func(n): return "bake" in n))
	quit()
