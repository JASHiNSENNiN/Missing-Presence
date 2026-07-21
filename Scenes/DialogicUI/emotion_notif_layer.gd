@tool
extends DialogicLayoutLayer

@export_range(0.2, 0.9, 0.01) var card_width_fraction: float = 0.5
@export var top_margin: float = 46.0
@export var card_gap: float = 16.0
@export_range(0.0, 1.0, 0.01) var max_blur_amount: float = 1.0
@export_range(0.1, 1.0, 0.01) var blur_per_card: float = 0.42
@export var blur_fade_time: float = 0.4
@export var block_advance: bool = true
@export var wave_interval: float = 0.7
@export var persist_refill_delay: float = 0.5
@export var arrival_shake: float = 14.0
@export var warning_card_count: int = 3

const EMOTION_DIR := "res://Art/UI/EmotionNotifs/"

var _cards_root: Control
var _blur_rect: ColorRect
var _backbuffer: BackBufferCopy
var _cards: Array = []

var _spawn_queue: Array = []
var _spawn_timer: float = 0.0
var _persist_emotion: String = ""
var _persist_remaining: int = 0

var _blur_tween: Tween
var _advance_blocked: bool = false
var _shake_time: float = 0.0
var _shake_intensity: float = 0.0
var _uisound: Node


func _ready() -> void:
	super()
	_cards_root = get_node_or_null("CardsRoot")
	_blur_rect = get_node_or_null("BlurRect")
	_backbuffer = get_node_or_null("BackBufferCopy")
	if Engine.is_editor_hint():
		return
	set_process(true)
	_uisound = get_node_or_null("/root/UISound")
	if _backbuffer != null:
		_backbuffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	if _blur_rect != null:
		_blur_rect.visible = false
		_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_blur_amount(0.0)
	if not Dialogic.signal_event.is_connected(_on_signal_event):
		Dialogic.signal_event.connect(_on_signal_event)
	get_viewport().size_changed.connect(_relayout)


func _exit_tree() -> void:
	if _advance_blocked and not Engine.is_editor_hint():
		Dialogic.paused = false
		_advance_blocked = false


func _on_signal_event(argument: Variant) -> void:
	if not (argument is String):
		return
	var arg := argument as String
	if arg == "emotion_clear":
		_clear_all()
		return
	if arg.begins_with("emotion_persist:"):
		var body := arg.substr("emotion_persist:".length())
		var parts := body.split(":")
		var emotion := parts[0].strip_edges().to_lower()
		var count: int = int(parts[1]) if parts.size() > 1 else 3
		_start_persist(emotion, count)
		return
	if arg.begins_with("emotion:"):
		var body := arg.substr("emotion:".length())
		var parts := body.split(":")
		var emotion := parts[0].strip_edges().to_lower()
		var count: int = int(parts[1]) if parts.size() > 1 else 1
		for _i in maxi(count, 1):
			_spawn_queue.append(emotion)
		return


func _start_persist(emotion: String, count: int) -> void:
	_persist_emotion = emotion
	_persist_remaining = maxi(count, 1)
	var initial: int = mini(warning_card_count, _persist_remaining)
	for _i in initial:
		_spawn_queue.append(emotion)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var emotion: String = _spawn_queue.pop_front()
			_spawn_card(emotion)
			_spawn_timer = wave_interval
	_apply_shake(delta)
	_apply_wobble()
	_apply_warning_pulse(delta)


func _spawn_card(emotion: String) -> void:
	if _cards_root == null:
		return
	var path := EMOTION_DIR + emotion + ".png"
	if not ResourceLoader.exists(path):
		push_warning("[EmotionNotif] no banner for '%s' (%s)" % [emotion, path])
		return
	var tex: Texture2D = load(path)
	var view := get_viewport().get_visible_rect().size
	var card_w: float = view.x * card_width_fraction
	var card_h: float = card_w * (tex.get_height() / maxf(tex.get_width(), 1.0))

	var card := EmotionNotificationCard.new()
	_cards_root.add_child(card)
	card.configure(tex, Vector2(card_w, card_h))
	card.dismissed.connect(_on_card_dismissed)
	_cards.append(card)
	_relayout()
	card.appear_from(-card_h - 12.0)

	_shake_intensity = arrival_shake
	_shake_time = 0.28
	if _uisound != null:
		_uisound.play("error")
	_update_blur()


func _relayout() -> void:
	var view := get_viewport().get_visible_rect().size
	var y := top_margin
	for card in _cards:
		if not is_instance_valid(card):
			continue
		var home := Vector2((view.x - card.size.x) * 0.5, y)
		card.set_home(home)
		y += card.size.y + card_gap


func _on_card_dismissed(card: Control) -> void:
	_cards.erase(card)
	if is_instance_valid(card):
		card.queue_free()
	if _uisound != null:
		_uisound.play("page_turn")
	if _persist_remaining > 0:
		_persist_remaining -= 1
		if _persist_remaining > 0:
			get_tree().create_timer(persist_refill_delay).timeout.connect(_refill_persist)
	_relayout()
	_update_blur()


func _refill_persist() -> void:
	if _persist_remaining <= 0 or _persist_emotion.is_empty():
		return
	if _cards.size() + _spawn_queue.size() < _persist_remaining and _cards.size() < warning_card_count:
		_spawn_queue.append(_persist_emotion)


func _clear_all() -> void:
	_spawn_queue.clear()
	_persist_remaining = 0
	_persist_emotion = ""
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	_update_blur()


func _pending_total() -> int:
	return _cards.size() + _spawn_queue.size()


func _update_blur() -> void:
	if _blur_rect == null:
		return
	var count := _cards.size()
	var active := count > 0 or not _spawn_queue.is_empty()
	var target: float = 0.0
	if active:
		target = minf(float(maxi(count, 1)) * blur_per_card, max_blur_amount)
		if _backbuffer != null:
			_backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
		_blur_rect.visible = true
		_blur_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_advance_blocked(active)
	if is_instance_valid(_blur_tween):
		_blur_tween.kill()
	_blur_tween = create_tween()
	_blur_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_blur_tween.tween_method(_set_blur_amount, _current_blur_amount(), target, blur_fade_time)
	if not active:
		_blur_tween.tween_callback(func() -> void:
			if _blur_rect != null:
				_blur_rect.visible = false
				_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if _backbuffer != null:
				_backbuffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED)


func _set_advance_blocked(should_block: bool) -> void:
	if not block_advance:
		return
	if should_block == _advance_blocked:
		return
	if should_block and Dialogic.current_timeline == null:
		return
	_advance_blocked = should_block
	Dialogic.paused = should_block


func _apply_shake(delta: float) -> void:
	if _cards_root == null:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var mag: float = _shake_intensity * (_shake_time / 0.28)
		_cards_root.position = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
	elif _cards_root.position != Vector2.ZERO:
		_cards_root.position = Vector2.ZERO


func _apply_wobble() -> void:
	var count := _cards.size()
	if count < warning_card_count:
		return
	var amplitude: float = 0.02 + 0.01 * float(count - warning_card_count)
	for card in _cards:
		if is_instance_valid(card) and card.age() > 0.5:
			card.apply_wobble(amplitude)


func _apply_warning_pulse(_delta: float) -> void:
	if _blur_rect == null or not (_blur_rect.material is ShaderMaterial):
		return
	var mat := _blur_rect.material as ShaderMaterial
	if _cards.size() >= warning_card_count:
		var pulse: float = 0.42 + 0.14 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
		mat.set_shader_parameter("dim_strength", pulse)
	else:
		mat.set_shader_parameter("dim_strength", 0.42)


func _current_blur_amount() -> float:
	if _blur_rect != null and _blur_rect.material is ShaderMaterial:
		return (_blur_rect.material as ShaderMaterial).get_shader_parameter("amount")
	return 0.0


func _set_blur_amount(v: float) -> void:
	if _blur_rect != null and _blur_rect.material is ShaderMaterial:
		(_blur_rect.material as ShaderMaterial).set_shader_parameter("amount", v)
