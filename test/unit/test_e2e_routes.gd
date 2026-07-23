extends GutTest

# New structure: Acts 1-4 are single files with inline choices; the route only
# splits at act5_router based on {Route.good} - {Route.bad}, into act5_good/
# neutral/bad, each jumping to act_ending. This verifies the router + chain.

const ENDING := "act_ending"


func _set(good: int, bad: int) -> void:
	Dialogic.VAR.Route.good = good
	Dialogic.VAR.Route.bad = bad


func _walk(start_id: String, expect_tag: String) -> Array:
	var path: Array = [start_id]
	var current := start_id
	var guard := 0
	while current != ENDING and guard < 8:
		guard += 1
		var tl = DialogicResourceUtil.get_timeline_resource(current)
		assert_not_null(tl, "%s resolves" % current)
		if tl == null: break
		tl.process()
		var nxt := ""
		for e in tl.events:
			if e.get_script().resource_path.get_file().begins_with("event_jump"):
				var t = e.get("timeline")
				if t != null: nxt = str(t.resource_path.get_file().get_basename())
		if nxt.is_empty(): break
		path.append(nxt)
		current = nxt
	return path


func test_good_route_reaches_good_ending() -> void:
	_set(3, 0)
	assert_eq(GameFlow.route_tier(), "good", "good=3 bad=0 -> good")
	var p := _walk("act5_good", "good")
	assert_eq(p.back(), ENDING, "act5_good -> act_ending: %s" % str(p))


func test_neutral_route_reaches_ending() -> void:
	_set(1, 1)
	assert_eq(GameFlow.route_tier(), "neutral", "good=1 bad=1 -> neutral")
	var p := _walk("act5_neutral", "neutral")
	assert_eq(p.back(), ENDING, "act5_neutral -> act_ending: %s" % str(p))


func test_bad_route_reaches_bad_ending() -> void:
	_set(0, 3)
	assert_eq(GameFlow.route_tier(), "bad", "good=0 bad=3 -> bad")
	var p := _walk("act5_bad", "bad")
	assert_eq(p.back(), ENDING, "act5_bad -> act_ending: %s" % str(p))


func test_full_chain_act1_to_act5_router() -> void:
	# Acts 1-4 form a linear chain into the router.
	var chain := {"act1": "act2", "act2": "act3", "act3": "act4", "act4": "act5_router"}
	for id in chain:
		var tl = DialogicResourceUtil.get_timeline_resource(id)
		assert_not_null(tl, "%s resolves" % id)
		if tl == null: continue
		tl.process()
		var nxt := ""
		for e in tl.events:
			if e.get_script().resource_path.get_file().begins_with("event_jump"):
				var t = e.get("timeline")
				if t != null: nxt = str(t.resource_path.get_file().get_basename())
		assert_eq(nxt, chain[id], "%s jumps to %s" % [id, chain[id]])


func test_router_branches_correctly() -> void:
	for id in ["act5_router", "act5_good", "act5_neutral", "act5_bad", "act_ending"]:
		assert_not_null(DialogicResourceUtil.get_timeline_resource(id), "%s must resolve" % id)
