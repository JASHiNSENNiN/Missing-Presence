extends GutTest

# Regression tests for the Continue-after-exit save/load bugs (2026-07-22):
#  1. Autosave must never write a null-timeline stub (root data-loss cause).
#  2. GameFlow.slot_has_timeline must reject stub/empty saves.
#  3. load_slot_and_wait must refuse a slot with no timeline (no clear/corrupt).

const SLOT := "gut_regression_slot"


func before_all() -> void:
	GameFlow._heal_maya_portraits()
	Dialogic.Save.autosave_mode = Dialogic.Save.AutoSaveMode.ON_TIMER


func after_all() -> void:
	# Saving sets the global "latest_save_slot" to our test slot; deleting it would
	# leave the real Continue pointer dangling. Restore it to a real save.
	if not GameFlow.slot_has_timeline(Dialogic.Save.get_latest_slot()):
		Dialogic.Save.set_latest_slot("autosave")


func after_each() -> void:
	if Dialogic.Save.has_slot(SLOT):
		Dialogic.Save.delete_slot(SLOT)
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
		for _i in 12:
			if Dialogic.current_timeline == null:
				break
			await wait_frames(1)
	await wait_frames(2)


func test_autosave_refuses_null_timeline() -> void:
	# End any timeline so current_timeline is null, then force an autosave.
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
		await wait_frames(4)
	assert_null(Dialogic.current_timeline, "precondition: no active timeline")
	var default_slot := Dialogic.Save.get_default_slot()
	var had_slot_before := Dialogic.Save.has_slot(default_slot)
	Dialogic.Save.perform_autosave()
	await wait_frames(2)
	# The guard returns OK without writing; if the default slot existed it must
	# NOT have been turned into a null-timeline stub.
	if had_slot_before:
		assert_true(GameFlow.slot_has_timeline(default_slot),
			"autosave must not overwrite an existing save with a null-timeline stub")


func test_slot_has_timeline_true_for_real_save() -> void:
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	await wait_frames(4)
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "real"})
	await wait_frames(2)
	assert_true(GameFlow.slot_has_timeline(SLOT), "a save taken mid-timeline has a timeline")


func test_slot_has_timeline_false_for_missing_slot() -> void:
	assert_false(GameFlow.slot_has_timeline("no_such_slot_zzz"), "missing slot has no timeline")
	assert_false(GameFlow.slot_has_timeline(""), "empty slot name has no timeline")


func test_load_slot_and_wait_refuses_missing_slot() -> void:
	var ok: bool = await GameFlow.load_slot_and_wait("no_such_slot_zzz")
	assert_false(ok, "load_slot_and_wait returns false for a slot that does not exist")


func test_load_slot_and_wait_restores_real_save() -> void:
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	await wait_frames(4)
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "r"})
	await Dialogic.end_timeline(true)
	for _i in 12:
		if Dialogic.current_timeline == null:
			break
		await wait_frames(1)
	assert_null(Dialogic.current_timeline, "precondition: timeline cleared before load")
	var ok: bool = await GameFlow.load_slot_and_wait(SLOT)
	assert_true(ok, "load_slot_and_wait restores a valid save")
	assert_not_null(Dialogic.current_timeline, "timeline is live after the awaited load returns")
	assert_string_contains(str(Dialogic.current_timeline.resource_path), "act1",
		"restores the exact saved timeline")
