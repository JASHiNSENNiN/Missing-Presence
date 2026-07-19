extends Node

## Central UI SFX + ambience player.
##
## UI foley (soft ASMR paper) routes through the "UI" bus; the looping outdoor
## ambience bed (grass rustle + soft wind) routes through the "SFX" bus. Both
## buses are created + volume-controlled by Settings.gd.
##
## WAVs are loaded with AudioStreamWAV.load_from_file() rather than load() so
## they read the raw file fresh and never depend on the editor's import cache
## (which would otherwise serve stale audio right after a file is re-baked).
##
## Usage:
##   UISound.hover() / .select() / .confirm() / .back() / .error()
##   UISound.page_turn() / .book_open()
##   UISound.play_ambience()  -- start the grass+wind loop (menus, in _ready)
##   UISound.stop_ambience()  -- fade the loop out

const UI_DIR := "res://Audio/UI/"
const AMB_DIR := "res://Audio/Ambience/"
const SOUND_NAMES := ["hover", "select", "confirm", "back", "error", "page_turn", "book_open"]
const AMBIENCE_NAMES := ["grass", "wind"]

const POOL_SIZE := 8
## Slight per-play pitch drift keeps repeated taps from sounding mechanical
## ("always alive") without turning them tonal.
const PITCH_VARIATION := 0.05
const AMBIENCE_FADE := 1.2

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _ui_bus: StringName = &"UI"
var _amb_bus: StringName = &"SFX"

var _amb_players: Dictionary = {}
var _amb_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if AudioServer.get_bus_index("UI") == -1:
		_ui_bus = &"Master"
	if AudioServer.get_bus_index("SFX") == -1:
		_amb_bus = &"Master"

	for snd in SOUND_NAMES:
		var stream := _load_wav(UI_DIR + "ui_" + snd + ".wav")
		if stream != null:
			_streams[snd] = stream

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = _ui_bus
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)

	_setup_ambience()


func _load_wav(path: String) -> AudioStreamWAV:
	if not FileAccess.file_exists(path):
		push_warning("UISound: missing " + path)
		return null
	return AudioStreamWAV.load_from_file(path)


func _setup_ambience() -> void:
	for amb in AMBIENCE_NAMES:
		var stream := _load_wav(AMB_DIR + "amb_" + amb + ".wav")
		if stream == null:
			continue
		# Seamless forward loop over the whole (crossfade-tiled) buffer.
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / 2  # 16-bit mono -> 2 bytes/frame
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = _amb_bus
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = -80.0
		add_child(player)
		_amb_players[amb] = player


func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _streams.has(sound_name):
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	player.play()


func hover() -> void:
	play("hover")


func select() -> void:
	play("select")


func confirm() -> void:
	play("confirm")


func back() -> void:
	play("back")


func error() -> void:
	play("error")


func page_turn() -> void:
	play("page_turn")


func book_open() -> void:
	play("book_open")


## Start the looping grass+wind bed (idempotent). Fades in from silence.
func play_ambience() -> void:
	if _amb_active:
		return
	_amb_active = true
	for amb in _amb_players:
		var player: AudioStreamPlayer = _amb_players[amb]
		var target: float = -14.0 if amb == "grass" else -20.0
		player.volume_db = -80.0
		if not player.playing:
			player.play()
		var tween := create_tween()
		tween.tween_property(player, "volume_db", target, AMBIENCE_FADE)


## Fade the ambience bed out and stop it.
func stop_ambience() -> void:
	if not _amb_active:
		return
	_amb_active = false
	for amb in _amb_players:
		var player: AudioStreamPlayer = _amb_players[amb]
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -80.0, AMBIENCE_FADE)
		tween.tween_callback(player.stop)


## Convenience: wire a Control so hovering it plays the soft hover tick.
func bind_hover(control: Control) -> void:
	if is_instance_valid(control) and not control.mouse_entered.is_connected(hover):
		control.mouse_entered.connect(hover)
