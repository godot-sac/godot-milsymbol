extends GutTest
## Compares MilSymbolTextLayout with the reference outlines from tools/export/text-to-path.mjs
## (tests/golden/text_layout.json).

const SvgCompare = preload("res://tests/helpers/svg_compare.gd")
const CASES_PATH := "res://tests/golden/text_layout.json"
const VIEW_BOX := Rect2(0, 0, 400, 200)
const STYLE := {"strokeWidth": 4, "styleFill": false}

var _cases: Array = []


func before_all() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CASES_PATH))
	if parsed is Array:
		_cases = parsed


func _svg_of(instructions: Array) -> String:
	return MilSymbolSvgWriter.write(instructions, STYLE, VIEW_BOX, VIEW_BOX.size)


func test_cases_are_loaded() -> void:
	assert_gt(_cases.size(), 20)


## Same outlines, same positions: only anti-aliasing of the different path structure may differ.
## The tolerance is 1% of the canvas pixels (text covers a few percent of it).
func test_layout_matches_reference_pixels() -> void:
	for entry in _cases:
		var expected := SvgCompare.rasterize(_svg_of([{"type": "path", "d": entry.d, "fill": "black"}]))
		var instruction := MilSymbolTextLayout.to_instruction(entry.instr)
		var actual := SvgCompare.rasterize(_svg_of([instruction]))
		assert_not_null(expected, "reference rasterized")
		assert_not_null(actual, "layout rasterized")
		if expected == null or actual == null:
			continue
		assert_gt(_ink(actual), 0, "layout draws something: " + str(entry.instr.text))
		var ratio := SvgCompare.pixel_mismatch_ratio(expected, actual)
		assert_lt(ratio, 0.01, "%s (%s, %s): %f" % [entry.instr.text,
				entry.instr.get("textanchor", "start"), entry.instr.get("alignmentBaseline", "-"), ratio])


func test_measure_known_width() -> void:
	var units := 2048.0  # Arimo unitsPerEm
	assert_almost_eq(MilSymbolTextLayout.measure("A", units, false), 1366.0, 0.01)
	assert_almost_eq(MilSymbolTextLayout.measure("A", units / 2.0, false), 683.0, 0.01)
	assert_gt(MilSymbolTextLayout.measure("A", 20.0, true), 0.0)


func test_measure_applies_kerning() -> void:
	var pair := MilSymbolTextLayout.measure("AV", 100.0, false)
	var separate := MilSymbolTextLayout.measure("A", 100.0, false) + MilSymbolTextLayout.measure("V", 100.0, false)
	assert_lt(pair, separate)
	assert_eq(MilSymbolTextLayout.measure("", 100.0, false), 0.0)


func test_empty_text_returns_empty_instruction() -> void:
	assert_eq(MilSymbolTextLayout.to_instruction({"type": "text", "text": ""}), {})
	assert_eq(MilSymbolTextLayout.to_instruction({"type": "text", "text": "   "}), {})
	assert_eq(MilSymbolTextLayout.to_instruction({"type": "text"}), {})


func test_unknown_character_uses_question_mark_advance_and_draws_nothing() -> void:
	var unknown := "中"
	assert_almost_eq(MilSymbolTextLayout.measure(unknown, 40.0, false),
			MilSymbolTextLayout.measure("?", 40.0, false), 0.001)
	var instruction := MilSymbolTextLayout.to_instruction({"type": "text", "text": unknown, "fontsize": 40})
	assert_eq(instruction.draw[0].draw.size(), 0)
	var mixed := MilSymbolTextLayout.to_instruction({"type": "text", "text": "A" + unknown + "B", "fontsize": 40})
	assert_eq(mixed.draw[0].draw.size(), 2)


func test_turkish_letters_have_outlines() -> void:
	for ch in ["Ş", "İ", "ğ", "ı", "Ö"]:
		var instruction := MilSymbolTextLayout.to_instruction({"type": "text", "text": ch, "fontsize": 40})
		assert_eq(instruction.draw[0].draw.size(), 1, ch)
	assert_almost_eq(MilSymbolTextLayout.measure("Ş", 40.0, false), MilSymbolTextLayout.measure("S", 40.0, false), 0.001)


func test_stroke_is_compensated_for_the_scale_group() -> void:
	var instruction := MilSymbolTextLayout.to_instruction(
			{"type": "text", "text": "A", "fontsize": 40, "stroke": "red", "strokewidth": 2, "fill": "black"})
	var factor: float = instruction.draw[0].factor
	var path: Dictionary = instruction.draw[0].draw[0].draw[0]
	assert_almost_eq(factor * float(path.non_scaling_stroke), 1.0, 0.0001)
	assert_eq(path.stroke, "red")
	assert_true(_svg_of([instruction]).contains("stroke-width=\"%s\"" % MilSymbolSvgWriter.num(2.0 / factor)))
	var plain := MilSymbolTextLayout.to_instruction({"type": "text", "text": "A", "fill": "black", "stroke": false})
	assert_false(plain.draw[0].draw[0].draw[0].has("stroke"))


func _ink(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count
