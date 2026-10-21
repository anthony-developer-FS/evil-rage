@tool
class_name Backdrop
extends Node2D
## Paints the room's world theme behind everything, plus a few ambient motes:
## fireflies in the jungle, drips in the caves, dust in the temple, embers in the
## castle, wind in the sky ruins, sparkles in the mirror halls, snow in the frozen
## depths. Unthemed rooms get the old flat dark fill. Purely visual.

const SIZE := Vector2(320, 180)
const FALLBACK := Color(0.09, 0.09, 0.12)
const MOTES := 14

var _theme: WorldTheme
var _motes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_theme = WorldTheme.of(self)
	_rng.seed = 7
	if _theme and _theme.ambient != WorldTheme.Ambient.NONE and not Engine.is_editor_hint():
		for i in MOTES:
			_motes.append(_spawn(true))
	else:
		set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	for i in _motes.size():
		var m := _motes[i]
		m.age += delta
		m.pos += m.vel * delta
		if _theme.ambient == WorldTheme.Ambient.FIREFLIES:
			m.pos.x += sin(m.age * 1.7 + m.seed) * 6.0 * delta
		elif _theme.ambient == WorldTheme.Ambient.DRIPS:
			m.vel.y += 300.0 * delta
		elif _theme.ambient == WorldTheme.Ambient.SNOW:
			m.pos.x += sin(m.age * 1.3 + m.seed) * 8.0 * delta
		if m.age > m.life:
			_motes[i] = _spawn(false)
	queue_redraw()


func _draw() -> void:
	if _theme == null or _theme.backdrop == null:
		draw_rect(Rect2(Vector2.ZERO, SIZE), FALLBACK)
		return
	draw_texture(_theme.backdrop, Vector2.ZERO)
	for m in _motes:
		var a := sin(clampf(m.age / m.life, 0.0, 1.0) * PI)
		if _theme.ambient == WorldTheme.Ambient.FIREFLIES:
			a *= 0.5 + 0.5 * sin(m.age * 5.0 + m.seed)
		elif _theme.ambient == WorldTheme.Ambient.SPARKLES:
			a *= maxf(sin(m.age * 7.0 + m.seed), 0.0)
		var c := _theme.ambient_color
		c.a *= a
		# Wind leaves short streaks; everything else is a single pixel.
		var streak := Vector2(4, 1) if _theme.ambient == WorldTheme.Ambient.WIND else Vector2.ONE
		draw_rect(Rect2(m.pos.floor(), streak), c)


func _spawn(anywhere_in_life: bool) -> Dictionary:
	var pos := Vector2(_rng.randf_range(0, SIZE.x), _rng.randf_range(20, SIZE.y - 20))
	if not _theme.ambient_points.is_empty():
		pos = _theme.ambient_points[_rng.randi() % _theme.ambient_points.size()]
		pos += Vector2(_rng.randf_range(-2, 2), 0)
	var vel := Vector2.ZERO
	var life := _rng.randf_range(2.0, 5.0)
	match _theme.ambient:
		WorldTheme.Ambient.FIREFLIES:
			vel = Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-5, -1))
		WorldTheme.Ambient.DRIPS:
			life = _rng.randf_range(0.8, 1.6)
		WorldTheme.Ambient.DUST:
			vel = Vector2(_rng.randf_range(2, 6), _rng.randf_range(-1, 2))
			life = _rng.randf_range(4.0, 8.0)
		WorldTheme.Ambient.EMBERS:
			vel = Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-16, -8))
			life = _rng.randf_range(0.8, 1.8)
		WorldTheme.Ambient.WIND:
			vel = Vector2(_rng.randf_range(40, 70), _rng.randf_range(-2, 2))
			life = _rng.randf_range(1.0, 2.5)
		WorldTheme.Ambient.SPARKLES:
			life = _rng.randf_range(1.5, 3.0)
		WorldTheme.Ambient.SNOW:
			vel = Vector2(_rng.randf_range(-2, 2), _rng.randf_range(8, 14))
			life = _rng.randf_range(4.0, 8.0)
	# Start the first batch partway through their lives so the room doesn't pulse.
	var age := _rng.randf_range(0, life) if anywhere_in_life else 0.0
	pos += vel * age
	return {"pos": pos, "vel": vel, "age": age, "life": life, "seed": _rng.randf() * TAU}
