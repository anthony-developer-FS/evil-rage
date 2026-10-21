class_name Saw
extends Area2D
## A spinning blade Death throws. It flies along `velocity` and kills on touch.
## Saws shatter on the first block they hit, unless they have `cuts_walls`, which
## growing saws need since they sit half in the floor. With `stop_at` it halts
## there; with `grow_to` it swells to that radius once stopped; with `chase` it
## steers after that player. Any saw with a `life` breaks up when it runs out.

const RECT := Rect2(-32, -32, 384, 244)

var velocity := Vector2.ZERO
var radius := 5.0
var grow_to := 0.0
var cuts_walls := false
var stop_at := Vector2.INF
var chase: Player
## Seconds before it breaks up. 0 lasts until it leaves the room or hits something.
var life := 0.0

var _age := 0.0
var _shape: CircleShape2D
var _dying := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 if cuts_walls else 3  # player, and the world unless it cuts through
	_shape = CircleShape2D.new()
	_shape.radius = radius - 1.0
	var shape := CollisionShape2D.new()
	shape.shape = _shape
	add_child(shape)
	body_entered.connect(_on_body_entered)
	if stop_at != Vector2.INF:
		# Given in global coordinates by whoever threw it.
		stop_at = get_parent().to_local(stop_at) if get_parent() is Node2D else stop_at


func _physics_process(delta: float) -> void:
	_age += delta
	if _dying > 0.0:
		_dying += delta
		scale = Vector2.ONE * maxf(1.0 - _dying / 0.2, 0.05)
		if _dying > 0.2:
			queue_free()
		return
	if life > 0.0 and _age > life:
		_break()
		return
	if chase and not chase.is_dead:
		# Steer toward the middle of the player, at the same speed.
		var want := (chase.global_position + Vector2(0, -7) - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, minf(5.0 * delta, 1.0))
	var step := velocity * delta
	if stop_at != Vector2.INF and position.distance_to(stop_at) <= step.length():
		position = stop_at
		velocity = Vector2.ZERO
		stop_at = Vector2.INF
	else:
		position += step
	if grow_to > radius and velocity == Vector2.ZERO:
		radius = move_toward(radius, grow_to, 30.0 * delta)
		_shape.radius = radius - 1.0
	if not RECT.has_point(position):
		queue_free()
	queue_redraw()


func _draw() -> void:
	# Teeth around a steel disc, turning fast, and a dark hub.
	var spin := _age * 18.0
	var teeth := maxi(8, int(radius * 2.0))
	var points := PackedVector2Array()
	for i in teeth * 2:
		var a := spin + i * PI / teeth
		var r := radius if i % 2 == 0 else radius * 0.72
		points.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, Color("b8c0c8"))
	draw_circle(Vector2.ZERO, radius * 0.62, Color("8a929c"))
	draw_line(Vector2.from_angle(spin) * radius * 0.55, Vector2.from_angle(spin + PI) * radius * 0.55, Color("dfe6ec"))
	draw_circle(Vector2.ZERO, maxf(radius * 0.22, 1.0), Color("3a3a44"))


func _on_body_entered(body: Node2D) -> void:
	if _dying > 0.0:
		return
	if body is Player:
		body.die()
	elif not cuts_walls:
		_break()


func _break() -> void:
	_dying = 0.001
	set_deferred("monitoring", false)
