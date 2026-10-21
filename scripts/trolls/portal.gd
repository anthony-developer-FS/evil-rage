@tool
class_name Portal
extends Area2D
## A swirling rift that moves the player to `exit`, keeping their speed. The exit
## is usually another portal, which makes the pair two-way, but it can be any
## node: a Marker2D hanging over a spike pit makes a portal that lies. Leave
## `exit` empty for a portal that only ever lets people out. Every portal looks
## the same apart from its `color`, which rooms may use to hint where it goes, or
## to lie about it. Place it standing on the floor, like the goal.

## Fires each time it sends the player somewhere. Audio listens for it.
signal triggered

@export var exit: NodePath:
	set(value):
		exit = value
		queue_redraw()
@export var color := Color("a070ff"):
	set(value):
		color = value
		queue_redraw()

## Bodies that just arrived here. They must step clear before it takes them
## again, or a pair of portals would bounce them back and forth forever.
var _arrived: Array[Node2D] = []
var _t := 0.0


func _ready() -> void:
	# Each portal swirls at its own phase, so a row of them doesn't pulse together.
	_t = fposmod(position.x * 0.37 + position.y * 0.11, TAU)
	if Engine.is_editor_hint():
		return
	set_physics_process(false)
	body_entered.connect(_on_body_entered)
	body_exited.connect(func(body: Node2D) -> void: _arrived.erase(body))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# An upright oval: dark heart, a bright rim, and motes spiralling inward.
	var center := Vector2(0, -10)
	var dark := color.darkened(0.75)
	_oval(center, Vector2(7, 11), color.darkened(0.35))
	_oval(center, Vector2(6, 10), color)
	_oval(center, Vector2(4, 8), dark.lerp(color, 0.35))
	_oval(center, Vector2(3, 6), dark)
	for i in 6:
		var a := _t * 2.4 + i * TAU / 6.0
		var r := fposmod(1.0 - (_t * 0.8 + i / 6.0), 1.0)
		var p := center + Vector2(cos(a) * 5.0 * r, sin(a) * 9.0 * r)
		draw_rect(Rect2(p.floor(), Vector2.ONE), color.lightened(0.6))
	if Engine.is_editor_hint() and has_node(exit):
		var target := get_node(exit) as Node2D
		if target:
			draw_line(center, to_local(target.global_position) + Vector2(0, -10), Color(color, 0.7))


func _oval(center: Vector2, radii: Vector2, c: Color) -> void:
	var points := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, c)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or body.is_dead or body in _arrived:
		return
	var target := get_node_or_null(exit) as Node2D
	if target == null:
		return
	body.teleport(target.global_position)
	triggered.emit()
	if target is Portal:
		target._receive(body)


func _receive(body: Node2D) -> void:
	_arrived.append(body)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	# Arrivals are let go when they step out, but someone dropped in falling fast
	# may never "enter", so never step out either. Let them go once they are clear.
	for body in _arrived.duplicate():
		if not is_instance_valid(body) or body.global_position.distance_to(global_position) > 16.0:
			_arrived.erase(body)
	set_physics_process(not _arrived.is_empty())
