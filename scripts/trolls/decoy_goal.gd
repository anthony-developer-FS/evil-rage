@tool
class_name DecoyGoal
extends Goal
## Looks exactly like the exit. Bites.

var _bit := false


func _draw() -> void:
	if not _bit:
		super()
		return
	# Show its teeth for the moment before the room reloads.
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
	body.die()
