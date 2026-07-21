@tool
extends "res://addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Portraits/vn_portrait_layer.gd"

@export var slot_centers: Array[float] = [0.10, 0.30, 0.50, 0.70, 0.90]
@export_range(0.05, 1.0, 0.01) var slot_width: float = 0.20
@export var character_scale: Dictionary = {
	"Maya": 1.0,
	"Ethan": 1.0,
	"Ricardo": 1.0,
	"Jennifer": 1.0,
	"Professor": 1.0,
}


func _ready() -> void:
	super()
	_layout_slots()
	if Engine.is_editor_hint():
		return
	if Dialogic.has_subsystem("Portraits") and not Dialogic.Portraits.character_joined.is_connected(_on_character_joined):
		Dialogic.Portraits.character_joined.connect(_on_character_joined)


func _layout_slots() -> void:
	var portraits: Control = get_node_or_null("%Portraits")
	if portraits == null:
		return
	var containers := portraits.get_children()
	var half := slot_width * 0.5
	for i in containers.size():
		if i >= slot_centers.size():
			continue
		var c := containers[i] as Control
		if c == null:
			continue
		var center: float = clampf(slot_centers[i], 0.0, 1.0)
		c.anchor_left = clampf(center - half, 0.0, 1.0)
		c.anchor_right = clampf(center + half, 0.0, 1.0)
		c.offset_left = 0.0
		c.offset_right = 0.0


func _on_character_joined(info: Dictionary) -> void:
	var character: DialogicCharacter = info.get("character")
	if character == null:
		return
	var mult: float = character_scale.get(character.get_identifier(), 1.0)
	if is_equal_approx(mult, 1.0):
		return
	var node: Node2D = info.get("node") as Node2D
	if not is_instance_valid(node):
		node = Dialogic.Portraits.get_character_node(character)
	if is_instance_valid(node):
		node.scale *= mult
