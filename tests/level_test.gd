extends Node
## Proves every prototype room can be beaten by playing a scripted run through it,
## and that the obvious naive route fails because of the troll. Run with:
##   godot --headless --path . res://tests/level_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.
##
## Script commands: ["right", x] / ["left", x] hold a direction until the player
## crosses x. ["jump", frames] holds jump for that many physics frames, keeping the
## current direction. ["hold", frames] keeps the direction. ["idle", frames] lets go.
## After the script ends the current direction is held until the run resolves.

const RUNS := {
	"room_01": {
		"solve": [["right", 84], ["jump", 60], ["idle", 20], ["right", 142], ["jump", 60], ["right", 400]],
		"naive": [["right", 84], ["jump", 60], ["idle", 20], ["right", 148], ["jump", 8], ["right", 400]],
	},
	"room_02": {
		"solve": [["right", 66], ["jump", 40], ["right", 132], ["jump", 40], ["right", 188], ["jump", 60], ["right", 400]],
		"naive": [["right", 66], ["jump", 40], ["right", 132], ["jump", 40], ["right", 400]],
	},
	"room_03": {
		"solve": [["right", 275], ["idle", 30], ["left", 200], ["idle", 30], ["right", 220], ["jump", 60], ["idle", 30], ["right", 248], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_04": {
		"solve": [["right", 100], ["jump", 60], ["right", 400]],
		"naive": [["right", 113], ["jump", 60], ["right", 400]],
	},
	"room_05": {
		"solve": [["right", 136], ["idle", 1], ["left", 110], ["idle", 60], ["right", 128], ["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_06": {
		"solve": [["right", 50], ["jump", 60], ["right", 148], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
}

var _failures := 0


func _ready() -> void:
	for room_name in RUNS:
		for kind in ["solve", "naive"]:
			var result: String = await _play(room_name, RUNS[room_name][kind])
			var ok: bool = (result == "goal") == (kind == "solve")
			print("%s  %s %s -> %s" % ["ok  " if ok else "FAIL", room_name, kind, result])
			if not ok:
				_failures += 1
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _play(room_name: String, script: Array) -> String:
	var room: Room = load("res://scenes/rooms/%s.tscn" % room_name).instantiate()
	# Keep the run inside this test: no scene changes, no reloads.
	room.get_node("Goal").next_room = ""
	add_child(room)
	room.player.died.disconnect(room._on_player_died)
	var state := {"result": ""}
	room.player.died.connect(func() -> void: state.result = "dead")
	room.get_node("Goal").reached.connect(func() -> void: state.result = "goal")

	var dir := ""
	for cmd in script:
		if state.result != "":
			break
		match cmd[0]:
			"right", "left":
				_set_dir(cmd[0])
				dir = cmd[0]
				for i in 600:
					var x := room.player.global_position.x
					if (dir == "right" and x >= cmd[1]) or (dir == "left" and x <= cmd[1]) or state.result != "":
						break
					await get_tree().physics_frame
			"jump":
				Input.action_press("jump")
				await _frames(cmd[1], state)
				Input.action_release("jump")
			"hold":
				await _frames(cmd[1], state)
			"idle":
				_set_dir("")
				dir = ""
				await _frames(cmd[1], state)
	await _frames(600, state)
	if state.result == "":
		print("      timed out with player at ", room.player.global_position, " goal at ", room.get_node("Goal").global_position)
	_set_dir("")
	Input.action_release("jump")
	room.queue_free()
	await get_tree().physics_frame
	return state.result if state.result != "" else "timeout"


func _set_dir(dir: String) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if dir != "":
		Input.action_press("move_" + dir)


func _frames(n: int, state: Dictionary) -> void:
	for i in n:
		if state.result != "":
			return
		await get_tree().physics_frame
