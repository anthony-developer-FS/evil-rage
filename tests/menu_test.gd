extends Node
## Headless checks for the level catalog and the world and level select menu.
## Run with:
##   godot --headless --path . res://tests/menu_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const MAIN := preload("res://scenes/main.tscn")

var _failures := 0
var _main: Node
var _menu: LevelSelect


func _ready() -> void:
	_check("every room_N scene is in the catalog, in order", _test_catalog_order())
	_check("worlds follow world themes", _test_catalog_worlds())
	_check("room titles drop their number", _test_catalog_titles())
	_main = MAIN.instantiate()
	add_child(_main)
	_menu = _main.get_node("LevelSelect")
	await _frames(2)
	_check("game opens on the menu with room 1 focused", _test_opens_on_menu())
	_check("one world button per world", _menu._world_buttons.size() == LevelCatalog.worlds().size())
	_check("picking a room plays it", await _test_pick_room())
	_check("Esc pauses and focuses the current room", await _test_pause())
	_check("Esc backs out to worlds, then resumes", await _test_back_out())
	_check("rooms of another world can be picked", await _test_other_world())
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().paused = false
	get_tree().quit(0 if _failures == 0 else 1)


func _check(name: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", name])
	if not ok:
		_failures += 1


func _test_catalog_order() -> bool:
	var numbers: Array[int] = []
	for world in LevelCatalog.worlds():
		for level in world.levels:
			numbers.append(level.number)
	var files := 0
	for file in DirAccess.get_files_at(LevelCatalog.ROOMS_DIR):
		if file.begins_with("room_") and file.ends_with(".tscn"):
			files += 1
	var sorted := numbers.duplicate()
	sorted.sort()
	return files > 0 and numbers.size() == files and numbers == sorted


func _test_catalog_worlds() -> bool:
	var worlds := LevelCatalog.worlds()
	if worlds.is_empty() or worlds[0].name != "The Jungle":
		return false
	for i in worlds.size():
		if worlds[i].levels.is_empty() or worlds[i].theme == null:
			return false
		if i > 0 and worlds[i].theme == worlds[i - 1].theme:
			return false
		for level in worlds[i].levels:
			var room: Room = load(level.path).instantiate()
			var same := room.world_theme == worlds[i].theme
			room.free()
			if not same:
				return false
	return true


func _test_catalog_titles() -> bool:
	var first := LevelCatalog.worlds()[0].levels[0]
	return first.number == 1 and first.title != "" and not first.title.begins_with("1.")


func _test_opens_on_menu() -> bool:
	return (_menu._root.visible and not _menu.resumable
		and Game.world.get_child_count() == 0
		and get_viewport().gui_get_focus_owner() == _menu._room_buttons[0])


func _test_pick_room() -> bool:
	_menu._room_buttons[1].pressed.emit()
	await _frames(3)
	return (not _menu._root.visible and not get_tree().paused
		and Game.current_room() == LevelCatalog.worlds()[0].levels[1].path
		and Game.world.get_child_count() == 1)


func _test_pause() -> bool:
	_press("menu")
	await _frames(2)
	return (_menu._root.visible and get_tree().paused and _menu.resumable
		and get_viewport().gui_get_focus_owner() == _menu._room_buttons[1])


func _test_back_out() -> bool:
	_press("ui_cancel")
	await _frames(2)
	var on_world := get_viewport().gui_get_focus_owner() == _menu._world_buttons[0]
	_press("ui_cancel")
	await _frames(2)
	return on_world and not _menu._root.visible and not get_tree().paused


func _test_other_world() -> bool:
	_press("menu")
	await _frames(2)
	var worlds := LevelCatalog.worlds()
	var index := mini(2, worlds.size() - 1)
	_menu._world_buttons[index].grab_focus()
	await _frames(1)
	var last := worlds[index].levels.back() as LevelCatalog.Level
	_menu._room_buttons.back().pressed.emit()
	await _frames(3)
	return Game.current_room() == last.path and not get_tree().paused


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
