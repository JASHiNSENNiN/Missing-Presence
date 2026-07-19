extends ColorRect


@export var inflate := Vector2(13.0, 7.0)
@export var flag_rotation := -0.08

@onready var target: Control = get_node("../NameLabelPanel")


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	visible = target.visible and target.size.length() > 1.0
	if not visible:
		return
	size = target.size + inflate * 2.0
	pivot_offset = size * 0.5
	rotation = flag_rotation
	global_position = target.global_position - inflate
