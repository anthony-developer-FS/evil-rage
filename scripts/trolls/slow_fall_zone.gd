@tool
class_name SlowFallZone
extends Node2D
## A rising draft. Inside it gravity is weak and falling is capped at a slow
## drift, so jumps float higher and drops become glides. It only helps while the
## player is inside: drift out of the side and they drop like a stone again.

@export var size := Vector2(32, 64):
	set(value):
		size = value
		queue_redraw()
## Gravity is multiplied by this inside the draft.
@export_range(0.0, 1.0) var gravity_scale := 0.3
## Fastest the player can fall inside the draft.
@export var fall_speed := 35.0
@export var color := Color("d8f0ff")

var _time := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var zone := Zone.make(self, Rect2(Vector2.ZERO, size))
	zone.body_entered.connect(_on_entered)
	zone.body_exited.connect(_on_exited)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	Zone.draw_outline(self, Rect2(Vector2.ZERO, size), color)
	var tint := color
	tint.a = 0.07
	draw_rect(Rect2(Vector2.ZERO, size), tint)
	# Wisps rising through the column at staggered speeds.
	var c := color
	for i in int(size.x * size.y / 160.0) + 2:
		var x := fmod(i * 37.0, maxf(size.x - 2.0, 1.0)) + 1.0
		var speed := 18.0 + fmod(i * 13.0, 16.0)
		var y := size.y - fmod(_time * speed + i * 23.0, size.y)
		c.a = 0.35 * sin(y / size.y * PI)
		draw_rect(Rect2(floorf(x), floorf(y), 1, 3), c)


func _on_entered(body: Node2D) -> void:
	if body is Player:
		body.slow_fall = self


func _on_exited(body: Node2D) -> void:
	if body is Player and body.slow_fall == self:
		body.slow_fall = null
