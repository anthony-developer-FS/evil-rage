extends Node
## Proves every prototype room can be beaten by playing a scripted run through it,
## and that the obvious naive route fails because of the troll. Run with:
##   godot --headless --path . res://tests/level_test.tscn
## Pass room names after "--" to check only those rooms, e.g. "-- room_07 room_08".
## Set LEVEL_KIND=solve or LEVEL_KIND=naive to play only that run.
## Exits with code 0 when every check passes, 1 otherwise.
##
## Script commands: ["right", x] / ["left", x] hold a direction until the player
## crosses x. ["jump", frames] holds jump for that many physics frames, keeping the
## current direction, or switches to the direction given as a third element, e.g.
## ["jump", 60, "left"]. ["hold", frames] keeps the direction. ["idle", frames] lets go.
## ["key", "left", x] holds that key until the player crosses x from either side,
## for when mirrored controls make the left key walk right.
## After the script ends the current direction is held until the run resolves.
##
## Rooms that change after a death also get "retry_solve" and "retry_naive" runs,
## played as if the player had already died once in the room.

## Room 9: walk into the shaft, then wall jump between its walls until the top.
const SHAFT_CLIMB := [
	["right", 162.5], ["jump", 20], ["jump", 8],
	["left", 141.5], ["jump", 8], ["right", 162.5], ["jump", 8],
	["left", 141.5], ["jump", 8], ["right", 162.5], ["jump", 8],
	["left", 141.5], ["jump", 8], ["right", 162.5], ["jump", 8],
	["left", 141.5], ["jump", 8],
]

var runs := {
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
	"room_07": {
		"solve": [["right", 84], ["jump", 60], ["right", 150], ["jump", 60], ["right", 200], ["jump", 60], ["idle", 40], ["left", 240], ["jump", 60], ["left", 0]],
		"naive": [["right", 84], ["jump", 60], ["right", 400]],
	},
	"room_08": {
		"solve": [["right", 400]],
		"naive": [["right", 100], ["jump", 200], ["right", 400]],
	},
	"room_09": {
		# Same climb both times. Hopping off it onto the trapdoor is the trap.
		"solve": SHAFT_CLIMB + [["right", 175], ["idle", 30], ["right", 177], ["jump", 60], ["right", 400]],
		"naive": SHAFT_CLIMB + [["right", 400]],
	},
	"room_10": {
		"solve": [["right", 40], ["jump", 200], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_11": {
		"solve": [["right", 236], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_12": {
		"solve": [["right", 48], ["jump", 60], ["right", 140], ["jump", 60], ["right", 196], ["jump", 200], ["right", 400]],
		"naive": [["right", 76], ["jump", 60], ["right", 400]],
	},
	"room_13": {
		# Hop the rubble. The face only shoots along the floor.
		"solve": [["right", 70], ["jump", 60], ["right", 122], ["jump", 60], ["right", 186], ["jump", 60],
			["right", 240], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_14": {
		# Jump from the second stone straight to the fourth.
		"solve": [["right", 76], ["jump", 30], ["right", 128], ["jump", 60], ["right", 192], ["idle", 10],
			["right", 200], ["jump", 30], ["right", 400]],
		"naive": [["right", 76], ["jump", 30], ["right", 128], ["jump", 20], ["right", 160], ["jump", 20], ["right", 400]],
	},
	"room_15": {
		# Peek off the edge to set it off, back up onto the dais, wait out the volley.
		"solve": [["right", 44], ["left", 30], ["idle", 360], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_16": {
		"solve": [["right", 92], ["jump", 8], ["right", 188], ["jump", 8], ["right", 400]],
		"naive": [["right", 92], ["jump", 60], ["right", 188], ["jump", 60], ["right", 400]],
	},
	"room_17": {
		"solve": [["left", 0]],
		"naive": [["right", 400]],
	},
	"room_18": {
		# Run the bridge, then stop the moment the portcullis drops and hop over it.
		"solve": [["right", 214], ["idle", 30], ["right", 240], ["idle", 60], ["left", 226], ["idle", 20],
			["right", 230], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_19": {
		# Each hole fires as you get near it. Stop, let the darts land, move on.
		"solve": [["right", 48], ["idle", 80], ["right", 110], ["idle", 80], ["right", 174], ["idle", 80], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_20": {
		# Land on the spring with jump held, steer left onto the ledge, walk into the wall.
		"solve": [["right", 30], ["jump", 75], ["jump", 90, "left"], ["left", 0]],
		"naive": [["right", 400]],
	},
	"room_21": {
		# Wait for the lift to come back down, step on, and lean on the cliff until it is level.
		"solve": [["right", 100], ["idle", 300], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_22": {
		# Poke the trigger, back off, then run under while the press is up.
		"solve": [["right", 120], ["left", 100], ["idle", 100], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_23": {
		"solve": [["right", 70], ["idle", 60], ["right", 88], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_24": {
		# Let each press slam before going under it, waiting in the gaps between them.
		"solve": [["right", 70], ["idle", 70], ["right", 140], ["idle", 60], ["right", 212], ["idle", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_25": {
		"solve": [["right", 88], ["jump", 60], ["right", 240], ["jump", 40], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_26": {
		"solve": [["right", 76], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_27": {
		# Step off, hang in the gap until under the first shelf, then drift right.
		"solve": [["right", 60], ["idle", 150], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_28": {
		# Hop stone to stone without stopping, and skip the narrow one.
		"solve": [["right", 42], ["jump", 20], ["right", 82], ["jump", 20], ["right", 122], ["jump", 14],
			["right", 178], ["jump", 20], ["right", 220], ["jump", 20], ["right", 236], ["jump", 20], ["right", 250], ["jump", 120], ["right", 400]],
		"naive": [["right", 42], ["jump", 20], ["right", 82], ["jump", 20], ["right", 124], ["jump", 8],
			["right", 400]],
	},
	"room_29": {
		"solve": [["right", 92], ["jump", 8], ["right", 400]],
		"naive": [["right", 92], ["jump", 120], ["right", 400]],
	},
	"room_30": {
		# Board the ferry before it leaves, chase the exit off the island, jump into the
		# draft and float right past the crumbly lip of the rock.
		"solve": [["right", 80], ["idle", 300], ["right", 190], ["jump", 120], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_31": {
		# Jump the pit and swap to left the moment the mirror flips you.
		"solve": [["right", 112], ["jump", 30], ["right", 143], ["key", "left", 400]],
		"naive": [["right", 112], ["jump", 60], ["right", 400]],
	},
	"room_32": {
		# Walk until the hidden mirror turns you round, then swap keys before the spikes.
		"solve": [["right", 157], ["key", "left", 400]],
		"naive": [["right", 400]],
	},
	"room_33": {
		# First try: the patch over the pit is rotten, so jump it. After a death it is
		# solid, and jumping it lands on spikes instead.
		"solve": [["right", 150], ["jump", 60], ["right", 400]],
		"naive": [["right", 400]],
		"retry_solve": [["right", 400]],
		"retry_naive": [["right", 150], ["jump", 60], ["right", 400]],
	},
	"room_34": {
		# Swap to left over the first pit, back to right over the second, and to left
		# again when the hidden one turns you round at the end.
		"solve": [["right", 88], ["jump", 30], ["right", 112], ["key", "left", 196], ["jump", 30],
			["key", "left", 224], ["right", 273], ["key", "left", 400]],
		"naive": [["right", 88], ["jump", 30], ["right", 400]],
	},
	"room_35": {
		"solve": [["key", "left", 136], ["jump", 60], ["key", "left", 400]],
		"naive": [["right", 400]],
		"retry_solve": [["right", 136], ["jump", 14], ["key", "left", 400]],
		"retry_naive": [["key", "left", 136], ["jump", 60], ["key", "left", 400]],
	},
	"room_36": {
		# On the ceiling a jump goes down: hop the hole in it.
		"solve": [["right", 170], ["jump", 30], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_37": {
		"solve": [["right", 96], ["jump", 30], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_38": {
		# A short hop stays under the hidden field.
		"solve": [["right", 112], ["jump", 8], ["right", 400]],
		"naive": [["right", 112], ["jump", 60], ["right", 400]],
	},
	"room_39": {
		# Let each piston stab the ceiling before walking over it.
		"solve": [["right", 96], ["idle", 72], ["right", 168], ["idle", 36], ["right", 400]],
		"naive": [["right", 400]],
	},
	"room_40": {
		# Ride the lift, jump into the draft, swap keys at the mirror, hop the biting
		# door into the flip, then walk back along the ceiling to the real exit.
		"solve": [["right", 80], ["idle", 300], ["right", 136], ["jump", 60], ["right", 200], ["key", "left", 264],
			["jump", 40], ["key", "left", 306], ["key", "right", 200]],
		"naive": [["right", 400]],
	},
}

var _failures := 0


func _ready() -> void:
	var only := OS.get_cmdline_user_args()
	for room_name in runs:
		if not only.is_empty() and not room_name in only:
			continue
		for kind: String in runs[room_name]:
			if OS.get_environment("LEVEL_KIND") not in ["", kind, kind.trim_prefix("retry_")]:
				continue
			var deaths := 1 if kind.begins_with("retry_") else 0
			var result: String = await _play(room_name, runs[room_name][kind], deaths)
			var ok: bool = (result == "goal") == kind.ends_with("solve")
			print("%s  %s %s -> %s" % ["ok  " if ok else "FAIL", room_name, kind, result])
			if not ok:
				_failures += 1
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _play(room_name: String, script: Array, deaths := 0) -> String:
	var path := "res://scenes/rooms/%s.tscn" % room_name
	# Pretend the player is already in this room with that many deaths, so
	# retry variants pick their layout and the room keeps the count.
	Game.enter_room(path)
	Game.room_deaths = deaths
	var room: Room = load(path).instantiate()
	# Keep the run inside this test: no scene changes, no reloads.
	room.get_node("Goal").next_room = ""
	add_child(room)
	room.player.died.disconnect(room._on_player_died)
	var state := {"result": ""}
	room.player.died.connect(func() -> void: state.result = "dead")
	room.get_node("Goal").reached.connect(func() -> void: state.result = "goal")
	# Set LEVEL_TRACE=1 to print the player's path while writing a run.
	var trace := func() -> void:
		if Engine.get_physics_frames() % 6 == 0 and state.result == "":
			print("      ", room.player.global_position.round(), " v", room.player.velocity.round())
	if OS.get_environment("LEVEL_TRACE") != "":
		get_tree().physics_frame.connect(trace)

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
			"key":
				_set_dir(cmd[1])
				dir = cmd[1]
				var was_left: bool = room.player.global_position.x < cmd[2]
				for i in 600:
					if (room.player.global_position.x < cmd[2]) != was_left or state.result != "":
						break
					await get_tree().physics_frame
			"jump":
				if cmd.size() > 2:
					_set_dir(cmd[2])
					dir = cmd[2]
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
	if get_tree().physics_frame.is_connected(trace):
		get_tree().physics_frame.disconnect(trace)
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
