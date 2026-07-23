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
var _hidden_choice_buttons: Array = []
var _shake_time: float = 0.0
var _shake_intensity: float = 0.0
var _uisound: Node
var _scenesfx: Node

const TUTORIAL_MARKER := "user://emotion_tutorial_seen.dat"
var _hint: Control
var _hint_tween: Tween
var _tutorial_active: bool = false


func _tutorial_seen() -> bool:
	return FileAccess.file_exists(TUTORIAL_MARKER)


func _mark_tutorial_seen() -> void:
	var f := FileAccess.open(TUTORIAL_MARKER, FileAccess.WRITE)
	if f != null:
		f.store_8(1)
		f.close()


func _ready() -> void:
	super()
	_cards_root = get_node_or_null("CardsRoot")
	_blur_rect = get_node_or_null("BlurRect")
	_backbuffer = get_node_or_null("BackBufferCopy")
	if Engine.is_editor_hint():
		return
	set_process(true)
	_uisound = get_node_or_null("/root/UISound")
	_scenesfx = get_node_or_null("/root/SceneSFX")
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
	if not _notifications_enabled():
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


func _notifications_enabled() -> bool:
	var settings := get_node_or_null("/root/Settings")
	if settings == null:
		return true
	return bool(settings.get("notifications_enabled"))


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
	# A choice can be presented a frame after the block engages; keep it hidden
	# until the notifications are cleared.
	if _advance_blocked:
		_set_choices_hidden(true)


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
	# The actual phone-notification sound when a card arrives; a chat-flood burst
	# once the pile-up hits the warning count, so it *sounds* overwhelming too.
	if _scenesfx != null:
		if _cards.size() >= warning_card_count:
			_scenesfx.play_sfx("chat_flood")
		else:
			_scenesfx.play_sfx("phone_notif")
	elif _uisound != null:
		_uisound.play("error")
	if not _tutorial_seen() and not _tutorial_active and _cards.size() == 1:
		_show_tutorial_hint(card)
	_update_blur()


func _show_tutorial_hint(card: Control) -> void:
	_tutorial_active = true
	_hint = VBoxContainer.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	var arrows := Label.new()
	arrows.text = "←  swipe  →"
	arrows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrows.add_theme_font_size_override(&"font_size", 30)
	arrows.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.95))
	arrows.add_theme_color_override(&"font_outline_color", Color(0.16, 0.10, 0.05, 0.9))
	arrows.add_theme_constant_override(&"outline_size", 6)
	var tip := Label.new()
	tip.text = "Swipe the notification off-screen to dismiss it"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override(&"font_size", 17)
	tip.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.9))
	tip.add_theme_color_override(&"font_outline_color", Color(0.16, 0.10, 0.05, 0.9))
	tip.add_theme_constant_override(&"outline_size", 5)
	_hint.add_child(arrows)
	_hint.add_child(tip)
	_cards_root.add_child(_hint)
	var view := get_viewport().get_visible_rect().size
	_hint.size = Vector2(view.x * 0.6, 80.0)
	_hint.position = Vector2((view.x - _hint.size.x) * 0.5, card.get_home().y + card.size.y + 26.0)
	_hint.modulate.a = 0.0
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_hint, ^"modulate:a", 1.0, 0.5)
	_hint_tween.tween_property(_hint, ^"position:y", _hint.position.y + 10.0, 0.7).set_trans(Tween.TRANS_SINE)
	_hint_tween.parallel().tween_property(_hint, ^"modulate:a", 0.6, 0.7)
	_hint_tween.tween_property(_hint, ^"position:y", _hint.position.y, 0.7).set_trans(Tween.TRANS_SINE)
	_hint_tween.parallel().tween_property(_hint, ^"modulate:a", 1.0, 0.7)


func _clear_tutorial_hint() -> void:
	if not _tutorial_active:
		return
	_tutorial_active = false
	_mark_tutorial_seen()
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
	if is_instance_valid(_hint):
		var h := _hint
		_hint = null
		var fade := create_tween()
		fade.tween_property(h, ^"modulate:a", 0.0, 0.25)
		fade.tween_callback(h.queue_free)


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
	_clear_tutorial_hint()
	# Swiping a notification away = the phone-lock sound.
	if _scenesfx != null:
		_scenesfx.play_sfx("phone_lock")
	elif _uisound != null:
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
	_clear_tutorial_hint()
	_update_blur()


func _pending_total() -> int:
	return _cards.size() + _spawn_queue.size()


func _update_blur() -> void:
	if _blur_rect == null:
		return
	var count := _cards.size()
	# `_persist_remaining` keeps the block engaged through the brief refill gap between
	# persist cards, so a pending choice never flickers visible for a frame mid-sequence.
	var active := count > 0 or not _spawn_queue.is_empty() or _persist_remaining > 0
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
	# Notifications-first, then choice: while cards are up, keep any pending choice
	# buttons hidden so the decision only appears once the player clears them.
	_set_choices_hidden(should_block)


func _set_choices_hidden(hidden: bool) -> void:
	# Dialogic keeps a fixed POOL of choice buttons; only the valid few are made
	# visible per question, the rest stay hidden. So we must only hide the buttons
	# that are actually showing and restore exactly those — never blanket-show the
	# whole group, or the empty pooled buttons appear as a wall of blank options.
	if hidden:
		for button in get_tree().get_nodes_in_group(&"dialogic_choice_button"):
			if button is CanvasItem and (button as CanvasItem).visible:
				(button as CanvasItem).visible = false
				if button not in _hidden_choice_buttons:
					_hidden_choice_buttons.append(button)
	else:
		for button in _hidden_choice_buttons:
			if is_instance_valid(button) and button is CanvasItem:
				(button as CanvasItem).visible = true
		_hidden_choice_buttons.clear()


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
