class_name MilSymbolSidc
extends RefCounted
## Decodes number based (2525D/E, APP-6D) SIDCs into milsymbol's metadata dictionary.
## Port of milsymbol src/ms/symbol/getmetadata.js and src/numbersidc/metadata.js.

const CONTEXT := ["Reality", "Exercise", "Simulation"]
const STATUS := ["Present", "Planned", "FullyCapable", "Damaged", "Destroyed", "FullToCapacity"]
const ECHELON_MOBILITY := {
	11: "Team/Crew",
	12: "Squad",
	13: "Section",
	14: "Platoon/detachment",
	15: "Company/battery/troop",
	16: "Battalion/squadron",
	17: "Regiment/group",
	18: "Brigade",
	21: "Division",
	22: "Corps/MEF",
	23: "Army",
	24: "Army Group/front",
	25: "Region/Theater",
	26: "Command",
	31: "Wheeled limited cross country",
	32: "Wheeled cross country",
	33: "Tracked",
	34: "Wheeled and tracked combination",
	35: "Towed",
	36: "Rail",
	37: "Pack animals",
	41: "Over snow (prime mover)",
	42: "Sled",
	51: "Barge",
	52: "Amphibious",
	61: "Short towed array",
	62: "Long towed Array",
	71: "Leader Individual",
	72: "Deputy Individual",
}
const AFFILIATION_BY_IDENTITY := {
	"0": "Unknown",
	"1": "Unknown",
	"2": "Friend",
	"3": "Friend",
	"4": "Neutral",
	"5": "Hostile",
	"6": "Hostile",
}
const DIMENSION_BY_SYMBOL_SET := {
	"00": "Sea",
	"01": "Air",
	"02": "Air",
	"05": "Air",
	"06": "Air",
	"10": "Ground",
	"11": "Ground",
	"12": "Ground",
	"15": "Ground",
	"20": "Ground",
	"30": "Sea",
	"35": "Subsurface",
	"36": "Subsurface",
	"39": "Subsurface",
	"40": "Ground",
	"50": "Air",
	"51": "Air",
	"52": "Ground",
	"53": "Sea",
	"54": "Subsurface",
	"60": "Ground",
}


## Returns true if the string looks like a number based SIDC (milsymbol accepts 20 to 30 digits).
static func is_number_sidc(sidc: String) -> bool:
	return sidc.length() >= 20 and sidc.substr(0, 20).is_valid_int()


## Decodes a SIDC. `style` is the resolved style dictionary (see MilSymbol.STYLE_DEFAULTS).
## `dash_arrays` is {pending, anticipated, feintDummy}.
static func decode(sidc: String, style: Dictionary, dash_arrays: Dictionary) -> Dictionary:
	var metadata := {
		"activity": false,
		"affiliation": "undefined",
		"baseAffilation": "",
		"baseDimension": "",
		"civilian": false,
		"condition": "",
		"context": CONTEXT[0],
		"dimension": "undefined",
		"dimensionUnknown": false,
		"echelon": "",
		"faker": false,
		"feintDummy": false,
		"fill": style.fill,
		"frame": style.frame,
		"functionid": "",
		"headquarters": false,
		"installation": false,
		"joker": false,
		"mobility": "",
		"notpresent": "",
		"numberSIDC": false,
		"space": false,
		"STD2525": style.standard != "APP6",
		"taskForce": false,
		"unit": false,
	}
	if style.monoColor != "":
		metadata.fill = false
	sidc = sidc.replace("*", "-").replace(" ", "")
	metadata.numberSIDC = is_number_sidc(sidc)
	if metadata.numberSIDC:
		_decode_number(sidc, metadata, dash_arrays, style)
	return metadata


static func _decode_number(sidc: String, metadata: Dictionary, dash_arrays: Dictionary, style: Dictionary) -> void:
	var version := sidc.substr(0, 2)
	var identity1 := sidc.substr(2, 1)
	var identity2 := sidc.substr(3, 1)
	var symbol_set := sidc.substr(4, 2)
	var status := sidc.substr(6, 1)
	var hq_tf_dummy := sidc.substr(7, 1)
	var echelon_mobility := sidc.substr(8, 2).to_int()
	var frame_shape := sidc.substr(22, 1) if sidc.length() > 22 else "0"
	var functionid := sidc.substr(10, 10)
	var entity := functionid.substr(0, 6)

	if version in ["10", "11", "12"]:
		metadata.edition = "D"
	if version in ["13", "14"]:
		metadata.edition = "E"
	if version == "13" and identity2 == "5":
		metadata.suspect = true

	metadata.functionid = functionid
	metadata._modifier1 = (sidc.substr(20, 1) if sidc.length() > 20 else "0") + functionid.substr(6, 2)
	metadata._modifier2 = (sidc.substr(21, 1) if sidc.length() > 21 else "0") + functionid.substr(8, 2)

	var context_index := identity1.to_int()
	metadata.context = CONTEXT[context_index] if context_index < CONTEXT.size() else null
	metadata.affiliation = AFFILIATION_BY_IDENTITY.get(identity2, null)
	metadata.dimension = DIMENSION_BY_SYMBOL_SET.get(symbol_set, "")

	if symbol_set in ["10", "11", "25", "27", "40"]:
		metadata.unit = true
	if symbol_set in ["05", "06", "50"]:
		metadata.space = true
	if symbol_set == "40":
		metadata.activity = true
	if symbol_set == "15":
		metadata.landequipment = true
	if symbol_set == "20":
		metadata.installation = true
	if symbol_set == "25":
		metadata.controlMeasure = true
	if symbol_set == "60":
		metadata.cyberspace = true
	if symbol_set == "36" and style.alternateMedal == false:
		metadata.fill = false
	if symbol_set == "30" and entity == "150000":
		metadata.frame = false

	# Planned / anticipated / pending symbols have a dashed frame.
	if status == "1":
		metadata.notpresent = dash_arrays.anticipated
	if identity2 in ["0", "2", "5"]:
		metadata.notpresent = dash_arrays.pending
	if (symbol_set == "30" and entity == "160000") or (symbol_set == "35" and entity in ["140000", "150000"]):
		metadata.notpresent = dash_arrays.pending

	if status in ["2", "3", "4", "5"]:
		metadata.condition = STATUS[status.to_int()]

	metadata.baseDimension = metadata.dimension
	metadata.baseAffilation = metadata.affiliation

	if identity2 == "5" and identity1 == "1":
		metadata.joker = true
	if identity2 == "6" and identity1 == "1":
		metadata.faker = true
	if metadata.joker or metadata.faker:
		metadata.affiliation = "Friend"

	if symbol_set == "00":
		metadata.dimensionUnknown = true
		if identity1 == "1" and metadata.affiliation != "Unknown":
			metadata.affiliation = ""

	if symbol_set == "27":
		metadata.dimension = "LandDismountedIndividual"
		metadata.dismounted = true
	if symbol_set in ["15", "52"]:
		metadata.dimension = "Sea"

	var prefix := functionid.substr(0, 2)
	if ((symbol_set in ["01", "05", "12"] and prefix == "12") or symbol_set == "11"
			or (symbol_set == "15" and prefix == "16") or (symbol_set == "30" and prefix == "14")
			or (symbol_set == "35" and prefix == "12")):
		metadata.civilian = true

	if frame_shape != "0" and metadata.get("edition") == "E":
		_apply_frame_shape(frame_shape, metadata)
	if frame_shape == "A":
		metadata.frame = false

	if hq_tf_dummy in ["1", "3", "5", "7"]:
		metadata.feintDummy = true
	if hq_tf_dummy in ["2", "3", "6", "7"]:
		metadata.headquarters = true
	if hq_tf_dummy in ["4", "5", "6", "7"]:
		metadata.taskForce = true

	# Unknown codes map to null, which marks the symbol invalid (mirrors milsymbol's undefined).
	if echelon_mobility <= 30:
		metadata.echelon = ECHELON_MOBILITY.get(echelon_mobility, null)
	if echelon_mobility >= 30 and echelon_mobility < 70:
		metadata.mobility = ECHELON_MOBILITY.get(echelon_mobility, null)
	if echelon_mobility >= 70 and echelon_mobility < 80:
		metadata.leadership = ECHELON_MOBILITY.get(echelon_mobility, null)


static func _apply_frame_shape(frame_shape: String, metadata: Dictionary) -> void:
	for key in ["civilian", "cyberspace", "installation", "landequipment", "activity", "space", "unit"]:
		metadata[key] = false
	match frame_shape:
		"1":
			metadata.dimension = "Air"
			metadata.space = true
		"2":
			metadata.dimension = "Air"
		"3":
			metadata.dimension = "Ground"
			metadata.unit = true
		"4":
			metadata.dimension = "Sea"
			metadata.landequipment = true
		"5":
			metadata.dimension = "Ground"
			metadata.installation = true
		"6":
			metadata.dimension = "LandDismountedIndividual"
			metadata.dismounted = true
		"7":
			metadata.dimension = "Subsurface"
		"8":
			metadata.dimension = "Ground"
			metadata.activity = true
			metadata.unit = true
		"9":
			metadata.dimension = "Ground"
			metadata.unit = true
