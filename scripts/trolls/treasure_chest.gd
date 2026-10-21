@tool
class_name TreasureChest
extends Area2D
## A chest the player opens by touching it. Every chest looks the same, and the
## first few really do help, so the player learns to grab them. Later ones do not.
## What it gives lasts until the player dies, since the room reloads on death.
## Place it standing on the floor, like the goal.

## Fires when it opens. Audio listens for it.
signal triggered
## Fires as well when what was inside turns out to be bad news.
signal cursed

enum Gift {
	## One extra jump in the air.
	DOUBLE_JUMP,
	## Takes one hit from spikes or a trap.
	SHIELD,
	## Jumps lose a third of their height.
	LEAD_BOOTS,
	## Jumps go half again as high. Great, unless the ceiling has spikes.
	SPRING_BOOTS,
	## It bites.
	MIMIC,
	## Sets off the trap at `wakes`.
	ALARM,
}

const MESSAGES := {
	Gift.DOUBLE_JUMP: "Feathered boots! Jump again in mid-air.",
	Gift.SHIELD: "A lucky amulet. It will take one hit for you.",
	Gift.LEAD_BOOTS: "Golden boots! ...they're lead. Painted lead.",
	Gift.SPRING_BOOTS: "Spring boots! Jump higher than ever.",
	Gift.MIMIC: "It was a mimic.",
	Gift.ALARM: "Empty. Except for the alarm.",
}
const BAD := [Gift.LEAD_BOOTS, Gift.MIMIC, Gift.ALARM]

@export var gift := Gift.DOUBLE_JUMP:
	set(value):
		gift = value
		queue_redraw()
## For ALARM: the trap opening the chest sets off. Anything with a `spring()`.
@export var wakes: NodePath

var opened := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var wood := Color("7a4a24")
	var band := Color("e0b040")
	if not opened:
		draw_rect(Rect2(-7, -10, 14, 10), wood)
		draw_rect(Rect2(-7, -10, 14, 4), wood.lightened(0.15))
		draw_rect(Rect2(-7, -6, 14, 1), wood.darkened(0.4))
		draw_rect(Rect2(-7, -10, 1, 10), band)
		draw_rect(Rect2(6, -10, 1, 10), band)
		draw_rect(Rect2(-1, -7, 2, 3), band)
		if Engine.is_editor_hint():
			# Designers see at a glance which chests are lies.
			draw_rect(Rect2(-7, -12, 14, 1), Color("d94a4a") if gift in BAD else Color("4ad97a"))
		return
	if gift == Gift.MIMIC:
		draw_rect(Rect2(-7, -6, 14, 6), wood)
		draw_rect(Rect2(-7, -14, 14, 6), wood)
		draw_rect(Rect2(-6, -8, 12, 2), Color("8a1a1a"))
		for i in 3:
			var x := -6 + i * 4
			draw_colored_polygon(PackedVector2Array([Vector2(x, -8), Vector2(x + 2, -5), Vector2(x + 4, -8)]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(x, -6), Vector2(x + 2, -9), Vector2(x + 4, -6)]), Color.WHITE)
		draw_rect(Rect2(-4, -13, 2, 2), Color("ff4040"))
		draw_rect(Rect2(2, -13, 2, 2), Color("ff4040"))
		return
	# Lid thrown back, and whatever was inside glowing.
	draw_rect(Rect2(-7, -6, 14, 6), wood)
	draw_rect(Rect2(-7, -6, 1, 6), band)
	draw_rect(Rect2(6, -6, 1, 6), band)
	draw_rect(Rect2(-7, -13, 14, 3), wood.lightened(0.15))
	var glow := Color("ff6a6a") if gift in BAD else Color("fff0a0")
	draw_rect(Rect2(-5, -7, 10, 1), glow)


func _on_body_entered(body: Node2D) -> void:
	if opened or not body is Player or body.is_dead:
		return
	opened = true
	queue_redraw()
	triggered.emit()
	Game.show_banner(MESSAGES[gift], 2.5)
	if gift in BAD:
		cursed.emit()
	var player: Player = body
	match gift:
		Gift.DOUBLE_JUMP:
			player.air_jumps += 1
		Gift.SHIELD:
			player.shields += 1
		Gift.LEAD_BOOTS:
			player.jump_scale *= 0.66
		Gift.SPRING_BOOTS:
			player.jump_scale *= 1.5
		Gift.MIMIC:
			player.die(true)
		Gift.ALARM:
			var trap := get_node_or_null(wakes)
			if trap and trap.has_method("spring"):
				trap.spring()
