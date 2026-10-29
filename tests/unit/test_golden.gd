extends GutTest
## Checks the golden reference set produced by tools/export/golden.mjs.
## The renderer comparison (our SVG vs golden) is added in Phase 2.

const SvgCompare = preload("res://tests/helpers/svg_compare.gd")
const GOLDEN_DIR := "res://tests/golden/"

var _manifest: Array = []


func before_all() -> void:
	var text := FileAccess.get_file_as_string(GOLDEN_DIR + "manifest.json")
	var parsed = JSON.parse_string(text)
	if parsed is Array:
		_manifest = parsed


func _read_svg(id: String) -> String:
	return FileAccess.get_file_as_string(GOLDEN_DIR + id + ".svg")


func test_manifest_is_not_empty() -> void:
	assert_gt(_manifest.size(), 0, "run `npm run golden` in tools/export")


func test_every_golden_svg_exists_and_parses() -> void:
	for entry in _manifest:
		var svg := _read_svg(entry.id)
		assert_ne(svg, "", "%s.svg missing" % entry.id)
		assert_false(SvgCompare.parse(svg).is_empty(), "%s.svg is not valid XML" % entry.id)


func test_every_golden_svg_rasterizes_at_manifest_size() -> void:
	for entry in _manifest:
		var image := SvgCompare.rasterize(_read_svg(entry.id))
		assert_not_null(image, "%s: Godot could not load the SVG" % entry.id)
		if image == null:
			continue
		# Godot rounds fractional SVG sizes to whole pixels.
		assert_almost_eq(float(image.get_width()), float(entry.width), 1.0, "%s width" % entry.id)
		assert_almost_eq(float(image.get_height()), float(entry.height), 1.0, "%s height" % entry.id)


func test_rasterized_symbols_are_not_blank() -> void:
	for entry in _manifest:
		var image := SvgCompare.rasterize(_read_svg(entry.id))
		if image == null:
			continue
		var used := image.get_used_rect()
		assert_gt(used.get_area(), image.get_width() * image.get_height() / 4,
				"%s: almost nothing was drawn" % entry.id)
