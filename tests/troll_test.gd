extends Node
## Headless troll trap checks. Run with:
##   godot --headless --path . res://tests/troll_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const PLAYER := preload("res://scenes/objects/player.tscn")
const BLOCK := preload("res://scenes/objects/block.tscn")
const FAKE_FLOOR := preload("res://scenes/trolls/fake_floor.tscn")
const POP_SPIKES := preload("res://scenes/trolls/pop_spikes.tscn")
const RUNAWAY_GOAL := preload("res://scenes/trolls/runaway_goal.tscn")
const INVISIBLE_BLOCK := preload("res://scenes/trolls/invisible_block.tscn")
const FALLING_CEILING := preload("res://scenes/trolls/falling_ceiling.tscn")

var _failures := 0
var _world: Node2D
var _player: Player


func _ready() -> void:
	await _run("fake floor drops the player", _test_fake_floor)
	await _run("pop spikes are hidden, then kill", _test_pop_spikes)
	await _run("goal runs away, then can be reached", _test_runaway_goal)
	await _run("invisible block appears and bonks", _test_invisible_block)
	await _run("falling ceiling crushes the player", _test_falling_ceiling)
	await _run("falling ceiling lands on the floor", _test_ceiling_lands)
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _run(name: String, test: Callable) -> void:
	_world = Node2D.new()
	add_child(_world)
	_place(BLOCK, Vector2(0, 160), Vector2(320, 20))
	_player = PLAYER.instantiate()
	_player.position = Vector2(40, 159)
	_world.add_child(_player)
	var ok: bool = await test.call()
	print("%s  %s" % ["ok  " if ok else "FAIL", name])
	if not ok:
		_failures += 1
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)
	_world.queue_free()
	await _frames(1)


func _place(scene: PackedScene, pos: Vector2, size := Vector2.ZERO) -> Node2D:
	var node: Node2D = scene.instantiate()
	node.position = pos
	# Set size before entering the tree, as a saved room would.
	if size != Vector2.ZERO:
		node.size = size
	_world.add_child(node)
	return node


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _test_fake_floor() -> bool:
	_place(FAKE_FLOOR, Vector2(100, 100), Vector2(48, 8))
	_player.position = Vector2(124, 99)
	await _frames(90)
	return _player.position.y > 140.0


func _test_pop_spikes() -> bool:
	var spikes: PopSpikes = _place(POP_SPIKES, Vector2(120, 152), Vector2(16, 8))
	await _frames(5)
	var hidden: bool = not spikes.visible
	Input.action_press("move_right")
	await _frames(120)
	return hidden and spikes.visible and _player.is_dead


func _test_runaway_goal() -> bool:
	var goal: RunawayGoal = _place(RUNAWAY_GOAL, Vector2(120, 160))
	goal.flee_points = PackedVector2Array([Vector2(200, 160)])
	var reached := [false]
	goal.reached.connect(func() -> void: reached[0] = true)
	Input.action_press("move_right")
	await _frames(70)
	var fled: bool = goal.global_position.x > 190.0 and not reached[0]
	await _frames(240)
	return fled and reached[0]


func _test_invisible_block() -> bool:
	var block: InvisibleBlock = _place(INVISIBLE_BLOCK, Vector2(32, 120), Vector2(16, 16))
	await _frames(10)
	Input.action_press("jump")
	await _frames(30)
	return block.visible and _player.global_position.y >= 150.0


func _test_falling_ceiling() -> bool:
	_place(FALLING_CEILING, Vector2(112, 40), Vector2(32, 16))
	_player.position = Vector2(90, 159)
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	await _frames(120)
	return _player.is_dead


func _test_ceiling_lands() -> bool:
	var ceiling: FallingCeiling = _place(FALLING_CEILING, Vector2(112, 40), Vector2(32, 16))
	_player.position = Vector2(128, 159)
	_player.set_physics_process(false)
	_player.collision_layer = 0
	await _frames(5)
	# Trigger by teleporting the player through the zone, then out of the way.
	_player.collision_layer = 2
	await _frames(5)
	_player.position = Vector2(20, 159)
	await _frames(120)
	return is_equal_approx(ceiling.position.y + ceiling.size.y, 160.0)
