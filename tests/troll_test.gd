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
const DECOY_GOAL := preload("res://scenes/trolls/decoy_goal.tscn")
const HAZARD := preload("res://scenes/objects/hazard.tscn")
const SPRING := preload("res://scenes/objects/spring.tscn")
const DART_TRAP := preload("res://scenes/trolls/dart_trap.tscn")
const FAKE_WALL := preload("res://scenes/trolls/fake_wall.tscn")
const MOVING_WALL := preload("res://scenes/trolls/moving_wall.tscn")
const GRAVITY_FIELD := preload("res://scenes/trolls/gravity_field.tscn")
const MIRROR_ZONE := preload("res://scenes/trolls/mirror_zone.tscn")
const SLOW_FALL := preload("res://scenes/trolls/slow_fall_zone.tscn")
const RETRY_VARIANT := preload("res://scenes/trolls/retry_variant.tscn")
const SHIFTING_VOID := preload("res://scenes/trolls/shifting_void.tscn")
const CREEPING_SPIKES := preload("res://scenes/trolls/creeping_spikes.tscn")
const POP_BLOCK := preload("res://scenes/trolls/pop_block.tscn")
const CHEST := preload("res://scenes/trolls/treasure_chest.tscn")

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
	await _run("decoy goal kills instead of finishing", _test_decoy_goal)
	await _run("spring gives a short hop when walked onto", _test_spring_tap)
	await _run("spring launches high when jump is held", _test_spring_hold)
	await _run("dart trap fires when the player crosses it", _test_dart_hits)
	await _run("dart breaks on a wall in its way", _test_dart_blocked)
	await _run("fake wall lets the player walk through", _test_fake_wall)
	await _run("moving wall carries a rider", _test_moving_wall_rides)
	await _run("closing walls crush", _test_moving_wall_crushes)
	await _run("spiked face of a moving wall kills", _test_moving_wall_spikes)
	await _run("gravity field drops the player onto the ceiling", _test_gravity_field)
	await _run("upside down, jump goes down", _test_gravity_jump)
	await _run("mirror zone swaps left and right", _test_mirror_zone)
	await _run("slow-fall zone caps the fall", _test_slow_fall)
	await _run("downward spikes kill from below", _test_ceiling_spikes)
	await _run("retry variant only exists on its attempts", _test_retry_variant)
	await _run("shifting void lunges at a player who comes close", _test_void_approach)
	await _run("shifting void moves every jump, in order", _test_void_jump)
	await _run("creeping spikes spare only the safe square", _test_creep_safe)
	await _run("creeping spikes kill outside the safe square", _test_creep_kills)
	await _run("creeping spikes chase out of the safe square", _test_creep_chase)
	await _run("a runner outpaces the chasing spikes", _test_creep_escape)
	await _run("pop block hides, then shoves the player", _test_pop_block)
	await _run("chest: feathered boots give a mid-air jump", _test_chest_double_jump)
	await _run("chest: amulet takes one hit", _test_chest_shield)
	await _run("chest: amulet does not save a fall", _test_chest_shield_fall)
	await _run("chest: lead boots shorten the jump", _test_chest_lead)
	await _run("chest: mimic bites", _test_chest_mimic)
	await _run("chest: alarm sets off a trap", _test_chest_alarm)
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


func _test_decoy_goal() -> bool:
	var decoy: DecoyGoal = _place(DECOY_GOAL, Vector2(80, 160))
	var reached := [false]
	decoy.reached.connect(func() -> void: reached[0] = true)
	Input.action_press("move_right")
	await _frames(60)
	return _player.is_dead and not reached[0]


## Peak height reached after walking onto a spring, with or without jump held.
func _spring_peak(hold_jump: bool) -> float:
	var spring: Spring = _place(SPRING, Vector2(60, 156))
	spring.power = 480.0
	if hold_jump:
		# Jump from further back so jump is held, not freshly pressed, on landing.
		_player.position = Vector2(20, 159)
		Input.action_press("jump")
	Input.action_press("move_right")
	var peak := 160.0
	for i in 120:
		await _frames(1)
		peak = minf(peak, _player.global_position.y)
		if _player.global_position.x > 56.0:
			Input.action_release("move_right")
	return 160.0 - peak


func _test_spring_tap() -> bool:
	var height := await _spring_peak(false)
	print("      spring bounce walked on: %.1f px" % height)
	return height > 20.0 and height < 40.0


func _test_spring_hold() -> bool:
	var height := await _spring_peak(true)
	print("      spring bounce jump held: %.1f px" % height)
	return height > 100.0


func _test_dart_hits() -> bool:
	var trap: DartTrap = _dart_trap(Vector2(200, 154), Rect2(-80, -16, 40, 16))
	Input.action_press("move_right")
	await _frames(150)
	return _player.is_dead


func _test_dart_blocked() -> bool:
	var trap: DartTrap = _dart_trap(Vector2(200, 154), Rect2(-180, -16, 40, 16))
	_place(BLOCK, Vector2(120, 120), Vector2(8, 40))
	await _frames(120)
	return not _player.is_dead and trap.get_parent().get_children().all(
		func(n: Node) -> bool: return not n is DartTrap.Dart)


func _test_fake_wall() -> bool:
	_place(FAKE_WALL, Vector2(100, 112), Vector2(16, 48))
	Input.action_press("move_right")
	await _frames(120)
	return _player.global_position.x > 140.0


## Trigger set before entering the tree, as a saved room would.
func _dart_trap(pos: Vector2, trigger: Rect2) -> DartTrap:
	var trap: DartTrap = DART_TRAP.instantiate()
	trap.position = pos
	trap.trigger = trigger
	_world.add_child(trap)
	return trap


func _test_moving_wall_rides() -> bool:
	var lift: MovingWall = MOVING_WALL.instantiate()
	lift.position = Vector2(30, 140)
	lift.size = Vector2(24, 8)
	lift.travel = Vector2(0, -60)
	lift.duration = 1.0
	# Put the player on the lift before it exists, so it never spawns around them.
	_player.position = Vector2(40, 139)
	await _frames(1)
	_world.add_child(lift)
	await _frames(180)
	return not _player.is_dead and absf(_player.global_position.y - 80.0) < 2.0


func _test_moving_wall_crushes() -> bool:
	_place(BLOCK, Vector2(0, 100), Vector2(16, 60))
	var wall: MovingWall = MOVING_WALL.instantiate()
	wall.position = Vector2(100, 100)
	wall.size = Vector2(16, 60)
	wall.travel = Vector2(-84, 0)
	wall.duration = 0.6
	wall.trigger = Rect2(-90, 0, 40, 60)
	_world.add_child(wall)
	_player.position = Vector2(24, 159)
	await _frames(120)
	return _player.is_dead


func _test_moving_wall_spikes() -> bool:
	var wall: MovingWall = MOVING_WALL.instantiate()
	wall.position = Vector2(200, 120)
	wall.size = Vector2(16, 40)
	wall.spikes = MovingWall.Side.LEFT
	wall.travel = Vector2.ZERO
	_world.add_child(wall)
	Input.action_press("move_right")
	await _frames(240)
	return _player.is_dead


func _test_gravity_field() -> bool:
	_place(BLOCK, Vector2(0, 40), Vector2(320, 8))
	var field: GravityField = GRAVITY_FIELD.instantiate()
	field.position = Vector2(80, 48)
	field.size = Vector2(16, 112)
	_world.add_child(field)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	await _frames(120)
	return _player.gravity_sign < 0.0 and _player.is_on_floor() and absf(_player.global_position.y - 62.0) < 2.0


func _test_gravity_jump() -> bool:
	_place(BLOCK, Vector2(0, 40), Vector2(320, 8))
	_player.position = Vector2(40, 62)
	_player.set_gravity_inverted(true)
	await _frames(30)
	var rest := _player.global_position.y
	Input.action_press("jump")
	var lowest := rest
	for i in 90:
		await _frames(1)
		lowest = maxf(lowest, _player.global_position.y)
	print("      upside-down jump: %.1f px" % (lowest - rest))
	return lowest - rest > 30.0 and absf(_player.global_position.y - rest) < 1.0


func _test_mirror_zone() -> bool:
	var zone: MirrorZone = MIRROR_ZONE.instantiate()
	zone.position = Vector2(60, 120)
	zone.size = Vector2(8, 40)
	_world.add_child(zone)
	Input.action_press("move_right")
	await _frames(60)
	var turned: bool = _player.controls_reversed
	var x := _player.global_position.x
	await _frames(60)
	# Holding right now walks left, back out the way they came.
	return turned and _player.global_position.x < x - 20.0


func _test_slow_fall() -> bool:
	var zone: SlowFallZone = SLOW_FALL.instantiate()
	zone.position = Vector2(20, 0)
	zone.size = Vector2(40, 160)
	_world.add_child(zone)
	_player.position = Vector2(40, 20)
	var fastest := 0.0
	for i in 60:
		await _frames(1)
		fastest = maxf(fastest, _player.velocity.y)
	return fastest <= zone.fall_speed + 0.01 and _player.global_position.y < 60.0


func _test_ceiling_spikes() -> bool:
	var spikes: Hazard = HAZARD.instantiate()
	spikes.position = Vector2(30, 128)
	spikes.size = Vector2(24, 8)
	spikes.pointing = Vector2.DOWN
	_world.add_child(spikes)
	Input.action_press("jump")
	await _frames(40)
	return _player.is_dead


func _test_retry_variant() -> bool:
	var saved := Game.room_deaths
	var first: RetryVariant = RETRY_VARIANT.instantiate()
	first.max_deaths = 0
	var later: RetryVariant = RETRY_VARIANT.instantiate()
	later.min_deaths = 1
	Game.room_deaths = 2
	_world.add_child(first)
	_world.add_child(later)
	await _frames(2)
	Game.room_deaths = saved
	return not is_instance_valid(first) and is_instance_valid(later)


## Swaps the full-width test floor for a short ledge on the left, so a strip of
## trap floor can sit to its right.
func _ledge(width: float) -> void:
	_world.get_child(0).free()
	_place(BLOCK, Vector2(0, 160), Vector2(width, 20))


func _void(pos: Vector2, size: Vector2, positions: PackedFloat32Array) -> ShiftingVoid:
	var v: ShiftingVoid = SHIFTING_VOID.instantiate()
	v.position = pos
	v.size = size
	v.positions = positions
	return v


func _test_void_approach() -> bool:
	_ledge(80)
	# Hole starts well ahead, then lunges back under the player's feet.
	var v := _void(Vector2(80, 160), Vector2(240, 20), PackedFloat32Array([80, 64]))
	v.approach = 24.0
	v.hole_width = 24.0
	_world.add_child(v)
	Input.action_press("move_right")
	await _frames(240)
	return v.hole_x == 64.0 and _player.global_position.y > 175.0


func _test_void_jump() -> bool:
	_ledge(80)
	var v := _void(Vector2(80, 160), Vector2(240, 20), PackedFloat32Array([120, 40, 200]))
	v.on_jump = true
	_world.add_child(v)
	await _frames(10)
	var seen: Array[float] = []
	for i in 3:
		Input.action_press("jump")
		await _frames(3)
		Input.action_release("jump")
		await _frames(90)
		seen.append(v.hole_x)
	return seen == [40.0, 200.0, 120.0] and not _player.is_dead


func _spikes(safe: int) -> CreepingSpikes:
	var c: CreepingSpikes = CREEPING_SPIKES.instantiate()
	c.position = Vector2(0, 152)
	c.size = Vector2(320, 8)
	c.safe_cell = safe
	c.delay = 0.0
	c.creep_interval = 0.02
	c.hold = 10.0
	return c


func _test_creep_safe() -> bool:
	# The player stands on x 40, which is cells 4 and 5.
	var c := _spikes(4)
	_world.add_child(c)
	await _frames(180)
	var bare := not c.is_cell_deadly(4) and not c.is_cell_deadly(5)
	var covered := c.is_cell_deadly(3) and c.is_cell_deadly(6) and c.is_cell_deadly(0) and c.is_cell_deadly(39)
	return bare and covered and not _player.is_dead


func _test_creep_kills() -> bool:
	_world.add_child(_spikes(20))
	await _frames(180)
	return _player.is_dead


func _test_creep_chase() -> bool:
	var c := _spikes(4)
	c.hold = 0.2
	c.chase_delay = 0.2
	_world.add_child(c)
	await _frames(120)
	var retracted := c.phase >= CreepingSpikes.Phase.RETRACTED and not _player.is_dead
	await _frames(120)
	# Standing still on the safe square: the chase starts right under the player.
	return retracted and _player.is_dead


func _test_creep_escape() -> bool:
	var c := _spikes(4)
	c.hold = 0.2
	c.chase_delay = 0.3
	_world.add_child(c)
	await _frames(60)
	await c.retracted
	Input.action_press("move_right")
	await _frames(300)
	return not _player.is_dead and _player.global_position.x > 300.0


func _test_pop_block() -> bool:
	var block: PopBlock = POP_BLOCK.instantiate()
	block.position = Vector2(100, 160)
	block.size = Vector2(16, 16)
	block.travel = Vector2(0, -16)
	block.duration = 0.15
	block.trigger = Rect2(-10, -24, 10, 24)
	block.shove = Vector2(-240, -120)
	_world.add_child(block)
	await _frames(5)
	var hidden := not block.visible
	Input.action_press("move_right")
	var furthest := 0.0
	for i in 120:
		await _frames(1)
		furthest = maxf(furthest, _player.global_position.x)
	# Thrown back and up, nowhere near the block.
	return hidden and block.visible and _player.global_position.x < furthest - 24.0 and not _player.is_dead


func _chest(gift: TreasureChest.Gift) -> TreasureChest:
	var chest: TreasureChest = CHEST.instantiate()
	chest.position = Vector2(60, 160)
	chest.gift = gift
	_world.add_child(chest)
	return chest


func _jump_peak() -> float:
	var rest := _player.global_position.y
	var top := rest
	Input.action_press("jump")
	for i in 90:
		await _frames(1)
		top = minf(top, _player.global_position.y)
	Input.action_release("jump")
	await _frames(60)
	return rest - top


func _test_chest_double_jump() -> bool:
	_chest(TreasureChest.Gift.DOUBLE_JUMP)
	_player.position = Vector2(60, 159)
	await _frames(10)
	var rest := _player.global_position.y
	Input.action_press("jump")
	await _frames(30)
	Input.action_release("jump")
	await _frames(2)
	Input.action_press("jump")
	var top := rest
	for i in 60:
		await _frames(1)
		top = minf(top, _player.global_position.y)
	print("      double jump: %.1f px" % (rest - top))
	return rest - top > 50.0


func _test_chest_shield() -> bool:
	_chest(TreasureChest.Gift.SHIELD)
	_place(HAZARD, Vector2(96, 152), Vector2(32, 8))
	_player.position = Vector2(60, 159)
	await _frames(5)
	var had := _player.shields
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	var survived := not _player.is_dead and _player.shields == 0
	Input.action_press("move_right")
	await _frames(200)
	# One hit only: the next spikes still kill once the blink wears off.
	_place(HAZARD, Vector2(200, 152), Vector2(120, 8))
	await _frames(200)
	return had == 1 and survived and _player.is_dead


func _test_chest_shield_fall() -> bool:
	_ledge(80)
	_chest(TreasureChest.Gift.SHIELD)
	Input.action_press("move_right")
	await _frames(90)
	# A bottomless fall has to kill, or the player would fall forever.
	_player.die(true)
	return _player.is_dead


func _test_chest_lead() -> bool:
	var before: float = await _jump_peak()
	_chest(TreasureChest.Gift.LEAD_BOOTS)
	_player.position = Vector2(60, 159)
	await _frames(10)
	var after: float = await _jump_peak()
	print("      lead boots: %.1f px -> %.1f px" % [before, after])
	return after < before * 0.6


func _test_chest_mimic() -> bool:
	var chest := _chest(TreasureChest.Gift.MIMIC)
	Input.action_press("move_right")
	await _frames(40)
	return chest.opened and _player.is_dead


func _test_chest_alarm() -> bool:
	var c := _spikes(20)
	c.trigger = Rect2(400, 0, 8, 8)
	_world.add_child(c)
	var chest := _chest(TreasureChest.Gift.ALARM)
	chest.wakes = chest.get_path_to(c)
	await _frames(10)
	var asleep := c.phase == CreepingSpikes.Phase.WAITING
	Input.action_press("move_right")
	await _frames(20)
	return asleep and c.phase != CreepingSpikes.Phase.WAITING
