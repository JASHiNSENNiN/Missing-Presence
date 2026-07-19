extends CanvasItem


@export var min_quality: int = 1

var _material: Material


func _ready() -> void:
	_material = material
	var settings := get_node("/root/Settings")
	settings.background_quality_changed.connect(_on_quality_changed)
	_on_quality_changed(settings.background_quality)


func _on_quality_changed(quality: int) -> void:
	material = _material if quality >= min_quality else null
