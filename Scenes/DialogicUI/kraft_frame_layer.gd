@tool
extends DialogicLayoutLayer


const DESIGN_SIZE := Vector2(1152.0, 648.0)

@export_group("Frame")
@export var frame_color: Color = Color(0.831, 0.643, 0.376, 1.0)
@export var window_position: Vector2 = Vector2(71.0, 61.0)
@export var window_size: Vector2 = Vector2(1010.0, 551.0)
@export var corner_radius: float = 26.0
@export var edge_softness: float = 1.5

const IRIS_DURATION := 0.6
const IRIS_DELAY := 0.05

const PARALLAX_STRENGTH := 13.0
const PARALLAX_TWEEN_TIME := 0.5

const TALK_REACTION_AMPLITUDE := 4.0
const TALK_REACTION_DURATION := 0.22

const BOX_HEIGHT_FRACTION := 0.2392
const BOX_MARGIN_BOTTOM_FRACTION := 0.0494
const RIGHT_MARGIN_FRACTION := 0.035
const CHARACTER_GAP_FRACTION := 0.13
const MIN_BOX_WIDTH_FRACTION := 0.32
const BOX_MODE_DURATION := 0.5

const PORTRAIT_NATIVE_SIZE := Vector2(482.0, 540.0)

const CHARACTER_FADE_DURATION := 0.3

# Exact per-character nameplate TEXT colors from the universal palette sheet
# (pill FILL comes from each character's .dch `color`). Fallback = darkened fill.
const NAMETAG_TEXT_COLORS := {
	"Maya": Color(0.420, 0.498, 0.275),
	"Ethan": Color(0.278, 0.514, 0.510),
	"Jennifer": Color(0.753, 0.498, 0.224),
	"Ricardo": Color(0.498, 0.412, 0.349),
}

var _material: ShaderMaterial
var _played_intro := false
var _background_holder: Control
var _background_base_position := Vector2.ZERO
var _parallax_tween: Tween

var _textbox_anchor: Control
var _textbox_sizer: Control
var _box_tween: Tween
var _box_left_abs := 0.0
var _target_left_abs := 0.0
var _character_fade_tweens: Dictionary = {}
var _nametag_stylebox: StyleBoxFlat


func _apply_export_overrides() -> void:
	if !is_inside_tree():
		await ready

	var frame: ColorRect = %Frame
	_material = frame.material
	_material.set_shader_parameter(&"frame_color", frame_color)
	_material.set_shader_parameter(&"corner_radius_ratio", corner_radius / DESIGN_SIZE.y)
	_material.set_shader_parameter(&"edge_softness_ratio", edge_softness / DESIGN_SIZE.y)

	if not Engine.is_editor_hint():
		_connect_talk_reactions()
		set_process_input(true)

	if _played_intro or Engine.is_editor_hint():
		_material.set_shader_parameter(&"window_position_ratio", window_position / DESIGN_SIZE)
		_material.set_shader_parameter(&"window_size_ratio", window_size / DESIGN_SIZE)
		return

	_played_intro = true
	var center_ratio := (window_position + window_size * 0.5) / DESIGN_SIZE
	_material.set_shader_parameter(&"window_position_ratio", center_ratio)
	_material.set_shader_parameter(&"window_size_ratio", Vector2.ZERO)

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_window_position_ratio, center_ratio, window_position / DESIGN_SIZE, IRIS_DURATION).set_delay(IRIS_DELAY)
	tween.tween_method(_set_window_size_ratio, Vector2.ZERO, window_size / DESIGN_SIZE, IRIS_DURATION).set_delay(IRIS_DELAY)


func _set_window_position_ratio(value: Vector2) -> void:
	_material.set_shader_parameter(&"window_position_ratio", value)


func _set_window_size_ratio(value: Vector2) -> void:
	_material.set_shader_parameter(&"window_size_ratio", value)



func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseMotion:
		_update_parallax(event.position)


func _update_parallax(mouse_position: Vector2) -> void:
	if not is_instance_valid(_background_holder):
		_background_holder = get_tree().get_first_node_in_group(&"dialogic_background_holders")
		if not is_instance_valid(_background_holder):
			return
		_background_base_position = _background_holder.position

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var mouse_normalized := (mouse_position / viewport_size) * 2.0 - Vector2.ONE
	mouse_normalized = mouse_normalized.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	var target := _background_base_position - mouse_normalized * PARALLAX_STRENGTH

	if is_instance_valid(_parallax_tween):
		_parallax_tween.kill()
	_parallax_tween = create_tween()
	_parallax_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_parallax_tween.tween_property(_background_holder, ^"position", target, PARALLAX_TWEEN_TIME)




func _connect_talk_reactions() -> void:
	if not Dialogic.has_subsystem("Text"):
		return
	if not Dialogic.Text.text_started.is_connected(_on_text_started):
		Dialogic.Text.text_started.connect(_on_text_started)
	if Dialogic.has_subsystem("Portraits") and not Dialogic.Portraits.character_joined.is_connected(_on_character_joined):
		Dialogic.Portraits.character_joined.connect(_on_character_joined)


func _on_character_joined(info: Dictionary) -> void:
	# Keep newly-joined portraits invisible so they never "blink" in. The
	# spotlight (_update_character_visibility) fades a character up only when
	# they become the speaker, so a join must never show anything on its own.
	var node: Node2D = info.get("node") as Node2D
	if not is_instance_valid(node):
		var ch: DialogicCharacter = info.get("character")
		if ch != null:
			node = Dialogic.Portraits.get_character_node(ch)
	if is_instance_valid(node):
		node.modulate.a = 0.0


func _on_text_started(info: Dictionary) -> void:
	var character: DialogicCharacter = info.get("character")

	_update_textbox_fill(character)
	_update_character_visibility(character)
	_update_nametag(character)

	if character == null:
		return
	if info.get("append", false):
		return

	var character_node: Node2D = Dialogic.Portraits.get_character_node(character)
	if not is_instance_valid(character_node):
		return

	var base_position: Vector2 = character_node.position
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_node, ^"position:y", base_position.y - TALK_REACTION_AMPLITUDE, TALK_REACTION_DURATION * 0.5)
	tween.tween_property(character_node, ^"position:y", base_position.y, TALK_REACTION_DURATION * 0.5)


func _update_nametag(character: DialogicCharacter) -> void:
	# Tint the nameplate pill to the speaker's character colour (palette-driven),
	# matching the delivered art's per-character coloured pills. Narration = no name.
	if character == null:
		return
	var name_label := get_tree().get_first_node_in_group(&"dialogic_name_label") as Control
	if not is_instance_valid(name_label):
		return
	var panel := name_label.get_parent() as PanelContainer
	if not is_instance_valid(panel):
		return
	if _nametag_stylebox == null:
		var base := panel.get_theme_stylebox(&"panel")
		_nametag_stylebox = (base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()) as StyleBoxFlat
		panel.add_theme_stylebox_override(&"panel", _nametag_stylebox)
	_nametag_stylebox.bg_color = character.color
	var text_color: Color = NAMETAG_TEXT_COLORS.get(character.get_identifier(), character.color.darkened(0.5))
	name_label.add_theme_color_override(&"font_color", text_color)
	# Clean single-pill look (match art): drop the red accent flag behind the pill.
	var flag := panel.get_parent().get_node_or_null("AccentFlag")
	if flag is ColorRect:
		(flag as ColorRect).color.a = 0.0


func _update_character_visibility(speaking_character: DialogicCharacter) -> void:
	if not Dialogic.has_subsystem("Portraits"):
		return

	for character in Dialogic.Portraits.get_joined_characters():
		var character_node: Node2D = Dialogic.Portraits.get_character_node(character)
		if not is_instance_valid(character_node):
			continue

		var should_be_visible: bool = speaking_character != null and character == speaking_character
		var target_alpha := 1.0 if should_be_visible else 0.0
		if is_equal_approx(character_node.modulate.a, target_alpha):
			continue

		if _character_fade_tweens.has(character_node) and is_instance_valid(_character_fade_tweens[character_node]):
			_character_fade_tweens[character_node].kill()

		var tween := create_tween()
		tween.tween_property(character_node, ^"modulate:a", target_alpha, CHARACTER_FADE_DURATION)
		_character_fade_tweens[character_node] = tween




func _update_textbox_fill(speaking_character: DialogicCharacter) -> void:
	if not _find_textbox_nodes():
		return

	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var window_left_abs: float = (window_position.x / DESIGN_SIZE.x) * viewport_size.x
	var window_right_abs: float = ((window_position.x + window_size.x) / DESIGN_SIZE.x) * viewport_size.x
	var side_margin: float = RIGHT_MARGIN_FRACTION * viewport_size.x
	var gap: float = CHARACTER_GAP_FRACTION * viewport_size.x
	var min_width: float = MIN_BOX_WIDTH_FRACTION * viewport_size.x

	var box_left_abs: float
	var box_right_abs: float

	if speaking_character == null:
		# Narration: full-width box.
		box_left_abs = window_left_abs + side_margin
		box_right_abs = window_right_abs - side_margin
	else:
		var bounds := _get_character_bounds(speaking_character)
		var char_left := bounds.x
		var char_right := bounds.y
		if char_left < 0.0 and char_right < 0.0:
			char_left = window_left_abs
			char_right = window_left_abs
		var window_center := (window_left_abs + window_right_abs) * 0.5
		var char_center := (char_left + char_right) * 0.5
		if char_center <= window_center:
			# Speaker on the left half -> textbox fills to their RIGHT.
			box_left_abs = char_right + gap
			box_right_abs = window_right_abs - side_margin
			box_left_abs = minf(box_left_abs, box_right_abs - min_width)
		else:
			# Speaker on the right half -> textbox fills to their LEFT.
			box_right_abs = char_left - gap
			box_left_abs = window_left_abs + side_margin
			box_right_abs = maxf(box_right_abs, box_left_abs + min_width)

	_target_left_abs = box_left_abs

	if is_instance_valid(_box_tween):
		_box_tween.kill()
	_box_tween = create_tween()
	_box_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_box_tween.tween_method(_apply_box_left.bind(box_right_abs, viewport_size), _box_left_abs, _target_left_abs, BOX_MODE_DURATION)


func _apply_box_left(left_abs: float, right_abs: float, viewport_size: Vector2) -> void:
	_box_left_abs = left_abs
	var width: float = right_abs - left_abs
	var height: float = BOX_HEIGHT_FRACTION * viewport_size.y
	var margin_bottom: float = BOX_MARGIN_BOTTOM_FRACTION * viewport_size.y

	_textbox_sizer.size = Vector2(width, height)
	_textbox_sizer.position = Vector2(left_abs - viewport_size.x, -height - margin_bottom)


func _get_character_bounds(character: DialogicCharacter) -> Vector2:
	# Returns (left_x, right_x) of the speaking character's sprite in global space.
	var character_node := Dialogic.Portraits.get_character_node(character)
	if not is_instance_valid(character_node):
		return Vector2(-1.0, -1.0)
	var sprite := _find_sprite(character_node)
	if not is_instance_valid(sprite):
		return Vector2(-1.0, -1.0)
	var r := sprite.get_rect()
	var a := sprite.to_global(r.position).x
	var b := sprite.to_global(r.position + Vector2(r.size.x, 0.0)).x
	return Vector2(minf(a, b), maxf(a, b))


func _get_character_right_edge(character: DialogicCharacter, viewport_size: Vector2) -> float:
	var character_node := Dialogic.Portraits.get_character_node(character)
	if not is_instance_valid(character_node):
		return -1.0

	var sprite := _find_sprite(character_node)
	if not is_instance_valid(sprite):
		return -1.0

	var half_width: float = PORTRAIT_NATIVE_SIZE.x * sprite.global_scale.x * 0.5
	return sprite.global_position.x + half_width


func _find_sprite(node: Node) -> Sprite2D:
	if node is Sprite2D:
		return node
	for child in node.get_children():
		var found := _find_sprite(child)
		if is_instance_valid(found):
			return found
	return null


func _find_textbox_nodes() -> bool:
	if is_instance_valid(_textbox_sizer) and is_instance_valid(_textbox_anchor):
		return true

	var dialog_text := get_tree().get_first_node_in_group(&"dialogic_dialog_text")
	if not is_instance_valid(dialog_text):
		return false

	var panel := dialog_text.get_parent()
	if not is_instance_valid(panel):
		return false

	_textbox_sizer = panel.get_parent()
	if not is_instance_valid(_textbox_sizer):
		return false

	var animation_parent := _textbox_sizer.get_parent()
	if not is_instance_valid(animation_parent):
		return false

	_textbox_anchor = animation_parent.get_parent()
	return is_instance_valid(_textbox_anchor)

