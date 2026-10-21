class_name MovementTuning
extends Resource
## Every number that shapes how the player feels. Edit resources/default_tuning.tres
## in the inspector to retune movement without touching code. Units are pixels and seconds.

@export_group("Run")
@export var run_speed := 110.0
@export var ground_accel := 1000.0
@export var ground_decel := 1400.0
@export var air_accel := 800.0
@export var air_decel := 600.0

@export_group("Jump")
@export var jump_velocity := 260.0
@export var gravity := 900.0
## Extra gravity while falling, for a snappier arc.
@export var fall_gravity_mult := 1.6
@export var max_fall_speed := 280.0
## Vertical speed is multiplied by this when jump is released while rising.
@export_range(0.0, 1.0) var jump_cut := 0.45
@export var coyote_time := 0.1
@export var jump_buffer := 0.1

@export_group("Wall")
@export var wall_slide_speed := 50.0
@export var wall_jump_velocity := Vector2(130.0, 240.0)
## Time after a wall jump during which the stick can't steer back into the wall.
@export var wall_jump_lock := 0.14

@export_group("Flappy")
## Upward speed of one flap in a flappy room.
@export var flap_velocity := 170.0
## Forward speed in a flappy room. The player cannot speed up, slow down or stop.
@export var flap_speed := 70.0
