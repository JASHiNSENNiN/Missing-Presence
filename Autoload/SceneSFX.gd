extends Node

## Scene sound-effects director. Three channels, all fed by the delivered SFX set:
##  - one-shots  -> [signal arg="sfx:<name>"]         (SFX bus)
##  - ambience   -> auto by background, or [signal arg="amb:<name>"] / "amb:stop"  (Music bus)
##  - text bleep -> auto per speaker on each line       (Voice bus)

const SFX_DIR := "res://SFX/"
const BLEEP_DIR := "res://SFX/CHARACTER text bleep/"

# One-shot cues: short name -> file. Fired by [signal arg="sfx:<name>"].
const ONESHOTS := {
	"alarm": "Alarm clock ringing.mp3",
	"zipper": "Backpack zipper or rustling.mp3",
	"camera": "camera shutter.mp3",
	"car": "Car engine or ignition sound.mp3",
	"chair": "Chair scraping or sitting down on furniture.mp3",
	"crumple": "Crumpling paper.mp3",
	"doorbell": "door bell.mp3",
	"door_close": "door close.mp3",
	"drawer": "Drawer opening and closing.mp3",
	"footsteps": "footsteps.mp3",
	"laughter": "Group laughter.mp3",
	"heartbeat": "Heartbeat or tense underscore.mp3",
	"knock": "knock on door.mp3",
	"chat_flood": "Multiple rapid phone pings or chat flooding.mp3",
	"breath_out": "Out of breath breathing.mp3",
	"page": "page turn.mp3",
	"pencil": "pencil.mp3",
	"phone_lock": "phone lock.mp3",
	"phone_notif": "phone notif.mp3",
	"phone_unlock": "phone unlock.mp3",
	"rice": "Rice serving or scooping sound.mp3",
	"run": "Running footsteps.mp3",
	"school_bell": "School bell ringing.mp3",
	"breath_shaky": "Shaky breath or held breath sound.mp3",
	"tools": "tools.mp3",
	"utensils": "Utensils and cutlery clinking against plates.mp3",
}

# Looping ambience beds. Fired by [signal arg="amb:<name>"] or auto (below).
const AMBIENCES := {
	"crowd": "BG_people talking.mp3",
	"commute": "commute ambiance.mp3",
	"kitchen": "Kitchen ambiance or cooking sounds.mp3",
	"tv": "TV playing softly in background.mp3",
	"fan": "Ceiling fan hum.mp3",
	"rain": "Rain tapping on windows.mp3",
	"clock": "Wall clock ticking.mp3",
}

# Background image (basename) -> ambience name. Scene changes pick a bed automatically.
const BG_AMBIENCE := {
	"classroom.png": "crowd",
	"campus_hallway.png": "crowd",
	"campus_courtyard.png": "commute",
	"mayas_room.png": "fan",
	"image 3.png": "tv",
}

# Speaker identifier -> text-bleep file. Narration / unknown -> universal.
const BLEEPS := {
	"Maya": "maya text bleep.wav",
	"Ethan": "ethan bleep text.wav",
	"Jennifer": "jennifer bleep text.wav",
	"Ricardo": "ricardo bleep text.wav",
	"_universal": "universal bleep text.wav",
}

const POOL_SIZE := 6
const AMBIENCE_FADE := 1.4
const BLEEP_PITCH_JITTER := 0.06

var _oneshot_streams: Dictionary = {}
var _bleep_streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _bleep_player: AudioStreamPlayer
var _amb_player: AudioStreamPlayer
var _amb_current: String = ""
var _amb_tween: Tween

var _sfx_bus: StringName = &"SFX"
var _music_bus: StringName = &"Music"
var _voice_bus: StringName = &"Voice"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("SFX") == -1: _sfx_bus = &"Master"
	if AudioServer.get_bus_index("Music") == -1: _music_bus = &"Master"
	if AudioServer.get_bus_index("Voice") == -1: _voice_bus = &"Master"

	for name: String in ONESHOTS:
		var s := _load(SFX_DIR + ONESHOTS[name])
		if s != null:
			_oneshot_streams[name] = s
	for key: String in BLEEPS:
		var s := _load(BLEEP_DIR + BLEEPS[key])
		if s != null:
			_bleep_streams[key] = s

	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = _sfx_bus
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)

	_bleep_player = AudioStreamPlayer.new()
	_bleep_player.bus = _voice_bus
	_bleep_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bleep_player)

	_amb_player = AudioStreamPlayer.new()
	_amb_player.bus = _music_bus
	_amb_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_amb_player)

	if Engine.has_singleton("Dialogic") or get_node_or_null("/root/Dialogic") != null:
		_connect_dialogic.call_deferred()


func _connect_dialogic() -> void:
	if not Dialogic.signal_event.is_connected(_on_signal_event):
		Dialogic.signal_event.connect(_on_signal_event)
	if Dialogic.has_subsystem("Text") and not Dialogic.Text.text_started.is_connected(_on_text_started):
		Dialogic.Text.text_started.connect(_on_text_started)
	if Dialogic.has_subsystem("Backgrounds") and not Dialogic.Backgrounds.background_changed.is_connected(_on_background_changed):
		Dialogic.Backgrounds.background_changed.connect(_on_background_changed)
	if not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)


func _load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("[SceneSFX] missing: %s" % path)
		return null
	return load(path)


func play_sfx(name: String, volume_db: float = 0.0) -> void:
	var s: AudioStream = _oneshot_streams.get(name)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.bus = _sfx_bus
	p.play()


func play_bleep(speaker_id: String) -> void:
	var s: AudioStream = _bleep_streams.get(speaker_id, _bleep_streams.get("_universal"))
	if s == null:
		return
	_bleep_player.stream = s
	_bleep_player.pitch_scale = 1.0 + randf_range(-BLEEP_PITCH_JITTER, BLEEP_PITCH_JITTER)
	_bleep_player.play()


func play_ambience(name: String) -> void:
	if name == _amb_current and _amb_player.playing:
		return
	var s: AudioStream = null
	if AMBIENCES.has(name):
		s = _load(SFX_DIR + AMBIENCES[name])
	if s == null:
		stop_ambience()
		return
	_amb_current = name
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	if is_instance_valid(_amb_tween):
		_amb_tween.kill()
	_amb_player.stream = s
	_amb_player.volume_db = -40.0
	_amb_player.play()
	_amb_tween = create_tween()
	_amb_tween.tween_property(_amb_player, ^"volume_db", -12.0, AMBIENCE_FADE)


func stop_ambience() -> void:
	_amb_current = ""
	if not _amb_player.playing:
		return
	if is_instance_valid(_amb_tween):
		_amb_tween.kill()
	_amb_tween = create_tween()
	_amb_tween.tween_property(_amb_player, ^"volume_db", -40.0, AMBIENCE_FADE)
	_amb_tween.tween_callback(_amb_player.stop)


func _on_signal_event(argument: Variant) -> void:
	if not (argument is String):
		return
	var arg := argument as String
	if arg.begins_with("sfx:"):
		play_sfx(arg.substr(4).strip_edges())
	elif arg.begins_with("amb:"):
		var a := arg.substr(4).strip_edges()
		if a == "stop":
			stop_ambience()
		else:
			play_ambience(a)


func _on_text_started(_info: Dictionary) -> void:
	var speaker: String = str(Dialogic.current_state_info.get("speaker", ""))
	play_bleep(speaker if _bleep_streams.has(speaker) else "_universal")


func _on_background_changed(info: Dictionary) -> void:
	var arg: String = str(info.get("argument", ""))
	if arg.is_empty():
		return
	var base := arg.get_file()
	if BG_AMBIENCE.has(base):
		play_ambience(BG_AMBIENCE[base])


func _on_timeline_ended() -> void:
	stop_ambience()
