@tool
class_name SwitchBlock
extends Block
## A block a button switches on and off. Solid, it looks like any other block with
## a colored rim. Switched off, only a dotted outline in that color is left, and
## the player passes straight through. Switching it on around the player crushes them.

## Whether it starts solid.
@export var solid := true:
	set(value):
		solid = value
		queue_redraw()
## The rim and the dotted outline. Match it to the button that works it.
@export var rim := Color("e04848"):
	set(value):
		rim = value
		queue_redraw()

var _inside: Area2D


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_inside = Zone.make(self, Rect2(Vector2(2, 2), size - Vector2(4, 4)))
	$CollisionShape2D.disabled = not solid


func _draw() -> void:
	if not solid:
		var r := Rect2(Vector2(0.5, 0.5), size - Vector2.ONE)
		var c := rim
		c.a = 0.7
		for edge in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
				[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
			draw_dashed_line(edge[0], edge[1], c, 1.0, 2.0)
		return
	super()
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), rim, false, 1.0)


func press() -> void:
	solid = not solid
	$CollisionShape2D.set_deferred("disabled", not solid)
	if solid:
		for body in _inside.get_overlapping_bodies():
			if body is Player:
				body.die(true)
