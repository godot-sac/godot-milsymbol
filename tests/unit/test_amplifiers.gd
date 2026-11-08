extends GutTest
## Text amplifier fields and direction of movement (MilSymbolAmplifiers) outside the golden comparison:
## string widths, option handling, path mode, nodes and the tactical map.

const FRIEND_INF := "10031000001211000000"


func test_string_width_matches_milsymbol_table() -> void:
	# milsymbol: W is 32 units at size 30, unknown characters 28.5, plus the given space.
	assert_almost_eq(MilSymbolAmplifiers.string_width("W", 30, 0), 32.0, 0.0001)
	assert_almost_eq(MilSymbolAmplifiers.string_width("Ş", 30, 0), 28.5, 0.0001)
	assert_almost_eq(MilSymbolAmplifiers.string_width("A/1", 40, 20), 40.0 / 30.0 * (23 + 10 + 19) + 20, 0.0001)
	assert_eq(MilSymbolAmplifiers.string_width("", 40, 20), 0.0, "empty text takes no room")


func test_option_follows_javascript_truthiness() -> void:
	var options := {"a": "", "b": 0, "c": false, "d": null, "e": "0", "f": 12, "g": 12.5, "h": 3.0}
	for key in ["a", "b", "c", "d", "missing"]:
		assert_eq(MilSymbolAmplifiers.option(options, key), "", key)
	assert_eq(MilSymbolAmplifiers.option(options, "e"), "0")
	assert_eq(MilSymbolAmplifiers.option(options, "f"), "12")
	assert_eq(MilSymbolAmplifiers.option(options, "g"), "12.5")
	assert_eq(MilSymbolAmplifiers.option(options, "h"), "3")


func test_fields_widen_the_symbol_and_keep_the_anchor_on_the_frame() -> void:
	var plain := MilSymbol.render(FRIEND_INF, {"size": 100})
	var with_text := MilSymbol.render(FRIEND_INF, {"size": 100, "uniqueDesignation": "A/1-32",
			"higherFormation": "3 BDE"})
	assert_gt(with_text.size.x, plain.size.x + 200, "text on both sides")
	assert_true(with_text.valid)
	# The anchor stays the frame centre: left text width + half the frame.
	var frame_left := with_text.anchor.x - 75.0
	assert_almost_eq(frame_left - 20.0 - 4.0, MilSymbolAmplifiers.string_width("A/1-32", 40, 0), 0.01)


func test_info_fields_off_and_empty_values_draw_nothing() -> void:
	var plain := MilSymbol.render(FRIEND_INF)
	assert_eq(MilSymbol.render(FRIEND_INF, {"uniqueDesignation": "X", "infoFields": false}).svg, plain.svg)
	assert_eq(MilSymbol.render(FRIEND_INF, {"uniqueDesignation": "", "speed": 0}).svg, plain.svg)


func test_path_mode_text_is_outlines_and_outline_strokes_are_not_scaled_away() -> void:
	var render := MilSymbol.render(FRIEND_INF, {"uniqueDesignation": "A", "outlineWidth": 3})
	assert_false(render.svg.contains("<text"), "path mode draws glyph outlines")
	assert_true(render.svg.contains("milsymbol-textfields"))
	# The outline copy sits in a scale group of about 0.02: its stroke must be compensated (10 / 0.0195 ~ 512).
	var regex := RegEx.create_from_string('stroke-width="([0-9.]+)"[^>]*stroke="rgb\\(239, 239, 239\\)"[^>]*class="milsymbol-textfields"')
	var found := regex.search(render.svg)
	assert_not_null(found, "outline of the text field")
	if found:
		assert_gt(float(found.get_string(1)), 100.0)
	assert_not_null(render.to_image())


func test_direction_arrow_grows_the_symbol_in_its_direction() -> void:
	var plain := MilSymbol.render(FRIEND_INF, {"size": 100})
	var east := MilSymbol.render(FRIEND_INF, {"size": 100, "direction": 90})
	# The tip is one frame height (95) east of the stem, 20 beyond the frame's right edge.
	assert_almost_eq(east.size.x, plain.size.x + 20, 0.01, "arrow points east of the stem")
	assert_gt(east.size.y, plain.size.y + 80, "stem below the frame")
	assert_eq(east.anchor.x, plain.anchor.x, "nothing added on the left")
	var empty_direction := MilSymbol.render(FRIEND_INF, {"size": 100, "direction": ""})
	assert_eq(empty_direction.svg, plain.svg, "an empty string is no direction")


func test_sprite_amplifiers_refresh_the_texture() -> void:
	var sprite := MilSymbolSprite2D.new()
	sprite.sidc = FRIEND_INF
	add_child_autofree(sprite)
	var plain_width := sprite.texture.get_width()
	sprite.amplifiers = {"uniqueDesignation": "A/1-32"}
	sprite.refresh()
	assert_gt(sprite.texture.get_width(), plain_width)
	assert_eq(sprite.offset, -sprite.symbol.anchor, "the node origin stays the anchor")


func test_map_unit_amplifiers() -> void:
	var map := TacticalMap2D.new()
	map.size = Vector2(800, 600)
	add_child_autofree(map)
	map.center_on(41.02, 29.05, 50.0)
	map.add_unit("a", FRIEND_INF, 41.02, 29.05)
	var plain: Rect2 = map._units["a"].entry.bounds
	map.set_unit_amplifiers("a", {"uniqueDesignation": "A/1-32", "direction": 45})
	var with_text: Rect2 = map._units["a"].entry.bounds
	assert_gt(with_text.size.x, plain.size.x)
	assert_eq(map.get_unit_amplifiers("a"), {"uniqueDesignation": "A/1-32", "direction": 45})
	map.set_unit_sidc("a", "10061000001211000000")
	assert_gt((map._units["a"].entry.bounds as Rect2).size.x, plain.size.x, "amplifiers survive a SIDC change")
	map.set_unit_amplifiers("a", {})
	map.add_unit("b", "10061000001211000000", 41.0, 29.0)
	assert_eq((map._units["a"].entry.bounds as Rect2).size, (map._units["b"].entry.bounds as Rect2).size,
			"no amplifiers: the plain symbol")
