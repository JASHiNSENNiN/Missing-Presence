extends Node

## Debug cheat codes (GTA-style): type a code any time during play to jump to an act.
## Skipped acts are auto-scored as all-GOOD. The score is SET absolutely on every jump
## (not added), so jumping BACKWARD — e.g. toolazy3 then toolazy2 — automatically reverts
## the extra points and keeps the good/bad route system consistent. For debugging only.

## good_before = the good-route points earned across the acts BEFORE this one
## (act1=2, act2=2, act3=0, act4=1 good options), so "everything skipped was good".
const ACTS := {
	"toolazy1": {"path": "res://Dialogue/Acts/act1.dtl", "good_before": 0},
	"toolazy2": {"path": "res://Dialogue/Acts/act2.dtl", "good_before": 2},
	"toolazy3": {"path": "res://Dialogue/Acts/act3.dtl", "good_before": 4},
	"toolazy4": {"path": "res://Dialogue/Acts/act4.dtl", "good_before": 4},
	"toolazy5": {"path": "res://Dialogue/Acts/act5_router.dtl", "good_before": 5},
}
const MAX_BUFFER := 24

var _buffer := ""
var _pending: DialogicTimeline
var _toast_layer: CanvasLayer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 128
	add_child(_toast_layer)
	_toast_label = Label.new()
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.offset_top = 22.0
	_toast_label.add_theme_font_size_override(&"font_size", 22)
	_toast_label.add_theme_color_override(&"font_color", Color(0.98, 0.95, 0.86))
	_toast_label.add_theme_color_override(&"font_outline_color", Color(0.16, 0.10, 0.05, 0.9))
	_toast_label.add_theme_constant_override(&"outline_size", 6)
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.modulate.a = 0.0
	_toast_layer.add_child(_toast_label)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	# derive the typed character: prefer unicode (respects keyboard layout), fall back
	# to the keycode name so simulated/injected key events are recognised too.
	var ch := ""
	if key.unicode > 0:
		ch = String.chr(key.unicode).to_lower()
	else:
		var ks := OS.get_keycode_string(key.keycode)
		if ks.length() == 1:
			ch = ks.to_lower()
	if ch.length() != 1 or not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9")):
		return
	_buffer += ch
	if _buffer.length() > MAX_BUFFER:
		_buffer = _buffer.substr(_buffer.length() - MAX_BUFFER)
	var code := match_code(_buffer)
	if not code.is_empty():
		_buffer = ""
		activate(code)


## Returns the cheat code the buffer currently ends with, or "" if none.
func match_code(buffer: String) -> String:
	for code: String in ACTS:
		if buffer.ends_with(code):
			return code
	return ""


func activate(code: String) -> void:
	if not ACTS.has(code):
		return
	var data: Dictionary = ACTS[code]
	var timeline := load(data["path"]) as DialogicTimeline
	if timeline == null:
		push_warning("[Cheat] missing timeline: %s" % data["path"])
		return
	# absolute score for the all-good skipped acts — auto-reverts on backward jumps
	Dialogic.VAR.set_variable("Route.good", data["good_before"])
	Dialogic.VAR.set_variable("Route.bad", 0)
	# drop any notification block so the jump isn't swallowed
	Dialogic.signal_event.emit("emotion_clear")
	Dialogic.paused = false
	# defer the actual timeline switch to a clean idle frame — restarting Dialogic from
	# inside input/script processing risks re-entrancy while it tears down the timeline.
	_pending = timeline
	_start_pending.call_deferred()
	_toast("%s  →  jump  (Route good=%d · bad=0)" % [code, data["good_before"]])


func _start_pending() -> void:
	if _pending == null:
		return
	var timeline := _pending
	_pending = null
	# switch the timeline in-place when a layout already exists (the in-game path,
	# same as the jump event); only build a fresh layout when there is none (e.g.
	# triggered from the main menu).
	if Dialogic.has_subsystem("Styles") and Dialogic.Styles.has_active_layout_node():
		Dialogic.start_timeline(timeline)
	else:
		Dialogic.start(timeline)


func _toast(msg: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = msg
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_label.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, ^"modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_label, ^"modulate:a", 0.0, 0.5)
