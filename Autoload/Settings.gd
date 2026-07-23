extends Node

signal master_volume_changed(value: float)
signal music_volume_changed(value: float)
signal sfx_volume_changed(value: float)
signal voice_volume_changed(value: float)
signal ui_volume_changed(value: float)
signal background_quality_changed(value: int)

const SETTINGS_PATH := "user://settings.cfg"

const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 0.8
const DEFAULT_VOICE_VOLUME := 1.0
const DEFAULT_UI_VOLUME := 1.0

const DEFAULT_FULLSCREEN := false
const DEFAULT_WINDOW_SIZE := Vector2i(1152, 648)

const DEFAULT_TEXT_SPEED := 0.5
const DEFAULT_AUTO_ADVANCE := false
const DEFAULT_AUTO_ADVANCE_SPEED := 0.5
const DEFAULT_SKIP_UNREAD := false

const DEFAULT_LANGUAGE := "en"

const DEFAULT_BACKGROUND_QUALITY := 2

const DEFAULT_NOTIFICATIONS := true

var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var voice_volume: float = DEFAULT_VOICE_VOLUME
var ui_volume: float = DEFAULT_UI_VOLUME

var fullscreen: bool = DEFAULT_FULLSCREEN
var window_size: Vector2i = DEFAULT_WINDOW_SIZE

var text_speed: float = DEFAULT_TEXT_SPEED
var auto_advance: bool = DEFAULT_AUTO_ADVANCE
var auto_advance_speed: float = DEFAULT_AUTO_ADVANCE_SPEED
var skip_unread: bool = DEFAULT_SKIP_UNREAD

var language: String = DEFAULT_LANGUAGE
var background_quality: int = DEFAULT_BACKGROUND_QUALITY
var notifications_enabled: bool = DEFAULT_NOTIFICATIONS

var _config := ConfigFile.new()


func _ready() -> void:
	_sanitize_dialogic_autosave_settings()
	_enforce_dialogic_layout_end_behaviour()
	_ensure_audio_buses()
	load_settings()
	_apply_audio_settings()
	_apply_display_settings()
	_apply_language_setting()


func _sanitize_dialogic_autosave_settings() -> void:
	if ProjectSettings.has_setting("dialogic/save/autosave"):
		ProjectSettings.set_setting("dialogic/save/autosave", _variant_to_bool(ProjectSettings.get_setting("dialogic/save/autosave", false)))
	if ProjectSettings.has_setting("dialogic/save/autosave_mode"):
		ProjectSettings.set_setting("dialogic/save/autosave_mode", int(ProjectSettings.get_setting("dialogic/save/autosave_mode", 0)))
	if ProjectSettings.has_setting("dialogic/save/autosave_delay"):
		ProjectSettings.set_setting("dialogic/save/autosave_delay", float(ProjectSettings.get_setting("dialogic/save/autosave_delay", 60.0)))


func _enforce_dialogic_layout_end_behaviour() -> void:
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 1)


func _variant_to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	if value is String:
		return value.to_lower() in ["true", "1", "yes"]
	if value is int or value is float:
		return value != 0
	return false


const VALID_LOCALES := ["en", "fil", "tl"]
const MAX_WINDOW := Vector2i(7680, 4320)
const MIN_WINDOW := Vector2i(640, 360)


func _cfg_float(section: String, key: String, default: float, lo: float, hi: float) -> float:
	var v: Variant = _config.get_value(section, key, default)
	if not (v is float or v is int):
		return default
	return clampf(float(v), lo, hi)


func _cfg_int(section: String, key: String, default: int, lo: int, hi: int) -> int:
	var v: Variant = _config.get_value(section, key, default)
	if not (v is float or v is int):
		return default
	return clampi(int(v), lo, hi)


func _cfg_bool(section: String, key: String, default: bool) -> bool:
	return _variant_to_bool(_config.get_value(section, key, default))


func load_settings() -> void:
	# A corrupt/tampered settings.cfg must never crash boot: bad types fall back
	# to defaults and every numeric value is range-clamped.
	if _config.load(SETTINGS_PATH) != OK:
		return

	master_volume = _cfg_float("audio", "master_volume", DEFAULT_MASTER_VOLUME, 0.0, 1.0)
	music_volume = _cfg_float("audio", "music_volume", DEFAULT_MUSIC_VOLUME, 0.0, 1.0)
	sfx_volume = _cfg_float("audio", "sfx_volume", DEFAULT_SFX_VOLUME, 0.0, 1.0)
	voice_volume = _cfg_float("audio", "voice_volume", DEFAULT_VOICE_VOLUME, 0.0, 1.0)
	ui_volume = _cfg_float("audio", "ui_volume", DEFAULT_UI_VOLUME, 0.0, 1.0)

	fullscreen = _cfg_bool("display", "fullscreen", DEFAULT_FULLSCREEN)
	var ws: Variant = _config.get_value("display", "window_size", DEFAULT_WINDOW_SIZE)
	window_size = ws if ws is Vector2i else DEFAULT_WINDOW_SIZE
	window_size = window_size.clamp(MIN_WINDOW, MAX_WINDOW)

	text_speed = _cfg_float("text", "text_speed", DEFAULT_TEXT_SPEED, 0.0, 1.0)
	auto_advance = _cfg_bool("text", "auto_advance", DEFAULT_AUTO_ADVANCE)
	auto_advance_speed = _cfg_float("text", "auto_advance_speed", DEFAULT_AUTO_ADVANCE_SPEED, 0.0, 1.0)
	skip_unread = _cfg_bool("text", "skip_unread", DEFAULT_SKIP_UNREAD)

	var loc: Variant = _config.get_value("language", "locale", DEFAULT_LANGUAGE)
	language = loc if (loc is String and loc in VALID_LOCALES) else DEFAULT_LANGUAGE
	background_quality = _cfg_int("visual", "background_quality", DEFAULT_BACKGROUND_QUALITY, 0, 3)
	notifications_enabled = _cfg_bool("gameplay", "notifications", DEFAULT_NOTIFICATIONS)


func save_settings() -> void:
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "music_volume", music_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("audio", "voice_volume", voice_volume)
	_config.set_value("audio", "ui_volume", ui_volume)

	_config.set_value("display", "fullscreen", fullscreen)
	_config.set_value("display", "window_size", window_size)

	_config.set_value("text", "text_speed", text_speed)
	_config.set_value("text", "auto_advance", auto_advance)
	_config.set_value("text", "auto_advance_speed", auto_advance_speed)
	_config.set_value("text", "skip_unread", skip_unread)

	_config.set_value("language", "locale", language)
	_config.set_value("visual", "background_quality", background_quality)
	_config.set_value("gameplay", "notifications", notifications_enabled)

	_config.save(SETTINGS_PATH)


func set_master_volume(value: float) -> void:
	master_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	master_volume_changed.emit(value)
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	music_volume_changed.emit(value)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
	sfx_volume_changed.emit(value)
	save_settings()


func set_voice_volume(value: float) -> void:
	voice_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(value))
	voice_volume_changed.emit(value)
	save_settings()


func set_ui_volume(value: float) -> void:
	ui_volume = value
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(value))
	ui_volume_changed.emit(value)
	save_settings()


func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	get_window().mode = Window.MODE_FULLSCREEN if enabled else Window.MODE_WINDOWED
	save_settings()


func set_window_size(size: Vector2i) -> void:
	window_size = size
	if not fullscreen:
		get_window().size = size
		get_window().move_to_center()
	save_settings()


func set_text_speed(value: float) -> void:
	text_speed = value
	save_settings()


func set_auto_advance(enabled: bool) -> void:
	auto_advance = enabled
	save_settings()


func set_auto_advance_speed(value: float) -> void:
	auto_advance_speed = value
	save_settings()


func set_skip_unread(enabled: bool) -> void:
	skip_unread = enabled
	save_settings()


func set_language(locale: String) -> void:
	language = locale
	TranslationServer.set_locale(locale)
	save_settings()


func set_background_quality(value: int) -> void:
	background_quality = value
	background_quality_changed.emit(value)
	save_settings()


func set_notifications_enabled(enabled: bool) -> void:
	notifications_enabled = enabled
	save_settings()


func _ensure_audio_buses() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Voice")
	_ensure_bus("UI")


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return

	var index := AudioServer.bus_count
	AudioServer.bus_count = index + 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _apply_audio_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(voice_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(ui_volume))


func _apply_display_settings() -> void:
	get_window().mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
	if not fullscreen:
		get_window().size = window_size


func _apply_language_setting() -> void:
	TranslationServer.set_locale(language)
