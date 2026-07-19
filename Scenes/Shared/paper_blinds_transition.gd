extends CanvasLayer

## "Camera-settle" scene transition (SceneTransition autoload).
##
## The MENU scenes (Main Menu / Options / Load) all sit on the SAME hand-painted
## grass+sky background, so a scene change between them is really just the
## foreground UI changing over one continuous world. This transition leans into
## that: it swaps the scene and eases the incoming view in with a gentle camera
## push -- the whole new scene starts slightly zoomed (as if the camera is
## settling onto it) and relaxes to rest while its living background (grass sway
## / paper grain) animates and its UI plays its own drop-in intro. The art is
## never hidden (no opaque wipe/fade).
##
## Implemented by animating the incoming scene's CanvasLayer transform(s)
## directly (scale + centered offset) -- no viewport texture readback, which is
## unreliable under the GL Compatibility renderer this project targets.
##
## IMPORTANT: the settle is ONLY applied to menu-world scenes. The gameplay
## scene (DialogicTest) builds its Dialogic layout on its own CanvasLayers at
## runtime; pushing a transform onto those offsets their input hit-testing and
## makes the dialogue un-clickable, so gameplay is swapped straight in with no
## camera settle. Menu scenes are opted in by path via SETTLE_SCENES.
##
## Kept as the SceneTransition autoload's own scene so every scene-change call
## site goes through change_scene() below; this persistent node is never itself
## replaced by a scene swap, so it is the safe place to perform the actual
## get_tree().change_scene_to_file() call.

const SETTLE_ZOOM := 1.06
const SETTLE_DURATION := 0.45

## Only these menu-world scenes get the camera settle. Anything else (gameplay)
## is swapped straight in.
const SETTLE_SCENES := [
	"res://Scenes/Main Menu/MainMenu.tscn",
	"res://Scenes/Options/Options.tscn",
	"res://Scenes/Load/Load.tscn",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100


func change_scene(path: String) -> void:
	var should_settle: bool = path in SETTLE_SCENES
	get_tree().change_scene_to_file(path)
	if not should_settle:
		return
	# Let the incoming scene enter the tree and lay out before we drive its
	# camera settle (its own _ready intro starts on the same frames).
	await get_tree().process_frame
	await get_tree().process_frame
	_camera_settle(get_tree().current_scene)


## Push the whole incoming view in slightly and ease it back to rest, reading as
## a camera settling onto the new scene. Applied to every CanvasLayer in the
## scene so background and UI move together as one framed view.
func _camera_settle(scene: Node) -> void:
	if scene == null:
		return
	var center := get_viewport().get_visible_rect().size * 0.5
	var layers: Array[CanvasLayer] = []
	_gather_canvas_layers(scene, layers)
	for cl in layers:
		cl.scale = Vector2.ONE * SETTLE_ZOOM
		cl.offset = center * (1.0 - SETTLE_ZOOM)
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(cl, "scale", Vector2.ONE, SETTLE_DURATION)
		tween.tween_property(cl, "offset", Vector2.ZERO, SETTLE_DURATION)


func _gather_canvas_layers(node: Node, out: Array[CanvasLayer]) -> void:
	if node is CanvasLayer:
		out.append(node)
	for child in node.get_children():
		_gather_canvas_layers(child, out)
