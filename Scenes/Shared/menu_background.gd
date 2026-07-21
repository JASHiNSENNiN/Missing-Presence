extends Node2D


const BACKGROUND_CANVAS_SIZE := Vector2(3000.0, 1687.0)
const BACKGROUND_OVERSCAN_ZOOM := 1.06
const BACKGROUND_PARALLAX_SMOOTHING := 6.0
const BACKGROUND_PARALLAX_LIMIT := Vector2(200.0, 40.0)

const LAYER_PARALLAX_STRENGTH := {
	"Sky": 0.10,
	"Hill": 0.28,
	"Character": 0.48,
	"GrassMid": 0.75,
	"GrassFront": 1.0,
}

const IDLE_BOB_LAYER := "Character"
const CHARACTER_IDLE_BOB_AMPLITUDE := 6.0
const CHARACTER_IDLE_BOB_SPEED := 1.4

@onready var settings: Node = get_node("/root/Settings")

var _layers: Array[Sprite2D] = []
var _layer_materials: Dictionary = {}
var _base_positions: Dictionary = {}
var _target_offsets: Dictionary = {}
var _idle_time := 0.0


func _ready() -> void:
	for child in get_children():
		if child is Sprite2D:
			_layers.append(child)
			_layer_materials[child] = child.material
			_base_positions[child] = child.position
			_target_offsets[child] = Vector2.ZERO

	get_viewport().size_changed.connect(_update_cover_fit)
	_update_cover_fit()

	settings.background_quality_changed.connect(_apply_quality)
	_apply_quality(settings.background_quality)


func _apply_quality(quality: int) -> void:
	set_process(quality >= 1)
	set_process_input(quality >= 1)
	for layer in _layers:
		layer.material = _layer_materials[layer] if quality >= 2 else null
		if quality < 1:
			layer.position = _base_positions[layer]


func _update_cover_fit() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var cover_scale := maxf(
		viewport_size.x / BACKGROUND_CANVAS_SIZE.x,
		viewport_size.y / BACKGROUND_CANVAS_SIZE.y
	) * BACKGROUND_OVERSCAN_ZOOM

	scale = Vector2(cover_scale, cover_scale)
	position = viewport_size / 2.0 - BACKGROUND_CANVAS_SIZE / 2.0 * cover_scale


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_parallax_target(event.position)


func _update_parallax_target(mouse_position: Vector2) -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var normalized := (mouse_position / viewport_size) * 2.0 - Vector2.ONE
	normalized = normalized.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))

	for layer in _layers:
		var strength: float = LAYER_PARALLAX_STRENGTH.get(layer.name, 0.0)
		_target_offsets[layer] = normalized * BACKGROUND_PARALLAX_LIMIT * strength


func _process(delta: float) -> void:
	_idle_time += delta
	var character_bob := Vector2(0.0, sin(_idle_time * CHARACTER_IDLE_BOB_SPEED) * CHARACTER_IDLE_BOB_AMPLITUDE)

	for layer in _layers:
		var base_position: Vector2 = _base_positions[layer]
		var target_offset: Vector2 = _target_offsets[layer]
		var idle_offset := character_bob if layer.name == IDLE_BOB_LAYER else Vector2.ZERO
		layer.position = layer.position.lerp(base_position + target_offset + idle_offset, delta * BACKGROUND_PARALLAX_SMOOTHING)
