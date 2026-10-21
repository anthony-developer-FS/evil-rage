@tool
class_name Reaper
extends Area2D
## Death. Rises out of the floor of the room at a random spot on the far side of
## the screen from the player, then keeps conjuring things to throw at them, in
## the order spelled out by `pattern`, one letter per cast, round and round:
##
##   s  a saw shot straight at where the player is
##   g  a saw that drifts to where the player is and grows there
##   c  a saw that chases the player for a few seconds, until it hits a wall
##   b  a bullet, fired level and straight across the room
##   .  a pause the length of one cast
##
## He raises his arms and a glow gathers between his hands for `windup` seconds
## before each one, which is the player's warning. If the player comes within
## `too_close` of him he sinks away and rises again on the other side. Touching
## him kills. Place him anywhere: where he appears is picked from `area`, a
## rectangle in the room's coordinates, on the side away from the player.

## Fires when he rises. Audio listens for it.
signal triggered
## Fires as each saw or bullet leaves his hands: what is "saw" or "bullet".
signal cast(what: StringName)

const FRAMES := preload("res://resources/reaper_frames.tres")
const SCREEN_MIDDLE := 160.0

## Where he may appear, in room coordinates. He picks a spot in the part of it
## on the far side of the screen's middle from the player.
@export var area := Rect2(24, 40, 272, 64):
	set(value):
		area = value
		queue_redraw()
@export var pattern := "s"
## Seconds after rising before the first windup.
@export var first_delay := 0.6
## Seconds from one cast to the start of the next windup.
@export var interval := 1.2
@export var windup := 0.45
## Trigger area, in room coordinates. Leave it empty to rise as the room starts.
@export var trigger := Rect2():
	set(value):
		trigger = value
		queue_redraw()
## Sink away and rise across the room when the player gets this close. 0 never.
@export var too_close := 56.0
@export var saw_speed := 130.0
@export var bullet_speed := 120.0

var _player: Player
var _sprite: AnimatedSprite2D
var _shape: CollisionShape2D
var _charge := 0.0
var _step := 0
## Bumped every time he moves, so a cast that was winding up when he left is dropped.
var _visit := 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	# Frames are 20x26 and he floats, hem a few pixels above his position.
	_sprite.position = Vector2(0, -13)
	_sprite.animation = &"idle"
	add_child(_sprite)
	if Engine.is_editor_hint():
		return
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 18)
	_shape.shape = rect
	_shape.position = Vector2(0, -10)
	add_child(_shape)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			body.die())
	_hide()
	_arm.call_deferred()


## Deferred from _ready: the trigger belongs to the room, which is still adding
## its children while ours run.
func _arm() -> void:
	if trigger.has_area():
		Zone.make(get_parent(), trigger).body_entered.connect(_rise.unbind(1), CONNECT_ONE_SHOT)
	else:
		_rise()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not visible or _player == null:
		return
	_sprite.flip_h = _player.global_position.x < global_position.x
	if too_close > 0.0 and absf(_player.global_position.x - global_position.x) < too_close \
			and not _player.is_dead and _sprite.animation == &"idle":
		_move_away()


func _process(_delta: float) -> void:
	if _charge > 0.0:
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		# Both are in the room's coordinates.
		Zone.draw_outline(self, Rect2(area.position - position, area.size), Color(0.8, 0.2, 0.3, 0.8))
		Zone.draw_outline(self, Rect2(trigger.position - position, trigger.size))
		return
	if _charge <= 0.0:
		return
	# The glow gathering between his raised hands.
	var p := _hands()
	var r := 1.0 + _charge * 4.0
	var flicker := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.05)
	draw_circle(p, r + 2.0, Color(1.0, 0.3, 0.2, 0.35 * flicker))
	draw_circle(p, r, Color(1.0, 0.55, 0.3, 0.9))
	draw_circle(p, r * 0.5, Color(1.0, 0.95, 0.7))


## Between his raised hands, above the hood.
func _hands() -> Vector2:
	return Vector2(2.0 if _sprite.flip_h else -2.0, -27.0)


func _rise() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null:
		return
	_visit += 1
	global_position = _pick_spot()
	show()
	_shape.set_deferred("disabled", false)
	triggered.emit()
	_sprite.play(&"appear")
	await _sprite.animation_finished
	_sprite.play(&"idle")
	_attack(_visit)


func _move_away() -> void:
	_visit += 1
	_charge = 0.0
	queue_redraw()
	_shape.set_deferred("disabled", true)
	_sprite.play(&"vanish")
	await _sprite.animation_finished
	_hide()
	await get_tree().create_timer(0.3).timeout
	if is_inside_tree():
		_rise()


func _hide() -> void:
	hide()
	if _shape:
		_shape.set_deferred("disabled", true)


## A random spot in `area`, on the half of the screen away from the player.
func _pick_spot() -> Vector2:
	var parent := get_parent() as Node2D
	var player_x := parent.to_local(_player.global_position).x
	var lo := area.position.x
	var hi := area.end.x
	if player_x < SCREEN_MIDDLE:
		lo = maxf(lo, SCREEN_MIDDLE)
	else:
		hi = minf(hi, SCREEN_MIDDLE)
	if lo > hi:
		lo = hi
	var spot := Vector2(randf_range(lo, hi), randf_range(area.position.y, area.end.y))
	return parent.to_global(spot.round())


func _attack(visit: int) -> void:
	await get_tree().create_timer(first_delay).timeout
	while visit == _visit and is_inside_tree() and not pattern.is_empty():
		var what := pattern[_step % pattern.length()]
		_step += 1
		if what != ".":
			await _wind_up()
			if visit != _visit or not is_inside_tree():
				return
			_throw(what)
		else:
			await get_tree().create_timer(windup).timeout
		await get_tree().create_timer(interval).timeout


func _wind_up() -> void:
	_sprite.play(&"cast")
	var tween := create_tween()
	tween.tween_property(self, "_charge", 1.0, windup)
	await tween.finished


func _throw(what: String) -> void:
	_charge = 0.0
	queue_redraw()
	_sprite.play(&"idle")
	if _player == null or _player.is_dead:
		return
	var from := global_position + _hands()
	var target := _player.global_position + Vector2(0, -7)
	var shot: Node2D
	match what:
		"s":
			shot = Saw.new()
			shot.velocity = (target - from).normalized() * saw_speed
		"g":
			shot = Saw.new()
			shot.velocity = (target - from).normalized() * saw_speed * 0.8
			shot.stop_at = target
			shot.grow_to = 22.0
			shot.cuts_walls = true
			shot.life = 3.5
		"c":
			shot = Saw.new()
			shot.velocity = (target - from).normalized() * saw_speed * 1.2
			shot.chase = _player
			shot.life = 3.0
		"b":
			shot = Bullet.new()
			from = global_position + Vector2(0, -10)
			shot.velocity = Vector2(signf(target.x - from.x), 0.0) * bullet_speed
		_:
			return
	shot.position = get_parent().to_local(from)
	# Deferred: casts can land mid physics step, when areas cannot be added.
	get_parent().add_child.call_deferred(shot)
	cast.emit(&"bullet" if what == "b" else &"saw")
