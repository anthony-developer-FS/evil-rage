extends Node
## Game entry point. The world renders into a 320x180 SubViewport that the window
## scales up by whole numbers with nearest filtering, so pixel art stays blocky.
## The HUD sits outside it, and the window's canvas_items stretch mode draws its
## text at the screen's native resolution.

@export_file("*.tscn") var first_room := "res://scenes/rooms/room_01.tscn"

@onready var _world: SubViewport = $WorldView/World


func _ready() -> void:
	Game.world = _world
	Game.go_to_room(first_room)
