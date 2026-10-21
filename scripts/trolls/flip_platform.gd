@tool
class_name FlipPlatform
extends Block
## A slab with spikes on one face. A button flips it over and the spikes swap
## sides: from underneath to on top, which kills whoever stands on it, or from on
## top to underneath, which makes it safe to walk on. `delay` holds the flip back
## after the press, `flip_back` turns it back over a while after that, and with
## `interval` it also flips over on its own, forever.

## Fires when it flips over. Audio listens for it.
signal triggered

## Whether the spikes start on top. Off, they hang underneath.
@export var spikes_up := false:
	set(value):
		spikes_up = value
		queue_redraw()
## Seconds between a press and the flip.
@export var delay := 0.0
## Seconds after a pressed flip before it flips back over. 0 stays flipped.
@export var flip_back := 0.0
## Flips over on its own every this many seconds. 0 never does.
@export var interval := 0.0
## Seconds the flip takes. It only changes which side kills once it is over.
@export var flip_time := 0.2

var _top: Area2D
var _bottom: Area2D
## Vertical scale it is drawn at, from 1 through 0 to -1 while it turns over.
var _turn := 1.0:
	set(value):
		_turn = value
		queue_redraw()
var _clock := 0.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_top = Zone.make(self, Rect2(1, -5, size.x - 2, 5))
	_bottom = Zone.make(self, Rect2(1, size.y, size.x - 2, 5))
	_top.body_entered.connect(_on_touched.bind(true))
	_bottom.body_entered.connect(_on_touched.bind(false))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or interval <= 0.0:
		return
	_clock += delta
	if _clock >= interval:
		_clock -= interval
		flip()


func _draw() -> void:
	# Turning over is drawn as the slab squashing flat and opening out upside down.
	var middle := size.y / 2.0
	draw_set_transform(Vector2(0, middle * (1.0 - _turn)), 0.0, Vector2(1, _turn))
	super()
	var theme := WorldTheme.of(self)
	var c := theme.spike_color if theme else Color("d94a4a")
	if spikes_up:
		Hazard.draw_spikes(self, Rect2(0, -6, size.x, 6), Vector2.UP, c)
	else:
		Hazard.draw_spikes(self, Rect2(0, size.y, size.x, 6), Vector2.DOWN, c)
	draw_set_transform(Vector2.ZERO)


func press() -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay, false, true).timeout
	await flip()
	if flip_back > 0.0:
		await get_tree().create_timer(flip_back, false, true).timeout
		flip()


func flip() -> void:
	triggered.emit()
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "_turn", -1.0, flip_time)
	await tween.finished
	_turn = 1.0
	spikes_up = not spikes_up
	# Whoever is on the side that just turned to spikes is on the spikes now.
	for body in (_top if spikes_up else _bottom).get_overlapping_bodies():
		_on_touched(body, spikes_up)


func _on_touched(body: Node2D, top: bool) -> void:
	if body is Player and top == spikes_up:
		body.die()
