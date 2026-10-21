extends Node
## Headless movement checks. Run with:
##   godot --headless --path . res://tests/movement_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const PLAYER := preload("res://scenes/objects/player.tscn")
const BLOCK := preload("res://scenes/objects/block.tscn")
const HAZARD := preload("res://scenes/objects/hazard.tscn")

var _failures := 0
var _world: Node2D
var _player: Player


func _ready() -> void:
	await _run("lands on the floor", _test_lands)
	await _run("reaches run speed", _test_run_speed)
	await _run("full jump is higher than a short hop", _test_variable_jump)
	await _run("coyote time allows a late jump", _test_coyote)
	await _run("buffered jump fires on landing", _test_buffer)
	await _run("wall jump pushes away from the wall", _test_wall_jump)
	await _run("spikes kill the player", _test_hazard)
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _run(name: String, test: Callable) -> void:
	_build_world()
	var ok: bool = await test.call()
	print("%s  %s" % ["ok  " if ok else "FAIL", name])
	if not ok:
		_failures += 1
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)
	_world.queue_free()
	await _frames(1)


## Floor from x 0 to 160 at y 160, a wall at x 200, and the player at (40, 160).
func _build_world() -> void:
	_world = Node2D.new()
	add_child(_world)
	_add_block(Vector2(0, 160), Vector2(160, 20))
	_add_block(Vector2(200, 0), Vector2(16, 180))
	_player = PLAYER.instantiate()
	_player.position = Vector2(40, 159)
	_world.add_child(_player)


func _add_block(pos: Vector2, size: Vector2) -> void:
	var b: Block = BLOCK.instantiate()
	b.position = pos
	_world.add_child(b)
	b.size = size


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _test_lands() -> bool:
	await _frames(20)
	return _player.is_on_floor()


func _test_run_speed() -> bool:
	await _frames(10)
	Input.action_press("move_right")
	await _frames(30)
	return is_equal_approx(_player.velocity.x, _player.tuning.run_speed)


func _jump_height(hold_frames: int) -> float:
	await _frames(10)
	var start_y := _player.position.y
	var peak := start_y
	Input.action_press("jump")
	for i in 120:
		if i == hold_frames:
			Input.action_release("jump")
		await _frames(1)
		peak = minf(peak, _player.position.y)
	return start_y - peak


func _test_variable_jump() -> bool:
	var full := await _jump_height(100)
	_player.position = Vector2(40, 159)
	var hop := await _jump_height(4)
	print("      full jump %.1f px, short hop %.1f px" % [full, hop])
	return full > 30.0 and hop < full * 0.6


func _test_coyote() -> bool:
	_player.position = Vector2(150, 159)
	await _frames(10)
	Input.action_press("move_right")
	# Walk off the ledge at x 160 and wait until just after leaving the floor.
	for i in 120:
		await _frames(1)
		if not _player.is_on_floor():
			break
	await _frames(int(_player.tuning.coyote_time * 120 * 0.5))
	Input.action_press("jump")
	await _frames(2)
	return _player.velocity.y < -_player.tuning.jump_velocity * 0.8


func _test_buffer() -> bool:
	_player.position = Vector2(40, 120)
	# Fall until a few frames from the floor, then press jump early.
	for i in 240:
		await _frames(1)
		if _player.position.y > 154.0:
			break
	Input.action_press("jump")
	await _frames(8)
	return _player.velocity.y < 0.0


func _test_wall_jump() -> bool:
	# Against the wall at x 200, in the air.
	_player.position = Vector2(194, 80)
	Input.action_press("move_right")
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	return _player.velocity.x < 0.0 and _player.velocity.y < 0.0


func _test_hazard() -> bool:
	var spikes: Hazard = HAZARD.instantiate()
	spikes.position = Vector2(80, 152)
	_world.add_child(spikes)
	spikes.size = Vector2(32, 8)
	await _frames(10)
	Input.action_press("move_right")
	await _frames(60)
	return _player.is_dead
