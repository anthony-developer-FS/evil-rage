class_name LevelSelect
extends CanvasLayer
## World and level select. Opens when the game starts and on Esc (or Start) during
## play, which pauses the room underneath. Worlds and rooms come from
## LevelCatalog, so new rooms show up here on their own. Every room is open from
## the start: there is no unlocking.
##
## Like the HUD it sits outside the 320x180 world viewport, so text is drawn at
## the screen's native resolution. Sizes below are in 320x180 units.

const ROOM_COLUMNS := 6
const ACCENT := Color(0.85, 0.3, 0.3)
const DIM := Color(0.62, 0.62, 0.7)

## True while a room is paused under the menu, so Esc can go back to it.
var resumable := false

var _worlds: Array[LevelCatalog.World] = []
var _world_buttons: Array[Button] = []
var _room_buttons: Array[Button] = []
var _shown_world := -1

var _root: Control
var _backdrop: TextureRect
var _world_list: VBoxContainer
var _world_name: Label
var _room_grid: GridContainer
var _room_title: Label
var _hint: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_worlds = LevelCatalog.worlds()
	_build()
	hide_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		if event.is_action_pressed("menu") and Game.world:
			open(true)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		var focus := get_viewport().gui_get_focus_owner()
		if focus in _room_buttons and _shown_world >= 0:
			_world_buttons[_shown_world].grab_focus()
		elif resumable:
			hide_menu()


## Shows the menu. With `pause_room`, the current room freezes underneath and Esc
## resumes it. Focus starts on the room being played, or room 1.
func open(pause_room := false) -> void:
	resumable = pause_room
	if pause_room:
		get_tree().paused = true
	_root.show()
	_hint.text = "Enter  play      Esc  resume" if resumable else "Enter  play"
	var world_index := 0
	var room_index := 0
	var current := LevelCatalog.world_of(Game.current_room())
	if current:
		world_index = _worlds.find(current)
		for i in current.levels.size():
			if current.levels[i].path == Game.current_room():
				room_index = i
	_show_world(world_index)
	if _room_buttons.size() > room_index:
		_room_buttons[room_index].grab_focus()
	elif _world_buttons.size() > world_index:
		_world_buttons[world_index].grab_focus()


func hide_menu() -> void:
	_root.hide()
	get_tree().paused = false
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


func play(level: LevelCatalog.Level) -> void:
	hide_menu()
	Game.go_to_room(level.path)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_backdrop)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.02, 0.04, 0.62)
	_root.add_child(shade)

	var heading := _label("EVIL RAGE", 16, ACCENT)
	heading.position = Vector2(8, 4)
	_root.add_child(heading)
	var sub := _label("Pick your poison.", 8, DIM)
	sub.position = Vector2(10, 24)
	_root.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 40)
	scroll.size = Vector2(108, 130)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(2, 0)
	bar.add_theme_stylebox_override("scroll", _bar_box(Color(1, 1, 1, 0.08)))
	bar.add_theme_stylebox_override("grabber", _bar_box(Color(DIM, 0.6)))
	bar.add_theme_stylebox_override("grabber_highlight", _bar_box(DIM))
	bar.add_theme_stylebox_override("grabber_pressed", _bar_box(DIM))
	_root.add_child(scroll)
	_world_list = VBoxContainer.new()
	_world_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_list.add_theme_constant_override("separation", 1)
	scroll.add_child(_world_list)

	for i in _worlds.size():
		var world := _worlds[i]
		var button := _button("%d  %s" % [i + 1, world.name], _color_of(world))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 10)
		button.focus_entered.connect(_show_world.bind(i))
		button.pressed.connect(_enter_rooms)
		_world_list.add_child(button)
		_world_buttons.append(button)

	_world_name = _label("", 12, Color.WHITE)
	_world_name.position = Vector2(126, 40)
	_root.add_child(_world_name)

	_room_grid = GridContainer.new()
	_room_grid.columns = ROOM_COLUMNS
	_room_grid.position = Vector2(126, 60)
	_room_grid.add_theme_constant_override("h_separation", 3)
	_room_grid.add_theme_constant_override("v_separation", 3)
	_root.add_child(_room_grid)

	_room_title = _label("", 8, Color.WHITE)
	_room_title.position = Vector2(126, 128)
	_room_title.size = Vector2(186, 12)
	_room_title.clip_text = true
	_root.add_child(_room_title)

	_hint = _label("", 8, DIM)
	_hint.position = Vector2(126, 160)
	_root.add_child(_hint)


## Fills the room grid with the rooms of world `index`.
func _show_world(index: int) -> void:
	if index == _shown_world or index < 0 or index >= _worlds.size():
		return
	# The world being shown stays lit while focus is down in its rooms.
	if _shown_world >= 0:
		_world_buttons[_shown_world].add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0)))
	_shown_world = index
	var world := _worlds[index]
	var color := _color_of(world)
	_world_buttons[index].add_theme_stylebox_override("normal", _box(Color(color.darkened(0.55), 0.85), Color(0, 0, 0, 0)))
	_backdrop.texture = world.theme.backdrop if world.theme else null
	_world_name.text = world.name
	_world_name.add_theme_color_override("font_color", color)
	_room_title.text = ""
	for button in _room_buttons:
		_room_grid.remove_child(button)
		button.queue_free()
	_room_buttons.clear()

	var world_button := _world_buttons[index]
	for i in world.levels.size():
		var level := world.levels[i]
		var button := _button(str(level.number), color)
		button.custom_minimum_size = Vector2(26, 18)
		button.focus_entered.connect(_show_room.bind(level))
		button.mouse_entered.connect(_show_room.bind(level))
		button.pressed.connect(play.bind(level))
		_room_grid.add_child(button)
		if i % ROOM_COLUMNS == 0:
			button.focus_neighbor_left = button.get_path_to(world_button)
		_room_buttons.append(button)
	# The room buttons are new, so point the world buttons at them again.
	for b in _world_buttons:
		b.focus_neighbor_right = b.get_path_to(_room_buttons[0]) if not _room_buttons.is_empty() else NodePath()


func _show_room(level: LevelCatalog.Level) -> void:
	_room_title.text = "%d. %s" % [level.number, level.title]


func _enter_rooms() -> void:
	if not _room_buttons.is_empty():
		_room_buttons[0].grab_focus()


func _color_of(world: LevelCatalog.World) -> Color:
	return world.theme.title_color if world.theme else DIM


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.25))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := _box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
	var lit := _box(Color(color.darkened(0.55), 0.85), color)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", lit)
	button.add_theme_stylebox_override("pressed", lit)
	button.add_theme_stylebox_override("focus", lit)
	return button


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1 if border.a > 0.0 else 0)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


func _bar_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	return box
