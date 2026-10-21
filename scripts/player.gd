class_name Player
extends CharacterBody2D
## Kinematic platformer controller. No physics forces: velocity is set directly every
## tick so the controls stay predictable. Only the level is allowed to cheat.

signal died
signal jumped
signal wall_jumped
## fall_speed is the downward speed just before touching down.
signal landed(fall_speed: float)
## Fires when a gravity field turns the player upside down or back.
signal gravity_flipped
## Fires when a mirror zone swaps left and right, or swaps them back.
signal controls_flipped

@export var tuning: MovementTuning = preload("res://resources/default_tuning.tres")

var is_dead := false
## 1 while gravity pulls down, -1 while a gravity field has turned it upside down.
## Every vertical number below is "along gravity" so jumps and falls just flip.
var gravity_sign := 1.0
## Set by mirror zones: left moves right and right moves left.
var controls_reversed := false
## The slow-fall zone the player is floating in, or null.
var slow_fall: SlowFallZone

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
	if controls_reversed:
		input_dir = -input_dir
	# Launched off the floor this tick (by a spring) counts as airborne.
	var on_floor := is_on_floor() and velocity.y * gravity_sign >= 0.0
	var wall_dir := _get_wall_dir()

	_tick_timers(delta, on_floor)

	if Input.is_action_just_pressed("jump"):
		_buffer_timer = tuning.jump_buffer

	_apply_horizontal(input_dir, on_floor, delta)
	_apply_gravity(input_dir, wall_dir, on_floor, delta)
	_try_jump(wall_dir, on_floor)

	# Variable jump height: releasing early cuts the rise.
	if _jumping and velocity.y * gravity_sign < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= tuning.jump_cut
		_jumping = false

	var fall_speed := velocity.y * gravity_sign
	move_and_slide()
	if not on_floor and is_on_floor():
		landed.emit(fall_speed)
	_update_sprite(input_dir, wall_dir)

	if Input.is_action_just_pressed("restart"):
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_sprite.play("death")
	died.emit()


## Throws the player upward, as a spring does. It counts as a jump: let go of jump
## early and the rise is cut short, so holding jump decides how high they go.
func launch(speed: float) -> void:
	velocity.y = -speed * gravity_sign
	_jumping = true
	_coyote_timer = 0.0
	_buffer_timer = 0.0


## Turns gravity upside down (inverted) or back. The player keeps their speed, so
## a flip mid-jump carries them up into the ceiling, which is now the floor.
func set_gravity_inverted(inverted: bool) -> void:
	var new_sign := -1.0 if inverted else 1.0
	if new_sign == gravity_sign:
		return
	gravity_sign = new_sign
	up_direction = Vector2(0, -new_sign)
	_coyote_timer = 0.0
	_jumping = false
	_sprite.flip_v = inverted
	gravity_flipped.emit()


func set_controls_reversed(reversed: bool) -> void:
	if reversed == controls_reversed:
		return
	controls_reversed = reversed
	controls_flipped.emit()


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
	# Work in "fall speed": positive means moving with gravity, whichever way it points.
	var fall := velocity.y * gravity_sign
	var g := tuning.gravity
	if fall > 0.0:
		g *= tuning.fall_gravity_mult
	var cap := tuning.max_fall_speed
	if slow_fall:
		g *= slow_fall.gravity_scale
		cap = slow_fall.fall_speed
	if fall > cap:
		# Drifting into a slow-fall zone at full speed: brake hard but not instantly.
		fall = move_toward(fall, cap, tuning.gravity * 2.0 * delta)
	else:
		fall = minf(fall + g * delta, cap)
	# Wall slide when falling and holding into a wall.
	if wall_dir != 0.0 and signf(input_dir) == wall_dir and fall > tuning.wall_slide_speed:
		fall = tuning.wall_slide_speed
	velocity.y = fall * gravity_sign


func _try_jump(wall_dir: float, on_floor: bool) -> void:
	if _buffer_timer <= 0.0:
		return
	if on_floor or _coyote_timer > 0.0:
		velocity.y = -tuning.jump_velocity * gravity_sign
		jumped.emit()
	elif wall_dir != 0.0:
		velocity = Vector2(-wall_dir * tuning.wall_jump_velocity.x, -tuning.wall_jump_velocity.y * gravity_sign)
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
	elif wall_dir != 0.0 and signf(input_dir) == wall_dir and velocity.y * gravity_sign > 0.0:
		anim = "wall_slide"
	elif velocity.y * gravity_sign < 0.0:
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
