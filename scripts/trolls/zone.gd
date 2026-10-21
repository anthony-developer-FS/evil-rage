class_name Zone
## Builds invisible trigger areas for troll traps. Zones detect only the player (layer 2).


static func make(parent: Node, rect: Rect2) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.position + rect.size / 2.0
	area.add_child(shape)
	parent.add_child(area)
	return area


## Editor-only outline so designers can see where a trap's trigger sits.
static func draw_outline(item: CanvasItem, rect: Rect2, color := Color(1, 0.6, 0, 0.8)) -> void:
	if Engine.is_editor_hint():
		item.draw_rect(rect, color, false, 1.0)
