extends RefCounted
## Control measure test cases: one per specific geometry. Used by test_graphics.gd and
## tools/graphics_golden.gd (which writes tests/golden/graphics.json).

const LINE := [Vector2(0, 100), Vector2(200, 80), Vector2(400, 120)]
const AREA := [Vector2(0, 0), Vector2(200, 0), Vector2(220, 150), Vector2(10, 160)]
const AXIS := [Vector2(400, 100), Vector2(200, 120), Vector2(0, 100), Vector2(340, 135)]
const ARROW := [Vector2(400, 60), Vector2(200, 120), Vector2(0, 100)]
const AMP := {"T": "BLUE", "T1": "RED", "W": "0600Z", "W1": "1800Z", "H": "AT", "X": "500FT"}

# entity code, points, extra amplifiers
const CASES: Array[Array] = [
	["110100", LINE, {}], ["110200", LINE, {}], ["140300", LINE, {}], ["141000", LINE, {}], ["141100", LINE, {}],
	["140900", LINE, {}], ["140100", LINE, {}],
	["260100", LINE, {}], ["260200", LINE, {}], ["260300", LINE, {}], ["260500", LINE, {}],
	["150100", AREA, {}], ["120100", AREA, {}], ["120200", AREA, {}], ["120300", AREA, {}], ["150200", AREA, {}],
	["151300", AREA, {}], ["151700", AREA, {}],
	["240201", AREA, {}], ["240202", [Vector2(0, 50), Vector2(200, 50)], {"AM": 80.0}],
	["240203", [Vector2(100, 100)], {"AM": 60.0}],
	["240301", AREA, {}], ["240302", [Vector2(0, 50), Vector2(200, 50)], {"AM": 80.0}],
	["240303", [Vector2(100, 100)], {"AM": 60.0}],
	["240401", AREA, {}], ["240402", [Vector2(0, 50), Vector2(200, 50)], {"AM": 80.0}],
	["240403", [Vector2(100, 100)], {"AM": 60.0}],
	["151401", AXIS, {}], ["151402", AXIS, {}], ["151403", AXIS, {}], ["151404", AXIS, {}],
	["140601", ARROW, {}], ["140602", ARROW, {}], ["140603", ARROW, {}],
	["290100", LINE, {}], ["290101", LINE, {}], ["270100", AREA, {}], ["270200", AREA, {}], ["270300", AREA, {}],
	["270400", AREA, {}],
	["270707", AREA, {}], ["270800", AREA, {}], ["270801", AREA, {}],
	["330300", LINE, {}], ["330301", LINE, {}], ["330302", LINE, {}], ["330303", LINE, {}],
	["330400", LINE, {}], ["330401", LINE, {}],
	["170100", LINE, {"AM": 30.0}], ["170300", LINE, {"AM": 30.0}],
]


static func sidc(code: String, identity: String = "3", status: String = "0", echelon: String = "16",
		hq_tf_dummy: String = "0") -> String:
	return "100%s25%s%s%s%s0000" % [identity, status, hq_tf_dummy, echelon, code]


static func points_of(case: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in case[1]:
		points.append(p)
	return points


static func amplifiers_of(case: Array) -> Dictionary:
	return AMP.merged(case[2], true)


## Golden key -> SIDC for every case in three variants (friend, hostile planned, friend feint).
static func golden_variants() -> Dictionary:
	var result := {}
	for case in CASES:
		result["%s friend" % case[0]] = sidc(case[0])
		result["%s hostile planned" % case[0]] = sidc(case[0], "6", "1")
	for code in ["151404", "140603", "140300", "150200"]:
		result["%s feint" % code] = sidc(code, "3", "0", "16", "1")
	return result


static func case_of(code: String) -> Array:
	for case in CASES:
		if case[0] == code:
			return case
	return []
