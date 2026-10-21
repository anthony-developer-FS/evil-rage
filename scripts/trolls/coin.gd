@tool
class_name Coin
extends Area2D
## A big gold coin, about as tall as the player, like the ones in old plumber
## games. The first ones really are just coins. Later ones are not:
##
## GOLD is collected on touch and counts toward the coin total.
## BOMB looks and chimes like gold, then lights a fuse and explodes, killing
## anyone within `blast_radius`. With `approach` it lights as soon as the player
## comes that close, so it can be baited and dodged.
## PLATFORM is solid: stand on it over a void. It does not spin, which is the
## only way to tell it from gold, so a bridge of them with a few gold coins in it
## has holes nobody sees coming.
##
## The coin's position is its center.

## Fires when collected (and when a bomb is touched, since it pretends). Audio listens.
signal triggered
## Fires when a bomb's fuse is lit.
signal lit
## Fires when a bomb goes off.
signal exploded

enum Kind { GOLD, BOMB, PLATFORM }

const SIZE := Vector2(10, 14)

@export var kind := Kind.GOLD:
	set(value):
		kind = value
		queue_redraw()
## Bomb only: seconds between lighting and the blast. 0 explodes on the spot.
@export var fuse := 0.0
## Bomb only: light when the player comes this close. 0 means only on touch.
@export var approach := 0.0
@export var blast_radius := 22.0

var collected := false
var _lit := false
var _boom := 0.0
var _t := 0.0
var _player: Player


func _ready() -> void:
	_t = fposmod(position.x * 0.05, 1.0)
	if Engine.is_editor_hint():
		return
	if kind == Kind.PLATFORM:
		# Solid like a block, so the player stands on it. The area stays, unused.
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = SIZE
		shape.shape = rect
		body.add_child(shape)
		add_child(body)
		monitoring = false
		return
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if _boom > 0.0:
		_boom += delta
		if _boom > 0.4:
			queue_free()
	if not Engine.is_editor_hint() and kind == Kind.BOMB and approach > 0.0 and not _lit:
		if _player == null:
			_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player and not _player.is_dead and _reach(_player) < approach:
			_light()
	queue_redraw()


func _draw() -> void:
	if _boom > 0.0:
		# A ring of fire spreading out, then smoke.
		var k := clampf(_boom / 0.4, 0.0, 1.0)
		draw_circle(Vector2.ZERO, blast_radius * (0.5 + 0.5 * k), Color(1.0, 0.6, 0.2, 0.7 * (1.0 - k)))
		draw_circle(Vector2.ZERO, blast_radius * 0.6 * (1.0 - k), Color(1.0, 0.95, 0.6, 1.0 - k))
		return
	if collected:
		return
	# Spin by squashing the coin's width, the way old 8-bit coins did. Platform
	# coins hold still: that is the tell.
	var widths := [10, 8, 4, 2, 4, 8]
	var w: int = 10 if kind == Kind.PLATFORM else widths[int(_t * 10.0) % widths.size()]
	var gold := Color("f8c838")
	var shade := Color("c88a18")
	var shine := Color("fff4b0")
	if _lit and int(_t * 16.0) % 2 == 0:
		gold = Color("ff5a3a")
		shade = Color("a82a1a")
	var half := w / 2.0
	draw_rect(Rect2(-half, -6, w, 12), gold)
	draw_rect(Rect2(-half + 1, -7, maxf(w - 2, 1), 14), gold)
	if w >= 4:
		draw_rect(Rect2(-half, -6, 1, 12), shade)
		draw_rect(Rect2(half - 1, -6, 1, 12), shade)
		draw_rect(Rect2(-1, -4, 2, 8), shade)
		draw_rect(Rect2(-half + 1, -5, 1, 3), shine)


func _on_body_entered(body: Node2D) -> void:
	if collected or _lit or not body is Player or body.is_dead:
		return
	# A bomb chimes like any coin first. That is the joke.
	triggered.emit()
	if kind == Kind.GOLD:
		collected = true
		Game.collect_coin()
		_pop()
	else:
		_light()


## The coin jumps up and fades, like it was banked.
func _pop() -> void:
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 16.0, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


func _light() -> void:
	_lit = true
	lit.emit()
	if fuse > 0.0:
		await get_tree().create_timer(fuse).timeout
	_explode()


func _explode() -> void:
	_boom = 0.001
	set_deferred("monitoring", false)
	exploded.emit()
	for player: Player in get_tree().get_nodes_in_group(&"player"):
		if _reach(player) < blast_radius:
			player.die()


## Distance to the middle of the player, not their feet.
func _reach(player: Player) -> float:
	return (player.global_position + Vector2(0, -7)).distance_to(global_position)
