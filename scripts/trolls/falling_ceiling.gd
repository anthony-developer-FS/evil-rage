@tool
class_name FallingCeiling
extends Block
## A ceiling chunk that drops when the player walks under it. Crushes on contact,
## then becomes a normal block where it lands.

## Fires when it starts to fall, and `landed` when it hits the floor. Audio listens.
signal triggered
signal landed

@export var gravity := 1400.0
@export var max_speed := 400.0
## How far below the block the trigger reaches.
@export var trigger_depth := 160.0:
	set(value):
		trigger_depth = value
		queue_redraw()
## How far the trigger reaches past each side of the block, so it can drop just
## in front of the player instead of only on top of them.
@export var trigger_reach := 0.0:
	set(value):
		trigger_reach = value
		queue_redraw()

var _falling := false
var _speed := 0.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	# Only collide with the world while falling, so it passes through the player
	# and the kill zone decides what happens to them.
	collision_mask = 1
	Zone.make(self, _trigger_rect()).body_entered.connect(
		_start_falling.unbind(1), CONNECT_ONE_SHOT)
	var kill := Zone.make(self, Rect2(1, size.y - 2, size.x - 2, 3))
	kill.body_entered.connect(_on_crush)


func _draw() -> void:
	super()
	Zone.draw_outline(self, _trigger_rect())


func _trigger_rect() -> Rect2:
	return Rect2(-trigger_reach, size.y, size.x + trigger_reach * 2.0, trigger_depth)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _falling:
		return
	_speed = minf(_speed + gravity * delta, max_speed)
	var hit := move_and_collide(Vector2(0, _speed * delta))
	if hit == null:
		return
	if hit.get_normal().y < -0.7:
		# Landed. Snap off the physics safe margin so it sits flush on the pixel grid.
		position.y = roundf(position.y)
		_falling = false
		set_physics_process(false)
		landed.emit()
	else:
		# Scraping a neighbouring ceiling block on the way down: keep falling.
		position += hit.get_remainder()


func _start_falling() -> void:
	_falling = true
	triggered.emit()


func _on_crush(body: Node2D) -> void:
	if _falling and body is Player:
		body.die()
