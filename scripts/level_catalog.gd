class_name LevelCatalog
extends RefCounted
## Finds every room in scenes/rooms/ and groups them into worlds, so the level
## select menu needs no edits when rooms or worlds are added. A room is any
## room_<number>.tscn. Rooms are ordered by that number, and a run of rooms that
## share a world_theme is one world. The room title comes from its Title label.

const ROOMS_DIR := "res://scenes/rooms/"

static var _worlds: Array[World] = []


class Level:
	var path: String
	var number: int
	## The Title label's text without its "7. " prefix.
	var title: String


class World:
	var theme: WorldTheme
	var name: String
	var levels: Array[Level] = []


## Every world in play order. Scanned once, then cached.
static func worlds() -> Array[World]:
	if _worlds.is_empty():
		_worlds = scan()
	return _worlds


## The world holding the room at `path`, or null.
static func world_of(path: String) -> World:
	for world in worlds():
		for level in world.levels:
			if level.path == path:
				return world
	return null


static func scan() -> Array[World]:
	var levels: Array[Level] = []
	var number_re := RegEx.create_from_string("^room_(\\d+)\\.tscn$")
	for file in DirAccess.get_files_at(ROOMS_DIR):
		# Exported builds list "room_01.tscn.remap" for each converted scene.
		file = file.trim_suffix(".remap")
		var m := number_re.search(file)
		if m == null:
			continue
		var level := Level.new()
		level.path = ROOMS_DIR + file
		level.number = m.get_string(1).to_int()
		levels.append(level)
	levels.sort_custom(func(a: Level, b: Level) -> bool: return a.number < b.number)

	var result: Array[World] = []
	for level in levels:
		var theme := _read_room(level)
		if result.is_empty() or result.back().theme != theme:
			var world := World.new()
			world.theme = theme
			world.name = theme.display_name if theme and theme.display_name != "" else "Uncharted"
			result.append(world)
		result.back().levels.append(level)
	return result


## Reads the room's theme and title from its packed scene without instancing it.
static func _read_room(level: Level) -> WorldTheme:
	var theme: WorldTheme = null
	level.title = "Room %d" % level.number
	var scene := load(level.path) as PackedScene
	if scene == null:
		return null
	var state := scene.get_state()
	for i in state.get_node_count():
		var path := str(state.get_node_path(i))
		if i == 0 or path == "./Title":
			for p in state.get_node_property_count(i):
				var prop := state.get_node_property_name(i, p)
				var value = state.get_node_property_value(i, p)
				if i == 0 and prop == &"world_theme" and value is WorldTheme:
					theme = value
				elif i > 0 and prop == &"text":
					level.title = _strip_number(str(value))
	return theme


static func _strip_number(text: String) -> String:
	var m := RegEx.create_from_string("^\\d+\\.\\s*").search(text)
	return text.substr(m.get_end()) if m else text
