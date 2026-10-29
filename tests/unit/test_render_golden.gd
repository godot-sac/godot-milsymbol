extends GutTest
## Compares MilSymbol.render() output with milsymbol's reference SVGs in tests/golden/.

const SvgCompare = preload("res://tests/helpers/svg_compare.gd")
const GOLDEN_DIR := "res://tests/golden/"

## Golden ids the renderer is expected to match so far. Grows with each phase.
const SUPPORTED_PREFIX_FRAME_ONLY := "0000000000"  # entity + modifiers: frame only

var _manifest: Array = []


func before_all() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_DIR + "manifest.json"))
	if parsed is Array:
		_manifest = parsed


func _supported_entries() -> Array:
	return _manifest.filter(func(entry): return entry.sidc.substr(10) == SUPPORTED_PREFIX_FRAME_ONLY)


func test_there_are_frame_only_goldens() -> void:
	assert_gt(_supported_entries().size(), 20)


func test_svg_matches_golden() -> void:
	for entry in _supported_entries():
		var expected := FileAccess.get_file_as_string(GOLDEN_DIR + entry.id + ".svg")
		var render := MilSymbol.render(entry.sidc, entry.options)
		var problems := SvgCompare.diff(expected, render.svg)
		assert_eq(problems.size(), 0, "%s (%s):\n%s\n%s" % [entry.id, entry.description,
				"\n".join(problems), render.svg])


func test_size_and_anchor_match_manifest() -> void:
	for entry in _supported_entries():
		var render := MilSymbol.render(entry.sidc, entry.options)
		assert_almost_eq(render.size, Vector2(entry.width, entry.height), Vector2(0.001, 0.001), entry.id + " size")
		assert_almost_eq(render.anchor, Vector2(entry.anchor.x, entry.anchor.y), Vector2(0.001, 0.001),
				entry.id + " anchor")
		assert_true(render.valid, entry.id + " valid")


func test_rasterized_frames_match_golden_pixels() -> void:
	for entry in _supported_entries():
		var expected := SvgCompare.rasterize(FileAccess.get_file_as_string(GOLDEN_DIR + entry.id + ".svg"))
		var actual := MilSymbol.render(entry.sidc, entry.options).to_image()
		assert_not_null(actual, entry.id)
		if actual == null:
			continue
		assert_lt(SvgCompare.pixel_mismatch_ratio(expected, actual), 0.001, entry.id)
