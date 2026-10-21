class_name Goal
extends Area2D
## Room exit. Leave next_room empty to show the "you win" message instead.

signal reached

@export_file("*.tscn") var next_room := ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	draw_rect(Rect2(-6, -16, 12, 16), Color("4ad97a"))


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or body.is_dead:
		return
	reached.emit()
	if next_room != "":
		Game.go_to_room(next_room)
