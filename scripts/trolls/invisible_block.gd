@tool
class_name InvisibleBlock
extends Block
## Not there until the player jumps into it from below. Then it appears and
## bonks them, usually into whatever is underneath.


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	visible = false
	$CollisionShape2D.disabled = true
	# Sensor on the block's lower half so only a hit from below reveals it.
	var sensor := Zone.make(self, Rect2(0, size.y / 2.0, size.x, size.y / 2.0))
	sensor.body_entered.connect(_on_hit)


func _draw() -> void:
	super()
	Zone.draw_outline(self, Rect2(Vector2.ZERO, size))


func _on_hit(body: Node2D) -> void:
	if visible or not body is Player or body.velocity.y >= 0.0:
		return
	visible = true
	$CollisionShape2D.set_deferred("disabled", false)
	# Push the player out under the block and kill their upward speed.
	body.global_position.y = global_position.y + size.y + 14.0
	body.velocity.y = 0.0
