class_name Hud
extends CanvasLayer

@onready var _deaths: Label = $Deaths
@onready var _taunt: Label = $Taunt
@onready var _banner: Label = $Banner
@onready var _title: Label = $Title


func _ready() -> void:
	Game.deaths_changed.connect(_on_deaths_changed)
	Game.taunted.connect(show_taunt)
	Game.banner_shown.connect(show_banner)
	Game.title_shown.connect(func(text: String) -> void: _title.text = text)
	_on_deaths_changed(Game.total_deaths, Game.room_deaths)
	_banner.visible = false


func show_taunt(line: String) -> void:
	_taunt.text = line


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


## Also fires when a room loads, so it refreshes the taunt and clears the banner.
func _on_deaths_changed(total: int, in_room: int) -> void:
	_deaths.text = "Deaths: %d  (room: %d)" % [total, in_room]
	_taunt.text = Game.last_taunt
	_banner.visible = false
