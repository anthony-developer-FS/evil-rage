@tool
class_name DecoyGoal
extends Goal
## Looks exactly like the exit. Bites.

## Fires when it bites. Audio listens for it.
signal triggered

var _bit := false


func _draw() -> void:
	if not _bit:
		super()
		return
	# Show its teeth for the moment before the room reloads. A themed door keeps
	# its shape and flushes red, so it is clearly the same door that bit.
	var theme := WorldTheme.of(self)
	if theme and theme.door:
		draw_texture(theme.door, Vector2(-6, -16), Color(1.6, 0.35, 0.3))
		draw_rect(Rect2(-4, -12, 8, 8), Color("d94a4a"))
	else:
		draw_rect(Rect2(-6, -16, 12, 16), Color("d94a4a"))
	for i in 3:
		var x := -6 + i * 4
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -10), Vector2(x + 2, -6), Vector2(x + 4, -10)
		]), Color("1a1a22"))


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or body.is_dead:
		return
	_bit = true
	queue_redraw()
	triggered.emit()
	body.die()
