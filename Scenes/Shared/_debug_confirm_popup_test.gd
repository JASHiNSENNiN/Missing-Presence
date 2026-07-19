extends Node2D


const CONFIRM_POPUP_SCENE := preload("res://Scenes/Shared/confirm_popup.tscn")


func _ready() -> void:
	var popup := CONFIRM_POPUP_SCENE.instantiate()
	add_child(popup)
	await get_tree().create_timer(0.5).timeout
	popup.open("Return to Main Menu? Unsaved progress will be lost.", "Return to Main Menu", "Keep Playing")
