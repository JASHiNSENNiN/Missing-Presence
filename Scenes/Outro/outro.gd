extends Node2D

const MAIN_MENU := "res://Scenes/Main Menu/MainMenu.tscn"
const DIALOGIC_TEST := "res://Scenes/DialogicTest/DialogicTest.tscn"

const GEOM := preload("res://Fonts/Geom/static/Geom-ExtraBold.ttf")
const OUTFIT_BODY := preload("res://Fonts/Outfit/static/Outfit-Bold.ttf")

const MENU_BROWN := Color(0.631, 0.443, 0.29)
const CREAM := Color(0.98, 0.95, 0.86)
const ROUTE_ACCENT := {
	"good": Color(0.58, 0.72, 0.44), "neutral": Color(0.86, 0.68, 0.36), "bad": Color(0.56, 0.64, 0.86),
}
const ROUTE_MOOD := {
	# subtle, theme-faithful: warmer & brighter when hopeful, gently faded when not.
	"good":    {"bg": Color(1.05, 1.01, 0.93), "scrim": Color(0.13, 0.10, 0.06, 0.26)},
	"neutral": {"bg": Color(1.0, 1.0, 1.0),    "scrim": Color(0.14, 0.10, 0.06, 0.35)},
	"bad":     {"bg": Color(0.86, 0.84, 0.88), "scrim": Color(0.12, 0.10, 0.10, 0.42)},
}

const ENDING_NAMES := {
	"good": "An Open Door", "neutral": "Somewhere In Between", "bad": "Missing Presence",
}
const REFLECTIONS := {
	"good": "Maya kept choosing honesty — with her parents, with Ethan, with herself.\nIt didn't make the pressure disappear. But the screens dimmed, just a little,\nand a door she'd kept shut stayed open.",
	"neutral": "Some days honest, some days guarded.\nThe distance didn't close — but it didn't widen either.\nThe family kept eating in their quiet bubble, still searching, together, for the words.",
	"bad": "The mask never came off. The distance she felt became the distance that was real.\nThree people under one roof, farther apart than ever —\nlit only by the glow of their screens.",
}
const CREDITS := [
	"~MISSING PRESENCE",
	"The perception of 18–25 year olds toward parental phubbing.", "",
	"#SCHOOL OF DESIGN AND ARTS  ·  MTHE0ME GROUP 1", "",
	"#CREATED BY",
	"Matilde Ysobel Acuña", "Ranyelle Dayne Aquias", "John Allendrea Enciso",
	"Janine Ann Regala", "Paulo Louis Relente", "",
	"#MADE WITH", "Godot Engine 4.6  ·  Dialogic 2", "",
	"~Salamat sa paglalaro.", "Thank you for playing.",
]

# Auto-scroll base speed (px/sec). Wheel/drag adds momentum that decays on top,
# so scrolling has weight but the credits keep rolling by themselves.
const AUTO_SCROLL_PX := 42.0
const WHEEL_IMPULSE := 18.0
const DRAG_IMPULSE := 0.6
const FRICTION := 9.0

const TITLE_LOGO := "res://Mocks/main menu/title logo.png"
const CAST := [
	["Maya", "res://Art/Characters/maya/smile.png", "the daughter"],
	["Ethan", "res://Art/Characters/ethan/glad_close.png", "the childhood friend"],
	["Jennifer", "res://Art/Characters/jennifer/glad_close.png", "her mother"],
	["Ricardo", "res://Art/Characters/ricardo/glad_close.png", "her father"],
]
const SCENES := [
	"res://Art/Backgrounds/classroom.png",
	"res://Art/Backgrounds/campus_hallway.png",
	"res://Art/Backgrounds/campus_courtyard.png",
	"res://Art/Backgrounds/mayas_room.png",
]
const NAME_COLORS := {
	"Maya": Color(0.42, 0.55, 0.30), "Ethan": Color(0.28, 0.55, 0.55),
	"Jennifer": Color(0.75, 0.5, 0.22), "Ricardo": Color(0.55, 0.42, 0.30),
}

@onready var content: Control = $CanvasLayer/Content
@onready var confirm_flash: ColorRect = $CanvasLayer/ConfirmFlash

var _game_flow: Node
var _ui_sound: Node
var _scene_transition: Node:
	get: return get_node_or_null("/root/SceneTransition")
var _leaving := false
var _route := "neutral"
var _scroll: ScrollContainer
var _scroll_pos := 0.0
var _velocity := 0.0
var _scroll_loop_at := 1
var _dragging := false
var _label_tweens := {}


func _ready() -> void:
	_game_flow = get_node_or_null("/root/GameFlow")
	_ui_sound = get_node_or_null("/root/UISound")
	if _ui_sound:
		_ui_sound.play_ambience()
	if _game_flow:
		var r := str(_game_flow.get("last_ending_route"))
		if not r.is_empty():
			_route = r
	_build()


func _build() -> void:
	var view := get_viewport().get_visible_rect().size

	# match the setting to the mood (research: warm/hopeful for good, cool/dim for bad)
	var mood: Dictionary = ROUTE_MOOD.get(_route, ROUTE_MOOD["neutral"])
	var bg := get_node_or_null("CanvasLayer/BackgroundLayers")
	if bg is CanvasItem:
		(bg as CanvasItem).modulate = mood["bg"]

	# overall gentle dim, deeper on the bad route
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = mood["scrim"]
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(scrim)


	# scroll fills the top ~82%; the bottom is a clean footer for the fixed buttons
	# (so credits never collide with Play Again / Main Menu)
	_scroll = ScrollContainer.new()
	_scroll.anchor_left = 0.0
	_scroll.anchor_right = 1.0
	_scroll.anchor_top = 0.0
	_scroll.anchor_bottom = 0.82
	_scroll.offset_left = 0
	_scroll.offset_right = 0
	_scroll.offset_top = 0
	_scroll.offset_bottom = 0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.clip_contents = true
	content.add_child(_scroll)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(col)

	# --- opening: the ending this run earned ---
	col.add_child(_gap(int(view.y * 0.42)))
	col.add_child(_heading(ENDING_NAMES.get(_route, "The End"), 58, CREAM))
	col.add_child(_body(REFLECTIONS.get(_route, ""), 18, Color(0.95, 0.92, 0.85)))
	col.add_child(_gap(8))
	col.add_child(_tracker())

	# --- title logo ---
	col.add_child(_gap(int(view.y * 0.5)))
	if ResourceLoader.exists(TITLE_LOGO):
		var logo := TextureRect.new()
		logo.texture = load(TITLE_LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.custom_minimum_size = Vector2(0, 150)
		logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(logo)

	# --- CAST: portrait + name + role for each character ---
	col.add_child(_gap(60))
	col.add_child(_heading("CAST", 26, CREAM))
	col.add_child(_gap(20))
	for entry in CAST:
		col.add_child(_cast_card(entry[0], entry[1], entry[2]))
		col.add_child(_gap(28))

	# --- SCENES: the journey as tilted polaroids ---
	col.add_child(_gap(30))
	col.add_child(_heading("THE JOURNEY", 26, CREAM))
	col.add_child(_gap(24))
	col.add_child(_polaroid_strip())

	# --- this run's stats (grouping + data) ---
	col.add_child(_gap(30))
	col.add_child(_divider())
	col.add_child(_gap(30))
	col.add_child(_heading("THIS RUN", 26, CREAM))
	col.add_child(_gap(12))
	var g := 0
	var b := 0
	if _game_flow and Dialogic.VAR.has("Route"):
		g = int(Dialogic.VAR.Route.good)
		b = int(Dialogic.VAR.Route.bad)
	col.add_child(_body("Good  %d      ·      Bad  %d" % [g, b], 18, Color(0.94, 0.91, 0.84)))
	var seen: Array = _game_flow.endings_seen() if _game_flow else [_route]
	col.add_child(_body("Endings discovered  %d of 3" % seen.size(), 16, Color(0.86, 0.80, 0.70)))

	# --- team credits ---
	col.add_child(_gap(40))
	col.add_child(_divider())
	col.add_child(_gap(40))
	for line in CREDITS:
		if line == "":
			col.add_child(_gap(12))
		elif line.begins_with("~"):
			col.add_child(_heading(line.substr(1), 30, CREAM))
		elif line.begins_with("#"):
			col.add_child(_body(line.substr(1), 12, Color(0.80, 0.72, 0.60)))
		else:
			col.add_child(_body(line, 19, Color(0.94, 0.91, 0.84)))

	col.add_child(_gap(40))
	col.add_child(_divider())
	col.add_child(_gap(30))
	col.add_child(_body("SPECIAL THANKS", 12, Color(0.80, 0.72, 0.60)))
	col.add_child(_body("Our professors and advisors, for their guidance.", 17, Color(0.94, 0.91, 0.84)))
	col.add_child(_body("And you — for staying present.", 17, Color(0.94, 0.91, 0.84)))
	col.add_child(_gap(int(view.y * 0.6)))

	# FIXED paper buttons (overlay, always clickable — not part of the roll)
	_add_fixed_buttons()

	await get_tree().process_frame
	await get_tree().process_frame
	_scroll_loop_at = maxi(int(col.size.y - view.y), 1)
	set_process(true)


func _process(delta: float) -> void:
	if _scroll == null:
		return
	# base auto-scroll + decaying manual momentum = "weight" that keeps rolling
	_scroll_pos += AUTO_SCROLL_PX * delta + _velocity
	_velocity = move_toward(_velocity, 0.0, FRICTION * delta * 60.0)
	# seamless wrap in both directions
	if _scroll_pos >= float(_scroll_loop_at):
		_scroll_pos -= float(_scroll_loop_at)
	elif _scroll_pos < 0.0:
		_scroll_pos += float(_scroll_loop_at)
	_scroll.scroll_vertical = int(_scroll_pos)


func _input(event: InputEvent) -> void:
	if _scroll == null:
		return
	# capture the wheel BEFORE the ScrollContainer jumps, turn it into momentum
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_velocity -= WHEEL_IMPULSE
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_velocity += WHEEL_IMPULSE
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		_velocity -= event.relative.y * DRAG_IMPULSE
		get_viewport().set_input_as_handled()


const PAPER_BUTTON := "res://Mocks/Novel UI/Rectangle 1.png"


func _add_fixed_buttons() -> void:
	# Two real cream-paper buttons (Rectangle 1.png), pinned bottom, always clickable.
	var view := get_viewport().get_visible_rect().size
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override(&"separation", 40)
	bar.position = Vector2(view.x * 0.5 - 250, view.y - 96)
	bar.custom_minimum_size = Vector2(500, 64)
	content.add_child(bar)
	bar.add_child(_paper_button("Play Again", _on_play_again))
	bar.add_child(_paper_button("Main Menu", _on_main_menu))
	# juicy drop-in from below
	bar.position.y += 120.0
	bar.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(bar, ^"position:y", view.y - 96, 0.55).set_delay(0.5)
	t.tween_property(bar, ^"modulate:a", 1.0, 0.45).set_delay(0.5)


func _paper_button(text: String, cb: Callable) -> Control:
	var btn := TextureRect.new()
	if ResourceLoader.exists(PAPER_BUTTON):
		btn.texture = load(PAPER_BUTTON)
	btn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	btn.stretch_mode = TextureRect.STRETCH_SCALE
	btn.custom_minimum_size = Vector2(210, 64)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pivot_offset = Vector2(105, 32)

	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override(&"font_size", 24)
	lbl.add_theme_color_override(&"font_color", MENU_BROWN.darkened(0.05))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	# same hover tilt as the main-menu labels (-6°, cubic ease-out)
	btn.mouse_entered.connect(func() -> void:
		if _ui_sound: _ui_sound.hover()
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
			.tween_property(btn, ^"rotation_degrees", -6.0, 0.2)
		lbl.add_theme_color_override(&"font_color", Color(0.55, 0.32, 0.18)))
	btn.mouse_exited.connect(func() -> void:
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
			.tween_property(btn, ^"rotation_degrees", 0.0, 0.2)
		lbl.add_theme_color_override(&"font_color", MENU_BROWN.darkened(0.05)))
	btn.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if _ui_sound: _ui_sound.select()
			var tw := create_tween()
			tw.tween_property(btn, ^"scale", Vector2.ONE * 0.9, 0.07)
			tw.tween_property(btn, ^"scale", Vector2.ONE, 0.09)
			cb.call())
	return btn


func _cast_card(cname: String, portrait_path: String, role: String) -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 4)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ResourceLoader.exists(portrait_path):
		var wrap := CenterContainer.new()
		var pr := TextureRect.new()
		pr.texture = load(portrait_path)
		pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# fit the whole portrait — never crop the characters
		pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pr.custom_minimum_size = Vector2(210, 240)
		pr.clip_contents = false
		wrap.add_child(pr)
		box.add_child(wrap)
	box.add_child(_heading(cname, 26, NAME_COLORS.get(cname, CREAM)))
	box.add_child(_body(role, 14, Color(0.82, 0.78, 0.70)))
	return box


func _polaroid_strip() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 18)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tilts := [-4.0, 3.0, -3.0, 4.0]
	var i := 0
	for path in SCENES:
		if not ResourceLoader.exists(path):
			i += 1
			continue
		# a white polaroid frame around a scene thumbnail
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.98, 0.96, 0.90)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 7
		sb.content_margin_right = 7
		sb.content_margin_top = 7
		sb.content_margin_bottom = 18
		sb.shadow_color = Color(0.1, 0.06, 0.03, 0.5)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 5)
		frame.add_theme_stylebox_override(&"panel", sb)
		frame.rotation_degrees = tilts[i % tilts.size()]
		frame.pivot_offset = Vector2(90, 70)
		var thumb := TextureRect.new()
		thumb.texture = load(path)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.custom_minimum_size = Vector2(168, 112)
		thumb.clip_contents = true
		frame.add_child(thumb)
		row.add_child(frame)
		i += 1
	return row


func _gap(h: int) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, h)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sp


func _shadowed(l: Label) -> Label:
	# no stroke / no shadow — the thick font + the scrim carry readability
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _heading(txt: String, sz: int, col: Color) -> Label:
	# Geom display face for titles / section heads
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override(&"font", GEOM)
	l.add_theme_font_size_override(&"font_size", sz)
	l.add_theme_color_override(&"font_color", col)
	return _shadowed(l)


func _body(txt: String, sz: int, col: Color) -> Label:
	# static bold Outfit for reading text (thick, clean — no variable-weight override)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override(&"font", OUTFIT_BODY)
	l.add_theme_font_size_override(&"font_size", sz)
	l.add_theme_color_override(&"font_color", col)
	return _shadowed(l)


func _divider() -> Control:
	# small centered ornament rule for section rhythm
	var c := CenterContainer.new()
	var line := ColorRect.new()
	line.color = Color(0.88, 0.82, 0.68, 0.6)
	line.custom_minimum_size = Vector2(120, 2)
	c.add_child(line)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _tracker() -> Control:
	var seen: Array = _game_flow.endings_seen() if _game_flow else [_route]
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override(&"separation", 6)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(_body("%d of 3 endings discovered" % seen.size(), 15, Color(0.90, 0.86, 0.78)))
	# list ALL three endings; unlocked ones in their route colour, locked ones dim
	for r in ["good", "neutral", "bad"]:
		var unlocked: bool = r in seen
		var name: String = ENDING_NAMES.get(r, r) if unlocked else "??? — locked"
		var col: Color = ROUTE_ACCENT.get(r, Color.WHITE) if unlocked else Color(0.55, 0.52, 0.46)
		var mark := "✦ " if unlocked else "· "
		wrap.add_child(_body(mark + name, 14, col.lightened(0.15) if unlocked else col))
	return wrap


func _menu_label(text: String, cb: Callable) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", 30)
	l.add_theme_color_override(&"font_color", CREAM)
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.resized.connect(func() -> void: l.pivot_offset = l.size * 0.5)
	l.mouse_entered.connect(_on_menu_hover.bind(l, true))
	l.mouse_exited.connect(_on_menu_hover.bind(l, false))
	l.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_punch(l)
			cb.call())
	return l


func _on_menu_hover(l: Label, hovering: bool) -> void:
	if hovering and _ui_sound:
		_ui_sound.hover()
	if _label_tweens.has(l) and is_instance_valid(_label_tweens[l]):
		_label_tweens[l].kill()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, ^"rotation_degrees", -6.0 if hovering else 0.0, 0.2)
	_label_tweens[l] = tw


func _punch(l: Label) -> void:
	if _ui_sound:
		_ui_sound.select()
	var tw := create_tween()
	tw.tween_property(l, ^"scale", Vector2.ONE * 0.92, 0.08).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, ^"scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash() -> void:
	if _ui_sound:
		_ui_sound.confirm()
	var tw := create_tween()
	tw.tween_property(confirm_flash, ^"color:a", 0.3, 0.05)
	tw.tween_property(confirm_flash, ^"color:a", 0.0, 0.25)


func _on_play_again() -> void:
	if _leaving:
		return
	_leaving = true
	_flash()
	if _game_flow:
		_game_flow.set("pending_load_slot", "")
	_go(DIALOGIC_TEST)


func _on_main_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_flash()
	_go(MAIN_MENU)


func _go(path: String) -> void:
	var st := _scene_transition
	if st and st.has_method("change_scene"):
		st.change_scene(path)
	else:
		get_tree().change_scene_to_file(path)
