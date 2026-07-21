extends GutTest

# All timeline FILES (path-based, immune to dtl-directory key naming).
const FILES := [
	"res://Dialogue/Acts/Act1/act1_intro_classroom.dtl", "res://Dialogue/Acts/Act1/act1_hallway.dtl",
	"res://Dialogue/Acts/Act1/act1_dinner.dtl", "res://Dialogue/Acts/Act1/act1_montage.dtl",
	"res://Dialogue/Acts/Act1/act1_exam_day.dtl", "res://Dialogue/Acts/Act1/act1_courtyard.dtl",
	"res://Dialogue/Acts/Act2/act2_montage.dtl", "res://Dialogue/Acts/Act2/act2_dinner.dtl", "res://Dialogue/Acts/Act2/act2_sala.dtl",
	"res://Dialogue/Acts/Act3/act3_router.dtl", "res://Dialogue/Acts/Act3/act3_good_shop.dtl", "res://Dialogue/Acts/Act3/act3_good_dinner.dtl",
	"res://Dialogue/Acts/Act3/act3_neutral.dtl", "res://Dialogue/Acts/Act3/act3_bad.dtl",
	"res://Dialogue/Acts/Act4/act4_good.dtl", "res://Dialogue/Acts/Act4/act4_neutral.dtl", "res://Dialogue/Acts/Act4/act4_bad.dtl",
	"res://Dialogue/Acts/Act5/act5_good.dtl", "res://Dialogue/Acts/Act5/act5_neutral.dtl", "res://Dialogue/Acts/Act5/act5_bad.dtl",
	"res://Dialogue/Acts/act_ending.dtl",
]


func test_all_timeline_files_load() -> void:
	for f in FILES:
		assert_true(ResourceLoader.exists(f), "file should exist: %s" % f)
		var tl = load(f)
		assert_not_null(tl, "should load: %s" % f)


func test_all_timelines_have_events() -> void:
	for f in FILES:
		var tl = load(f)
		if tl == null:
			continue
		tl.process()
		assert_gt(tl.events.size(), 0, "%s should have events" % f.get_file())


func test_every_jump_target_resolves() -> void:
	# every `jump X` in every timeline must resolve to a real timeline
	for f in FILES:
		var tl = load(f)
		if tl == null:
			continue
		tl.process()
		for e in tl.events:
			if e.get_script().resource_path.get_file().begins_with("event_jump"):
				assert_not_null(e.get("timeline"),
					"jump in %s must resolve to a real timeline (found null)" % f.get_file())


func test_router_and_ending_reachable() -> void:
	for id in ["act3_router", "act3_good_shop", "act3_neutral", "act3_bad", "act_ending"]:
		assert_not_null(DialogicResourceUtil.get_timeline_resource(id), "%s must resolve" % id)
