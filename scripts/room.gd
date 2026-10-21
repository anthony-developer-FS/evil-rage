class_name Room
extends Node2D
## Root of every room. Spawns the player at $Spawn and reloads the room on death.

## Short freeze before the reload so the death registers visually. Keep it tiny.
const RESPAWN_DELAY := 0.25

@onready var player: Player = $Player
@onready var hud: Hud = $Hud


func _ready() -> void:
	Game.enter_room(scene_file_path)
	player.global_position = $Spawn.global_position
	player.died.connect(_on_player_died)
	$Goal.reached.connect(_on_goal_reached)
	hud.show_taunt(Game.last_taunt)


func _process(_delta: float) -> void:
	# Falling off the bottom of the screen counts as a death.
	if player.global_position.y > get_viewport_rect().size.y + 32:
		player.die()


func _on_player_died() -> void:
	Game.register_death()
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	Game.restart_room()


func _on_goal_reached() -> void:
	if $Goal.next_room == "":
		player.set_physics_process(false)
		hud.show_banner("You win. For now.")
