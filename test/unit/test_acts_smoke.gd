extends GutTest

const ACTS := [
	"res://Dialogue/Acts/Act1/act1_intro_classroom.dtl",
	"res://Dialogue/Acts/Act1/act1_hallway.dtl",
	"res://Dialogue/Acts/Act1/act1_dinner.dtl",
	"res://Dialogue/Acts/Act1/act1_montage.dtl",
	"res://Dialogue/Acts/Act1/act1_exam_day.dtl",
	"res://Dialogue/Acts/Act1/act1_courtyard.dtl",
	"res://Dialogue/Acts/Act2/act2_montage.dtl",
	"res://Dialogue/Acts/Act2/act2_dinner.dtl",
	"res://Dialogue/Acts/Act2/act2_sala.dtl",
	"res://Dialogue/Acts/Act3/act3_router.dtl",
	"res://Dialogue/Acts/Act3/act3_good_shop.dtl",
	"res://Dialogue/Acts/Act3/act3_good_dinner.dtl",
	"res://Dialogue/Acts/Act3/act3_neutral.dtl",
	"res://Dialogue/Acts/Act3/act3_bad.dtl",
	"res://Dialogue/Acts/Act4/act4_good.dtl",
	"res://Dialogue/Acts/Act4/act4_neutral.dtl",
	"res://Dialogue/Acts/Act4/act4_bad.dtl",
	"res://Dialogue/Acts/Act5/act5_good.dtl",
	"res://Dialogue/Acts/Act5/act5_neutral.dtl",
	"res://Dialogue/Acts/Act5/act5_bad.dtl",
	"res://Dialogue/Acts/act_ending.dtl",
]


func before_all() -> void:
	Dialogic.Save.autosave_mode = Dialogic.Save.AutoSaveMode.ON_TIMER


func _hard_end() -> void:
	if Dialogic.current_timeline == null:
		return
	await Dialogic.end_timeline(true)
	for _i in 15:
		if Dialogic.current_timeline == null:
			break
		await wait_frames(1)


func test_every_act_starts_without_error() -> void:
	for path in ACTS:
		Dialogic.start(path)
		await wait_frames(4)
		if path.ends_with("act3_router.dtl"):
			await wait_frames(4)
			await _hard_end()
			continue
		assert_not_null(Dialogic.current_timeline, "%s should start" % path.get_file())
		if Dialogic.current_timeline != null:
			assert_string_contains(str(Dialogic.current_timeline.resource_path), path.get_file().get_basename(),
				"%s should be the active timeline" % path.get_file())
		await _hard_end()
