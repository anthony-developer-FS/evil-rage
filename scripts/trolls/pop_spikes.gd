@tool
class_name PopSpikes
extends Hazard
## Spikes hidden in the floor that shoot up when the player enters the trigger.

## Fires when the trap springs. Audio listens for it.
signal triggered

## Trigger area, relative to the spikes' top-left corner.
@export var trigger := Rect2(-24, -32, 80, 40):
	set(value):
		trigger = value
		queue_redraw()

var _armed := false


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	monitoring = false
	visible = false
	Zone.make(self, trigger).body_entered.connect(_pop, CONNECT_ONE_SHOT)


func _draw() -> void:
	super()
	Zone.draw_outline(self, trigger)


func _pop(_body: Node2D) -> void:
	visible = true
	triggered.emit()
	set_deferred("monitoring", true)
	# Catch a player already standing on the spot when they pop.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		_on_body_entered(body)
