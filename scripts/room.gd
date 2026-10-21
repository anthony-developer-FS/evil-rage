class_name Room
extends Node2D
## Root of every room. Spawns the player at $Spawn and reloads the room on death.

## Short freeze before the reload so the death registers visually. Keep it tiny.
const RESPAWN_DELAY := 0.25

const HUD := preload("res://scenes/objects/hud.tscn")

## The explorer world this room belongs to. Blocks, spikes, the backdrop and the
## title all take their look from it. Leave empty for the plain grey look.
@export var world_theme: WorldTheme

@onready var player: Player = $Player


func _ready() -> void:
	# Run on its own from the editor (F6), a room brings its own HUD. Under
	# main.tscn the HUD lives outside the pixel viewport so text stays sharp.
	if has_node("Title") and world_theme:
		$Title.add_theme_color_override("font_color", world_theme.title_color)
	if Game.world == null and get_tree().current_scene == self:
		add_child(HUD.instantiate())
	elif has_node("Title"):
		# Under main.tscn the HUD shows the room title in sharp text instead.
		$Title.hide()
		var title: String = $Title.text
		if world_theme:
			title = "%s · %s" % [world_theme.display_name, title]
		Game.show_title(title, $Title.get_theme_color("font_color"))
	Game.enter_room(scene_file_path)
	Game.enter_world(world_theme)
	player.global_position = $Spawn.global_position
	player.died.connect(_on_player_died)
	$Goal.reached.connect(_on_goal_reached)


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
		Game.show_banner("You win. For now.")
