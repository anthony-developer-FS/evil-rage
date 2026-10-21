@tool
class_name RetryVariant
extends Node2D
## Its children only exist on some attempts at the room. Put the first-try layout
## under one variant with max_deaths = 0 and the changed layout under another with
## min_deaths = 1, and the room is different the moment the player thinks they
## have it figured out. Counts deaths in the current room, as the HUD shows them.

@export var min_deaths := 0
## -1 means no upper limit.
@export var max_deaths := -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not active_for(Game.room_deaths):
		# Disabled collision objects leave the physics world, so nothing inside
		# can be touched before the node is gone.
		process_mode = Node.PROCESS_MODE_DISABLED
		hide()
		queue_free()


func active_for(deaths: int) -> bool:
	return deaths >= min_deaths and (max_deaths < 0 or deaths <= max_deaths)
