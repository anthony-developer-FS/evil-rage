extends Node
## Autoload. Plays every sound and the music, and owns the volume settings.
##
## Gameplay code never calls this. It listens: whenever a Player, Goal or troll
## trap enters the tree, their signals get wired to sounds here. To give a new trap
## a sound, add a `triggered` signal to it and an entry to TRAP_SOUNDS.

## Emitted for every sound effect started. Tests use it to check the wiring.
signal played(sound: StringName)

const SFX := {
	&"jump": preload("res://assets/audio/sfx/jump.wav"),
	&"wall_jump": preload("res://assets/audio/sfx/wall_jump.wav"),
	&"land": preload("res://assets/audio/sfx/land.wav"),
	&"death": preload("res://assets/audio/sfx/death.wav"),
	&"respawn": preload("res://assets/audio/sfx/respawn.wav"),
	&"taunt": preload("res://assets/audio/sfx/taunt.wav"),
	&"goal": preload("res://assets/audio/sfx/goal.wav"),
	&"win": preload("res://assets/audio/sfx/win.wav"),
	&"fake_floor": preload("res://assets/audio/sfx/fake_floor.wav"),
	&"pop_spikes": preload("res://assets/audio/sfx/pop_spikes.wav"),
	&"runaway_goal": preload("res://assets/audio/sfx/runaway_goal.wav"),
	&"invisible_block": preload("res://assets/audio/sfx/invisible_block.wav"),
	&"falling_ceiling": preload("res://assets/audio/sfx/falling_ceiling.wav"),
	&"ceiling_thud": preload("res://assets/audio/sfx/ceiling_thud.wav"),
	&"ui_tick": preload("res://assets/audio/sfx/ui_tick.wav"),
	&"dart": preload("res://assets/audio/sfx/dart.wav"),
	&"secret": preload("res://assets/audio/sfx/secret.wav"),
	&"grind": preload("res://assets/audio/sfx/grind.wav"),
	&"gravity": preload("res://assets/audio/sfx/gravity.wav"),
	&"mirror": preload("res://assets/audio/sfx/mirror.wav"),
	&"void_shift": preload("res://assets/audio/sfx/void_shift.wav"),
	&"frost": preload("res://assets/audio/sfx/frost.wav"),
	&"pop_block": preload("res://assets/audio/sfx/pop_block.wav"),
	&"chest": preload("res://assets/audio/sfx/chest.wav"),
	&"curse": preload("res://assets/audio/sfx/curse.wav"),
	&"shield": preload("res://assets/audio/sfx/shield.wav"),
	&"portal": preload("res://assets/audio/sfx/portal.wav"),
	&"coin": preload("res://assets/audio/sfx/coin.wav"),
	&"fuse": preload("res://assets/audio/sfx/fuse.wav"),
	&"explosion": preload("res://assets/audio/sfx/explosion.wav"),
	&"reaper": preload("res://assets/audio/sfx/reaper.wav"),
	&"saw": preload("res://assets/audio/sfx/saw.wav"),
	&"bullet": preload("res://assets/audio/sfx/bullet.wav"),
	&"ghost": preload("res://assets/audio/sfx/ghost.wav"),
}
const MUSIC := preload("res://assets/audio/music/theme.ogg")

## Trap class name -> sound played when its `triggered` signal fires.
const TRAP_SOUNDS := {
	&"FakeFloor": &"fake_floor",
	&"PopSpikes": &"pop_spikes",
	&"RunawayGoal": &"runaway_goal",
	&"InvisibleBlock": &"invisible_block",
	&"FallingCeiling": &"falling_ceiling",
	&"Spring": &"jump",
	&"DecoyGoal": &"pop_spikes",
	&"DartTrap": &"dart",
	&"FakeWall": &"secret",
	&"MovingWall": &"grind",
	&"GravityField": &"gravity",
	&"MirrorZone": &"mirror",
	&"ShiftingVoid": &"void_shift",
	&"CreepingSpikes": &"frost",
	&"PopBlock": &"pop_block",
	&"TreasureChest": &"chest",
	&"Portal": &"portal",
	&"Coin": &"coin",
	&"Reaper": &"reaper",
	&"Ghost": &"ghost",
}
## Sounds that get a little random pitch so repeats don't sound robotic.
const JITTER := [&"jump", &"wall_jump", &"land"]
## Landings slower than this are silent, so spawning and tiny steps stay quiet.
const LAND_MIN_SPEED := 120.0
const VOLUME_STEP := 0.1
const SETTINGS_PATH := "user://settings.cfg"
const VOICES := 8

## Linear 0..1 per bus. Saved to SETTINGS_PATH.
var volumes := {&"Master": 0.8, &"Music": 0.6, &"SFX": 0.8}
var music_muted := false

## Headless runs (the test suites) skip actual playback but still emit `played`.
## Godot leaks any stream that played in headless mode at exit, which spams the logs.
var _silent := DisplayServer.get_name() == "headless"
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _respawn_pending := false
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_voices.append(p)

	var stream: AudioStreamOggVorbis = MUSIC.duplicate()
	stream.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.bus = &"Music"
	add_child(_music)

	_build_toast()
	_load_settings()
	_apply_volumes()
	if not _silent:
		_music.play()

	get_tree().node_added.connect(_on_node_added)
	Game.taunted.connect(func(_line: String) -> void: _play_later(&"taunt", 0.18))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("volume_up"):
		_nudge_master(VOLUME_STEP)
	elif event.is_action_pressed("volume_down"):
		_nudge_master(-VOLUME_STEP)
	elif event.is_action_pressed("toggle_music"):
		music_muted = not music_muted
		_apply_volumes()
		_save_settings()
		_show_toast("Music: %s" % ("off" if music_muted else "on"))


func play(sound: StringName) -> void:
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = SFX[sound]
	p.pitch_scale = randf_range(0.93, 1.07) if sound in JITTER else 1.0
	if not _silent:
		p.play()
	played.emit(sound)


## Sets a bus's volume, 0..1, and saves it. For a future options menu.
func set_volume(bus: StringName, value: float) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func _on_node_added(node: Node) -> void:
	if node is Player:
		node.jumped.connect(play.bind(&"jump"))
		node.wall_jumped.connect(play.bind(&"wall_jump"))
		node.landed.connect(_on_landed)
		node.died.connect(_on_died)
		node.shield_broken.connect(play.bind(&"shield"))
		if _respawn_pending:
			_respawn_pending = false
			play(&"respawn")
	elif node is Goal:
		node.reached.connect(_on_goal_reached.bind(node))
	# Not elif: RunawayGoal is a Goal and a trap.
	var script: Script = node.get_script()
	if script and TRAP_SOUNDS.has(script.get_global_name()):
		node.triggered.connect(play.bind(TRAP_SOUNDS[script.get_global_name()]))
	if node is FallingCeiling:
		node.landed.connect(play.bind(&"ceiling_thud"))
	if node is TreasureChest:
		node.cursed.connect(_play_later.bind(&"curse", 0.3))
	if node is CreepingSpikes:
		node.retracted.connect(play.bind(&"frost"))
	if node is Coin:
		node.lit.connect(play.bind(&"fuse"))
		node.exploded.connect(play.bind(&"explosion"))
	if node is Reaper:
		# Each cast is named after its sound: "saw" or "bullet".
		node.cast.connect(play)


func _on_landed(fall_speed: float) -> void:
	if fall_speed >= LAND_MIN_SPEED:
		play(&"land")


func _on_died() -> void:
	play(&"death")
	_respawn_pending = true


func _on_goal_reached(goal: Goal) -> void:
	if goal.next_room == "":
		play(&"win")
		# Duck the music under the fanfare, then bring it back.
		var tween := create_tween()
		tween.tween_property(_music, "volume_db", -18.0, 0.2)
		tween.tween_interval(2.0)
		tween.tween_property(_music, "volume_db", 0.0, 1.5)
	else:
		play(&"goal")


func _play_later(sound: StringName, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	play(sound)


func _nudge_master(step: float) -> void:
	set_volume(&"Master", snappedf(volumes[&"Master"] + step, VOLUME_STEP))
	play(&"ui_tick")
	_show_toast("Volume: %d%%" % roundi(volumes[&"Master"] * 100))


func _apply_volumes() -> void:
	for bus: StringName in volumes:
		var idx := AudioServer.get_bus_index(bus)
		if idx < 0:
			continue
		var v: float = volumes[bus]
		AudioServer.set_bus_volume_db(idx, linear_to_db(v) if v > 0.0 else -80.0)
		AudioServer.set_bus_mute(idx, v <= 0.0 or (bus == &"Music" and music_muted))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus: StringName in volumes:
		volumes[bus] = clampf(cfg.get_value("audio", String(bus).to_lower(), volumes[bus]), 0.0, 1.0)
	music_muted = cfg.get_value("audio", "music_muted", music_muted)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	# Keep any other sections another system saved in the same file.
	cfg.load(SETTINGS_PATH)
	for bus: StringName in volumes:
		cfg.set_value("audio", String(bus).to_lower(), volumes[bus])
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.save(SETTINGS_PATH)


## Small corner readout for volume changes. Lives on its own layer outside the
## pixel viewport so it renders at native resolution like the HUD.
func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.position = Vector2(156, 166)
	_toast.size = Vector2(160, 12)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
