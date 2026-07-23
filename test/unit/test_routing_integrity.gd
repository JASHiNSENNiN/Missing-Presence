extends GutTest

## Regression: the game must route every act to the maintained Dialogue/Acts/ files.
## A stale duplicate Dialogue/Acts_NEW/ once shadowed act5 in the dtl_directory, so the
## game played an old Act 5 (no expressions, no atmosphere, possessive-mis-split bugs).

const ACTS_DIR := "res://Dialogue/Acts/"
const TIMELINES := ["act1", "act2", "act3", "act4", "act5_bad", "act5_good", "act5_neutral", "act5_router", "act_ending"]


func _project_godot() -> String:
	return FileAccess.get_file_as_string("res://project.godot")


func test_no_stale_acts_new_referenced() -> void:
	assert_false(_project_godot().contains("Acts_NEW"), "project.godot must not reference the stale Acts_NEW directory")


func test_stale_acts_new_removed_from_project() -> void:
	var dirs := DirAccess.open("res://Dialogue").get_directories()
	assert_false(Array(dirs).has("Acts_NEW"), "stale res://Dialogue/Acts_NEW must be removed")


func test_every_timeline_file_exists_in_acts() -> void:
	for name in TIMELINES:
		assert_true(FileAccess.file_exists(ACTS_DIR + name + ".dtl"), "%s.dtl exists in Dialogue/Acts" % name)


func test_dtl_directory_keys_are_plain_and_point_to_acts() -> void:
	var text := _project_godot()
	# each act5 key must map to the maintained Acts/ path, never Acts_NEW
	for route in ["act5_bad", "act5_good", "act5_neutral"]:
		var expected := '"%s": "res://Dialogue/Acts/%s.dtl"' % [route, route]
		assert_true(text.contains(expected), "dtl_directory routes %s to Dialogue/Acts/" % route)


func test_every_jump_identifier_resolves_at_runtime() -> void:
	# The real guarantee: every plain identifier the router jumps to resolves to a
	# timeline resource at runtime (GameFlow registers them on boot, so this holds
	# even if the on-disk directory drifted to folder-prefixed keys).
	for id in ["act1", "act2", "act3", "act4", "act5_router", "act5_good", "act5_neutral", "act5_bad", "act_ending"]:
		var res := DialogicResourceUtil.get_timeline_resource(id)
		assert_not_null(res, "jump target '%s' resolves to a timeline resource" % id)
		if res != null:
			assert_true(res.resource_path.begins_with(ACTS_DIR), "'%s' resolves under Dialogue/Acts (%s)" % [id, res.resource_path])


func test_routed_act5_is_the_maintained_copy() -> void:
	# the maintained Act 5 has expression swaps; the stale copy had none.
	for route in ["act5_good", "act5_bad"]:
		var body := FileAccess.get_file_as_string(ACTS_DIR + route + ".dtl")
		assert_true(body.contains("update "), "%s is the maintained copy (has expression swaps)" % route)
		var re := RegEx.create_from_string("(?m)^\\s*[A-Z][a-z]+:\\s*'?s[ .]")
		assert_null(re.search(body), "%s has no possessive-mis-split speaker bug" % route)
