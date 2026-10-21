@tool
class_name PushButton
extends Node2D
## A button the player presses by touching it: walking over it on the floor,
## jumping into it on a ceiling, flying into it on a wall. It presses from the side
## its cap faces, so rotate it to hang it on a wall or a ceiling. Each press presses
## every one of its `targets`: anything with a press() method does its own thing
## (moving walls move, switch blocks switch, flip platforms flip), and any other
## node is switched: if it was there it vanishes, and if it started hidden and
## disabled it appears. With `turn` it also turns a flappy player round.

## Fires on each press. Audio listens for it.
signal triggered

## The nodes it works. In the editor a line runs to each one.
@export var targets: Array[NodePath] = []:
	set(value):
		targets = value
		queue_redraw()
## Stays down after one press. Off, it pops back up once the player lets go of
## it, and the next press works every target again.
@export var one_shot := true
## Turns a flappy player round, so they fly back the way they came.
@export var turn := false:
	set(value):
		turn = value
		queue_redraw()
@export var color := Color("e04848"):
	set(value):
		color = value
		queue_redraw()

var pressed := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var zone := Zone.make(self, Rect2(-7, -6, 14, 6))
	zone.body_entered.connect(_on_touched)
	zone.body_exited.connect(_on_left)


func _draw() -> void:
	# A dark base plate with the cap on top: up and bright, or pushed in and dim.
	draw_rect(Rect2(-7, -2, 14, 2), Color("4a4a56"))
	draw_rect(Rect2(-7, -2, 14, 1), Color("6a6a78"))
	var h := 1.0 if pressed else 3.0
	var cap := color.darkened(0.45) if pressed else color
	draw_rect(Rect2(-5, -2 - h, 10, h), cap)
	draw_rect(Rect2(-5, -2 - h, 10, 1), cap.lightened(0.35))
	if turn and not pressed:
		# A pair of arrows pointing apart: this one turns you round.
		var c := cap.darkened(0.5)
		draw_line(Vector2(-3, -3.5), Vector2(-1, -3.5), c, 1.0)
		draw_line(Vector2(1, -3.5), Vector2(3, -3.5), c, 1.0)
	if Engine.is_editor_hint():
		for path in targets:
			var target := get_node_or_null(path) as Node2D
			if target:
				draw_line(Vector2(0, -3), to_local(target.global_position), Color(1, 0.6, 0, 0.5), 1.0)


func press() -> void:
	pressed = true
	queue_redraw()
	triggered.emit()
	for path in targets:
		var target := get_node_or_null(path)
		if target == null:
			continue
		if target.has_method("press"):
			target.press()
		else:
			toggle(target)


## Takes a node out of the room, or puts it back if it was taken out. Disabled
## bodies and areas leave the physics world, so a hidden node cannot be touched.
static func toggle(node: Node) -> void:
	var on := node.process_mode != Node.PROCESS_MODE_DISABLED
	node.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT)
	if node is CanvasItem:
		node.visible = not on


func _on_touched(body: Node2D) -> void:
	if not body is Player or body.is_dead or pressed:
		return
	press()
	if turn:
		body.turn_around()


func _on_left(body: Node2D) -> void:
	if body is Player and not one_shot and pressed:
		pressed = false
		queue_redraw()
