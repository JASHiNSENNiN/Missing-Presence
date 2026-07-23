@tool
extends DialogicLayoutLayer

@export_group("Time Of Day")
@export var scene_tints: Dictionary = {
	"act1_intro_classroom": Color(1.0, 0.965, 0.90),
	"act1_hallway": Color(1.0, 0.99, 0.96),
	"act1_dinner": Color(1.0, 0.88, 0.74),
	"act1_montage": Color(0.80, 0.84, 1.0),
	"act1_exam_day": Color(1.0, 0.94, 0.84),
	"act1_courtyard": Color(1.0, 0.97, 0.90),
	"act2_montage": Color(0.82, 0.85, 1.0),
	"act2_dinner": Color(1.0, 0.86, 0.72),
	"act2_sala": Color(1.0, 0.83, 0.70),
	"act3_good_shop": Color(1.0, 0.95, 0.84),
	"act3_good_dinner": Color(1.0, 0.85, 0.71),
	"act3_neutral": Color(0.94, 0.96, 1.0),
	"act3_bad": Color(0.82, 0.83, 0.96),
	"act_ending": Color(0.90, 0.89, 0.96),
	"act4_good": Color(0.80, 0.82, 0.98),
	"act4_neutral": Color(0.83, 0.84, 0.95),
	"act4_bad": Color(0.72, 0.74, 0.92),
	"act5_good": Color(1.0, 0.94, 0.86),
	"act5_neutral": Color(0.90, 0.91, 0.97),
	"act5_bad": Color(0.70, 0.72, 0.90),
}
@export var default_tint: Color = Color.WHITE
@export_range(0.0, 4.0, 0.05) var tint_fade: float = 0.9

@export_group("Vignette And Grain")
@export var overlay_enabled: bool = true
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.34
@export_range(0.0, 1.0, 0.01) var vignette_softness: float = 0.55
@export var vignette_color: Color = Color(0.16, 0.10, 0.05)
@export_range(0.0, 0.25, 0.005) var grain_strength: float = 0.035

@export_group("Dust Motes")
@export var dust_scenes: Array[String] = ["act1_intro_classroom", "act1_exam_day", "act1_montage", "act2_montage", "act3_good_shop"]
@export_range(0, 200) var dust_amount: int = 26
@export var dust_color: Color = Color(1.0, 0.97, 0.86, 0.5)

@export_group("God Rays")
@export var ray_scenes: Array[String] = ["act1_intro_classroom", "act1_exam_day", "act1_courtyard", "act3_good_shop"]
@export_range(0.0, 1.0, 0.01) var ray_strength: float = 0.20
@export_range(-1.5, 1.5, 0.01) var ray_angle: float = 0.55

@export_group("Rain")
@export var rain_scenes: Array[String] = []
@export_range(0, 400) var rain_amount: int = 160
@export var rain_color: Color = Color(0.72, 0.78, 0.92, 0.5)

@export_group("Shock")
@export var shock_flash_color: Color = Color(1.0, 1.0, 1.0, 0.5)

@export_group("Emotional Grade")
@export var drain_color: Color = Color(0.62, 0.66, 0.74)
@export_range(0.0, 3.0, 0.05) var drain_fade: float = 1.6
@export_range(0.0, 0.4, 0.01) var heartbeat_depth: float = 0.13
@export_range(0.2, 3.0, 0.05) var heartbeat_period: float = 1.15
@export_range(0.0, 0.25, 0.005) var grain_surge_peak: float = 0.11

var _rain: CPUParticles2D
var _shock_tween: Tween

var _background_holder: CanvasItem
var _tint_tween: Tween

var _current_tint: Color = Color.WHITE
var _heartbeat_tween: Tween
var _drain_tween: Tween
var _grain_tween: Tween
var _draining: bool = false


func _ready() -> void:
	super()
	_apply_overlay_settings()
	if Engine.is_editor_hint():
		return
	if not Dialogic.timeline_started.is_connected(_on_scene_changed):
		Dialogic.timeline_started.connect(_on_scene_changed)
	if not Dialogic.signal_event.is_connected(_on_signal_event):
		Dialogic.signal_event.connect(_on_signal_event)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_resized):
		vp.size_changed.connect(_on_viewport_resized)
	_build_rain()
	_on_scene_changed.call_deferred()


func _build_rain() -> void:
	_rain = CPUParticles2D.new()
	_rain.name = "Rain"
	_rain.emitting = false
	_rain.visible = false
	_rain.amount = maxi(rain_amount, 1)
	_rain.lifetime = 1.1
	_rain.direction = Vector2(0.12, 1.0)
	_rain.spread = 4.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 900.0
	_rain.initial_velocity_max = 1200.0
	_rain.scale_amount_min = 1.0
	_rain.scale_amount_max = 2.0
	_rain.color = rain_color
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.texture = _make_streak_texture()
	add_child(_rain)


func _make_streak_texture() -> ImageTexture:
	# A thin vertical white streak, soft at both ends — reads as a raindrop trail.
	var h := 26
	var img := Image.create(2, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t: float = float(y) / float(h - 1)
		var a: float = sin(t * PI)
		var col := Color(1.0, 1.0, 1.0, a)
		img.set_pixel(0, y, col)
		img.set_pixel(1, y, col)
	return ImageTexture.create_from_image(img)


func _on_signal_event(argument: Variant) -> void:
	if not (argument is String):
		return
	var arg := argument as String
	if arg == "rain:on":
		_apply_rain(true)
		return
	if arg == "rain:off":
		_apply_rain(false)
		return
	if arg == "shock":
		_flash_shock()
		return
	if arg == "heartbeat:on":
		_set_heartbeat(true)
		return
	if arg == "heartbeat:off":
		_set_heartbeat(false)
		return
	if arg == "drain:on":
		_set_drain(true)
		return
	if arg == "drain:off":
		_set_drain(false)
		return
	if arg == "grain:surge":
		_surge_grain()
		return
	if arg != "emphasis":
		return
	var overlay := get_node_or_null("Overlay") as ColorRect
	if overlay == null:
		return
	var mat := overlay.material as ShaderMaterial
	if mat == null:
		return
	var tween := create_tween()
	tween.tween_method(_set_vignette, vignette_strength, minf(vignette_strength + 0.28, 1.0), 0.18)
	tween.tween_interval(0.5)
	tween.tween_method(_set_vignette, minf(vignette_strength + 0.28, 1.0), vignette_strength, 0.9)


func _apply_rain(enabled: bool) -> void:
	if _rain == null:
		return
	_rain.amount = maxi(rain_amount, 1)
	_rain.color = rain_color
	var view := get_viewport().get_visible_rect().size
	if view.x > 0.0:
		_rain.position = Vector2(view.x * 0.5, -view.y * 0.08)
		_rain.emission_rect_extents = Vector2(view.x * 0.65, 4.0)
	_rain.emitting = enabled
	_rain.visible = enabled


func _flash_shock() -> void:
	var flash := get_node_or_null("ShockFlash") as ColorRect
	if flash == null:
		flash = ColorRect.new()
		flash.name = "ShockFlash"
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.color = shock_flash_color
		add_child(flash)
	var view := get_viewport().get_visible_rect().size
	flash.position = Vector2.ZERO
	flash.size = view
	flash.color = Color(shock_flash_color.r, shock_flash_color.g, shock_flash_color.b, 0.0)
	flash.visible = true
	if is_instance_valid(_shock_tween):
		_shock_tween.kill()
	_shock_tween = create_tween()
	_shock_tween.tween_property(flash, ^"color:a", shock_flash_color.a, 0.05)
	_shock_tween.tween_property(flash, ^"color:a", 0.0, 0.4)
	_shock_tween.tween_callback(func() -> void: flash.visible = false)
	# a hard vignette snap under the flash for weight
	var tween := create_tween()
	tween.tween_method(_set_vignette, vignette_strength, minf(vignette_strength + 0.4, 1.0), 0.06)
	tween.tween_method(_set_vignette, minf(vignette_strength + 0.4, 1.0), vignette_strength, 0.7)
	_surge_grain()


func _set_vignette(value: float) -> void:
	var overlay := get_node_or_null("Overlay") as ColorRect
	if overlay != null and overlay.material is ShaderMaterial:
		(overlay.material as ShaderMaterial).set_shader_parameter(&"vignette_strength", value)


func _on_viewport_resized() -> void:
	var dust := get_node_or_null("Dust") as CPUParticles2D
	if dust != null:
		_fit_to_viewport(dust)


func _apply_export_overrides() -> void:
	if not is_inside_tree():
		await ready
	_apply_overlay_settings()


func _apply_overlay_settings() -> void:
	var overlay := get_node_or_null("Overlay") as ColorRect
	if overlay != null:
		overlay.visible = overlay_enabled
		var mat := overlay.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter(&"vignette_strength", vignette_strength)
			mat.set_shader_parameter(&"vignette_softness", vignette_softness)
			mat.set_shader_parameter(&"vignette_color", vignette_color)
			mat.set_shader_parameter(&"grain_strength", grain_strength)

	var rays := get_node_or_null("GodRays") as ColorRect
	if rays != null:
		var ray_mat := rays.material as ShaderMaterial
		if ray_mat != null:
			ray_mat.set_shader_parameter(&"ray_angle", ray_angle)

	var dust := get_node_or_null("Dust") as CPUParticles2D
	if dust != null:
		dust.amount = maxi(dust_amount, 1)
		dust.color = dust_color


func _current_scene_key() -> String:
	if Dialogic.current_timeline == null:
		return ""
	return Dialogic.current_timeline.resource_path.get_file().get_basename()


func _on_scene_changed() -> void:
	var key := _current_scene_key()
	_set_heartbeat(false)
	_apply_tint(scene_tints.get(key, default_tint))
	_apply_dust(key in dust_scenes)
	_apply_rays(key in ray_scenes)
	_apply_rain(key in rain_scenes)


func _apply_tint(target: Color) -> void:
	_current_tint = target
	if not _find_background_holder():
		return
	if is_instance_valid(_tint_tween):
		_tint_tween.kill()
	var resolved: Color = _drained(target) if _draining else target
	if tint_fade <= 0.0:
		_background_holder.modulate = resolved
		return
	_tint_tween = create_tween()
	_tint_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tint_tween.tween_property(_background_holder, ^"modulate", resolved, tint_fade)


func _drained(base: Color) -> Color:
	var lum: float = base.get_luminance()
	var grey := Color(lum, lum, lum) * drain_color
	return base.lerp(grey, 0.72)


func _set_drain(enabled: bool) -> void:
	_draining = enabled
	if not _find_background_holder():
		return
	if is_instance_valid(_drain_tween):
		_drain_tween.kill()
	if is_instance_valid(_tint_tween):
		_tint_tween.kill()
	var target: Color = _drained(_current_tint) if enabled else _current_tint
	_drain_tween = create_tween()
	_drain_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_drain_tween.tween_property(_background_holder, ^"modulate", target, drain_fade)


func _set_heartbeat(enabled: bool) -> void:
	if is_instance_valid(_heartbeat_tween):
		_heartbeat_tween.kill()
	if not enabled:
		_set_vignette(vignette_strength)
		return
	var peak: float = minf(vignette_strength + heartbeat_depth, 1.0)
	_heartbeat_tween = create_tween().set_loops()
	_heartbeat_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_heartbeat_tween.tween_method(_set_vignette, vignette_strength, peak, heartbeat_period * 0.42)
	_heartbeat_tween.tween_method(_set_vignette, peak, vignette_strength, heartbeat_period * 0.58)


func _surge_grain() -> void:
	var overlay := get_node_or_null("Overlay") as ColorRect
	if overlay == null or not (overlay.material is ShaderMaterial):
		return
	var mat := overlay.material as ShaderMaterial
	if is_instance_valid(_grain_tween):
		_grain_tween.kill()
	_grain_tween = create_tween()
	_grain_tween.tween_method(_set_grain, grain_strength, grain_surge_peak, 0.12)
	_grain_tween.tween_method(_set_grain, grain_surge_peak, grain_strength, 0.9)


func _set_grain(value: float) -> void:
	var overlay := get_node_or_null("Overlay") as ColorRect
	if overlay != null and overlay.material is ShaderMaterial:
		(overlay.material as ShaderMaterial).set_shader_parameter(&"grain_strength", value)


func _apply_dust(enabled: bool) -> void:
	var dust := get_node_or_null("Dust") as CPUParticles2D
	if dust == null:
		return
	dust.amount = maxi(dust_amount, 1)
	dust.color = dust_color
	dust.emitting = enabled
	dust.visible = enabled
	_fit_to_viewport(dust)


func _apply_rays(enabled: bool) -> void:
	var rays := get_node_or_null("GodRays") as ColorRect
	if rays == null:
		return
	rays.visible = enabled
	var mat := rays.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter(&"ray_strength", ray_strength if enabled else 0.0)
		mat.set_shader_parameter(&"ray_angle", ray_angle)


func _fit_to_viewport(dust: CPUParticles2D) -> void:
	var view_size := get_viewport().get_visible_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	dust.position = Vector2(view_size.x * 0.5, -view_size.y * 0.05)
	dust.emission_rect_extents = Vector2(view_size.x * 0.55, view_size.y * 0.08)


func _find_background_holder() -> bool:
	if is_instance_valid(_background_holder) and _background_holder.is_inside_tree():
		return true
	_background_holder = get_tree().get_first_node_in_group(&"dialogic_background_holders") as CanvasItem
	return is_instance_valid(_background_holder)
