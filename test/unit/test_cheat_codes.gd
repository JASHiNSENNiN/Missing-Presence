extends GutTest

## The toolazy1..5 debug cheat: jumps to an act, scoring skipped acts all-GOOD, with
## an ABSOLUTE score set so backward jumps revert points (keeps good/bad consistent).

var cheat: Node


func before_each() -> void:
	cheat = load("res://Autoload/CheatCodes.gd").new()
	add_child_autofree(cheat)


func test_match_code_detected_at_end_of_buffer() -> void:
	assert_eq(cheat.match_code("toolazy1"), "toolazy1")
	assert_eq(cheat.match_code("xxxtoolazy3"), "toolazy3", "GTA-style: matches even with junk typed before")
	assert_eq(cheat.match_code("toolazy4yy"), "", "code must be at the end of the buffer")
	assert_eq(cheat.match_code("toolaz"), "", "partial code is not a match")


func test_skipped_acts_scored_all_good() -> void:
	# good options available: act1=2, act2=2, act3=0, act4=1
	assert_eq(cheat.ACTS["toolazy1"]["good_before"], 0)
	assert_eq(cheat.ACTS["toolazy2"]["good_before"], 2)
	assert_eq(cheat.ACTS["toolazy3"]["good_before"], 4)
	assert_eq(cheat.ACTS["toolazy4"]["good_before"], 4)
	assert_eq(cheat.ACTS["toolazy5"]["good_before"], 5)


func test_backward_jump_reverts_score() -> void:
	# toolazy2 after toolazy3 must LOWER the score, never accumulate
	assert_lt(cheat.ACTS["toolazy2"]["good_before"], cheat.ACTS["toolazy3"]["good_before"],
		"jumping back (3 -> 2) reverts the extra good points")


func test_every_cheat_timeline_exists() -> void:
	for code: String in cheat.ACTS:
		assert_true(FileAccess.file_exists(cheat.ACTS[code]["path"]), "%s target timeline exists" % code)
