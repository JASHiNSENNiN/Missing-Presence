extends GutTest


func before_all() -> void:
	GameFlow._heal_maya_portraits()

const MAINS := ["Maya", "Ethan", "Jennifer", "Ricardo"]


func test_all_main_characters_resolve() -> void:
	for c in MAINS:
		assert_not_null(DialogicResourceUtil.get_character_resource(c), "character %s must resolve" % c)


func test_maya_has_full_expression_set() -> void:
	var maya = DialogicResourceUtil.get_character_resource("Maya")
	assert_gte(maya.portraits.size(), 13, "Maya should have >= 13 expressions")
	for e in ["neutral", "glad", "smile", "soft", "teary", "frown", "phone"]:
		assert_true(maya.portraits.has(e), "Maya must have '%s'" % e)


func test_ethan_has_grease_sprites() -> void:
	var ethan = DialogicResourceUtil.get_character_resource("Ethan")
	assert_true(ethan.portraits.has("grease_neutral"), "Ethan needs grease sprites for Act 3 shop")
	assert_true(ethan.portraits.has("teary"), "Ethan needs teary")


func test_character_portrait_images_exist() -> void:
	for c in MAINS:
		var res = DialogicResourceUtil.get_character_resource(c)
		for key in res.portraits:
			var img: String = res.portraits[key].get("export_overrides", {}).get("image", "")
			if img != "":
				assert_true(ResourceLoader.exists(img), "%s.%s image should exist: %s" % [c, key, img])


func test_default_portrait_is_valid() -> void:
	for c in MAINS:
		var res = DialogicResourceUtil.get_character_resource(c)
		assert_true(res.portraits.has(res.default_portrait),
			"%s default_portrait '%s' must be a real portrait" % [c, res.default_portrait])
