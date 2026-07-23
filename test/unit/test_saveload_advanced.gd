extends GutTest

const SLOT := "gut_adv_slot"


func before_all() -> void:
	Dialogic.Save.autosave_mode = Dialogic.Save.AutoSaveMode.ON_TIMER


func after_each() -> void:
	if Dialogic.Save.has_slot(SLOT):
		Dialogic.Save.delete_slot(SLOT)
	await _hard_end()


func _hard_end() -> void:
	if Dialogic.current_timeline == null:
		return
	await Dialogic.end_timeline(true)
	for _i in 15:
		if Dialogic.current_timeline == null:
			break
		await wait_frames(1)


func test_saveload_in_large_converted_act() -> void:
	Dialogic.start("res://Dialogue/Acts/act5_good.dtl")
	await wait_frames(4)
	assert_not_null(Dialogic.current_timeline, "act5_good should start")
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "big"})
	await _hard_end()
	var ok: bool = await GameFlow.load_slot_and_wait(SLOT)
	assert_true(ok, "big act should restore")
	assert_string_contains(str(Dialogic.current_timeline.resource_path), "act5_good", "restores act5_good")


const HALLWAY_BG := "res://Art/Backgrounds/classroom.png"


func test_saveload_restores_background() -> void:
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	var bg_before := ""
	for _i in 30:
		await wait_frames(1)
		bg_before = str(Dialogic.current_state_info.get("background_argument", ""))
		if bg_before == HALLWAY_BG:
			break
	assert_eq(bg_before, HALLWAY_BG, "act1 [background] event should set its own background")
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "bg"})
	await _hard_end()
	await GameFlow.load_slot_and_wait(SLOT)
	var bg_after = str(Dialogic.current_state_info.get("background_argument", ""))
	assert_eq(bg_after, HALLWAY_BG, "background should restore to the saved act1 image")


func test_saveload_restores_joined_characters() -> void:
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	await wait_frames(6)
	var joined_before = Dialogic.current_state_info.get("portraits", {}).size()
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "j"})
	await _hard_end()
	await GameFlow.load_slot_and_wait(SLOT)
	var joined_after = Dialogic.current_state_info.get("portraits", {}).size()
	assert_eq(joined_after, joined_before, "joined characters should restore")


func test_multiple_saveload_cycles_stable() -> void:
	Dialogic.start("res://Dialogue/Acts/act2.dtl")
	await wait_frames(4)
	for i in 3:
		Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "cycle%d" % i})
		var ok: bool = await GameFlow.load_slot_and_wait(SLOT)
		assert_true(ok, "cycle %d: robust load restores a valid timeline" % i)
		assert_not_null(Dialogic.current_timeline, "cycle %d: timeline stays valid" % i)


func test_load_slot_and_wait_blocks_until_restored() -> void:
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	await wait_frames(4)
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "block"})
	await _hard_end()
	assert_null(Dialogic.current_timeline, "precondition: timeline cleared before load")
	var ok: bool = await GameFlow.load_slot_and_wait(SLOT)
	assert_true(ok, "load_slot_and_wait returns true when restore succeeds")
	assert_not_null(Dialogic.current_timeline, "timeline is non-null the instant the await returns")


func test_can_save_false_during_load() -> void:
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	await wait_frames(4)
	assert_true(GameFlow.can_save(), "can_save is true with a live timeline")
	await _hard_end()
	assert_false(GameFlow.can_save(), "can_save is false once the timeline ends")


func test_latest_slot_tracks_save() -> void:
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	await wait_frames(4)
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "latest"})
	assert_eq(Dialogic.Save.get_latest_slot(), SLOT, "get_latest_slot should return the just-saved slot (Continue relies on this)")


func test_route_progress_persists_across_acts() -> void:
	Dialogic.start("res://Dialogue/Acts/act4.dtl")
	await wait_frames(4)
	Dialogic.VAR.Route.good = 3
	Dialogic.VAR.Route.bad = 1
	Dialogic.Save.save(SLOT, false, Dialogic.Save.ThumbnailMode.NONE, {"title": "r"})
	Dialogic.VAR.Route.good = 0
	Dialogic.VAR.Route.bad = 0
	await GameFlow.load_slot_and_wait(SLOT)
	assert_eq(int(Dialogic.VAR.Route.good), 3, "route progress must survive save/load")
	assert_eq(int(Dialogic.VAR.Route.bad), 1, "bad must survive save/load")
