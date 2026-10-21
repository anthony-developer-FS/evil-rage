@tool
class_name WrapStage
extends Node2D
## Its children only exist while the player has wrapped round a wraparound room
## between `min_wraps` and `max_wraps` times, so a fall that loops can change every
## time round: spikes move from one side to the other, a floor shows up on the third lap.

@export var min_wraps := 0
## -1 means no upper limit.
@export var max_wraps := -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var room := _room()
	if room:
		room.wrapped.connect(_apply)
	_apply(room.wraps if room else 0)


func active_for(wraps: int) -> bool:
	return wraps >= min_wraps and (max_wraps < 0 or wraps <= max_wraps)


func _apply(wraps: int) -> void:
	var on := active_for(wraps)
	# Disabled bodies and areas leave the physics world, so nothing hidden can be touched.
	set_deferred("process_mode", Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED)
	visible = on


func _room() -> Room:
	var node := get_parent()
	while node and not node is Room:
		node = node.get_parent()
	return node
