extends Control
class_name ContinueCascade


signal continue_pressed
signal start_over_pressed
signal cancel_pressed

@onready var continue_card: Control = $ContinueCard
@onready var start_over_card: Control = $StartOverCard
@onready var cancel_card: Control = $CancelCard

const CARD_SLOT_OFFSETS: Array[Vector2] = [
	Vector2(-347.9, -182.1),
	Vector2(-397.9, -82.1),
	Vector2(-447.9, 17.9),
]
const CARD_SLOT_TILTS: Array[float] = [-6.0, -14.0, -22.0]

const CARD_SPAWN_START_OFFSET := Vector2(-25.0, 10.0)
const CARD_SPAWN_START_TILT_BONUS := -40.0
const CARD_SPAWN_DURATION := 0.5
const CARD_STAGGER := 0.1
const CARD_START_DELAY := 0.05

const CONFIRM_HOLD_DURATION := 0.16

var _active: bool = false


func _ready() -> void:
	continue_card.pressed.connect(_on_continue_card_pressed)
	start_over_card.pressed.connect(_on_start_over_card_pressed)
	cancel_card.pressed.connect(_on_cancel_card_pressed)
	_setup_hover_spotlight()


func _setup_hover_spotlight() -> void:
	var cards: Array[Control] = [continue_card, start_over_card, cancel_card]
	for i in cards.size():
		var card := cards[i]
		var others: Array[Control] = []
		for j in cards.size():
			if j != i:
				others.append(cards[j])
		card.mouse_entered.connect(_on_card_hovered.bind(others))
		card.mouse_exited.connect(_on_card_unhovered.bind(others))


func _on_card_hovered(others: Array[Control]) -> void:
	if not _active:
		return
	var ui_sound = get_node_or_null("/root/UISound")
	if ui_sound:
		ui_sound.hover()
	for other in others:
		other.set_dimmed(true)


func _on_card_unhovered(others: Array[Control]) -> void:
	if not _active:
		return
	for other in others:
		other.set_dimmed(false)


func layout_and_spawn(head_screen_pos: Vector2) -> void:
	_active = true
	var cards: Array[Control] = [continue_card, start_over_card, cancel_card]
	var texts := ["Continue", "Start Over", "Cancel"]

	for i in cards.size():
		var card := cards[i]
		card.set_text(texts[i])
		card.pivot_offset = card.size * 0.5

		var final_position: Vector2 = head_screen_pos + CARD_SLOT_OFFSETS[i] - card.size * 0.5
		var final_rotation: float = CARD_SLOT_TILTS[i]
		card.set_meta("final_position", final_position)
		card.set_meta("final_rotation", final_rotation)

		card.position = head_screen_pos + CARD_SPAWN_START_OFFSET - card.size * 0.5
		card.rotation_degrees = final_rotation + CARD_SPAWN_START_TILT_BONUS
		card.modulate.a = 0.0

	show()
	for i in cards.size():
		_swing_card_into_place(cards[i], CARD_START_DELAY + i * CARD_STAGGER)


func _swing_card_into_place(card: Control, delay: float) -> void:
	var final_position: Vector2 = card.get_meta("final_position")
	var final_rotation: float = card.get_meta("final_rotation")

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", final_position, CARD_SPAWN_DURATION)
	tween.tween_property(card, "rotation_degrees", final_rotation, CARD_SPAWN_DURATION)
	tween.tween_property(card, "modulate:a", 1.0, CARD_SPAWN_DURATION * 0.7)


func _on_continue_card_pressed() -> void:
	if not _active:
		return
	_active = false
	await _play_confirm(continue_card)
	continue_pressed.emit()


func _on_start_over_card_pressed() -> void:
	if not _active:
		return
	_active = false
	await _play_confirm(start_over_card)
	start_over_pressed.emit()


func _play_confirm(chosen: Control) -> void:
	var cards: Array[Control] = [continue_card, start_over_card, cancel_card]
	chosen.play_confirm_punch()
	for card in cards:
		if card != chosen:
			card.play_dismiss()
	await get_tree().create_timer(CONFIRM_HOLD_DURATION).timeout


func _on_cancel_card_pressed() -> void:
	if not _active:
		return
	_active = false
	cancel_pressed.emit()


func reset() -> void:
	for card in [continue_card, start_over_card, cancel_card]:
		card.modulate.a = 0.0
	hide()
