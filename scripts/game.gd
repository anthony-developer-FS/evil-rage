extends Node
## Autoload. Survives room reloads, so it owns the death counters and the taunts.

signal deaths_changed(total: int, in_room: int)
signal taunted(line: String)

const TAUNTS := [
	"Skill issue.",
	"The floor was never real.",
	"Have you tried not dying?",
	"That one was on you. Probably.",
	"Again. I'm enjoying this.",
	"Trust nothing. Especially me.",
	"So close. Not really.",
	"Your controller is fine. You're not.",
]

var total_deaths := 0
var room_deaths := 0
var last_taunt := ""
var _room_path := ""


func _unhandled_input(event: InputEvent) -> void:
	# F11 or Alt+Enter. The 320x180 game scales by whole numbers, so it stays
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


## Reloading the whole room on death resets every trap for free.
func restart_room() -> void:
	get_tree().call_deferred("reload_current_scene")


func go_to_room(path: String) -> void:
	room_deaths = 0
	last_taunt = ""
	get_tree().call_deferred("change_scene_to_file", path)


## Called by each room on _ready so per-room counters reset only on a new room.
func enter_room(path: String) -> void:
	if path != _room_path:
		_room_path = path
		room_deaths = 0
		last_taunt = ""
	deaths_changed.emit(total_deaths, room_deaths)


func _pick_taunt() -> String:
	var line: String = TAUNTS.pick_random()
	while line == last_taunt and TAUNTS.size() > 1:
		line = TAUNTS.pick_random()
	return line
