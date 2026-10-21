@tool
class_name RunawayGoal
extends Goal
## The exit flees to the next point each time the player gets close. Once the
## points run out it stays put and can be reached.

## Fires on every hop. Audio listens for it.
signal triggered

## Positions to flee to, in the room's coordinates, in order.
@export var flee_points: PackedVector2Array = []:
	set(value):
		flee_points = value
		queue_redraw()
@export var flee_radius := 28.0

var _next := 0
var _fleeing := false
var _zone: Area2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super()
	_zone = Zone.make(self, Rect2(-flee_radius, -flee_radius - 8, flee_radius * 2, flee_radius * 2))
	_zone.body_entered.connect(_flee)


func _draw() -> void:
	super()
	if Engine.is_editor_hint():
		var from := Vector2.ZERO
		for p in flee_points:
			draw_line(from, to_local(p), Color(1, 0.6, 0, 0.8))
			from = to_local(p)


func _on_body_entered(body: Node2D) -> void:
	if _next >= flee_points.size():
		super(body)


func _flee(_body: Node2D) -> void:
	if _fleeing or _next >= flee_points.size():
		return
	_fleeing = true
	var target := flee_points[_next]
	_next += 1
	triggered.emit()
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target, 0.2)
	await tween.finished
	_fleeing = false
	# Still close after landing? Run again.
	await get_tree().physics_frame
	for body in _zone.get_overlapping_bodies():
		_flee(body)
