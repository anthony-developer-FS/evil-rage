@tool
class_name DartTrap
extends Node2D
## A carved stone face set into a wall. Looks like decoration until the player
## crosses its trigger, then it spits darts along `direction`. Darts kill on touch
## and break on the first solid thing they hit. Place it on the face of a wall,
## with `direction` pointing out of the wall.

## Fires on each volley. Audio listens for it.
signal triggered

## Which way darts fly. Use a unit vector: LEFT, RIGHT, UP or DOWN.
@export var direction := Vector2.LEFT:
	set(value):
		direction = value
		queue_redraw()
## Trigger area, relative to the trap.
@export var trigger := Rect2(-80, -16, 72, 24):
	set(value):
		trigger = value
		queue_redraw()
@export var speed := 180.0
## Seconds between entering the trigger and the first dart.
@export var delay := 0.0
@export var count := 1
## Seconds between darts when count > 1.
@export var interval := 0.3


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	Zone.make(self, trigger).body_entered.connect(_fire.unbind(1), CONNECT_ONE_SHOT)


func _draw() -> void:
	# A small carved face: brow, two eyes and the mouth the darts come out of.
	var c := Color("2a1e15")
	draw_rect(Rect2(-3, -3, 6, 6), Color("6a5038"))
	draw_rect(Rect2(-3, -3, 6, 1), Color("8a6a48"))
	draw_rect(Rect2(-2, -1, 1, 1), c)
	draw_rect(Rect2(1, -1, 1, 1), c)
	draw_rect(Rect2(-1, 1, 2, 1), c)
	Zone.draw_outline(self, trigger)
	if Engine.is_editor_hint():
		draw_line(Vector2.ZERO, direction * 12.0, Color(1, 0.6, 0, 0.8))


func _fire() -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	triggered.emit()
	for i in count:
		if i > 0:
			await get_tree().create_timer(interval).timeout
		var dart := Dart.new()
		dart.velocity = direction.normalized() * speed
		dart.position = position + direction.normalized() * 4.0
		# Deferred: the trigger fires mid physics step, when areas cannot be added.
		get_parent().add_child.call_deferred(dart)


class Dart:
	extends Area2D

	const LENGTH := 7.0

	var velocity := Vector2.ZERO

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 3  # world and player
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var along := velocity.normalized()
		rect.size = Vector2(LENGTH, 2) if absf(along.x) > absf(along.y) else Vector2(2, LENGTH)
		shape.shape = rect
		add_child(shape)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		position += velocity * delta
		if not Rect2(-32, -32, 384, 244).has_point(position):
			queue_free()

	func _draw() -> void:
		var along := velocity.normalized()
		draw_line(-along * LENGTH / 2.0, along * LENGTH / 2.0, Color("d8c8a0"), 1.0)
		draw_rect(Rect2((along * LENGTH / 2.0 - Vector2.ONE).floor(), Vector2(2, 2)), Color("3a3a40"))

	func _on_body_entered(body: Node2D) -> void:
		if body is Player:
			body.die()
		queue_free()
