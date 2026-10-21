@tool
class_name ShiftingVoid
extends Node2D
## A stretch of floor with a hole in it that will not stay put. The hole starts at
## the first of `positions` and slides to the next one each time it is set off:
## when the player comes within `approach` pixels of it, and, with `on_jump`, every
## time the player jumps anywhere in the room. After the last position it goes
## back to the first, unless `repeat` is off, in which case it stays. The floor is two ordinary blocks either side of the hole,
## so it looks and tiles like the ground around it.

## Fires each time the hole starts to slide. Audio listens for it.
signal triggered

const BLOCK := preload("res://scenes/objects/block.tscn")

## The whole strip of floor, hole included.
@export var size := Vector2(128, 20):
	set(value):
		size = value
		_layout()
@export var hole_width := 32.0:
	set(value):
		hole_width = value
		_layout()
## Where the hole's left edge sits, relative to the strip, in the order it visits
## them. The first is where it starts.
@export var positions := PackedFloat32Array([48.0]):
	set(value):
		positions = value
		_layout()
## Slide when the player gets this close to either edge of the hole. 0 turns it off.
@export var approach := 0.0
## Slide every time the player jumps.
@export var on_jump := false
## Go round the positions again after the last one. Off, the hole stops there.
@export var repeat := true
## Seconds the slide takes.
@export var shift_time := 0.25
## Seconds after a slide before it can be set off again.
@export var cooldown := 0.3

var hole_x := 0.0
var _index := 0
var _left: Block
var _right: Block
var _player: Player
var _wait := 0.0
var _tween: Tween


func _ready() -> void:
	_left = BLOCK.instantiate()
	_right = BLOCK.instantiate()
	add_child(_left)
	add_child(_right)
	hole_x = positions[0] if not positions.is_empty() else 0.0
	_layout()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_wait = maxf(_wait - delta, 0.0)
	if not _find_player() or approach <= 0.0 or _wait > 0.0 or _is_sliding():
		return
	var feet := _player.global_position - global_position
	var dx := maxf(maxf(hole_x - feet.x, feet.x - hole_x - hole_width), 0.0)
	# Only from above and near the floor's height: someone high overhead is not
	# close, and someone already falling down the hole is done with.
	if dx < approach and feet.y > -48.0 and feet.y < 1.0:
		spring()


## Slides the hole on to its next position. Chests and other traps can call it.
func spring() -> void:
	if positions.size() < 2 or (not repeat and _index == positions.size() - 1):
		return
	_index = (_index + 1) % positions.size()
	_wait = cooldown + shift_time
	if _tween:
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_method(_set_hole, hole_x, positions[_index], shift_time)
	triggered.emit()


func _is_sliding() -> bool:
	return _tween != null and _tween.is_running()


func _set_hole(x: float) -> void:
	hole_x = x
	_layout()


func _layout() -> void:
	if _left == null:
		return
	if Engine.is_editor_hint() and not positions.is_empty():
		hole_x = positions[0]
	var x := roundf(clampf(hole_x, 0.0, size.x - hole_width))
	_left.size = Vector2(x, size.y)
	_left.visible = x > 0.0
	_left.get_node("CollisionShape2D").disabled = x <= 0.0
	_right.position = Vector2(x + hole_width, 0)
	var rest := size.x - x - hole_width
	_right.size = Vector2(rest, size.y)
	_right.visible = rest > 0.0
	_right.get_node("CollisionShape2D").disabled = rest <= 0.0
	_left.queue_redraw()
	_right.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Show every place the hole will go, numbered by order.
	for i in positions.size():
		var c := Color(1, 0.6, 0, 0.8 if i == 0 else 0.4)
		draw_rect(Rect2(positions[i], 0, hole_width, size.y), c, false, 1.0)


func _find_player() -> bool:
	if is_instance_valid(_player) and _player.is_inside_tree() and not _player.is_dead:
		return true
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null or _player.is_dead:
		return false
	if on_jump and not _player.jumped.is_connected(_on_jumped):
		_player.jumped.connect(_on_jumped)
	return true


func _on_jumped() -> void:
	if _wait <= 0.0 and not _is_sliding():
		spring()
