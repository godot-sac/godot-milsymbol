extends GutTest
## Every symbol of milsymbol's own test suite (2525D, 2525E, APP-6D point symbols) renders like milsymbol.
## Data: tests/golden/coverage.json (tools/export/coverage.mjs). Report: tools/coverage_report.gd.

const Coverage = preload("res://tests/helpers/coverage.gd")
const MAX_LISTED := 15

var _entries: Array = []


func before_all() -> void:
	_entries = Coverage.load_entries()


func test_coverage_set_is_loaded() -> void:
	assert_gt(_entries.size(), 5000, "run `npm run coverage` in tools/export")
	var standards := {}
	for entry in _entries:
		standards[entry.standard] = true
	assert_eq(standards.keys().size(), Coverage.STANDARDS.size())


func test_every_symbol_matches_milsymbol() -> void:
	var summary := Coverage.summarize(_entries)
	var failures: Array = summary.failures
	assert_eq(failures.size(), 0, "%d of %d symbols differ:\n%s" % [failures.size(), _entries.size(),
			"\n".join(failures.slice(0, MAX_LISTED))])
