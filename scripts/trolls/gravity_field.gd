@tool
class_name GravityField
extends Node2D
## Walk into it and gravity turns upside down, or back the right way if
## `inverted` is off. It stays that way after leaving, so place a field where the
## player should flip, not where they should stay flipped. With `concealed` on it
## draws nothing, and the flip comes out of nowhere.

## Fires when it actually flips the player. Audio listens for it.
signal triggered

@export var size := Vector2(16, 32):
	set(value):
		size = value
		queue_redraw()
## True turns gravity upside down, false puts it back.
@export var inverted := true
@export var concealed := false
@export var color := Color("d49aff")

var _scroll := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Zone.make(self, Rect2(Vector2.ZERO, size)).body_entered.connect(_on_entered)
	set_process(not concealed)


func _process(delta: float) -> void:
	_scroll = fmod(_scroll + delta * 12.0, 8.0)
	queue_redraw()


func _draw() -> void:
	Zone.draw_outline(self, Rect2(Vector2.ZERO, size), color)
	if concealed:
		return
	var tint := color
	tint.a = 0.16
	draw_rect(Rect2(Vector2.ZERO, size), tint)
	# Chevrons drifting the way gravity will pull.
	var up := inverted
	var c := color
	c.a = 0.7
	for x in range(4, int(size.x) - 3, 8):
		var y := fmod(_scroll if not up else 8.0 - _scroll, 8.0)
		while y < size.y:
			var tip := y + (0.0 if up else 2.0)
			var wing := y + (2.0 if up else 0.0)
			draw_line(Vector2(x - 2, wing), Vector2(x, tip), c, 1.0)
			draw_line(Vector2(x, tip), Vector2(x + 2, wing), c, 1.0)
			y += 8.0


func _on_entered(body: Node2D) -> void:
	if body is Player and not body.is_dead and (body.gravity_sign < 0.0) != inverted:
		body.set_gravity_inverted(inverted)
		triggered.emit()
