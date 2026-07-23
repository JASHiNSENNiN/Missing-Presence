@tool
extends DialogicLayoutLayer

## Persona-style character intro cards: the first time a main character speaks in
## a playthrough, a kinetic name + role card slides in, holds, and slides out.
## Adapted to the cozy kraft palette (character-coloured accent, not P5 red/black).

@export var roles: Dictionary = {
	"Maya": "Computer Science Student",
	"Ethan": "Childhood Friend",
	"Jennifer": "Her Mother",
	"Ricardo": "Her Father",
	"Marie": "Ethan's Mother",
}
@export var accent_colors: Dictionary = {
	"Maya": Color(0.42, 0.498, 0.275),
	"Ethan": Color(0.278, 0.514, 0.510),
	"Jennifer": Color(0.753, 0.498, 0.224),
	"Ricardo": Color(0.498, 0.412, 0.349),
	"Marie": Color(0.55, 0.42, 0.55),
}
@export var hold_time: float = 6.5
@export var slide_time: float = 0.75

const PAPER_CARD := "res://Mocks/Novel UI/Rectangle 1.png"

var _shown: Dictionary = {}
var _queue: Array[String] = []
var _active: bool = false
var _current_card: Control
var _root: Control
var _tween: Tween
var _uisound: Node
var _scenesfx: Node


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	_uisound = get_node_or_null("/root/UISound")
	_scenesfx = get_node_or_null("/root/SceneSFX")
	_root = Control.new()
	_root.name = "IntroRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	if Dialogic.has_subsystem("Text") and not Dialogic.Text.text_started.is_connected(_on_text_started):
		Dialogic.Text.text_started.connect(_on_text_started)
	if not Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.connect(_on_timeline_ended)


func _on_timeline_ended() -> void:
	# Reset so a fresh playthrough re-introduces the cast.
	if Dialogic.current_timeline == null:
		_shown.clear()
		_queue.clear()
		_active = false
		if is_instance_valid(_tween):
			_tween.kill()
		if is_instance_valid(_current_card):
			_current_card.queue_free()


func _on_text_started(_info: Dictionary) -> void:
	var speaker: String = str(Dialogic.current_state_info.get("speaker", ""))
	if speaker.is_empty() or _shown.has(speaker) or not roles.has(speaker):
		return
	_shown[speaker] = true
	_queue.append(speaker)
	_pump()


func _pump() -> void:
	# One card at a time: a newly-introduced character waits its turn instead of
	# cutting the card before it off mid-hold.
	if _active or _queue.is_empty():
		return
	var speaker: String = _queue.pop_front()
	_active = true
	# Soft paper flourish for the card, plus the character's own text bleep so the
	# reveal is tied to their voice — keeps every delivered sound in play.
	if _uisound != null:
		_uisound.play("page_turn")
	if _scenesfx != null and _scenesfx.has_method("play_bleep"):
		_scenesfx.play_bleep(speaker)
	_play_intro(speaker)


func _play_intro(speaker: String) -> void:
	var view := get_viewport().get_visible_rect().size
	var accent: Color = accent_colors.get(speaker, Color(0.5, 0.45, 0.35))

	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(430, 120)
	card.size = Vector2(430, 120)
	_root.add_child(card)

	# real cream-paper asset as the card body (Rectangle 1.png)
	var paper := TextureRect.new()
	if ResourceLoader.exists(PAPER_CARD):
		paper.texture = load(PAPER_CARD)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.position = Vector2(8, 0)
	paper.size = Vector2(422, 120)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(paper)

	var bar := ColorRect.new()
	bar.color = accent
	bar.position = Vector2(0, 14)
	bar.size = Vector2(9, 92)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bar)

	var name_label := Label.new()
	name_label.text = speaker.to_upper()
	name_label.position = Vector2(34, 22)
	name_label.add_theme_font_size_override(&"font_size", 40)
	name_label.add_theme_color_override(&"font_color", accent.darkened(0.15))
	card.add_child(name_label)

	var role_label := Label.new()
	role_label.text = roles[speaker]
	role_label.position = Vector2(36, 76)
	role_label.add_theme_font_size_override(&"font_size", 19)
	role_label.add_theme_color_override(&"font_color", Color(0.42, 0.36, 0.28))
	card.add_child(role_label)

	# Top-right, sliding in from off the right edge.
	var rest_x := view.x - card.size.x - view.x * 0.035
	var rest_y := view.y * 0.09
	var off_x := view.x + 30.0
	card.position = Vector2(off_x, rest_y)
	card.modulate.a = 0.0
	_current_card = card

	if is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(card, ^"position:x", rest_x, slide_time)
	_tween.tween_property(card, ^"modulate:a", 1.0, slide_time * 0.7)
	_tween.set_parallel(false)
	_tween.tween_interval(hold_time)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.set_parallel(true)
	_tween.tween_property(card, ^"position:x", off_x, slide_time)
	_tween.tween_property(card, ^"modulate:a", 0.0, slide_time)
	_tween.chain().tween_callback(_finish_intro.bind(card))


func _finish_intro(card: Control) -> void:
	if is_instance_valid(card):
		card.queue_free()
	_active = false
	_current_card = null
	_pump()
