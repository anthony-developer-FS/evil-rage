@tool
class_name FakeWall
extends Block
## Looks exactly like a normal block but is not solid: a secret passage. It fades
## a little while the player is inside so they can tell they found something.

## Fires the first time the player steps in. Audio listens for it.
signal triggered

var _found := false
var _fade: Tween


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	$CollisionShape2D.disabled = true
	var zone := Zone.make(self, Rect2(Vector2.ZERO, size))
	zone.body_entered.connect(_on_entered)
	zone.body_exited.connect(_fade_to.bind(1.0).unbind(1))


func _draw() -> void:
	super()
	Zone.draw_outline(self, Rect2(Vector2.ZERO, size), Color(0.3, 0.8, 1, 0.8))


func _on_entered(_body: Node2D) -> void:
	_fade_to(0.45)
	if not _found:
		_found = true
		triggered.emit()


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, 0.15)
