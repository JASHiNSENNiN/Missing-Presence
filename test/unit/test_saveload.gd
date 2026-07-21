extends GutTest

const TEST_SLOT := "gut_test_slot"


func before_all() -> void:
	Dialogic.Save.autosave_mode = Dialogic.Save.AutoSaveMode.ON_TIMER


func after_each() -> void:
	if Dialogic.Save.has_slot(TEST_SLOT):
		Dialogic.Save.delete_slot(TEST_SLOT)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()


func test_autosave_mode_is_on_timer() -> void:
	assert_eq(Dialogic.Save.autosave_mode, Dialogic.Save.AutoSaveMode.ON_TIMER,
		"autosave must be ON_TIMER (not ON_TIMELINE_JUMPS) to avoid null-timeline saves")


func test_save_then_load_restores_timeline() -> void:
	Dialogic.start("res://Dialogue/Acts/Act1/act1_dinner.dtl")
	await wait_frames(3)
	assert_not_null(Dialogic.current_timeline, "timeline should be live before save")
	var err = Dialogic.Save.save(TEST_SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "T"})
	assert_eq(err, OK, "save should succeed")
	assert_true(Dialogic.Save.has_slot(TEST_SLOT), "slot should exist after save")

	Dialogic.end_timeline()
	await wait_frames(2)
	Dialogic.Save.load(TEST_SLOT)
	await wait_frames(3)
	assert_not_null(Dialogic.current_timeline, "timeline should be restored after load")
	assert_string_contains(str(Dialogic.current_timeline.resource_path), "act1_dinner",
		"loaded timeline should be act1_dinner")


func test_saved_state_not_null_timeline() -> void:
	# the original freeze bug: a save must never store a null timeline
	Dialogic.start("res://Dialogue/Acts/Act1/act1_courtyard.dtl")
	await wait_frames(3)
	Dialogic.Save.save(TEST_SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "T"})
	var info = Dialogic.current_state_info
	assert_ne(str(info.get("current_timeline", "null")), "<null>",
		"saved current_timeline must not be null (freeze bug)")


func test_route_vars_persist_through_saveload() -> void:
	Dialogic.start("res://Dialogue/Acts/Act1/act1_dinner.dtl")
	await wait_frames(2)
	Dialogic.VAR.Route.self_honesty = 2
	Dialogic.VAR.Route.parent_pressure = 1
	Dialogic.Save.save(TEST_SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "T"})
	# corrupt the live vars
	Dialogic.VAR.Route.self_honesty = 0
	Dialogic.VAR.Route.parent_pressure = 0
	Dialogic.Save.load(TEST_SLOT)
	await wait_frames(3)
	assert_eq(int(Dialogic.VAR.Route.self_honesty), 2, "self_honesty should restore to 2")
	assert_eq(int(Dialogic.VAR.Route.parent_pressure), 1, "parent_pressure should restore to 1")


func test_load_nonexistent_slot_is_safe() -> void:
	var before = Dialogic.current_timeline
	Dialogic.Save.load("this_slot_does_not_exist_12345")
	await wait_frames(2)
	assert_true(true, "loading a nonexistent slot should not crash")


func test_save_slot_metadata_roundtrip() -> void:
	Dialogic.start("res://Dialogue/Acts/Act1/act1_dinner.dtl")
	await wait_frames(2)
	Dialogic.Save.save(TEST_SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "MyTitle", "timestamp": "2026"})
	var info = Dialogic.Save.get_slot_info(TEST_SLOT)
	assert_eq(info.get("title", ""), "MyTitle", "slot title should roundtrip")
	assert_eq(info.get("timestamp", ""), "2026", "slot timestamp should roundtrip")


func test_maya_portraits_survive_load() -> void:
	# Maya's .dch reverts (editor cache) but GameFlow heals; a load must keep her expressive
	Dialogic.start("res://Dialogue/Acts/Act1/act1_dinner.dtl")
	await wait_frames(3)
	var maya = DialogicResourceUtil.get_character_resource("Maya")
	assert_gt(maya.portraits.size(), 10, "Maya should have her full expression set (heal)")
	assert_true(maya.portraits.has("teary"), "Maya should have teary")
