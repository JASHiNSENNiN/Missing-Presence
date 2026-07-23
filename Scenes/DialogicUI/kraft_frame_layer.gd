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
const PARALLAX_SMOOTHING := 6.0

const BG_PUSHIN_START := 1.06
const BG_PUSHIN_TIME := 1.5

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
var _parallax_target := Vector2.ZERO
var _parallax_active := false
var _bg_pushin_tween: Tween

var _textbox_anchor: Control
var _textbox_sizer: Control
var _box_tween: Tween
var _box_left_abs := 0.0
var _target_left_abs := 0.0
var _box_right_abs := 0.0
var _target_right_abs := 0.0
var _character_fade_tweens: Dictionary = {}
var _entrance_bop_tweens: Dictionary = {}
var _portrait_base_scales: Dictionary = {}
var _impact_shake_tweens: Dictionary = {}
var _nametag_stylebox: StyleBoxFlat

const ENTRANCE_BOP_START_SCALE := 0.88
const ENTRANCE_BOP_DURATION := 0.36
const LINE_BOP_START_SCALE := 0.965
const LINE_BOP_DURATION := 0.26



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
	if not _ensure_background_holder():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var mouse_normalized := (mouse_position / viewport_size) * 2.0 - Vector2.ONE
	mouse_normalized = mouse_normalized.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	_parallax_target = _background_base_position - mouse_normalized * PARALLAX_STRENGTH
	_parallax_active = true


func _ensure_background_holder() -> bool:
	if is_instance_valid(_background_holder) and _background_holder.is_inside_tree():
		return true
	_background_holder = get_tree().get_first_node_in_group(&"dialogic_background_holders")
	if not is_instance_valid(_background_holder):
		return false
	_background_base_position = _background_holder.position
	_parallax_target = _background_base_position
	return true


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _parallax_active:
		return
	if not _ensure_background_holder():
		return
	_background_holder.position = _background_holder.position.lerp(_parallax_target, minf(delta * PARALLAX_SMOOTHING, 1.0))




func _connect_talk_reactions() -> void:
	if not Dialogic.has_subsystem("Text"):
		return
	if not Dialogic.Text.text_started.is_connected(_on_text_started):
		Dialogic.Text.text_started.connect(_on_text_started)
	if not Dialogic.signal_event.is_connected(_on_signal_event):
		Dialogic.signal_event.connect(_on_signal_event)
	if not Dialogic.Text.speaker_updated.is_connected(_on_speaker_updated):
		Dialogic.Text.speaker_updated.connect(_on_speaker_updated)
	if not Dialogic.timeline_started.is_connected(_on_timeline_started):
		Dialogic.timeline_started.connect(_on_timeline_started)
	_reapply_textbox_layout.call_deferred(true)
	if Dialogic.has_subsystem("Portraits") and not Dialogic.Portraits.character_joined.is_connected(_on_character_joined):
		Dialogic.Portraits.character_joined.connect(_on_character_joined)
	if Dialogic.has_subsystem("Backgrounds") and not Dialogic.Backgrounds.background_changed.is_connected(_on_background_changed):
		Dialogic.Backgrounds.background_changed.connect(_on_background_changed)


func _on_background_changed(_info: Dictionary) -> void:
	if Engine.is_editor_hint() or not _ensure_background_holder():
		return
	var holder := _background_holder
	holder.pivot_offset = holder.size * 0.5
	if is_instance_valid(_bg_pushin_tween):
		_bg_pushin_tween.kill()
	holder.scale = Vector2(BG_PUSHIN_START, BG_PUSHIN_START)
	_bg_pushin_tween = create_tween()
	_bg_pushin_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bg_pushin_tween.tween_property(holder, ^"scale", Vector2.ONE, BG_PUSHIN_TIME)


func _on_speaker_updated(character: DialogicCharacter) -> void:
	_update_textbox_fill(character)
	_update_nametag(character)


func _on_timeline_started() -> void:
	_reapply_textbox_layout.call_deferred(true)


func _reapply_textbox_layout(instant: bool = false) -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return
	var speaker_id: String = str(Dialogic.current_state_info.get("speaker", ""))
	var character: DialogicCharacter = null
	if not speaker_id.is_empty():
		character = DialogicResourceUtil.get_character_resource(speaker_id)
	if instant:
		_box_left_abs = _predicted_left_abs(character)
		_box_right_abs = _predicted_right_abs(character)
	_update_textbox_fill(character)
	_update_nametag(character)


func _predicted_left_abs(speaking_character: DialogicCharacter) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		return _box_left_abs
	var window_left_abs: float = (window_position.x / DESIGN_SIZE.x) * viewport_size.x
	var window_right_abs: float = ((window_position.x + window_size.x) / DESIGN_SIZE.x) * viewport_size.x
	var side_margin: float = RIGHT_MARGIN_FRACTION * viewport_size.x
	if speaking_character == null:
		return window_left_abs + side_margin
	var bounds := _get_character_bounds(speaking_character)
	if bounds.x < 0.0 and bounds.y < 0.0:
		return window_left_abs + side_margin
	var gap: float = CHARACTER_GAP_FRACTION * viewport_size.x
	var min_width: float = MIN_BOX_WIDTH_FRACTION * viewport_size.x
	var window_center := (window_left_abs + window_right_abs) * 0.5
	if (bounds.x + bounds.y) * 0.5 <= window_center:
		return minf(bounds.y + gap, window_right_abs - side_margin - min_width)
	return window_left_abs + side_margin


func _predicted_right_abs(speaking_character: DialogicCharacter) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		return _box_right_abs
	var window_left_abs: float = (window_position.x / DESIGN_SIZE.x) * viewport_size.x
	var window_right_abs: float = ((window_position.x + window_size.x) / DESIGN_SIZE.x) * viewport_size.x
	var side_margin: float = RIGHT_MARGIN_FRACTION * viewport_size.x
	if speaking_character == null:
		return window_right_abs - side_margin
	var bounds := _get_character_bounds(speaking_character)
	if bounds.x < 0.0 and bounds.y < 0.0:
		return window_right_abs - side_margin
	var gap: float = CHARACTER_GAP_FRACTION * viewport_size.x
	var min_width: float = MIN_BOX_WIDTH_FRACTION * viewport_size.x
	var window_center := (window_left_abs + window_right_abs) * 0.5
	if (bounds.x + bounds.y) * 0.5 <= window_center:
		return window_right_abs - side_margin
	return maxf(bounds.x - gap, window_left_abs + side_margin + min_width)


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

	var pre_node: Node2D = Dialogic.Portraits.get_character_node(character) if character != null else null
	var was_visible := is_instance_valid(pre_node) and pre_node.modulate.a > 0.5

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

	if was_visible:
		_play_bop(character_node, LINE_BOP_START_SCALE, LINE_BOP_DURATION)

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
		var was_hidden := character_node.modulate.a < 0.5
		if is_equal_approx(character_node.modulate.a, target_alpha):
			continue

		if _character_fade_tweens.has(character_node) and is_instance_valid(_character_fade_tweens[character_node]):
			_character_fade_tweens[character_node].kill()

		var tween := create_tween()
		tween.tween_property(character_node, ^"modulate:a", target_alpha, CHARACTER_FADE_DURATION)
		_character_fade_tweens[character_node] = tween

		if should_be_visible and was_hidden:
			_play_bop(character_node, ENTRANCE_BOP_START_SCALE, ENTRANCE_BOP_DURATION)


func _on_signal_event(argument: Variant) -> void:
	if not (argument is String):
		return
	var arg := argument as String
	if not arg.begins_with("emphasis"):
		return
	var target_id := ""
	if arg.begins_with("emphasis:"):
		target_id = arg.substr("emphasis:".length()).strip_edges()
	else:
		target_id = str(Dialogic.current_state_info.get("speaker", ""))
	if target_id.is_empty():
		return
	var character := DialogicResourceUtil.get_character_resource(target_id)
	if character == null:
		return
	var node: Node2D = Dialogic.Portraits.get_character_node(character)
	if is_instance_valid(node):
		_play_punch(node)


func _play_punch(node: Node2D) -> void:
	if not _portrait_base_scales.has(node):
		_portrait_base_scales[node] = node.scale
	var base_scale: Vector2 = _portrait_base_scales[node]
	if _entrance_bop_tweens.has(node) and is_instance_valid(_entrance_bop_tweens[node]):
		_entrance_bop_tweens[node].kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, ^"scale", base_scale * 1.08, 0.1)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, ^"scale", base_scale, 0.5)
	_entrance_bop_tweens[node] = tween
	_play_impact_shake(node)


const IMPACT_SHAKE_STEPS := 5
const IMPACT_SHAKE_AMOUNT := 7.0
const IMPACT_SHAKE_STEP_TIME := 0.045


func _play_impact_shake(node: Node2D) -> void:
	var base_pos: Vector2 = node.position
	if _impact_shake_tweens.has(node) and is_instance_valid(_impact_shake_tweens[node]):
		_impact_shake_tweens[node].kill()
		node.position = base_pos
	var shake := create_tween()
	for i in IMPACT_SHAKE_STEPS:
		var falloff: float = 1.0 - float(i) / float(IMPACT_SHAKE_STEPS)
		var dir: float = 1.0 if i % 2 == 0 else -1.0
		var offset := Vector2(dir * IMPACT_SHAKE_AMOUNT * falloff, IMPACT_SHAKE_AMOUNT * 0.4 * falloff)
		shake.tween_property(node, ^"position", base_pos + offset, IMPACT_SHAKE_STEP_TIME) \
			.set_trans(Tween.TRANS_SINE)
	shake.tween_property(node, ^"position", base_pos, IMPACT_SHAKE_STEP_TIME)
	_impact_shake_tweens[node] = shake


func _play_bop(node: Node2D, start_scale: float, duration: float) -> void:
	if not _portrait_base_scales.has(node):
		_portrait_base_scales[node] = node.scale
	var base_scale: Vector2 = _portrait_base_scales[node]
	if _entrance_bop_tweens.has(node) and is_instance_valid(_entrance_bop_tweens[node]):
		_entrance_bop_tweens[node].kill()
	node.scale = base_scale * start_scale
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, ^"scale", base_scale, duration)
	_entrance_bop_tweens[node] = tween




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
	_target_right_abs = box_right_abs
	# First show (right edge uninitialised): snap it so the box doesn't grow from
	# zero width. Otherwise interpolate BOTH edges together — binding the right
	# edge as a fixed value made it teleport while only the left slid.
	var from_left: float = _box_left_abs
	var from_right: float = _box_right_abs if _box_right_abs > 0.0 else box_right_abs
	_box_tween = create_tween()
	_box_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_box_tween.tween_method(_apply_box.bind(from_left, from_right, viewport_size), 0.0, 1.0, BOX_MODE_DURATION)


func _apply_box(t: float, from_left: float, from_right: float, viewport_size: Vector2) -> void:
	_box_left_abs = lerpf(from_left, _target_left_abs, t)
	_box_right_abs = lerpf(from_right, _target_right_abs, t)
	var width: float = _box_right_abs - _box_left_abs
	var height: float = BOX_HEIGHT_FRACTION * viewport_size.y
	var margin_bottom: float = BOX_MARGIN_BOTTOM_FRACTION * viewport_size.y

	_textbox_sizer.size = Vector2(width, height)
	_textbox_sizer.position = Vector2(_box_left_abs - viewport_size.x, -height - margin_bottom)


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

