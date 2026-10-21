@tool
class_name PopBlock
extends MovingWall
## A block that is not there until the player comes close. Then it bursts out of
## the floor (or, with `from_floor` off, out of thin air) and slides by `travel`,
## and anyone it hits is shoved by `shove`, controls gone for a moment, usually off
## the nearest ledge. Put it where it starts: for a block rising out of the
## ground, sunk into the floor with `travel` pulling it up.

## How hard it throws the player: x is sideways, y is up (negative) or down.
@export var shove := Vector2(240, -120)
## Rises out of the ground: the part still inside the floor is not drawn.
@export var from_floor := true

var _popped := false
var _shoved := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		hide()
		$CollisionShape2D.disabled = true
	super()


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or not _popped:
		return
	queue_redraw()
	# Only while it is still moving: once it stops it is just a block to stand on.
	if _shoved or not _moving:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.is_dead:
		return
	# The player's box, from their feet, against this block plus a pixel of reach.
	var body := Rect2(player.global_position + Vector2(-5, -14), Vector2(10, 14))
	if body.intersects(Rect2(global_position, size).grow(1.5)):
		_shoved = true
		player.shove(shove)


func _begin() -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	show()
	$CollisionShape2D.set_deferred("disabled", false)
	_popped = true
	_moving = true
	triggered.emit()


func _shown_rect() -> Rect2:
	if Engine.is_editor_hint() or not from_floor or not is_inside_tree():
		return super()
	# Only what has come up out of the ground so far.
	var risen := maxf(_start.y - position.y, 0.0)
	return Rect2(0, 0, size.x, minf(risen, size.y))


func _on_crushed(body: Node2D) -> void:
	# It throws people, it does not squash them.
	if body is Player and _moving and not _shoved:
		_shoved = true
		body.shove(shove)


## Pops it now, without waiting for the trigger. Chests can call it.
func spring() -> void:
	if not _popped:
		_begin()
