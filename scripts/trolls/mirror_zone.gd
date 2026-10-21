@tool
class_name MirrorZone
extends Node2D
## Walk into it and left and right swap, or swap back if `reversed` is off. It
## stays that way after leaving. With `concealed` on it draws nothing, so the first
## sign is running straight into whatever the player was running away from.

## Fires when it actually swaps the controls. Audio listens for it.
signal triggered

@export var size := Vector2(16, 32):
	set(value):
		size = value
		queue_redraw()
## True swaps left and right, false puts them back.
@export var reversed := true
@export var concealed := false
@export var color := Color("60e0d0")

var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Zone.make(self, Rect2(Vector2.ZERO, size)).body_entered.connect(_on_entered)
	set_process(not concealed)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	Zone.draw_outline(self, Rect2(Vector2.ZERO, size), color)
	if concealed:
		return
	var tint := color
	tint.a = 0.1 + 0.04 * sin(_time * 3.0)
	draw_rect(Rect2(Vector2.ZERO, size), tint)
	# A shimmering mirror edge down each side and a pair of crossed arrows.
	var c := color
	c.a = 0.5
	draw_rect(Rect2(0, 0, 1, size.y), c)
	draw_rect(Rect2(size.x - 1, 0, 1, size.y), c)
	var mid := size / 2.0
	draw_line(mid + Vector2(-3, -2), mid + Vector2(3, -2), c, 1.0)
	draw_line(mid + Vector2(1, -4), mid + Vector2(3, -2), c, 1.0)
	draw_line(mid + Vector2(-3, 2), mid + Vector2(3, 2), c, 1.0)
	draw_line(mid + Vector2(-1, 4), mid + Vector2(-3, 2), c, 1.0)


func _on_entered(body: Node2D) -> void:
	if body is Player and not body.is_dead and body.controls_reversed != reversed:
		body.set_controls_reversed(reversed)
		triggered.emit()
