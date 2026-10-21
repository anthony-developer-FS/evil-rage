@tool
class_name Block
extends StaticBody2D
## Solid ground. Set `size` in the inspector; collision and drawing follow. In a
## themed room it is drawn with the world's tiles, otherwise as a flat `color`.

const TILE := 8

@export var size := Vector2(16, 16):
	set(value):
		size = value
		_sync()
@export var color := Color("3a3a4a"):
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	_sync()
	# Tiles line up with the room grid, so redraw while being dragged in the editor.
	# Never switch it off: the physics body relies on it to follow the block when a
	# script moves it in game.
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _sync() -> void:
	if not is_inside_tree():
		return
	var shape := $CollisionShape2D as CollisionShape2D
	if shape:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
		shape.position = size / 2.0
	queue_redraw()


func _draw() -> void:
	var theme := WorldTheme.of(self)
	if theme == null or theme.tiles == null:
		draw_rect(_shown_rect(), color)
		return
	# Columns sit on a grid aligned to the room, not to the block, so neighbouring
	# blocks (and the fake floors next to them) join without a seam. Rows start at
	# the block's top so its surface tile is never cut off.
	var origin := global_position.round()
	var bounds := _shown_rect()
	var y := 0.0
	while y < size.y:
		var x := -float(posmod(int(origin.x), TILE))
		while x < size.x:
			var cell := Rect2(x, y, TILE, TILE)
			var shown := cell.intersection(bounds)
			if shown.has_area():
				var gx := int(origin.x + x + 1024) / TILE
				var gy := int(origin.y + y + 1024) / TILE
				var src := Rect2(_variant(gx, gy) * TILE, 0 if y == 0.0 else TILE, TILE, TILE)
				src.position += shown.position - cell.position
				src.size = shown.size
				draw_texture_rect_region(theme.tiles, shown, src)
			x += TILE
		y += TILE


## The part of the block that gets drawn. All of it, except for blocks that are
## still half hidden in the ground.
func _shown_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size)


## Which of the four tile variants a grid cell uses. Mostly the plain first one.
static func _variant(gx: int, gy: int) -> int:
	var h := absi(gx * 73856093 ^ gy * 19349663) % 16
	return 0 if h < 9 else 1 + h % 3
