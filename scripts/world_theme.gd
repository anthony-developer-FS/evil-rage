@tool
class_name WorldTheme
extends Resource
## The look of one explorer world: backdrop, block tiles, spike color and the
## little things that drift around. Set a room's `world_theme` and its blocks,
## spikes, backdrop and title pick it up. The art comes from tools/make_themes.py.

enum Ambient { NONE, FIREFLIES, DRIPS, DUST, EMBERS, WIND, SPARKLES, SNOW }

## Shown on the world's banner and before each room title, e.g. "The Jungle".
@export var display_name := ""
## 320x180 painting behind the room.
@export var backdrop: Texture2D
## 32x16 sheet of 8x8 tiles: top row is block surfaces, bottom row is fill.
@export var tiles: Texture2D
@export var spike_color := Color("d94a4a")
@export var title_color := Color(0.5, 0.5, 0.6)
@export var ambient := Ambient.NONE
@export var ambient_color := Color.WHITE
## Where embers rise from or drips fall from, in room coordinates. Empty means anywhere.
@export var ambient_points: PackedVector2Array = []


## The theme of the room `node` sits in, or null in an unthemed room.
static func of(node: Node) -> WorldTheme:
	while node:
		var theme = node.get("world_theme")
		if theme is WorldTheme:
			return theme
		node = node.get_parent()
	return null
