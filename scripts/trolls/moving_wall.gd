@tool
class_name MovingWall
extends Block
## A block that slides by `travel`. With a `trigger` it waits for the player and
## moves once: walls that close in, floors that pull away, a ceiling that comes
## down. With `loop` it shuttles back and forth forever, as a lift or a crusher.
## The player rides it when standing on top. Getting caught inside it, squeezed
## against something else, kills. A `spikes` side is deadly to touch as well.

## Fires when a triggered wall starts moving. Audio listens for it. Looping walls
## stay quiet, or a room full of lifts would never stop grinding.
signal triggered

enum Side { NONE, TOP, BOTTOM, LEFT, RIGHT }

## How far it moves, in pixels.
@export var travel := Vector2(0, -32)
## Seconds to cover `travel`.
@export var duration := 1.0
## Trigger area, relative to the wall. Leave it empty to start moving at once.
@export var trigger := Rect2():
	set(value):
		trigger = value
		queue_redraw()
## Seconds between triggering and moving.
@export var delay := 0.0
## Shuttle back and forth forever instead of moving once.
@export var loop := false
## Seconds to rest at the far end while looping.
@export var pause := 0.5
## Seconds to rest back at the start while looping. Negative means same as `pause`.
## A press that slams down and lingers up top uses a short `pause` and a long one here.
@export var home_pause := -1.0
## Which face, if any, is covered in spikes.
@export var spikes := Side.NONE:
	set(value):
		spikes = value
		queue_redraw()

var _start := Vector2.ZERO
var _t := 0.0
var _dir := 1.0
var _wait := 0.0
var _moving := false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_start = position
	# Inset so riding on top or brushing a side is fine but being inside is not.
	# The engine moves riders a frame behind the wall, so keep walls under about
	# 200 px/s or a rider sinks deep enough to count as crushed.
	Zone.make(self, Rect2(Vector2(2, 2), size - Vector2(4, 4))).body_entered.connect(_on_crushed)
	if spikes != Side.NONE:
		Zone.make(self, _spike_rect().grow(-1)).body_entered.connect(_on_crushed)
	if trigger.has_area():
		Zone.make(self, trigger).body_entered.connect(_begin.unbind(1), CONNECT_ONE_SHOT)
	else:
		_begin()


func _draw() -> void:
	super()
	if spikes != Side.NONE:
		var theme := WorldTheme.of(self)
		Hazard.draw_spikes(self, _spike_rect(), _spike_dir(), theme.spike_color if theme else Color("d94a4a"))
	Zone.draw_outline(self, trigger)
	if Engine.is_editor_hint():
		draw_rect(Rect2(travel, size), Color(1, 0.6, 0, 0.5), false, 1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not _moving:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	_t = clampf(_t + _dir * delta / duration, 0.0, 1.0)
	# The physics engine works out the wall's speed from this, so a player
	# standing on it rides along.
	position = _start + travel * smoothstep(0.0, 1.0, _t)
	if _t == 1.0 or _t == 0.0:
		if not loop:
			_moving = false
			return
		_dir = -_dir
		_wait = pause if _t == 1.0 or home_pause < 0.0 else home_pause


func _begin() -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_moving = true
	if not loop:
		triggered.emit()


## 6 px of spikes standing out of the chosen face.
func _spike_rect() -> Rect2:
	match spikes:
		Side.TOP:
			return Rect2(0, -6, size.x, 6)
		Side.BOTTOM:
			return Rect2(0, size.y, size.x, 6)
		Side.LEFT:
			return Rect2(-6, 0, 6, size.y)
		Side.RIGHT:
			return Rect2(size.x, 0, 6, size.y)
	return Rect2()


func _spike_dir() -> Vector2:
	match spikes:
		Side.TOP:
			return Vector2.UP
		Side.BOTTOM:
			return Vector2.DOWN
		Side.LEFT:
			return Vector2.LEFT
	return Vector2.RIGHT


func _on_crushed(body: Node2D) -> void:
	if body is Player:
		body.die()
