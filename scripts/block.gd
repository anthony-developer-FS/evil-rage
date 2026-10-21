@tool
class_name Block
extends StaticBody2D
## Placeholder solid. Set `size` in the inspector; collision and drawing follow.

@export var size := Vector2(16, 16):
	set(value):
		size = value
		_sync()
@export var color := Color("3a3a4a"):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	_sync()


func _sync() -> void:
	if not is_inside_tree():
		return
	var shape := $CollisionShape2D as CollisionShape2D
	if shape:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
		shape.position = size / 2.0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
