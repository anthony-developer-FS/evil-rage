extends Node
## Autoload. Survives room reloads, so it owns the death counters and the taunts.

signal deaths_changed(total: int, in_room: int)
signal taunted(line: String)
## seconds > 0 hides the banner again after that long.
signal banner_shown(text: String, seconds: float)
signal title_shown(text: String, color: Color)
## total counts banked coins plus the ones picked up on this attempt.
signal coins_changed(total: int)

const TAUNTS := [
	"Skill issue.",
	"The floor was never real.",
	"Have you tried not dying?",
	"That one was on you. Probably.",
	"Again. I'm enjoying this.",
	"Trust nothing. Especially me.",
	"So close. Not really.",
	"Your controller is fine. You're not.",
	"Not every exit is an exit.",
	"You held jump, didn't you?",
	"Up is a direction. Not always the right one.",
	"Which way is up again?",
	"Left. No, your other left.",
	"The walls were always closing in.",
	"It changed. So should you.",
]

var total_deaths := 0
var room_deaths := 0
## Coins kept from rooms already beaten. Coins picked up on this attempt only
## count once the exit is reached; dying throws them away with the room.
var coins := 0
var attempt_coins := 0
var last_taunt := ""
var _room_path := ""
var _world_theme: WorldTheme
## The 320x180 SubViewport that rooms render into, set by main.gd. Null when a room
## is run on its own from the editor; then rooms load as the current scene instead.
var world: SubViewport


func _unhandled_input(event: InputEvent) -> void:
	# F11 or Alt+Enter. The 320x180 world scales by whole numbers, so it stays
	# pixel-sharp at 1080p (6x), 1440p (8x) and 4K (12x).
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func register_death() -> void:
	total_deaths += 1
	room_deaths += 1
	last_taunt = _pick_taunt()
	deaths_changed.emit(total_deaths, room_deaths)
	taunted.emit(last_taunt)


func collect_coin() -> void:
	attempt_coins += 1
	coins_changed.emit(coins + attempt_coins)


## Reloading the whole room on death resets every trap for free.
func restart_room() -> void:
	attempt_coins = 0
	if world:
		_load_room.call_deferred(_room_path)
	else:
		get_tree().call_deferred("reload_current_scene")


func go_to_room(path: String) -> void:
	coins += attempt_coins
	attempt_coins = 0
	room_deaths = 0
	last_taunt = ""
	if world:
		_load_room.call_deferred(path)
	else:
		get_tree().call_deferred("change_scene_to_file", path)


func show_banner(text: String, seconds := 0.0) -> void:
	banner_shown.emit(text, seconds)


func show_title(text: String, color := Color(0.5, 0.5, 0.6)) -> void:
	title_shown.emit(text, color)


func _load_room(path: String) -> void:
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	world.add_child(load(path).instantiate())


## Called by each room on _ready so per-room counters reset only on a new room.
func enter_room(path: String) -> void:
	if path != _room_path:
		_room_path = path
		room_deaths = 0
		last_taunt = ""
	deaths_changed.emit(total_deaths, room_deaths)


## Called by each room after enter_room. Crossing into a new world announces it.
func enter_world(theme: WorldTheme) -> void:
	if theme == _world_theme:
		return
	_world_theme = theme
	if theme:
		show_banner(theme.display_name, 2.5)


func _pick_taunt() -> String:
	var line: String = TAUNTS.pick_random()
	while line == last_taunt and TAUNTS.size() > 1:
		line = TAUNTS.pick_random()
	return line
