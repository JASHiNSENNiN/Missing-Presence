extends GutTest

const FILES := {
	"act1": "res://Dialogue/Acts/act1.dtl", "act2": "res://Dialogue/Acts/act2.dtl",
	"act3": "res://Dialogue/Acts/act3.dtl", "act4": "res://Dialogue/Acts/act4.dtl",
	"act5_router": "res://Dialogue/Acts/act5_router.dtl", "act5_good": "res://Dialogue/Acts/act5_good.dtl",
	"act5_neutral": "res://Dialogue/Acts/act5_neutral.dtl", "act5_bad": "res://Dialogue/Acts/act5_bad.dtl",
	"act_ending": "res://Dialogue/Acts/act_ending.dtl",
}

func test_all_new_acts_load_and_have_events() -> void:
	for id in FILES:
		var tl = load(FILES[id])
		assert_not_null(tl, "%s loads" % id)
		if tl: tl.process(); assert_gt(tl.events.size(), 0, "%s has events" % id)

func test_every_jump_resolves() -> void:
	for id in FILES:
		var tl = load(FILES[id])
		if tl == null: continue
		tl.process()
		for e in tl.events:
			if e.get_script().resource_path.get_file().begins_with("event_jump"):
				assert_not_null(e.get("timeline"), "jump in %s resolves (not null)" % id)

func test_each_act_starts() -> void:
	for id in ["act1","act2","act3","act4","act5_good","act5_neutral","act5_bad"]:
		Dialogic.start(FILES[id])
		await wait_frames(3)
		assert_not_null(Dialogic.current_timeline, "%s starts at runtime" % id)
		await Dialogic.end_timeline(true)
		for _i in 8:
			if Dialogic.current_timeline == null: break
			await wait_frames(1)
