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
const PORTAL := preload("res://scenes/trolls/portal.tscn")
const COIN := preload("res://scenes/trolls/coin.tscn")
const REAPER := preload("res://scenes/trolls/reaper.tscn")
const GHOST := preload("res://scenes/trolls/ghost.tscn")

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
	await _run("portal sends the player to its exit, still running", _test_portal)
	await _run("a pair of portals does not bounce the player back", _test_portal_pair)
	await _run("an exit-only portal does nothing", _test_portal_exit_only)
	await _run("gold coin is collected and counted", _test_coin_gold)
	await _run("bomb coin chimes, then explodes", _test_coin_bomb)
	await _run("a bomb with a fuse can be outrun", _test_coin_fuse)
	await _run("a bomb with approach can be baited", _test_coin_bait)
	await _run("platform coins hold the player up", _test_coin_platform)
	await _run("Death rises on the far side of the screen", _test_reaper_far_side)
	await _run("Death's saw kills a player who stands still", _test_reaper_saw)
	await _run("a block stops a plain saw", _test_saw_blocked)
	await _run("a growing saw swells where the player stood", _test_saw_grow)
	await _run("a chasing saw follows the player", _test_saw_chase)
	await _run("Death fires bullets level", _test_reaper_bullet)
	await _run("Death moves across the room when approached", _test_reaper_moves)
	await _run("touching Death kills", _test_reaper_touch)
	await _run("ghost chases while the player looks away", _test_ghost_chases)
	await _run("ghost freezes while watched", _test_ghost_shy)
	await _run("ghost kills on touch", _test_ghost_kills)
	await _run("a sleeping ghost wakes on its trigger", _test_ghost_trigger)
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _run(name: String, test: Callable) -> void:
	# Death picks where to appear at random. Seed it, so a failure can be replayed.
	seed(name.hash())
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


func _portal(pos: Vector2) -> Portal:
	var portal: Portal = PORTAL.instantiate()
	portal.position = pos
	_world.add_child(portal)
	return portal


func _test_portal() -> bool:
	var a := _portal(Vector2(80, 160))
	var b := _portal(Vector2(240, 160))
	a.exit = a.get_path_to(b)
	Input.action_press("move_right")
	var moved := [false]
	_player.teleported.connect(func() -> void: moved[0] = true)
	for i in 120:
		await _frames(1)
		if moved[0]:
			break
	var arrived := _player.global_position.x > 230.0 and _player.velocity.x > 50.0
	await _frames(20)
	return arrived and _player.global_position.x > 245.0


func _test_portal_pair() -> bool:
	var a := _portal(Vector2(80, 160))
	var b := _portal(Vector2(240, 160))
	a.exit = a.get_path_to(b)
	b.exit = b.get_path_to(a)
	var trips := [0]
	_player.teleported.connect(func() -> void: trips[0] += 1)
	Input.action_press("move_right")
	await _frames(50)
	Input.action_release("move_right")
	await _frames(20)
	var one_way: bool = trips[0] == 1 and _player.global_position.x > 245.0
	# And back through b, the other way.
	Input.action_press("move_left")
	await _frames(60)
	return one_way and trips[0] == 2 and _player.global_position.x < 80.0


func _test_portal_exit_only() -> bool:
	_portal(Vector2(80, 160))
	Input.action_press("move_right")
	await _frames(90)
	return _player.global_position.x > 100.0


func _coin(pos: Vector2, kind: Coin.Kind) -> Coin:
	var coin: Coin = COIN.instantiate()
	coin.position = pos
	coin.kind = kind
	_world.add_child(coin)
	return coin


func _test_coin_gold() -> bool:
	var before := Game.attempt_coins
	var coin := _coin(Vector2(80, 152), Coin.Kind.GOLD)
	Input.action_press("move_right")
	await _frames(60)
	var counted := Game.attempt_coins == before + 1
	Game.attempt_coins = before
	return coin.collected and counted and not _player.is_dead


func _test_coin_bomb() -> bool:
	_coin(Vector2(80, 152), Coin.Kind.BOMB)
	Input.action_press("move_right")
	await _frames(60)
	return _player.is_dead


func _test_coin_fuse() -> bool:
	var coin := _coin(Vector2(80, 152), Coin.Kind.BOMB)
	coin.fuse = 0.4
	var blew := [false]
	coin.exploded.connect(func() -> void: blew[0] = true)
	Input.action_press("move_right")
	await _frames(150)
	return blew[0] and not _player.is_dead


func _test_coin_bait() -> bool:
	var coin := _coin(Vector2(120, 152), Coin.Kind.BOMB)
	coin.fuse = 0.4
	coin.approach = 40.0
	var blew := [false]
	coin.exploded.connect(func() -> void: blew[0] = true)
	# Edge up until it lights, back off, wait, then walk through where it was.
	Input.action_press("move_right")
	for i in 120:
		await _frames(1)
		if coin._lit:
			break
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(40)
	Input.action_release("move_left")
	await _frames(40)
	Input.action_press("move_right")
	await _frames(120)
	return blew[0] and not _player.is_dead and _player.global_position.x > 150.0


func _test_coin_platform() -> bool:
	_ledge(80)
	# A bridge of solid coins across the void, a coin every 12 pixels.
	for i in 12:
		_coin(Vector2(85 + i * 12, 167), Coin.Kind.PLATFORM)
	_player.position = Vector2(40, 159)
	Input.action_press("move_right")
	await _frames(140)
	return not _player.is_dead and _player.global_position.x > 150.0 and _player.global_position.y < 165.0


func _reaper(pattern: String) -> Reaper:
	var reaper: Reaper = REAPER.instantiate()
	reaper.area = Rect2(24, 100, 272, 20)
	reaper.pattern = pattern
	reaper.first_delay = 0.2
	reaper.too_close = 0.0
	_world.add_child(reaper)
	return reaper


func _test_reaper_far_side() -> bool:
	var a := _reaper("")
	await _frames(5)
	var right_side := a.visible and a.global_position.x >= 160.0
	a.queue_free()
	_player.position = Vector2(280, 159)
	await _frames(2)
	var b := _reaper("")
	await _frames(5)
	return right_side and b.visible and b.global_position.x <= 160.0


func _test_reaper_saw() -> bool:
	_reaper("s")
	await _frames(480)
	return _player.is_dead


func _test_saw_blocked() -> bool:
	_place(BLOCK, Vector2(56, 100), Vector2(16, 60))
	_reaper("s")
	await _frames(300)
	return not _player.is_dead


func _test_saw_grow() -> bool:
	var reaper := _reaper("g")
	reaper.area = Rect2(170, 100, 1, 1)
	var shots: Array[Saw] = []
	_world.child_entered_tree.connect(func(n: Node) -> void:
		if n is Saw:
			shots.append(n))
	await reaper.cast
	# Step well away before it gets there.
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	await _frames(240)
	return not shots.is_empty() and shots[0].radius > 15.0 and not _player.is_dead


func _test_saw_chase() -> bool:
	var reaper := _reaper("c")
	reaper.area = Rect2(280, 60, 1, 1)
	await reaper.cast
	# It set off toward where the player stood. They move; it follows anyway.
	Input.action_press("move_right")
	for i in 240:
		await _frames(1)
		if _player.global_position.x > 200.0 or _player.is_dead:
			break
	Input.action_release("move_right")
	await _frames(400)
	return _player.is_dead


func _test_reaper_bullet() -> bool:
	var reaper := _reaper("b")
	reaper.area = Rect2(280, 152, 1, 1)
	var shots: Array[Bullet] = []
	_world.child_entered_tree.connect(func(n: Node) -> void:
		if n is Bullet:
			shots.append(n))
	await reaper.cast
	await _frames(2)
	var level := shots.size() == 1 and shots[0].velocity.y == 0.0 and shots[0].velocity.x < 0.0
	await _frames(300)
	return level and _player.is_dead


func _test_reaper_moves() -> bool:
	var reaper := _reaper("")
	reaper.area = Rect2(24, 140, 272, 1)
	reaper.too_close = 48.0
	await _frames(60)
	var first := reaper.global_position.x
	# Walk at him. He should be gone before the player gets there.
	Input.action_press("move_right")
	for i in 240:
		await _frames(1)
		if _player.global_position.x > first - 40.0:
			break
	Input.action_release("move_right")
	await _frames(90)
	return first >= 160.0 and reaper.visible and reaper.global_position.x < 160.0 and not _player.is_dead


func _test_reaper_touch() -> bool:
	var reaper := _reaper("")
	reaper.area = Rect2(200, 158, 1, 1)
	await _frames(30)
	Input.action_press("move_right")
	await _frames(200)
	return reaper.visible and _player.is_dead


func _ghost(pos: Vector2, trigger := Rect2()) -> Ghost:
	# Let the player's move to the start settle first, or the ghost meets them there.
	await _frames(1)
	var ghost: Ghost = GHOST.instantiate()
	ghost.position = pos
	ghost.trigger = trigger
	_world.add_child(ghost)
	return ghost


func _test_ghost_chases() -> bool:
	# Ghost behind, player walking away from it.
	_player.position = Vector2(100, 159)
	var ghost: Ghost = await _ghost(Vector2(30, 150))
	Input.action_press("move_right")
	await _frames(2)
	Input.action_release("move_right")
	await _frames(30)
	return ghost.chasing and ghost.global_position.x > 32.0


func _test_ghost_shy() -> bool:
	_player.position = Vector2(100, 159)
	var ghost: Ghost = await _ghost(Vector2(30, 150))
	# Turn to face it.
	Input.action_press("move_left")
	await _frames(2)
	Input.action_release("move_left")
	await _frames(10)
	var start := ghost.global_position
	await _frames(120)
	return not ghost.chasing and ghost.global_position == start and not _player.is_dead


func _test_ghost_kills() -> bool:
	_player.position = Vector2(100, 159)
	await _ghost(Vector2(30, 150))
	Input.action_press("move_right")
	await _frames(2)
	Input.action_release("move_right")
	await _frames(300)
	return _player.is_dead


func _test_ghost_trigger() -> bool:
	_player.position = Vector2(100, 159)
	var ghost: Ghost = await _ghost(Vector2(30, 150), Rect2(120, -20, 20, 40))
	await _frames(60)
	var slept := not ghost.awake and ghost.global_position.x == 30.0
	Input.action_press("move_right")
	await _frames(60)
	return slept and ghost.awake
