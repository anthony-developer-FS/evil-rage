@tool
class_name Spring
extends Area2D
## Bounce pad. Sits on top of the floor and launches the player on touch. Hold jump
## for the full bounce, let go for a short one.

@export var size := Vector2(16, 4):
	set(value):
		size = value
		_sync()
## Launch speed. The full bounce reaches about speed² / 1800 pixels.
@export var power := 420.0
@export var color := Color("4ac0d9")


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
		rect.size = size
		shape.shape = rect
		shape.position = size / 2.0
	queue_redraw()


func _draw() -> void:
	# Pad on top, coil underneath.
	draw_rect(Rect2(0, 0, size.x, 2), color)
	for x in range(2, int(size.x) - 1, 4):
		draw_rect(Rect2(x, 2, 2, size.y - 2), color.darkened(0.4))


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not body.is_dead and body.velocity.y >= 0.0:
		body.launch(power)
