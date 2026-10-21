extends Node
## Game entry point. The world renders into a 320x180 SubViewport that the window
## scales up by whole numbers with nearest filtering, so pixel art stays blocky.
## The HUD and the level select sit outside it, and the window's canvas_items
## stretch mode draws their text at the screen's native resolution.

@onready var _world: SubViewport = $WorldView/World


func _ready() -> void:
	Game.world = _world
	# The game opens on the level select. Esc brings it back during play.
	$LevelSelect.open()
