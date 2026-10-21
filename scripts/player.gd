class_name Player
extends CharacterBody2D
## Kinematic platformer controller. No physics forces: velocity is set directly every
## tick so the controls stay predictable. Only the level is allowed to cheat.

signal died
signal jumped
signal wall_jumped
## fall_speed is the downward speed just before touching down.
signal landed(fall_speed: float)

@export var tuning: MovementTuning = preload("res://resources/default_tuning.tres")

var is_dead := false

var _coyote_timer := 0.0
var _buffer_timer := 0.0
var _wall_lock_timer := 0.0
var _wall_lock_dir := 0.0
var _jumping := false

@onready var _sprite: AnimatedSprite2D = $Sprite


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var input_dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	var wall_dir := _get_wall_dir()

	_tick_timers(delta, on_floor)

	if Input.is_action_just_pressed("jump"):
		_buffer_timer = tuning.jump_buffer

	_apply_horizontal(input_dir, on_floor, delta)
	_apply_gravity(input_dir, wall_dir, on_floor, delta)
	_try_jump(wall_dir, on_floor)

	# Variable jump height: releasing early cuts the rise.
	if _jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= tuning.jump_cut
		_jumping = false

	var fall_speed := velocity.y
	move_and_slide()
	if not on_floor and is_on_floor():
		landed.emit(fall_speed)

	if Input.is_action_just_pressed("restart"):
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_sprite.play("death")
	died.emit()


func _tick_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = tuning.coyote_time
		_jumping = false
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_buffer_timer = maxf(_buffer_timer - delta, 0.0)
	_wall_lock_timer = maxf(_wall_lock_timer - delta, 0.0)


func _apply_horizontal(input_dir: float, on_floor: bool, delta: float) -> void:
	# Right after a wall jump, ignore input pushing back toward that wall.
	if _wall_lock_timer > 0.0 and signf(input_dir) == -_wall_lock_dir:
		input_dir = 0.0
	var target := input_dir * tuning.run_speed
	var rate: float
	if on_floor:
		rate = tuning.ground_accel if input_dir != 0.0 else tuning.ground_decel
	else:
		rate = tuning.air_accel if input_dir != 0.0 else tuning.air_decel
	velocity.x = move_toward(velocity.x, target, rate * delta)


func _apply_gravity(input_dir: float, wall_dir: float, on_floor: bool, delta: float) -> void:
	if on_floor:
		return
	var g := tuning.gravity
	if velocity.y > 0.0:
		g *= tuning.fall_gravity_mult
	velocity.y = minf(velocity.y + g * delta, tuning.max_fall_speed)
	# Wall slide when falling and holding into a wall.
	if wall_dir != 0.0 and signf(input_dir) == wall_dir and velocity.y > tuning.wall_slide_speed:
		velocity.y = tuning.wall_slide_speed


func _try_jump(wall_dir: float, on_floor: bool) -> void:
	if _buffer_timer <= 0.0:
		return
	if on_floor or _coyote_timer > 0.0:
		velocity.y = -tuning.jump_velocity
		jumped.emit()
	elif wall_dir != 0.0:
		velocity = Vector2(-wall_dir * tuning.wall_jump_velocity.x, -tuning.wall_jump_velocity.y)
		_wall_lock_timer = tuning.wall_jump_lock
		_wall_lock_dir = -wall_dir
		wall_jumped.emit()
	else:
		return
	_buffer_timer = 0.0
	_coyote_timer = 0.0
	_jumping = true


## Picks the animation from the state the controller just moved in. Purely visual.
func _update_sprite(input_dir: float, wall_dir: float) -> void:
	var anim := "idle"
	if is_on_floor():
		if absf(velocity.x) > 1.0:
			anim = "run"
	elif wall_dir != 0.0 and signf(input_dir) == wall_dir and velocity.y > 0.0:
		anim = "wall_slide"
	elif velocity.y < 0.0:
		anim = "jump"
	else:
		anim = "fall"

	# Face the wall while sliding on it, otherwise face where the player is heading.
	if anim == "wall_slide":
		_sprite.flip_h = wall_dir < 0.0
	elif input_dir != 0.0:
		_sprite.flip_h = input_dir < 0.0
	_sprite.play(anim)


## -1 if touching a wall on the left, 1 on the right, 0 if none. Uses short shape
## casts instead of is_on_wall() so it also works while not pushing into the wall.
func _get_wall_dir() -> float:
	if test_move(global_transform, Vector2.RIGHT * 1.0):
		return 1.0
	if test_move(global_transform, Vector2.LEFT * 1.0):
		return -1.0
	return 0.0
