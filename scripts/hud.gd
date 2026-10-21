class_name Hud
extends CanvasLayer

@onready var _deaths: Label = $Deaths
@onready var _taunt: Label = $Taunt
@onready var _banner: Label = $Banner


func _ready() -> void:
	Game.deaths_changed.connect(_on_deaths_changed)
	Game.taunted.connect(show_taunt)
	_on_deaths_changed(Game.total_deaths, Game.room_deaths)
	_banner.visible = false


func show_taunt(line: String) -> void:
	_taunt.text = line


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true


func _on_deaths_changed(total: int, in_room: int) -> void:
	_deaths.text = "Deaths: %d  (room: %d)" % [total, in_room]
