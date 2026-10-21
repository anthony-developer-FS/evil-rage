@tool
class_name Hazard
extends Area2D
## Kills the player on touch. Drawn as a row of spikes, in the world theme's spike
## color when the room has one. Spikes point up unless `pointing` says otherwise:
## DOWN hangs them from a ceiling, which upside-down rooms need.

@export var size := Vector2(16, 8):
	set(value):
		size = value
		_sync()
@export var color := Color("d94a4a")
## Which way the points face: UP, DOWN, LEFT or RIGHT.
@export var pointing := Vector2.UP:
	set(value):
		pointing = value
		_sync()


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
		# Slightly smaller hitbox than the art, so near misses feel fair. The thin
		# tips give the most room, so the box leans toward the spikes' base.
		var vertical := absf(pointing.y) > absf(pointing.x)
		rect.size = size - (Vector2(4, 3) if vertical else Vector2(3, 4))
		shape.shape = rect
		shape.position = size / 2.0 - pointing.normalized() * 1.5
	queue_redraw()


func _draw() -> void:
	var theme := WorldTheme.of(self)
	draw_spikes(self, Rect2(Vector2.ZERO, size), pointing, theme.spike_color if theme else color)


## Draws a row of spikes filling `rect`, tips facing `toward`. Moving walls with a
## spiked face use it too.
static func draw_spikes(item: CanvasItem, rect: Rect2, toward: Vector2, c: Color) -> void:
	var vertical := absf(toward.y) > absf(toward.x)
	var length := rect.size.x if vertical else rect.size.y
	var count := maxi(int(length / 8.0), 1)
	var w := length / count
	for i in count:
		var a := i * w
		var mid := a + w / 2.0
		var base0: Vector2
		var base1: Vector2
		var base_mid: Vector2
		var tip: Vector2
		if vertical:
			var base_y := rect.end.y if toward.y < 0.0 else rect.position.y
			var tip_y := rect.position.y if toward.y < 0.0 else rect.end.y
			base0 = Vector2(rect.position.x + a, base_y)
			base1 = Vector2(rect.position.x + a + w, base_y)
			base_mid = Vector2(rect.position.x + mid, base_y)
			tip = Vector2(rect.position.x + mid, tip_y)
		else:
			var base_x := rect.end.x if toward.x < 0.0 else rect.position.x
			var tip_x := rect.position.x if toward.x < 0.0 else rect.end.x
			base0 = Vector2(base_x, rect.position.y + a)
			base1 = Vector2(base_x, rect.position.y + a + w)
			base_mid = Vector2(base_x, rect.position.y + mid)
			tip = Vector2(tip_x, rect.position.y + mid)
		item.draw_colored_polygon(PackedVector2Array([base0, tip, base1]), c)
		# Shade one face so each spike reads as a solid point.
		item.draw_colored_polygon(PackedVector2Array([tip, base1, base_mid]), c.darkened(0.3))


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
