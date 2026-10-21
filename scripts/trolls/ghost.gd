@tool
class_name Ghost
extends Area2D
## A shy ghost. While the player looks at it, it hides its face and stays put.
## The moment they turn their back it drifts after them, straight through walls,
## grinning. Touching it kills. With a `trigger` it sleeps, faded out, until the
## player enters it; otherwise it haunts from the start.

## Fires when it starts after the player again. Audio listens for it.
signal triggered

const FRAMES := preload("res://resources/ghost_frames.tres")

@export var speed := 45.0
## Trigger area, relative to the ghost. Leave it empty to be awake from the start.
@export var trigger := Rect2():
	set(value):
		trigger = value
		queue_redraw()

var awake := false
var chasing := false
var _player: Player
var _sprite: AnimatedSprite2D
var _bob := 0.0
## Seconds before it moans again, so turning round fast doesn't make it wail nonstop.
var _hush := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = FRAMES
	_sprite.animation = &"shy"
	add_child(_sprite)
	_bob = fposmod(position.x * 0.13, TAU)
	if Engine.is_editor_hint():
		return
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Player:
			body.die())
	if trigger.has_area():
		modulate.a = 0.25
		monitoring = false
		Zone.make(self, trigger).body_entered.connect(_wake.unbind(1), CONNECT_ONE_SHOT)
	else:
		_wake()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not awake:
		return
	_hush = maxf(_hush - delta, 0.0)
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	var target := _player.global_position + Vector2(0, -7)
	var to := target - global_position
	# Watched when the player faces it. Straight above or below counts as not.
	var watched := not _player.is_dead and absf(to.x) > 1.0 and signf(-to.x) == _player.facing()
	if watched or _player.is_dead:
		if chasing:
			chasing = false
			_sprite.play(&"shy")
	else:
		if not chasing:
			chasing = true
			_sprite.play(&"chase")
			if _hush <= 0.0:
				_hush = 1.0
				triggered.emit()
		global_position += to.limit_length(speed * delta)
	_sprite.flip_h = to.x < 0.0
	_bob += delta * 3.0
	_sprite.position.y = roundf(sin(_bob) * 1.5)


func _draw() -> void:
	Zone.draw_outline(self, trigger)


func _wake() -> void:
	awake = true
	set_deferred("monitoring", true)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
