extends GutTest

var gf


func before_all() -> void:
	gf = get_node("/root/GameFlow")


func _set_route(honesty: int, affinity: int, pressure: int) -> void:
	Dialogic.VAR.Route.self_honesty = honesty
	Dialogic.VAR.Route.affinity_ethan = affinity
	Dialogic.VAR.Route.parent_pressure = pressure


func test_gameflow_exists() -> void:
	assert_not_null(gf, "GameFlow autoload should exist")
	assert_true(gf.has_method("route_score"), "GameFlow should have route_score()")
	assert_true(gf.has_method("route_tier"), "GameFlow should have route_tier()")


func test_score_formula() -> void:
	_set_route(3, 1, 0)
	assert_eq(gf.route_score(), 4, "score = honesty(3)+affinity(1)-pressure(0) = 4")
	_set_route(0, 0, 3)
	assert_eq(gf.route_score(), -3, "score = 0+0-3 = -3")
	_set_route(1, 1, 1)
	assert_eq(gf.route_score(), 1, "score = 1+1-1 = 1")


func test_good_route() -> void:
	_set_route(3, 0, 0)
	assert_eq(gf.route_tier(), "good", "score +3 => good")
	_set_route(1, 1, 0)
	assert_eq(gf.route_tier(), "good", "score +2 (threshold) => good")


func test_bad_route() -> void:
	_set_route(0, 0, 3)
	assert_eq(gf.route_tier(), "bad", "score -3 => bad")
	_set_route(0, 0, 2)
	assert_eq(gf.route_tier(), "bad", "score -2 (threshold) => bad")


func test_neutral_route() -> void:
	_set_route(1, 0, 0)
	assert_eq(gf.route_tier(), "neutral", "score +1 => neutral")
	_set_route(1, 1, 1)
	assert_eq(gf.route_tier(), "neutral", "score +1 => neutral")
	_set_route(0, 0, 1)
	assert_eq(gf.route_tier(), "neutral", "score -1 => neutral")


func test_dialogic_condition_matches_gameflow() -> void:
	_set_route(2, 0, 0)
	var good := Dialogic.Expressions.execute_condition("{Route.self_honesty} + {Route.affinity_ethan} - {Route.parent_pressure} >= 2")
	assert_true(good, "Dialogic router condition agrees with GameFlow good threshold")
	assert_eq(gf.route_tier(), "good", "GameFlow agrees")
