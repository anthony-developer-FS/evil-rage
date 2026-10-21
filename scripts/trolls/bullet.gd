class_name Bullet
extends Area2D
## A big black bullet with a grumpy face, flying level and straight. Death fires
## them. Kills on touch and breaks on the first block it hits.

const RECT := Rect2(-32, -32, 384, 244)
const SIZE := Vector2(14, 10)

var velocity := Vector2.ZERO
var _dying := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3  # world and player
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = SIZE - Vector2(2, 2)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _dying > 0.0:
		_dying += delta
		modulate.a = maxf(1.0 - _dying / 0.2, 0.0)
		queue_redraw()
		if _dying > 0.2:
			queue_free()
		return
	position += velocity * delta
	if not RECT.has_point(position):
		queue_free()


func _draw() -> void:
	# Drawn flying right and mirrored for left: a round nose, a flat tail with a
	# fin, one angry eye and a little white arm.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 if velocity.x >= 0.0 else -1.0, 1.0))
	var body := Color("1e1e26")
	draw_rect(Rect2(-7, -5, 10, 10), body)
	draw_circle(Vector2(2, 0), 5, body)
	draw_rect(Rect2(-8, -6, 2, 12), Color("3a3a48"))
	draw_rect(Rect2(2, -3, 3, 3), Color.WHITE)
	draw_rect(Rect2(4, -2, 1, 2), body)
	draw_line(Vector2(1, -4), Vector2(5, -3), Color("e0e0e8"))
	draw_rect(Rect2(-3, 2, 2, 3), Color("e8e8f0"))
	if _dying > 0.0:
		draw_circle(Vector2.ZERO, 6.0 + _dying * 30.0, Color(0.9, 0.9, 0.9, 0.5))


func _on_body_entered(body: Node2D) -> void:
	if _dying > 0.0:
		return
	if body is Player:
		body.die()
	_dying = 0.001
	set_deferred("monitoring", false)
	queue_redraw()
