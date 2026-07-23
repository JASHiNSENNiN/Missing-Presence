extends GutTest

## Regression: after the emotion-notification minigame clears, only the REAL choice
## options may reappear. Dialogic keeps a fixed pool of choice buttons and shows only
## the valid few; the notif layer must restore exactly those, never blanket-show the
## whole group (which surfaced the empty pooled buttons as a wall of blank options).

var _layer: Node


func before_each() -> void:
	_layer = load("res://Scenes/DialogicUI/emotion_notif_layer.gd").new()
	add_child_autofree(_layer)


func _make_choice_pool(visible_count: int, total: int = 10) -> Array:
	var container := Control.new()
	add_child_autofree(container)
	var pool: Array = []
	for i in range(total):
		var b := Control.new()
		container.add_child(b)
		b.add_to_group(&"dialogic_choice_button")
		b.visible = i < visible_count
		pool.append(b)
	return pool


func test_clearing_notifications_restores_only_real_choices() -> void:
	var pool := _make_choice_pool(3)  # a 3-option choice + 7 empty pooled buttons

	_layer._set_choices_hidden(true)
	for b in pool:
		assert_false(b.visible, "every choice button hidden while notifications are up")

	_layer._set_choices_hidden(false)
	for i in range(3):
		assert_true(pool[i].visible, "real choice %d must reappear" % i)
	for i in range(3, 10):
		assert_false(pool[i].visible, "empty pooled button %d must STAY hidden" % i)


func test_repeated_hide_then_show_is_clean() -> void:
	# _process re-hides every frame while blocked; several hides then one show must
	# still restore only the two real options.
	var pool := _make_choice_pool(2)
	_layer._set_choices_hidden(true)
	_layer._set_choices_hidden(true)
	_layer._set_choices_hidden(true)
	_layer._set_choices_hidden(false)
	assert_true(pool[0].visible, "real choice 0 restored")
	assert_true(pool[1].visible, "real choice 1 restored")
	for i in range(2, 10):
		assert_false(pool[i].visible, "pooled button %d stayed hidden" % i)


func test_show_without_prior_hide_reveals_nothing() -> void:
	# clearing when nothing was hidden must not force any pooled button visible
	var pool := _make_choice_pool(0)
	_layer._set_choices_hidden(false)
	for i in range(10):
		assert_false(pool[i].visible, "pooled button %d must stay hidden" % i)
