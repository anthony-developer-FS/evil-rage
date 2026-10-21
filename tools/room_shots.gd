extends Node
## Saves a 320x180 screenshot of each room, for checking art without playing.
## Needs a display (not --headless). Run:
##   godot --path . res://tools/room_shots.tscn -- room_01 room_13
## Shots go to user://shots/<room>.png. No room names means every room.

func _ready() -> void:
	get_window().size = Vector2i(320, 180)
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		for f in DirAccess.get_files_at("res://scenes/rooms"):
			if f.begins_with("room_") and f.ends_with(".tscn"):
				names.append(f.get_basename())
	DirAccess.make_dir_recursive_absolute("user://shots")
	for room_name in names:
		var room: Node = load("res://scenes/rooms/%s.tscn" % room_name).instantiate()
		add_child(room)
		room.get_node("Title").show()
		for i in 30:
			await get_tree().process_frame
		var path := "user://shots/%s.png" % room_name
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", ProjectSettings.globalize_path(path))
		room.queue_free()
		await get_tree().process_frame
	get_tree().quit()
