class_name MilSymbolLegacy
extends RefCounted
## Converts letter based MIL-STD-2525C SIDCs (15 characters, e.g. "SFGPUCI----D---") to number based 2525D
## SIDCs (20 digits), so that older systems' codes can be drawn. MilSymbol.render() and MilGraphic.build()
## call it automatically.
##
## The symbol mapping comes from Esri's joint-military-symbology-xml legacy table (Apache-2.0, see
## THIRD_PARTY_NOTICES.md; data/legacy_2525c.json, written by tools/export/legacy.mjs). Symbols the table marks
## "Retired" have no 2525D equivalent and are not converted. The 2525D icon is used, which in a few cases looks
## different from the 2525C one. Country code and order of battle (characters 13-15) are not carried over.

const DATA_FILE := "res://addons/milsymbol/data/legacy_2525c.json"
const CODING_SCHEMES := "SGWIOE"
## 2525C standard identity (character 2) -> [2525D context, 2525D standard identity].
const IDENTITIES := {
	"P": ["0", "0"], "U": ["0", "1"], "A": ["0", "2"], "F": ["0", "3"], "N": ["0", "4"], "S": ["0", "5"],
	"H": ["0", "6"], "G": ["1", "0"], "W": ["1", "1"], "M": ["1", "2"], "D": ["1", "3"], "L": ["1", "4"],
	"J": ["1", "5"], "K": ["1", "6"], "O": ["0", "1"],
}
## 2525C status (character 4) -> 2525D status.
const STATUS := {"P": "0", "A": "1", "C": "2", "D": "3", "X": "4", "F": "5"}
## 2525C symbol modifier indicator (character 11) -> 2525D headquarters / task force / dummy digit.
const HQ_TF_DUMMY := {"A": "2", "B": "6", "C": "3", "D": "7", "E": "4", "F": "1", "G": "5"}
## 2525C echelon (character 12) -> 2525D amplifier.
const ECHELONS := {
	"A": "11", "B": "12", "C": "13", "D": "14", "E": "15", "F": "16", "G": "17", "H": "18", "I": "21",
	"J": "22", "K": "23", "L": "24", "M": "25", "N": "26",
}
## 2525C mobility (character 11 "M" or "N", then character 12) -> 2525D amplifier.
const MOBILITY := {
	"MO": "31", "MP": "32", "MQ": "33", "MR": "34", "MS": "35", "MT": "36", "MU": "41", "MV": "42", "MW": "37",
	"MX": "51", "MY": "52", "NS": "61", "NL": "62",
}

static var _table: Dictionary


## True for strings that look like letter based SIDCs (2525B/C, APP-6A/B structure).
static func is_letter_sidc(sidc: String) -> bool:
	if sidc.length() < 10 or sidc.substr(0, mini(20, sidc.length())).is_valid_int():
		return false
	return CODING_SCHEMES.contains(sidc.substr(0, 1).to_upper())


## 20 digit 2525D SIDC for a 2525C SIDC, or "" if it cannot be converted.
static func to_number_sidc(sidc: String) -> String:
	return convert_2525c(sidc).sidc


## Details of a conversion: {"sidc": String ("" on failure), "exact": bool (false when a more general symbol
## was used because the exact function ID is not in the table), "error": String}.
static func convert_2525c(sidc: String) -> Dictionary:
	var result := {"sidc": "", "exact": false, "error": ""}
	if not is_letter_sidc(sidc):
		result.error = "not a letter based SIDC"
		return result
	var c := sidc.to_upper().replace("*", "-").replace("_", "-").replace(" ", "-").rpad(15, "-")
	var scheme := c.substr(0, 1)
	var function_id := c.substr(4, 6)
	var mapping: Array = []
	var generalised := 0
	while mapping.is_empty():
		mapping = _lookup(scheme, c.substr(1, 1), c.substr(2, 1), function_id, c.substr(0, 10))
		if not mapping.is_empty():
			break
		# Try the parent symbol: blank the last specified character of the function ID.
		var last := function_id.length() - 1
		while last >= 0 and function_id[last] == "-":
			last -= 1
		if last < 0:
			result.error = "no 2525D equivalent for %s" % sidc
			return result
		function_id = function_id.substr(0, last) + "-".repeat(6 - last)
		generalised += 1

	var identity: Array = IDENTITIES.get(c.substr(1, 1), ["0", "1"])
	var status: String = STATUS.get(c.substr(3, 1), "0")
	var modifier := c.substr(10, 2)
	var hq_tf_dummy: String = HQ_TF_DUMMY.get(modifier.substr(0, 1), "0")
	var amplifier: String = MOBILITY.get(modifier, ECHELONS.get(modifier.substr(1, 1), "00"))
	if scheme == "W":
		identity = ["0", "0"]
		hq_tf_dummy = "0"
		amplifier = "00"
	result.sidc = "10%s%s%s%s%s%s%s%s%s" % [identity[0], identity[1], mapping[0], status, hq_tf_dummy, amplifier,
			mapping[1], mapping[2], mapping[3]]
	result.exact = generalised == 0
	return result


static func _lookup(scheme: String, identity: String, dimension: String, function_id: String,
		first_ten: String) -> Array:
	var table := _data()
	# A few graphics are keyed for one affiliation (e.g. "GHGPGLC---", hostile line of contact).
	for key in ["%s%s%sP%s" % [scheme, identity, dimension, function_id], "%s*%sP%s" % [scheme, dimension, function_id]]:
		if table.has(key):
			return table[key]
	# Meteorological symbols are keyed by their literal first ten characters.
	if scheme == "W":
		var literal := first_ten.substr(0, 4) + function_id
		if table.has(literal):
			return table[literal]
	return []


static func _data() -> Dictionary:
	if _table.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
		_table = parsed if parsed is Dictionary else {}
		if _table.is_empty():
			push_error("milsymbol: could not load %s" % DATA_FILE)
	return _table
