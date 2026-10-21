class_name Goal
extends Area2D
## Room exit. Leave next_room empty to show the "you win" message instead.

signal reached

@export_file("*.tscn") var next_room := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	# A stone doorway with the way out glowing inside it.
	draw_rect(Rect2(-6, -16, 12, 16), Color("6a6658"))
	draw_rect(Rect2(-6, -16, 12, 1), Color("8a8676"))
	draw_rect(Rect2(-4, -13, 8, 13), Color("4ad97a"))
	draw_rect(Rect2(-3, -14, 6, 1), Color("4ad97a"))
	draw_rect(Rect2(-1, -12, 2, 12), Color("9af0b4"))


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or body.is_dead:
		return
	reached.emit()
	if next_room != "":
		Game.go_to_room(next_room)
