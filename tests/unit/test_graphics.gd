extends GutTest
## Multipoint control measures (MilGraphic): geometry rules and SVG regression goldens.

const Cases = preload("res://tests/helpers/graphics_cases.gd")
const SvgCompare = preload("res://tests/helpers/svg_compare.gd")
const GOLDEN_FILE := "res://tests/golden/graphics.json"


func _build(code: String, points: Array, amplifiers: Dictionary = {}, identity: String = "3",
		status: String = "0", echelon: String = "16", hq_tf_dummy: String = "0") -> MilGraphicShape:
	var packed := PackedVector2Array()
	for p in points:
		packed.append(p)
	return MilGraphic.build(Cases.sidc(code, identity, status, echelon, hq_tf_dummy), packed, amplifiers)


func _of_type(shape: MilGraphicShape, type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for primitive in shape.primitives:
		if primitive.type == type:
			result.append(primitive)
	return result


func _text(shape: MilGraphicShape, text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for primitive in _of_type(shape, "text"):
		if primitive.text == text:
			result.append(primitive)
	return result


func test_every_case_has_its_own_geometry() -> void:
	for case in Cases.CASES:
		var shape := MilGraphic.build(Cases.sidc(case[0]), Cases.points_of(case), Cases.amplifiers_of(case))
		assert_true(shape.valid, "%s: %s" % [case[0], shape.errors])
		assert_true(shape.specific, "%s should not fall back to a generic shape" % case[0])
		assert_false(shape.primitives.is_empty(), case[0])
		assert_ne(shape.name, "", "%s has a name from the standard's table" % case[0])


func test_table_lists_2525d_2525e_and_app6d() -> void:
	var table := MilGraphic.table()
	assert_gt(table.size(), 300)
	for code in ["110100", "140300", "151404", "240301", "260100"]:
		assert_true(table[code].has("D") and table[code].has("E") and table[code].has("A"), code)
	assert_eq(table["140104"].get("A"), "line", "APP-6D FLOT subtype")
	assert_false(table["140104"].has("D"), "2525D Ch1 has no FLOT subtypes")


func test_is_specific() -> void:
	assert_true(MilGraphic.is_specific("140300"))
	assert_true(MilGraphic.is_specific("151403"))
	assert_true(MilGraphic.is_specific("240303"))
	assert_false(MilGraphic.is_specific("110300"), "engineer work line is generic")
	assert_false(MilGraphic.is_specific("999900"))


func test_invalid_input() -> void:
	assert_false(MilGraphic.build("10031000001211000000", PackedVector2Array([Vector2.ZERO, Vector2.ONE])).valid,
			"land unit is not a control measure")
	assert_false(MilGraphic.build("ABC", PackedVector2Array()).valid)
	assert_false(_build("140300", [Vector2(0, 0)]).valid, "a line needs two points")
	assert_false(_build("140300", [Vector2(5, 5), Vector2(5, 5)]).valid, "duplicate points do not count")
	assert_false(_build("150200", [Vector2(0, 0), Vector2(10, 0)]).valid, "an area needs three points")
	assert_false(_build("240302", [Vector2(0, 0), Vector2(10, 0)]).valid, "rectangular area needs AM")
	assert_false(_build("999900", [Vector2(0, 0), Vector2(10, 0)]).valid, "unknown code")


func test_generic_fallback_for_codes_without_own_geometry() -> void:
	var shape := _build("110300", [Vector2(0, 0), Vector2(100, 0)], {"T": "EWL"})  # engineer work line
	assert_true(shape.valid)
	assert_false(shape.specific)
	assert_eq(_text(shape, "EWL").size(), 1)


func test_planned_status_dashes_the_outline_but_not_arrowheads() -> void:
	var line := _build("140300", Cases.LINE, {}, "3", "1")
	assert_true(line.dashed)
	assert_true(_of_type(line, "line")[0].dashed)
	var arrow := _build("140603", Cases.ARROW, {}, "3", "1")
	var lines := _of_type(arrow, "line")
	assert_false(lines[0].dashed, "arrowhead stays solid")
	assert_true(lines[1].dashed, "shaft is dashed")


func test_colour_roles() -> void:
	assert_eq(_build("140300", Cases.LINE).color_role, "friend")
	assert_eq(_build("140300", Cases.LINE, {}, "6").color_role, "hostile")
	assert_eq(_build("140300", Cases.LINE, {}, "4").color_role, "neutral")
	assert_eq(_build("140300", Cases.LINE, {}, "1").color_role, "unknown")
	assert_eq(_build("290100", Cases.LINE, {}, "6").color_role, "obstacle", "obstacles are green for everyone")
	assert_eq(_build("270800", Cases.AREA, {}, "3").color_role, "obstacle")


func test_app6d_subtypes_use_identity_and_status_rules() -> void:
	var enemy_suspected := _build("140104", Cases.LINE)  # FLOT, enemy suspected or templated
	assert_eq(enemy_suspected.color_role, "hostile")
	assert_true(enemy_suspected.dashed)
	assert_eq(_text(enemy_suspected, "ENY").size(), 2)
	var feint := _build("151406", Cases.AXIS)
	var plain := _build("151404", Cases.AXIS)
	assert_eq(_of_type(feint, "line").size(), _of_type(plain, "line").size() + 1, "feint adds a dashed ^")


func test_boundary_echelon_and_labels() -> void:
	var shape := _build("110100", [Vector2(0, 100), Vector2(400, 100)], {"T": "1 BDE", "T1": "2 BDE"}, "3", "0", "16")
	assert_eq(_of_type(shape, "line").size(), 2, "the line is broken around the echelon")
	var echelon := _text(shape, "II")
	assert_eq(echelon.size(), 1, "battalion")
	assert_almost_eq(echelon[0].position, Vector2(200, 100), Vector2(0.01, 0.01))
	assert_lt(_text(shape, "1 BDE")[0].position.y, 100.0, "T above")
	assert_gt(_text(shape, "2 BDE")[0].position.y, 100.0, "T1 below")
	# Right-to-left lines keep the text upright.
	var reversed := _build("110100", [Vector2(400, 100), Vector2(0, 100)], {"T": "1 BDE"})
	assert_almost_eq(_text(reversed, "1 BDE")[0].angle, 0.0, 0.0001)


func test_phase_line_labels_sit_past_both_ends() -> void:
	var shape := _build("140300", [Vector2(0, 0), Vector2(300, 0)], {"T": "BLUE"})
	var labels := _text(shape, "PL BLUE")
	assert_eq(labels.size(), 2)
	var xs := [labels[0].position.x, labels[1].position.x]
	xs.sort()
	assert_lt(xs[0], 0.0)
	assert_gt(xs[1], 300.0)


func test_flot_scallops_bulge_left_of_the_drawing_direction() -> void:
	var shape := _build("140100", [Vector2(0, 0), Vector2(200, 0)])
	var points: PackedVector2Array = _of_type(shape, "line")[0].points
	assert_gt(points.size(), 50)
	for p in points:
		assert_true(p.y <= 0.001, "east-going line: left is up (negative y)")
	var back := _build("140100", [Vector2(200, 0), Vector2(0, 0)])
	for p in _of_type(back, "line")[0].points:
		assert_true(p.y >= -0.001, "west-going line: left is down")


func test_obstacle_belt_teeth_point_out_and_restricted_zone_teeth_in() -> void:
	for ring in [Cases.AREA, Cases.AREA.duplicate()]:
		var polygon := PackedVector2Array(ring)
		if ring != Cases.AREA:
			polygon.reverse()
		var belt: PackedVector2Array = _of_type(_build("270100", polygon), "line")[0].points
		var zone: PackedVector2Array = _of_type(_build("270400", polygon), "line")[0].points
		var belt_inside := 0
		var zone_inside := 0
		for p in belt:
			belt_inside += 1 if _strictly_inside(p, polygon) else 0
		for p in zone:
			zone_inside += 1 if _strictly_inside(p, polygon) else 0
		assert_eq(belt_inside, 0, "belt teeth are outside")
		assert_gt(zone_inside, 20, "restricted zone teeth are inside")


func _strictly_inside(p: Vector2, polygon: PackedVector2Array) -> bool:
	if not Geometry2D.is_point_in_polygon(p, polygon):
		return false
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.5:
			return false
	return true


func test_nfa_hatch_stays_inside_the_area() -> void:
	var polygon := PackedVector2Array(Cases.AREA)
	var shape := _build("240301", Cases.AREA)
	var hatch := _of_type(shape, "line").slice(1)
	assert_gt(hatch.size(), 10)
	for line in hatch:
		var middle: Vector2 = (line.points[0] + line.points[1]) / 2.0
		assert_true(Geometry2D.is_point_in_polygon(middle, polygon), str(middle))
	assert_true(_text(shape, "NFA")[0].get("boxed", false))
	assert_eq(_of_type(_build("240201", Cases.AREA), "line").size(), 1, "FFA has no hatching")


func test_rectangular_and_circular_fire_areas() -> void:
	var rect := _build("240302", [Vector2(0, 50), Vector2(200, 50)], {"AM": 80.0})
	var outline: PackedVector2Array = _of_type(rect, "line")[0].points
	assert_eq(outline.size(), 4)
	var box := Rect2(outline[0], Vector2.ZERO)
	for p in outline:
		box = box.expand(p)
	assert_almost_eq(box.size, Vector2(200, 80), Vector2(0.01, 0.01))
	var circle := _build("240303", [Vector2(100, 100)], {"AM": 60.0})
	for p in _of_type(circle, "line")[0].points:
		assert_almost_eq(p.distance_to(Vector2(100, 100)), 60.0, 0.01)


func test_axis_of_advance_tip_width_and_main_attack() -> void:
	var support := _build("151404", Cases.AXIS)
	var outline: PackedVector2Array = _of_type(support, "line")[0].points
	assert_true(outline.has(Cases.AXIS[0]), "the first point is the arrow tip")
	# The width point lies on the arrowhead edge: its distance from the axis is the half width of the head.
	var tip: Vector2 = Cases.AXIS[0]
	var direction: Vector2 = (tip - Cases.AXIS[1]).normalized()
	var normal := Vector2(direction.y, -direction.x)
	var half := absf((Cases.AXIS[3] - tip).dot(normal))
	var head_length: float = (tip - Cases.AXIS[3]).dot(direction)
	var widest := 0.0
	for p in outline:
		if (tip - p).dot(direction) <= head_length + 0.01:
			widest = maxf(widest, absf((p - tip).dot(normal)))
	assert_almost_eq(widest, half, 0.5)
	var main := _build("151403", Cases.AXIS)
	assert_eq(_of_type(main, "line").size(), _of_type(support, "line").size() + 1, "main attack closes the head")
	var aviation := _build("151401", Cases.AXIS)
	assert_eq(_of_type(aviation, "line").size(), 3, "outline + two bow-tie bars")


func test_direction_of_attack_main_has_two_heads() -> void:
	assert_eq(_of_type(_build("140603", Cases.ARROW), "line").size(), 2)
	assert_eq(_of_type(_build("140602", Cases.ARROW), "line").size(), 5)
	assert_eq(_of_type(_build("140601", Cases.ARROW), "line").size(), 3, "aviation adds a bow tie")


func test_minefield_carries_a_mine_symbol() -> void:
	var shape := _build("270800", Cases.AREA)
	var symbols := _of_type(shape, "symbol")
	assert_eq(symbols.size(), 1)
	assert_true(MilSymbol.render(symbols[0].sidc).valid)
	assert_eq(_text(shape, "M").size(), 4)


func test_supply_route_arrows() -> void:
	var line := [Vector2(0, 0), Vector2(300, 0)]
	assert_eq(_of_type(_build("330300", line), "line").size(), 1)
	assert_eq(_of_type(_build("330301", line), "line").size(), 3, "one way: line + arrow + head")
	assert_eq(_of_type(_build("330302", line), "line").size(), 5, "two way: two arrows")
	assert_eq(_of_type(_build("330303", line), "line").size(), 4, "alternating: heads at both ends")


func test_dash_polyline_keeps_the_pattern_across_vertices() -> void:
	var dashes := MilGraphicRenderer.dash_polyline(PackedVector2Array([Vector2(0, 0), Vector2(15, 0), Vector2(15, 25)]), 5.0)
	var drawn := 0.0
	for dash in dashes:
		for i in range(1, dash.size()):
			drawn += dash[i - 1].distance_to(dash[i])
	assert_almost_eq(drawn, 20.0, 0.01, "4 dashes of 5 in a 40 long line")
	assert_eq(dashes.size(), 4)


func test_svg_matches_goldens() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_FILE))
	assert_true(parsed is Dictionary, "run tools/graphics_golden.gd")
	if not parsed is Dictionary:
		return
	var variants := Cases.golden_variants()
	assert_eq(parsed.size(), variants.size())
	var failures := PackedStringArray()
	for key in variants:
		var case := Cases.case_of(key.split(" ")[0])
		var svg := MilGraphicRenderer.to_svg(MilGraphic.build(variants[key], Cases.points_of(case),
				Cases.amplifiers_of(case)))
		var problems := SvgCompare.diff(parsed.get(key, ""), svg)
		if not problems.is_empty():
			failures.append("%s: %s" % [key, "; ".join(problems.slice(0, 3))])
	assert_eq(failures.size(), 0, "\n".join(failures.slice(0, 10)))


func test_graphic_node_draws_its_shape() -> void:
	var node := MilGraphic2D.new()
	node.sidc = Cases.sidc("140300")
	node.points = PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	node.amplifiers = {"T": "RED"}
	add_child_autofree(node)
	assert_true(node.shape.valid)
	assert_eq(_text(node.shape, "PL RED").size(), 2)
