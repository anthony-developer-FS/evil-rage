@tool
class_name CreepingSpikes
extends Node2D
## A row of frost spikes that grows across the floor one 8 px cell at a time, from
## both ends inward, until only the safe square is bare. They hold there, sink
## back into the ground, and then grow again starting from the safe square and
## spreading outward, so whoever was hiding there has to run for the exit with
## the spikes coming up right behind them. Once grown back they stay.
##
## Place it standing on the floor: the row is `size` with spikes pointing up.

## Fires when the spikes start creeping. Audio listens for it.
signal triggered
## Fires when the spikes sink back and the chase is about to start.
signal retracted

enum Phase { WAITING, CREEPING, HOLDING, RETRACTED, CHASING, DONE }

const CELL := 8.0
## Seconds a spike takes to grow all the way up. Halfway up it already cuts.
const GROW_TIME := 0.12

@export var size := Vector2(256, 8):
	set(value):
		size = value
		queue_redraw()
## Index of the first bare cell, counting 8 px cells from the left.
@export var safe_cell := 8:
	set(value):
		safe_cell = value
		queue_redraw()
## How many cells stay bare. 2 is a 16 px square, just wider than the player.
@export var safe_cells := 2:
	set(value):
		safe_cells = value
		queue_redraw()
## Where a faint mark is drawn on the floor to show the safe square. -1 marks the
## real one. Pointing it somewhere else makes the mark a lie.
@export var marker_cell := -1:
	set(value):
		marker_cell = value
		queue_redraw()
## Trigger area, relative to the row. Leave it empty to start on its own.
@export var trigger := Rect2():
	set(value):
		trigger = value
		queue_redraw()
## Seconds before creeping starts, after the trigger (or the room loading).
@export var delay := 0.5
## Seconds between one cell growing and the next, on each side.
@export var creep_interval := 0.15
## Seconds the floor stays covered before the spikes sink.
@export var hold := 1.2
## Seconds between sinking and the chase starting.
@export var chase_delay := 0.5
## Seconds per cell while chasing. 0.1 is 80 px/s, slower than a running player.
@export var chase_interval := 0.1

var phase := Phase.WAITING
## 0..1 per cell: how far each spike is out of the ground.
var _height: PackedFloat32Array = []
## Whether each cell is growing (true) or sinking.
var _up: Array[bool] = []
var _clock := 0.0
var _step := 0
var _player: Player


func _ready() -> void:
	_resize()
	if Engine.is_editor_hint():
		return
	if trigger.has_area():
		Zone.make(self, trigger).body_entered.connect(func(_b: Node2D) -> void: spring(), CONNECT_ONE_SHOT)
	else:
		spring()


## Starts the creep, unless it already started. Chests can call it.
func spring() -> void:
	if phase != Phase.WAITING:
		return
	phase = Phase.CREEPING
	_clock = -delay
	_step = 0
	triggered.emit()


func cell_count() -> int:
	return maxi(int(size.x / CELL), 1)


func is_cell_deadly(i: int) -> bool:
	return _height[i] >= 0.5


func _resize() -> void:
	_height.resize(cell_count())
	_height.fill(0.0)
	_up.resize(cell_count())
	_up.fill(false)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or phase == Phase.WAITING:
		return
	_clock += delta
	match phase:
		Phase.CREEPING:
			# One more cell from each end every interval, stopping at the safe square.
			while _clock >= creep_interval * _step:
				var grew := false
				var left := _step
				var right := cell_count() - 1 - _step
				if left < safe_cell:
					_up[left] = true
					grew = true
				if right >= safe_cell + safe_cells:
					_up[right] = true
					grew = true
				_step += 1
				if not grew:
					phase = Phase.HOLDING
					_clock = 0.0
					break
		Phase.HOLDING:
			if _clock >= hold:
				_up.fill(false)
				phase = Phase.RETRACTED
				_clock = 0.0
				retracted.emit()
		Phase.RETRACTED:
			if _clock >= chase_delay:
				phase = Phase.CHASING
				_clock = 0.0
				_step = 0
		Phase.CHASING:
			# Out from the safe square in both directions, one cell per interval.
			while _clock >= chase_interval * _step:
				var a := safe_cell + safe_cells - 1 - _step
				var b := safe_cell + _step
				if a < 0 and b >= cell_count():
					phase = Phase.DONE
					break
				if a >= 0:
					_up[a] = true
				if b < cell_count():
					_up[b] = true
				_step += 1
	for i in cell_count():
		_height[i] = move_toward(_height[i], 1.0 if _up[i] else 0.0, delta / GROW_TIME)
	_cut()
	queue_redraw()


## Kills a player whose feet are in a cell that is far enough out of the ground.
func _cut() -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player == null or _player.is_dead:
		return
	var feet := _player.global_position - global_position
	# A little narrower than the player, so a toe over the edge is forgiven.
	if feet.y < 3.0 or feet.y > size.y + 14.0:
		return
	var first := maxi(int(floor((feet.x - 3.0) / CELL)), 0)
	var last := mini(int(floor((feet.x + 3.0) / CELL)), cell_count() - 1)
	for i in range(first, last + 1):
		if is_cell_deadly(i):
			_player.die()
			return


func _draw() -> void:
	var theme := WorldTheme.of(self)
	var c := theme.spike_color if theme else Color("d94a4a")
	var mark := safe_cell if marker_cell < 0 else marker_cell
	var glow := theme.title_color if theme else Color(0.6, 0.8, 1.0)
	glow.a = 0.6
	draw_rect(Rect2(mark * CELL + 2, size.y - 1, maxi(safe_cells, 2) * CELL - 4, 1), glow)
	if Engine.is_editor_hint():
		Zone.draw_outline(self, Rect2(Vector2.ZERO, size))
		Zone.draw_outline(self, Rect2(safe_cell * CELL, 0, safe_cells * CELL, size.y), Color(0.3, 1, 0.5, 0.8))
		Zone.draw_outline(self, trigger)
		return
	for i in _height.size():
		var h := _height[i] * size.y
		if h > 0.5:
			Hazard.draw_spikes(self, Rect2(i * CELL, size.y - h, CELL, h), Vector2.UP, c)
