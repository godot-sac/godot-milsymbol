extends RefCounted
## Compares MilSymbol.render() with milsymbol on the symbol lists of milsymbol's own test suite
## (tests/golden/coverage.json, written by tools/export/coverage.mjs) and summarizes the result.

const SvgCompare = preload("res://tests/helpers/svg_compare.gd")
const COVERAGE_FILE := "res://tests/golden/coverage.json"
const STANDARDS := ["2525D", "2525E", "APP-6D"]
const KIND_NAMES := {"main": "main icons", "m1": "modifier 1", "m2": "modifier 2"}


static func load_entries() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(COVERAGE_FILE))
	return parsed if parsed is Array else []


## Differences between milsymbol's rendering of `entry` and ours; empty when they match.
static func compare(entry: Dictionary) -> PackedStringArray:
	var render := MilSymbol.render(entry.sidc, entry.options.merged({"textMode": "svg", "milsymbolQuirks": true}))
	var problems := SvgCompare.diff(entry.svg, render.svg)
	if render.valid != entry.valid:
		problems.append("valid %s != %s" % [render.valid, entry.valid])
	if not render.size.is_equal_approx(Vector2(entry.width, entry.height)):
		problems.append("size %s != (%s, %s)" % [render.size, entry.width, entry.height])
	if not render.anchor.is_equal_approx(Vector2(entry.anchor.x, entry.anchor.y)):
		problems.append("anchor %s != (%s, %s)" % [render.anchor, entry.anchor.x, entry.anchor.y])
	return problems


## {standard: {set: {"name": String, "total": int, "valid": int, "match": int}}} plus "failures" (Array).
static func summarize(entries: Array, set_names: Dictionary = {}) -> Dictionary:
	var result := {"failures": []}
	for standard in STANDARDS:
		result[standard] = {}
	for entry in entries:
		var by_set: Dictionary = result[entry.standard]
		if not by_set.has(entry.set):
			by_set[entry.set] = {"name": set_names.get(entry.set, ""), "total": 0, "valid": 0, "match": 0}
		var row: Dictionary = by_set[entry.set]
		row.total += 1
		if entry.valid:
			row.valid += 1
		var problems := compare(entry)
		if problems.is_empty():
			row.match += 1
		else:
			result.failures.append("%s %s: %s" % [entry.standard, entry.sidc, "; ".join(problems.slice(0, 3))])
	return result
