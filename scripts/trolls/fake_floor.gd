@tool
class_name FakeFloor
extends Block
## Looks exactly like a normal block. Vanishes once the player stands on it.

## Seconds between first touch and collapse. 0 means it drops out instantly.
@export var delay := 0.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	var sensor := Zone.make(self, Rect2(0, -2, size.x, 2))
	sensor.body_entered.connect(_on_touched, CONNECT_ONE_SHOT)


func _draw() -> void:
	super()
	Zone.draw_outline(self, Rect2(Vector2.ZERO, size))


func _on_touched(_body: Node2D) -> void:
	if delay > 0.0:
		var shake := create_tween().set_loops(int(delay / 0.05))
		shake.tween_property(self, "position:x", position.x + 1, 0.025)
		shake.tween_property(self, "position:x", position.x, 0.025)
		await get_tree().create_timer(delay).timeout
	$CollisionShape2D.set_deferred("disabled", true)
	hide()
