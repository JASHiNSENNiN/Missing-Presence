@tool
class_name EmotionNotificationCard
extends Control

signal dismissed(card: Control)
signal grabbed(card: Control)

@export var swipe_threshold_fraction: float = 0.3
@export var fling_time: float = 0.26
@export var snap_time: float = 0.34
@export var flick_pixels: float = 45.0

var _texture: Texture2D
var _home: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _grab_offset: float = 0.0
var _flicked: bool = false
var _flick_dir: float = 0.0
var _tween: Tween
var _settling: bool = false

var _shadow: Panel
var _banner: TextureRect

var _born_at: float = 0.0
var _wobble_phase: float = 0.0


func is_idle() -> bool:
	return not _dragging and not _settling


func age() -> float:
	return (Time.get_ticks_msec() / 1000.0) - _born_at


func apply_wobble(amplitude: float) -> void:
	if not is_idle():
		return
	_wobble_phase += get_process_delta_time() * 6.0
	rotation = sin(_wobble_phase) * amplitude
	position.x = _home.x + sin(_wobble_phase * 0.7) * amplitude * 60.0


func configure(texture: Texture2D, card_size: Vector2) -> void:
	_born_at = Time.get_ticks_msec() / 1000.0
	_texture = texture
	custom_minimum_size = card_size
	size = card_size
	pivot_offset = card_size * 0.5
	_build()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _shadow == null:
		_shadow = Panel.new()
		_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.28)
		sb.corner_radius_top_left = 26
		sb.corner_radius_top_right = 26
		sb.corner_radius_bottom_left = 26
		sb.corner_radius_bottom_right = 26
		sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, 10)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		_shadow.add_theme_stylebox_override("panel", sb)
		add_child(_shadow)
	if _banner == null:
		_banner = TextureRect.new()
		_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_banner.clip_contents = true
		add_child(_banner)
	for child: Control in [_shadow, _banner]:
		child.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		child.position = Vector2.ZERO
		child.size = size
	_banner.texture = _texture


func set_home(pos: Vector2) -> void:
	_home = pos
	if not _dragging and not _settling:
		position = pos


func appear_from(offscreen_top: float) -> void:
	position = Vector2(_home.x, offscreen_top)
	modulate.a = 0.0
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"position:y", _home.y, 0.42)
	_tween.tween_property(self, ^"modulate:a", 1.0, 0.28)


func _gui_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.global_position.x)
		elif _dragging:
			_end_drag()
	elif event is InputEventMouseMotion and _dragging:
		_update_drag(event.global_position.x, event.relative.x)


func _begin_drag(global_x: float) -> void:
	if _settling:
		return
	_dragging = true
	_grab_offset = global_x - global_position.x
	_flicked = false
	_flick_dir = 0.0
	if is_instance_valid(_tween):
		_tween.kill()
	grabbed.emit(self)


func _update_drag(global_x: float, relative_x: float) -> void:
	position.x = global_x - _grab_offset
	if absf(relative_x) >= flick_pixels:
		_flicked = true
		_flick_dir = signf(relative_x)
	var travel: float = absf(position.x - _home.x)
	var fade: float = clampf(1.0 - (travel / (size.x * 1.15)), 0.15, 1.0)
	modulate.a = fade
	rotation = clampf((position.x - _home.x) / size.x, -1.0, 1.0) * 0.12


func _end_drag() -> void:
	_dragging = false
	var travel: float = position.x - _home.x
	var past_threshold: bool = absf(travel) >= size.x * swipe_threshold_fraction
	if past_threshold or _flicked:
		var dir: float = signf(travel) if absf(travel) > 4.0 else _flick_dir
		_fling(dir)
	else:
		_snap_back()


func _snap_back() -> void:
	_settling = true
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"position", _home, snap_time)
	_tween.tween_property(self, ^"rotation", 0.0, snap_time)
	_tween.tween_property(self, ^"modulate:a", 1.0, snap_time * 0.7)
	_tween.chain().tween_callback(func() -> void: _settling = false)


func _fling(dir: float) -> void:
	if dir == 0.0:
		dir = 1.0
	_settling = true
	var view_w: float = get_viewport().get_visible_rect().size.x
	var target_x: float = _home.x + dir * (view_w * 0.9 + size.x)
	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, ^"position:x", target_x, fling_time)
	_tween.tween_property(self, ^"rotation", dir * 0.35, fling_time)
	_tween.tween_property(self, ^"modulate:a", 0.0, fling_time * 0.9)
	_tween.chain().tween_callback(func() -> void: dismissed.emit(self))
