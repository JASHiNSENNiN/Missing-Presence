extends GutTest

const LAYER_SCENE := "res://Scenes/DialogicUI/emotion_notif_layer.tscn"


func before_all() -> void:
	GameFlow._heal_maya_portraits()


func after_each() -> void:
	Dialogic.paused = false
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
		for _i in 10:
			if Dialogic.current_timeline == null:
				break
			await wait_frames(1)


func _make_card(size := Vector2(400, 120)) -> EmotionNotificationCard:
	var card := EmotionNotificationCard.new()
	add_child_autofree(card)
	card.configure(null, size)
	card.set_home(Vector2(200, 50))
	await wait_frames(1)
	return card


func test_card_configures_to_size() -> void:
	var card := await _make_card(Vector2(360, 90))
	assert_eq(card.size, Vector2(360, 90), "card takes the configured size")
	assert_eq(card.pivot_offset, Vector2(180, 45), "pivot centered for rotation")


func test_swipe_past_threshold_dismisses() -> void:
	var card := await _make_card()
	watch_signals(card)
	card._begin_drag(card.global_position.x)
	card._update_drag(card.global_position.x + 260.0, 260.0)
	card._end_drag()
	await wait_seconds(0.5)
	assert_signal_emitted(card, "dismissed", "a big swipe flings the card away and dismisses it")


func test_small_nudge_snaps_back() -> void:
	var card := await _make_card()
	watch_signals(card)
	var home_x := card.position.x
	card._begin_drag(card.global_position.x)
	card._update_drag(card.global_position.x + 12.0, 12.0)
	card._end_drag()
	await wait_seconds(0.5)
	assert_signal_not_emitted(card, "dismissed", "a tiny nudge should NOT dismiss")
	assert_almost_eq(card.position.x, home_x, 2.0, "card snaps back to its home x")


func test_fast_fling_dismisses_even_if_short() -> void:
	var card := await _make_card()
	watch_signals(card)
	card._begin_drag(card.global_position.x)
	card._update_drag(card.global_position.x + 20.0, 60.0)
	card._end_drag()
	await wait_seconds(0.5)
	assert_signal_emitted(card, "dismissed", "a fast flick (large per-event motion) dismisses even with small travel")


func _make_layer():
	var layer = load(LAYER_SCENE).instantiate()
	add_child_autofree(layer)
	await wait_frames(2)
	layer.wave_interval = 0.0
	return layer


func _find_notif_layer():
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		var scr = nd.get_script()
		if scr and str(scr.resource_path).ends_with("emotion_notif_layer.gd"):
			return nd
		for c in nd.get_children():
			stack.append(c)
	return null


func test_layer_spawns_card_and_activates_blur() -> void:
	var layer = await _make_layer()
	var blur = layer.get_node("BlurRect")
	var cards_root = layer.get_node("CardsRoot")
	assert_false(blur.visible, "blur is hidden with no notifications")
	layer._on_signal_event("emotion:sad")
	await wait_frames(3)
	assert_gt(cards_root.get_child_count(), 0, "an emotion signal spawns a notification card")
	assert_true(blur.visible, "blur turns on while a notification is active")


func test_layer_clear_removes_all() -> void:
	var layer = await _make_layer()
	layer._on_signal_event("emotion:angry")
	layer._on_signal_event("emotion:nervous")
	await wait_frames(4)
	assert_eq(layer._cards.size(), 2, "two signals stack two cards")
	layer._on_signal_event("emotion_clear")
	await wait_frames(3)
	assert_eq(layer._cards.size(), 0, "emotion_clear removes every card")


func test_wave_count_spawns_multiple_over_time() -> void:
	var layer = await _make_layer()
	layer._on_signal_event("emotion:lost:3")
	await wait_frames(6)
	assert_eq(layer._cards.size(), 3, "emotion:name:3 spawns a wave of three cards")


func test_blur_scales_with_card_count() -> void:
	var layer = await _make_layer()
	layer._on_signal_event("emotion:sad")
	await wait_frames(3)
	var one: float = layer._current_blur_amount()
	layer._on_signal_event("emotion:sad")
	layer._on_signal_event("emotion:sad")
	await wait_frames(4)
	await wait_seconds(0.5)
	var three: float = layer._current_blur_amount()
	assert_gt(three, one, "more unread cards produce a stronger blur")


func test_persist_refills_on_dismiss() -> void:
	var layer = await _make_layer()
	layer._on_signal_event("emotion_persist:nervous:5")
	await wait_frames(6)
	var before: int = layer._cards.size()
	assert_gt(before, 0, "persist spawns an initial batch")
	assert_eq(layer._persist_remaining, 5, "persist tracks a quota of 5 to dismiss")
	var card = layer._cards[0]
	card._begin_drag(card.global_position.x)
	card._update_drag(card.global_position.x + 400.0, 400.0)
	card._end_drag()
	await wait_seconds(0.4)
	await wait_frames(3)
	assert_eq(layer._persist_remaining, 4, "dismissing one decrements the persist quota")
	assert_gt(layer._cards.size(), 0, "persist keeps notifications on screen after a dismiss")
