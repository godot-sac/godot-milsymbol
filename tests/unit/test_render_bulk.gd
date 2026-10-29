extends GutTest
## Compares MilSymbol.render() with milsymbol for every exported icon (tests/golden/bulk_icons.json,
## written by tools/export/golden-bulk.mjs). Structural SVG diff only; pixel checks are in
## test_render_golden.gd.

const SvgCompare = preload("res://tests/helpers/svg_compare.gd")
const BULK_FILE := "res://tests/golden/bulk_icons.json"
const MAX_LISTED := 15

var _entries: Array = []


func before_all() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(BULK_FILE))
	if parsed is Array:
		_entries = parsed


func _label(entry: Dictionary) -> String:
	return entry.sidc + ("" if entry.options.is_empty() else " " + JSON.stringify(entry.options))


func test_bulk_set_is_loaded() -> void:
	assert_gt(_entries.size(), 1000, "run `npm run golden:bulk` in tools/export")


func test_every_icon_matches_milsymbol() -> void:
	var failures := PackedStringArray()
	var failed := 0
	for entry in _entries:
		var render := MilSymbol.render(entry.sidc, entry.options.merged({"textMode": "svg"}))
		var problems := SvgCompare.diff(entry.svg, render.svg)
		if render.valid != entry.valid:
			problems.append("valid %s != %s" % [render.valid, entry.valid])
		if not render.size.is_equal_approx(Vector2(entry.width, entry.height)):
			problems.append("size %s != (%s, %s)" % [render.size, entry.width, entry.height])
		if not render.anchor.is_equal_approx(Vector2(entry.anchor.x, entry.anchor.y)):
			problems.append("anchor %s != (%s, %s)" % [render.anchor, entry.anchor.x, entry.anchor.y])
		if problems.is_empty():
			continue
		failed += 1
		if failures.size() < MAX_LISTED:
			failures.append("%s: %s" % [_label(entry), "; ".join(problems.slice(0, 3))])
	assert_eq(failed, 0, "%d of %d symbols differ:\n%s" % [failed, _entries.size(), "\n".join(failures)])


func test_text_labels_render_as_paths_by_default() -> void:
	# Liaison (LO) is a text-only icon; ThorVG ignores <text>, so the default mode must use outlines.
	var sidc := "10031000001105000000"
	var as_path := MilSymbol.render(sidc)
	var as_text := MilSymbol.render(sidc, {"textMode": "svg"})
	assert_false(as_path.svg.contains("<text"))
	assert_true(as_text.svg.contains("<text"))
	var frame_only := SvgCompare.rasterize(MilSymbol.render("10031000000000000000").svg)
	var ratio := SvgCompare.pixel_mismatch_ratio(frame_only, as_path.to_image())
	assert_gt(ratio, 0.03, "the LO label should cover part of the frame")
