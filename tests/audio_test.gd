extends Node
## Headless audio checks: buses exist, and gameplay signals reach the Audio autoload.
## Run with:
##   godot --headless --path . res://tests/audio_test.tscn
## Exits with code 0 when every check passes, 1 otherwise.

const PLAYER := preload("res://scenes/objects/player.tscn")
const BLOCK := preload("res://scenes/objects/block.tscn")
const HAZARD := preload("res://scenes/objects/hazard.tscn")
const FAKE_FLOOR := preload("res://scenes/trolls/fake_floor.tscn")
const POP_SPIKES := preload("res://scenes/trolls/pop_spikes.tscn")
const INVISIBLE_BLOCK := preload("res://scenes/trolls/invisible_block.tscn")
const FALLING_CEILING := preload("res://scenes/trolls/falling_ceiling.tscn")
const RUNAWAY_GOAL := preload("res://scenes/trolls/runaway_goal.tscn")
const DECOY_GOAL := preload("res://scenes/trolls/decoy_goal.tscn")
const SPRING := preload("res://scenes/objects/spring.tscn")
const DART_TRAP := preload("res://scenes/trolls/dart_trap.tscn")
const FAKE_WALL := preload("res://scenes/trolls/fake_wall.tscn")
const MOVING_WALL := preload("res://scenes/trolls/moving_wall.tscn")
const GRAVITY_FIELD := preload("res://scenes/trolls/gravity_field.tscn")
const MIRROR_ZONE := preload("res://scenes/trolls/mirror_zone.tscn")
const SHIFTING_VOID := preload("res://scenes/trolls/shifting_void.tscn")
const CREEPING_SPIKES := preload("res://scenes/trolls/creeping_spikes.tscn")
const POP_BLOCK := preload("res://scenes/trolls/pop_block.tscn")
const CHEST := preload("res://scenes/trolls/treasure_chest.tscn")

var _failures := 0
var _world: Node2D
var _player: Player
var _heard: Array[StringName] = []


func _ready() -> void:
	Audio.played.connect(func(sound: StringName) -> void: _heard.append(sound))
	await _run("Music and SFX buses exist", _test_buses)
	await _run("music is set up to loop", _test_music)
	await _run("jump and land play", _test_jump_land)
	await _run("spawning is silent", _test_spawn_silent)
	await _run("wall jump plays", _test_wall_jump)
	await _run("death plays, then respawn", _test_death_respawn)
	await _run("fake floor plays", _test_fake_floor)
	await _run("pop spikes play", _test_pop_spikes)
	await _run("invisible block plays", _test_invisible_block)
	await _run("falling ceiling rumbles, then thuds", _test_falling_ceiling)
	await _run("runaway goal plays on each hop", _test_runaway_goal)
	await _run("decoy goal bites, then death plays", _test_decoy_goal)
	await _run("spring plays on bounce", _test_spring)
	await _run("dart trap plays when it fires", _test_dart_trap)
	await _run("secret passage chimes once", _test_fake_wall)
	await _run("moving wall grinds when triggered", _test_moving_wall)
	await _run("gravity flip plays", _test_gravity_field)
	await _run("mirror plays once per swap", _test_mirror_zone)
	await _run("shifting void hisses when it slides", _test_shifting_void)
	await _run("creeping spikes crackle as they creep and as they sink", _test_creeping_spikes)
	await _run("pop block clangs", _test_pop_block)
	await _run("good chest chimes", _test_chest_good)
	await _run("bad chest chimes, then the curse", _test_chest_bad)
	await _run("amulet shatters when it takes a hit", _test_shield)
	await _run("volume changes apply to the bus", _test_volume)
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _run(name: String, test: Callable) -> void:
	_world = Node2D.new()
	add_child(_world)
	_place(BLOCK, Vector2(0, 160), Vector2(320, 20))
	_player = PLAYER.instantiate()
	_player.position = Vector2(40, 159)
	_world.add_child(_player)
	await _frames(10)
	_heard.clear()
	var ok: bool = await test.call()
	print("%s  %s" % ["ok  " if ok else "FAIL", name])
	if not ok:
		print("      heard: %s" % [_heard])
		_failures += 1
	for action in ["move_left", "move_right", "jump"]:
		Input.action_release(action)
	_world.queue_free()
	await _frames(1)


func _place(scene: PackedScene, pos: Vector2, size := Vector2.ZERO) -> Node2D:
	var node: Node2D = scene.instantiate()
	node.position = pos
	if size != Vector2.ZERO:
		node.size = size
	_world.add_child(node)
	return node


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _test_buses() -> bool:
	return AudioServer.get_bus_index(&"Music") >= 0 and AudioServer.get_bus_index(&"SFX") >= 0


func _test_music() -> bool:
	var music: AudioStreamPlayer = null
	for child in Audio.get_children():
		if child is AudioStreamPlayer and child.bus == &"Music":
			music = child
	# Headless runs skip playback, so only check the setup.
	return music != null and music.stream.loop and music.stream.get_length() > 10.0


func _test_jump_land() -> bool:
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	await _frames(90)
	return _heard == [&"jump", &"land"]


func _test_spawn_silent() -> bool:
	# The player in _run already spawned and settled; nothing should have played.
	await _frames(30)
	return _heard.is_empty()


func _test_wall_jump() -> bool:
	_place(BLOCK, Vector2(100, 0), Vector2(16, 160))
	Input.action_press("move_right")
	await _frames(50)
	Input.action_press("jump")
	await _frames(15)
	Input.action_release("jump")
	await _frames(10)
	Input.action_press("jump")
	await _frames(2)
	return &"wall_jump" in _heard


func _test_death_respawn() -> bool:
	_place(HAZARD, Vector2(60, 152), Vector2(16, 8))
	Input.action_press("move_right")
	await _frames(40)
	if _heard.count(&"death") != 1:
		return false
	# A new player entering the tree after a death is a respawn.
	_world.add_child(PLAYER.instantiate())
	await _frames(1)
	return &"respawn" in _heard


func _test_fake_floor() -> bool:
	_place(FAKE_FLOOR, Vector2(100, 100), Vector2(48, 8))
	_player.position = Vector2(124, 99)
	await _frames(40)
	return &"fake_floor" in _heard


func _test_pop_spikes() -> bool:
	_place(POP_SPIKES, Vector2(80, 152), Vector2(16, 8))
	Input.action_press("move_right")
	await _frames(40)
	return &"pop_spikes" in _heard


func _test_decoy_goal() -> bool:
	_place(DECOY_GOAL, Vector2(80, 160))
	Input.action_press("move_right")
	await _frames(40)
	return &"pop_spikes" in _heard and &"death" in _heard


func _test_spring() -> bool:
	_place(SPRING, Vector2(60, 156))
	Input.action_press("move_right")
	await _frames(30)
	return &"jump" in _heard


func _test_dart_trap() -> bool:
	var trap: DartTrap = _dart_trap(Vector2(200, 154), Rect2(-170, -16, 40, 16))
	await _frames(10)
	return &"dart" in _heard


func _test_fake_wall() -> bool:
	_place(FAKE_WALL, Vector2(60, 112), Vector2(16, 48))
	Input.action_press("move_right")
	await _frames(60)
	Input.action_press("move_left")
	Input.action_release("move_right")
	await _frames(60)
	return _heard.count(&"secret") == 1


func _test_invisible_block() -> bool:
	_place(INVISIBLE_BLOCK, Vector2(32, 128), Vector2(16, 16))
	Input.action_press("jump")
	await _frames(30)
	return &"invisible_block" in _heard


func _test_falling_ceiling() -> bool:
	_place(FALLING_CEILING, Vector2(112, 40), Vector2(32, 16))
	_player.position = Vector2(90, 159)
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	await _frames(120)
	var rumble := _heard.find(&"falling_ceiling")
	return rumble >= 0 and _heard.find(&"ceiling_thud") > rumble


func _test_runaway_goal() -> bool:
	var goal: RunawayGoal = RUNAWAY_GOAL.instantiate()
	goal.position = Vector2(80, 160)
	goal.flee_points = PackedVector2Array([Vector2(200, 160), Vector2(280, 160)])
	_world.add_child(goal)
	Input.action_press("move_right")
	await _frames(150)
	Input.action_release("move_right")
	# Let the last hop's tween finish before the world is freed.
	await _frames(60)
	return _heard.count(&"runaway_goal") == 2


func _test_volume() -> bool:
	var before: float = Audio.volumes[&"SFX"]
	Audio.set_volume(&"SFX", 0.5)
	var ok := is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), linear_to_db(0.5))
	Audio.set_volume(&"SFX", before)
	return ok


## Trigger set before entering the tree, as a saved room would.
func _dart_trap(pos: Vector2, trigger: Rect2) -> DartTrap:
	var trap: DartTrap = DART_TRAP.instantiate()
	trap.position = pos
	trap.trigger = trigger
	_world.add_child(trap)
	return trap


func _test_moving_wall() -> bool:
	var wall: MovingWall = MOVING_WALL.instantiate()
	wall.position = Vector2(200, 100)
	wall.size = Vector2(16, 16)
	wall.travel = Vector2(0, -32)
	wall.trigger = Rect2(-160, 0, 40, 60)
	_world.add_child(wall)
	await _frames(10)
	return _heard.count(&"grind") == 1


func _test_gravity_field() -> bool:
	var field: GravityField = GRAVITY_FIELD.instantiate()
	field.position = Vector2(30, 100)
	field.size = Vector2(20, 60)
	_world.add_child(field)
	await _frames(10)
	return &"gravity" in _heard


func _test_mirror_zone() -> bool:
	var zone: MirrorZone = MIRROR_ZONE.instantiate()
	zone.position = Vector2(30, 100)
	zone.size = Vector2(20, 60)
	_world.add_child(zone)
	await _frames(10)
	# Already mirrored: walking back in again changes nothing and stays quiet.
	_player.position = Vector2(80, 159)
	await _frames(10)
	_player.position = Vector2(40, 159)
	await _frames(10)
	return _heard.count(&"mirror") == 1


func _test_shifting_void() -> bool:
	var v: ShiftingVoid = SHIFTING_VOID.instantiate()
	v.position = Vector2(200, 100)
	v.size = Vector2(100, 8)
	v.positions = PackedFloat32Array([10, 60])
	v.on_jump = true
	_world.add_child(v)
	await _frames(2)
	Input.action_press("jump")
	await _frames(10)
	return _heard.count(&"void_shift") == 1


func _test_creeping_spikes() -> bool:
	var c: CreepingSpikes = CREEPING_SPIKES.instantiate()
	c.position = Vector2(0, 152)
	c.size = Vector2(320, 8)
	c.safe_cell = 4
	c.delay = 0.0
	c.creep_interval = 0.01
	c.hold = 0.1
	_world.add_child(c)
	await _frames(90)
	return _heard.count(&"frost") == 2


func _test_pop_block() -> bool:
	var block: PopBlock = POP_BLOCK.instantiate()
	block.position = Vector2(32, 160)
	block.size = Vector2(16, 16)
	block.trigger = Rect2(0, -8, 16, 8)
	_world.add_child(block)
	await _frames(10)
	return &"pop_block" in _heard


func _chest(gift: TreasureChest.Gift) -> void:
	var chest: TreasureChest = CHEST.instantiate()
	chest.position = Vector2(40, 160)
	chest.gift = gift
	_world.add_child(chest)
	await _frames(60)


func _test_chest_good() -> bool:
	await _chest(TreasureChest.Gift.DOUBLE_JUMP)
	return _heard == [&"chest"]


func _test_chest_bad() -> bool:
	await _chest(TreasureChest.Gift.LEAD_BOOTS)
	return _heard == [&"chest", &"curse"]


func _test_shield() -> bool:
	_player.shields = 1
	_place(HAZARD, Vector2(32, 152), Vector2(16, 8))
	await _frames(10)
	return &"shield" in _heard and not &"death" in _heard
