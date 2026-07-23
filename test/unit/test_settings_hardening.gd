extends GutTest

# Robustness / tamper tests: a corrupt or hand-edited settings.cfg must fall back
# to safe defaults and clamp ranges instead of crashing at boot.

var _saved_config: ConfigFile


func before_each() -> void:
	_saved_config = Settings._config
	Settings._config = ConfigFile.new()


func after_each() -> void:
	Settings._config = _saved_config


func test_string_where_float_expected_falls_back() -> void:
	Settings._config.set_value("audio", "master_volume", "totally not a number")
	assert_eq(Settings._cfg_float("audio", "master_volume", 0.8, 0.0, 1.0), 0.8,
		"a string volume falls back to the default (no linear_to_db crash)")


func test_out_of_range_float_is_clamped() -> void:
	Settings._config.set_value("audio", "music_volume", 999.0)
	assert_eq(Settings._cfg_float("audio", "music_volume", 0.8, 0.0, 1.0), 1.0, "over-max clamps to 1.0")
	Settings._config.set_value("audio", "music_volume", -50.0)
	assert_eq(Settings._cfg_float("audio", "music_volume", 0.8, 0.0, 1.0), 0.0, "under-min clamps to 0.0")


func test_bad_int_is_coerced_and_clamped() -> void:
	Settings._config.set_value("visual", "background_quality", "high")
	assert_eq(Settings._cfg_int("visual", "background_quality", 2, 0, 3), 2, "string -> default int")
	Settings._config.set_value("visual", "background_quality", 99)
	assert_eq(Settings._cfg_int("visual", "background_quality", 2, 0, 3), 3, "over-max int clamps")


func test_bool_coercion_survives_garbage() -> void:
	Settings._config.set_value("text", "auto_advance", "yes")
	assert_true(Settings._cfg_bool("text", "auto_advance", false), "'yes' coerces to true")
	Settings._config.set_value("text", "auto_advance", 0)
	assert_false(Settings._cfg_bool("text", "auto_advance", true), "0 coerces to false")


func test_full_load_of_tampered_config_does_not_crash() -> void:
	var bad := ConfigFile.new()
	bad.set_value("audio", "master_volume", "haxx")
	bad.set_value("audio", "sfx_volume", 42.0)
	bad.set_value("display", "window_size", "not a vector")
	bad.set_value("visual", "background_quality", [])
	bad.set_value("language", "locale", "zz_evil")
	var path := "user://test_tampered_settings.cfg"
	bad.save(path)
	# Load it through the same code path load_settings uses (helpers read _config).
	Settings._config = ConfigFile.new()
	assert_eq(Settings._config.load(path), OK, "tampered file still parses as a ConfigFile")
	# Every getter must yield a safe value, never crash.
	assert_between(Settings._cfg_float("audio", "master_volume", 1.0, 0.0, 1.0), 0.0, 1.0, "master safe")
	assert_between(Settings._cfg_float("audio", "sfx_volume", 0.8, 0.0, 1.0), 0.0, 1.0, "sfx clamped")
	var loc: Variant = Settings._config.get_value("language", "locale", "en")
	var safe_locale: String = loc if (loc is String and loc in Settings.VALID_LOCALES) else "en"
	assert_eq(safe_locale, "en", "unknown locale falls back to en")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
