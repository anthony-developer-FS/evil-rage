@tool
class_name Hazard
extends Area2D
## Kills the player on touch. Drawn as a row of spikes pointing up, in the world
## theme's spike color when the room has one.

@export var size := Vector2(16, 8):
	set(value):
		size = value
		_sync()
@export var color := Color("d94a4a")


func _ready() -> void:
	_sync()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _sync() -> void:
	if not is_inside_tree():
		return
	var shape := $CollisionShape2D as CollisionShape2D
	if shape:
		var rect := RectangleShape2D.new()
		# Slightly smaller hitbox than the art, so near misses feel fair.
		rect.size = size - Vector2(4, 3)
		shape.shape = rect
		shape.position = Vector2(size.x / 2.0, size.y / 2.0 + 1.5)
	queue_redraw()


func _draw() -> void:
	var theme := WorldTheme.of(self)
	var c := theme.spike_color if theme else color
	var count := maxi(int(size.x / 8.0), 1)
	var w := size.x / count
	for i in count:
		var x := i * w
		var tip := Vector2(x + w / 2.0, 0)
		draw_colored_polygon(PackedVector2Array([Vector2(x, size.y), tip, Vector2(x + w, size.y)]), c)
		# Shade the right face so each spike reads as a solid point.
		draw_colored_polygon(PackedVector2Array([tip, Vector2(x + w, size.y), Vector2(x + w / 2.0, size.y)]),
			c.darkened(0.3))


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
