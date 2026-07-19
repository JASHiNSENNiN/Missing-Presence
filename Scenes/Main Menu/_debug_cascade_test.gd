extends Node2D


const MAIN_MENU_SCENE := preload("res://Scenes/Main Menu/MainMenu.tscn")


func _ready() -> void:
	var main_menu := MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	await get_tree().create_timer(1.5).timeout
	main_menu._on_start_pressed()
