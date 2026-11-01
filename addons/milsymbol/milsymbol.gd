class_name MilSymbol
extends RefCounted
## Renders MIL-STD-2525 / APP-6 symbols from number based SIDCs.
##
##   var texture := MilSymbol.create_texture("10031000141211000000", {"size": 60})
##   var render := MilSymbol.render("10061000000000000000")  # SVG, size, anchor, metadata
##
## Port of milsymbol 3.0.5 (src/ms/symbol/setoptions.js and the symbol parts in src/symbolfunctions/).
## Implemented parts: frame (base geometry), icon, modifiers (HQ, task force, installation, feint/dummy,
## echelon, mobility, leadership), status (condition bar) and affiliation/dimension marks (exercise, simulation).

const DATA_DIR := "res://addons/milsymbol/data/"

## milsymbol style options and their defaults (src/ms/symbol.js). Any other key is a symbol option.
const STYLE_DEFAULTS := {
	"alternateMedal": false,
	"civilianColor": true,
	"colorMode": "Light",
	"fill": true,
	"fillColor": "",
	"fillOpacity": 1.0,
	"fontfamily": "Arial",
	"frame": true,
	"frameColor": "",
	"hqStaffLength": 0,
	"icon": true,
	"iconColor": "",
	"modifierColor": "",
	"monoColor": "",
	"outlineColor": "rgb(239, 239, 239)",
	"outlineWidth": 0.0,
	"padding": 0.0,
	"simpleStatusModifier": false,
	"size": 100.0,
	"square": false,
	"standard": "",
	"strokeWidth": 4.0,
	"styleFill": false,
	# Not in milsymbol: "path" draws icon labels as outlines (Godot's SVG loader has no text support),
	# "svg" writes <text> elements exactly like milsymbol does.
	"textMode": "path",
	# Not in milsymbol: true reproduces known milsymbol 3.0.5 drawing bugs exactly (golden tests use it).
	# See docs/draw-instructions.md, "Known milsymbol 3.0.5 quirks".
	"milsymbolQuirks": false,
}

const AFFILIATIONS := ["Civilian", "Friend", "Hostile", "Neutral", "Unknown", "Suspect"]

## Marker that _scale leaves in nested Arrays (see _set_non_scaling_stroke), only used with milsymbolQuirks.
const ARRAY_PROPERTY_MARK := "milsymbolArrayProperty"
## Drawn when an entity code has no icon (src/symbolfunctions/icon.js).
const UNDEFINED_ICON_D := "m 94.8206,78.1372 c -0.4542,6.8983 0.6532,14.323 5.3424,19.6985 4.509,5.6933 11.309,9.3573 14.98,15.7283 3.164,6.353 -0.09,14.245 -5.903,17.822 -7.268,4.817 -18.6219,2.785 -22.7328,-5.249 -1.5511,-2.796 -2.3828,-5.931 -2.8815,-9.071 -3.5048,0.416 -7.0093,0.835 -10.5142,1.252 0.8239,8.555 5.2263,17.287 13.2544,21.111 7.8232,3.736 17.1891,3.783 25.3291,1.052 8.846,-3.103 15.737,-11.958 15.171,-21.537 0.05,-6.951 -4.272,-12.85 -9.134,-17.403 -4.526,-4.6949 -11.048,-8.3862 -12.401,-15.2748 -1.215,-2.3639 -0.889,-8.129 -0.889,-8.129 z m -0.6253,-20.5177 0,11.6509 11.6527,0 0,-11.6509 z"
## Entity codes in symbol set 15 (land equipment) whose icon is not scaled for modifiers.
const EQUIPMENT_NO_SCALE := [130100, 170000, 170400, 170600, 170700, 170800, 170900, 171100, 200200, 200300,
	200600, 200700, 200800, 200900, 201100, 201301, 201302, 201400, 210100, 210200, 210300, 210400,
	210500, 230200, 250000]
## Echelon amplifiers drawn above the frame (src/symbolfunctions/modifier-echelon-json.js).
## "fill": true means the modifier color.
const ECHELONS := {
	"Team/Crew": {"g": [{"type": "circle", "cx": 100, "cy": -20, "r": 15}, {"type": "path", "d": "M80,-10L120,-30"}],
		"bbox": {"y1": -40}},
	"Squad": {"g": [{"type": "circle", "fill": true, "cx": 100, "cy": -20, "r": 7.5}], "bbox": {"y1": -27.5}},
	"Section": {"g": [{"type": "circle", "fill": true, "cx": 115, "cy": -20, "r": 7.5},
		{"type": "circle", "fill": true, "cx": 85, "cy": -20, "r": 7.5}], "bbox": {"y1": -27.5}},
	"Platoon/detachment": {"g": [{"type": "circle", "fill": true, "cx": 100, "cy": -20, "r": 7.5},
		{"type": "circle", "fill": true, "cx": 70, "cy": -20, "r": 7.5},
		{"type": "circle", "fill": true, "cx": 130, "cy": -20, "r": 7.5}], "bbox": {"y1": -27.5}},
	"Company/battery/troop": {"g": [{"type": "path", "d": "M100,-10 l0,-25"}], "bbox": {"y1": -40}},
	"Battalion/squadron": {"g": [{"type": "path", "d": "M90,-10 l0,-25"}, {"type": "path", "d": "M110,-10 l0,-25"}],
		"bbox": {"y1": -40}},
	"Regiment/group": {"g": [{"type": "path", "d": "M100,-10 l0,-25"}, {"type": "path", "d": "M120,-10 l0,-25"},
		{"type": "path", "d": "M80,-10 l0,-25"}], "bbox": {"y1": -40}},
	"Brigade": {"g": [{"type": "path", "d": "M87.5,-10 l25,-25 m0,25 l-25,-25"}], "bbox": {"y1": -40}},
	"Division": {"g": [{"type": "path", "d": "M70,-10 l25,-25 m0,25 l-25,-25 M105,-10 l25,-25 m0,25 l-25,-25"}],
		"bbox": {"y1": -40, "x1": 70, "x2": 130}},
	"Corps/MEF": {"g": [{"type": "path", "d": "M52.5,-10 l25,-25 m0,25 l-25,-25 M87.5,-10 l25,-25 m0,25 l-25,-25 M122.5,-10 l25,-25 m0,25 l-25,-25"}],
		"bbox": {"y1": -40, "x1": 52.5, "x2": 147.5}},
	"Army": {"g": [{"type": "path", "d": "M35,-10 l25,-25 m0,25 l-25,-25 M70,-10 l25,-25 m0,25 l-25,-25 M105,-10 l25,-25 m0,25 l-25,-25 M140,-10 l25,-25 m0,25 l-25,-25"}],
		"bbox": {"y1": -40, "x1": 35, "x2": 165}},
	"Army Group/front": {"g": [{"type": "path", "d": "M17.5,-10 l25,-25 m0,25 l-25,-25 M52.5,-10 l25,-25 m0,25 l-25,-25 M87.5,-10 l25,-25 m0,25 l-25,-25 M122.5,-10 l25,-25 m0,25 l-25,-25 M157.5,-10 l25,-25 m0,25 l-25,-25"}],
		"bbox": {"y1": -40, "x1": 17.5, "x2": 182.5}},
	"Region/Theater": {"g": [{"type": "path", "d": "M0,-10 l25,-25 m0,25 l-25,-25 M35,-10 l25,-25 m0,25 l-25,-25 M70,-10 l25,-25 m0,25 l-25,-25 M105,-10 l25,-25 m0,25 l-25,-25 M140,-10 l25,-25 m0,25 l-25,-25 M175,-10 l25,-25 m0,25 l-25,-25"}],
		"bbox": {"y1": -40, "x1": 0, "x2": 200}},
	"Command": {"g": [{"type": "path", "d": "M70,-22.5 l25,0 m-12.5,12.5 l0,-25 M105,-22.5 l25,0 m-12.5,12.5 l0,-25"}],
		"bbox": {"y1": -40, "x1": 70, "x2": 130}},
}
## Mobility amplifiers drawn below the frame; "dy" is added to the frame bottom for the bbox.
const MOBILITIES := {
	"Wheeled limited cross country": {"g": [{"type": "path", "d": "M 53,1 l 94,0"},
		{"type": "circle", "cx": 58, "cy": 8, "r": 8}, {"type": "circle", "cx": 142, "cy": 8, "r": 8}], "dy": 16},
	"Wheeled cross country": {"g": [{"type": "path", "d": "M 53,1 l 94,0"},
		{"type": "circle", "cx": 58, "cy": 8, "r": 8}, {"type": "circle", "cx": 142, "cy": 8, "r": 8},
		{"type": "circle", "cx": 100, "cy": 8, "r": 8}], "dy": 16},
	"Tracked": {"g": [{"type": "path", "d": "M 53,1 l 100,0 c15,0 15,15 0,15 l -100,0 c-15,0 -15,-15 0,-15"}],
		"dy": 18, "x1": 42, "x2": 168},
	"Wheeled and tracked combination": {"g": [{"type": "circle", "cx": 58, "cy": 8, "r": 8},
		{"type": "path", "d": "M 83,1 l 70,0 c15,0 15,15 0,15 l -70,0 c-15,0 -15,-15 0,-15"}], "dy": 16, "x2": 168},
	"Towed": {"g": [{"type": "path", "d": "M 63,1 l 74,0"}, {"type": "circle", "cx": 58, "cy": 3, "r": 8},
		{"type": "circle", "cx": 142, "cy": 3, "r": 8}], "dy": 10},
	"Rail": {"g": [{"type": "path", "d": "M 53,1 l 96,0"}, {"type": "circle", "cx": 58, "cy": 8, "r": 8},
		{"type": "circle", "cx": 73, "cy": 8, "r": 8}, {"type": "circle", "cx": 127, "cy": 8, "r": 8},
		{"type": "circle", "cx": 142, "cy": 8, "r": 8}], "dy": 16},
	"Over snow (prime mover)": {"g": [{"type": "path", "d": "M 50,-9 l10,10 90,0"}], "dy": 9},
	"Sled": {"g": [{"type": "path", "d": "M 145,-12  c15,0 15,15 0,15 l -90,0 c-15,0 -15,-15 0,-15"}],
		"dy": 15, "x1": 42, "x2": 168},
	"Pack animals": {"g": [{"type": "path", "d": "M 80,20 l 10,-20 10,20 10,-20 10,20"}], "dy": 20},
	"Barge": {"g": [{"type": "path", "d": "M 50,1 l 100,0 c0,10 -100,10 -100,0"}], "dy": 10},
	"Amphibious": {"g": [{"type": "path", "d": "M 65,10 c 0,-10 10,-10 10,0 0,10 10,10 10,0\t0,-10 10,-10 10,0 0,10 10,10 10,0\t0,-10 10,-10 10,0 0,10 10,10 10,0\t0,-10 10,-10 10,0"}],
		"dy": 20},
	"Short towed array": {"g": [{"type": "path", "fill": true, "d": "M 50,5 l 100,0 M50,0 l10,0 0,10 -10,0 z M150,0 l-10,0 0,10 10,0 z M100,0 l5,5 -5,5 -5,-5 z"}],
		"dy": 10},
	"Long towed Array": {"g": [{"type": "path", "fill": true, "d": "M 50,5 l 100,0 M50,0 l10,0 0,10 -10,0 z M150,0 l-10,0 0,10 10,0 z M105,0 l-10,0 0,10 10,0 z M75,0 l5,5 -5,5 -5,-5 z  M125,0 l5,5 -5,5 -5,-5 z"}],
		"dy": 10},
}
const TASK_FORCE_WIDTHS := {"Corps/MEF": 110, "Army": 145, "Army Group/front": 180, "Region/Theater": 215}
const HQ_STAFF_FROM_BOTTOM := ["AirFriend", "AirNeutral", "GroundFriend", "GroundNeutral", "SeaNeutral",
	"SubsurfaceNeutral"]
const CONDITION_COLORS := {
	"FullyCapable": "rgb(0,255,0)",
	"Damaged": "rgb(255,255,0)",
	"Destroyed": "rgb(255,0,0)",
	"FullToCapacity": "rgb(0, 180, 240)",
}

## Parts added for entity subtypes 95-98.
const SUBTYPE_PARTS := {
	"95": "GR.IC.FF.HEADQUARTERS OR HEADQUARTERS ELEMENT",
	"96": "GR.IC.FF.DIVISION AND BELOW SUPPORT",
	"97": "GR.IC.FF.CORPS SUPPORT",
	"98": "GR.IC.FF.THEATRE SUPPORT",
}

## Frame marks for space, activity and cyberspace symbol sets (src/symbolfunctions/basegeometry.js).
const SPACE_MARKS := {
	"Friend": "M 100,30 C 90,30 80,35 68.65625,50 l 62.6875,0 C 120,35 110,30 100,30",
	"Hostile": "M67,50 L100,20 133,50 z",
	"Neutral": "M45,50 l0,-20 110,0 0,20 z",
	"Unknown": "M 100 22.5 C 85 22.5 70 31.669211 66 50 L 134 50 C 130 31.669204 115 22.5 100 22.5 z",
}
const ACTIVITY_MARKS := {
	"Friend": "m 160,135 0,15 15,0 0,-15 z m -135,0 15,0 0,15 -15,0 z m 135,-85 0,15 15,0 0,-15 z m -135,0 15,0 0,15 -15,0 z",
	"Hostile": "M 100 28 L 89.40625 38.59375 L 100 49.21875 L 110.59375 38.59375 L 100 28 z M 38.6875 89.3125 L 28.0625 99.9375 L 38.6875 110.53125 L 49.28125 99.9375 L 38.6875 89.3125 z M 161.40625 89.40625 L 150.78125 100 L 161.40625 110.59375 L 172 100 L 161.40625 89.40625 z M 99.9375 150.71875 L 89.3125 161.3125 L 99.9375 171.9375 L 110.53125 161.3125 L 99.9375 150.71875",
	"Neutral": "m 140,140 15,0 0,15 -15,0 z m -80,0 0,15 -15,0 0,-15 z m 80,-80 0,-15 15,0 0,15 z m -80,0 -15,0 0,-15 15,0 z",
	"Unknown": "M 107.96875 31.46875 L 92.03125 31.71875 L 92.03125 46.4375 L 107.71875 46.4375 L 107.96875 31.46875 z M 47.03125 92.5 L 31.09375 92.75 L 31.09375 107.5 L 46.78125 107.5 L 47.03125 92.5 z M 168.4375 92.5 L 152.5 92.75 L 152.5 107.5 L 168.1875 107.5 L 168.4375 92.5 z M 107.96875 153.5625 L 92.03125 153.8125 L 92.03125 168.53125 L 107.71875 168.53125 L 107.96875 153.5625 z",
}
const CYBERSPACE_MARKS := {
	"Friend": "m 135,150 40,-40 0,40 z",
	"Hostile": "m 150,78 0,44 22,-22 z",
	"Neutral": "m 115,155 40,-40 0,40 z",
	"Unknown": "M 150 65.7 L 150 134 C 176 123 176 77.2 150 65.7 z",
}

static var _geometries: Dictionary
static var _color_modes: Dictionary
static var _dash_arrays: Dictionary
static var _hq_staff_length: float

## Maximum number of cached renders; the oldest entries are dropped first.
static var cache_limit: int = 1024
static var _cache: Dictionary = {}  # key -> {"render": MilSymbolRender, "textures": {scale: ImageTexture}}


## Renders a symbol. `options` takes milsymbol option names (size, colorMode, fill, frame, outlineWidth, ...).
static func render(sidc: String, options: Dictionary = {}) -> MilSymbolRender:
	_ensure_data()
	var style := STYLE_DEFAULTS.duplicate()
	var symbol_options := {}
	for key in options:
		if style.has(key):
			style[key] = options[key]
		else:
			symbol_options[key] = options[key]
	for key in ["fillOpacity", "outlineWidth", "padding", "size", "strokeWidth", "hqStaffLength"]:
		style[key] = float(style[key])

	var metadata := MilSymbolSidc.decode(sidc, style, _dash_arrays)
	metadata.baseGeometry = _base_geometry(metadata, style)
	var colors := _get_colors(metadata, style)
	var state := {"valid_icon": true}

	var result := MilSymbolRender.new()
	result.sidc = sidc
	result.style = style
	result.metadata = metadata

	var instructions: Array = []
	var bbox := {"x1": 100.0, "y1": 100.0, "x2": 100.0, "y2": 100.0}
	# Symbol parts in milsymbol's order: pre is drawn underneath everything so far, post on top.
	# Each part sees the bbox merged from the parts before it (mobility needs it).
	for part in ["base_geometry", "icon", "modifier", "status", "affiliation_dimension"]:
		var m: Dictionary
		match part:
			"base_geometry":
				m = _part_base_geometry(metadata, style, colors)
			"icon":
				m = _part_icon(sidc, metadata, style, colors, state)
			"modifier":
				m = _part_modifier(metadata, style, colors, bbox)
			"status":
				m = _part_status(metadata, style, colors, symbol_options)
			"affiliation_dimension":
				m = _part_affiliation_dimension(metadata, style, colors)
		var pre: Array = m.pre
		var post: Array = m.post
		if not pre.is_empty():
			instructions = pre + instructions
		if not post.is_empty():
			instructions = instructions + post
		if m.has("bbox") and not (pre.is_empty() and post.is_empty()):
			_merge_bbox(bbox, m.bbox)

	if style.padding:
		bbox.x1 -= style.padding
		bbox.x2 += style.padding
		bbox.y1 -= style.padding
		bbox.y2 += style.padding

	var anchor := Vector2(100, 100)
	var margin: float = style.strokeWidth + style.outlineWidth
	var scale: float = style.size / 100.0
	result.octagon_anchor = (anchor - Vector2(bbox.x1, bbox.y1) + Vector2(margin, margin)) * scale
	if metadata.headquarters:
		var staff: float = style.hqStaffLength if style.hqStaffLength else _hq_staff_length
		anchor = Vector2(metadata.baseGeometry.bbox.x1, metadata.baseGeometry.bbox.y2 + staff)

	if style.square:
		var max_x := maxf(anchor.x - bbox.x1, bbox.x2 - anchor.x)
		var max_y := maxf(anchor.y - bbox.y1, bbox.y2 - anchor.y)
		var max_xy := maxf(max_x, max_y)
		bbox = {"x1": anchor.x - max_xy, "y1": anchor.y - max_xy, "x2": anchor.x + max_xy, "y2": anchor.y + max_xy}

	var base_size := Vector2(bbox.x2 - bbox.x1 + margin * 2, bbox.y2 - bbox.y1 + margin * 2)
	result.size = base_size * scale
	result.anchor = (anchor - Vector2(bbox.x1, bbox.y1) + Vector2(margin, margin)) * scale
	result.draw_instructions = instructions
	result.valid = _is_valid(metadata) and state.valid_icon and not _contains_null(instructions)
	var view_box := Rect2(bbox.x1 - margin, bbox.y1 - margin, base_size.x, base_size.y)
	result.svg = MilSymbolSvgWriter.write(instructions, style, view_box, result.size)
	return result


## Cached render(): the same SIDC and options (in any key order) return the same object.
static func render_cached(sidc: String, options: Dictionary = {}) -> MilSymbolRender:
	return _cache_entry(sidc, options).render


## Cached texture for a symbol. Returns the same ImageTexture for the same SIDC, options and scale.
## Returns null if Godot cannot rasterize the SVG.
static func create_texture(sidc: String, options: Dictionary = {}, scale: float = 1.0) -> ImageTexture:
	var entry := _cache_entry(sidc, options)
	var textures: Dictionary = entry.textures
	if not textures.has(scale):
		textures[scale] = entry.render.to_texture(scale)
	return textures[scale]


static func clear_cache() -> void:
	_cache.clear()


static func cache_size() -> int:
	return _cache.size()


static func _cache_entry(sidc: String, options: Dictionary) -> Dictionary:
	var key := sidc + "|" + _options_key(options)
	if _cache.has(key):
		# Move to the end so the least recently used entry is first.
		var hit: Dictionary = _cache[key]
		_cache.erase(key)
		_cache[key] = hit
		return hit
	var entry := {"render": render(sidc, options), "textures": {}}
	_cache[key] = entry
	while _cache.size() > maxi(cache_limit, 1):
		_cache.erase(_cache.keys()[0])
	return entry


static func _options_key(options: Dictionary) -> String:
	var keys := options.keys()
	keys.sort()
	var parts := PackedStringArray()
	for key in keys:
		parts.append("%s=%s" % [key, var_to_str(options[key])])
	return ",".join(parts)


static func _ensure_data() -> void:
	if not _geometries.is_empty():
		return
	_geometries = _load_json("geometries.json").get("geometries", {})
	var colors := _load_json("colormodes.json")
	_color_modes = colors.get("colorModes", {})
	_dash_arrays = colors.get("dashArrays", {})
	_hq_staff_length = float(colors.get("hqStaffLength", 100))


static func _load_json(file_name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(DATA_DIR + file_name)
	var data = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("milsymbol: could not load %s%s" % [DATA_DIR, file_name])
		return {}
	return data


static func _base_geometry(metadata: Dictionary, style: Dictionary) -> Dictionary:
	if not style.frame and not style.icon:
		return _geometries.PositionMarker
	var key := "%s%s" % [metadata.dimension, metadata.affiliation]
	if _geometries.has(key):
		return _geometries[key]
	return {"g": {}, "bbox": {"x1": 100.0, "y1": 100.0, "x2": 100.0, "y2": 100.0}}


static func _is_valid(metadata: Dictionary) -> bool:
	if metadata.affiliation == null or metadata.affiliation == "undefined":
		return false
	if metadata.dimension == "undefined" and not metadata.get("controlMeasure", false):
		return false
	if metadata.mobility == null:
		return false
	return true


static func _contains_null(value: Variant) -> bool:
	if value == null:
		return true
	if value is Array:
		for item in value:
			if _contains_null(item):
				return true
	elif value is Dictionary:
		for key in value:
			if _contains_null(value[key]):
				return true
	return false


## Like milsymbol's BBox.merge: missing or null keys are ignored.
static func _merge_bbox(bbox: Dictionary, other: Dictionary) -> void:
	if other.get("x1") != null:
		bbox.x1 = minf(bbox.x1, other.x1)
	if other.get("y1") != null:
		bbox.y1 = minf(bbox.y1, other.y1)
	if other.get("x2") != null:
		bbox.x2 = maxf(bbox.x2, other.x2)
	if other.get("y2") != null:
		bbox.y2 = maxf(bbox.y2, other.y2)


#region Colors (src/ms/symbol/getcolors.js, resolvecolormode.js)

static func _color_mode(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate()
	return _color_modes.get(value, _color_modes.Light).duplicate()


static func _resolve_color_mode(mode: Dictionary, style: Dictionary, metadata: Dictionary,
		apply_mono_color: bool = false) -> Dictionary:
	var resolved := mode.duplicate()
	if style.civilianColor and metadata.civilian:
		resolved.Friend = resolved.Civilian
		resolved.Neutral = resolved.Civilian
		resolved.Unknown = resolved.Civilian
	if metadata.joker or metadata.faker:
		resolved.Friend = resolved.Hostile
	if metadata.get("suspect", false):
		resolved.Friend = resolved.Suspect
		resolved.Hostile = resolved.Suspect
	if apply_mono_color and style.monoColor != "":
		for affiliation in AFFILIATIONS:
			resolved[affiliation] = style.monoColor
	return resolved


static func _get_colors(metadata: Dictionary, style: Dictionary) -> Dictionary:
	var custom_frame: bool = style.frameColor is Dictionary
	var custom_icon: bool = style.iconColor is Dictionary
	var base_fill := _resolve_color_mode(_color_mode(style.colorMode), style, metadata)
	var base_frame := _resolve_color_mode(
			_color_mode(style.frameColor if custom_frame else "FrameColor"), style, metadata, true)
	var base_icon := _resolve_color_mode(
			_color_mode(style.iconColor if custom_icon else "IconColor"), style, metadata)
	var base_black := _color_mode("Black")
	var base_white := _color_mode("White")
	var base_off_white := _color_mode("OffWhite")
	var base_none := _color_mode("None")

	if style.monoColor != "":
		base_black = base_frame
		base_white = base_none
		base_fill = base_none

	var colors := {
		"fillColor": base_fill,
		"frameColor": base_frame,
		"iconColor": base_icon,
		"iconFillColor": base_fill,
		"none": base_none,
		"black": base_black,
		"white": base_white,
	}
	if metadata.frame:
		colors.frameColor = base_frame if custom_frame else base_black
	else:
		colors.frameColor = base_none

	if metadata.fill:
		colors.fillColor = base_none if (not metadata.frame and style.icon) else base_fill
		colors.iconColor = base_icon if custom_icon else base_black
		colors.iconFillColor = base_fill if not metadata.frame else base_off_white
		colors.white = base_off_white
	else:
		colors.fillColor = base_none
		colors.frameColor = base_none if not metadata.frame else base_frame
		colors.iconColor = base_frame
		colors.iconFillColor = base_none
		if not metadata.frame and not metadata.fill and not style.icon:
			colors.frameColor = base_black
			colors.fillColor = base_black
	return colors

#endregion


#region Symbol parts

## Frame (src/symbolfunctions/basegeometry.js).
static func _part_base_geometry(metadata: Dictionary, style: Dictionary, colors: Dictionary) -> Dictionary:
	var pre: Array = []
	var post: Array = []
	var base: Dictionary = metadata.baseGeometry
	var affiliation = metadata.affiliation
	var frame_color = colors.frameColor.get(affiliation, false)

	if (not metadata.frame and style.icon) or not base.g.has("type"):
		return {"pre": pre, "post": post, "bbox": base.bbox}

	var geom := _clone_geometry(base.g)
	geom.fill = style.fillColor if style.fillColor else colors.fillColor.get(affiliation, false)
	geom.fillopacity = style.fillOpacity
	geom.stroke = frame_color
	geom.strokewidth = style.strokeWidth if style.size >= 10 else 10.0

	if style.frame and style.outlineWidth > 0:
		var outline: Dictionary
		if geom.type == "path" and metadata.fill and style.monoColor == "":
			outline = {"type": "path", "d": base.g.d + " Z", "strokewidth": geom.strokewidth}
		else:
			outline = geom
		var outline_color = style.outlineColor
		if outline_color is Dictionary:
			outline_color = outline_color.get(affiliation)
		pre.append(_outline(outline, style.outlineWidth, style.strokeWidth, outline_color))

	if (style.monoColor != "" or not style.fill) and metadata.notpresent:
		geom.strokedasharray = metadata.notpresent
	post.append(geom)

	for marks in [
			[metadata.space, SPACE_MARKS],
			[metadata.activity, ACTIVITY_MARKS],
			[metadata.get("cyberspace", false), CYBERSPACE_MARKS]]:
		if marks[0] and marks[1].has(affiliation):
			post.append({"type": "path", "stroke": false, "fill": frame_color, "d": marks[1][affiliation]})

	if style.fill and style.frame and metadata.notpresent and not metadata.get("unframed", false):
		var dashed := _clone_geometry(base.g)
		dashed.fill = false
		dashed.stroke = colors.white.get(affiliation, false)
		dashed.strokewidth = style.strokeWidth + 1
		dashed.strokedasharray = metadata.notpresent
		post.append(dashed)

	return {"pre": pre, "post": post, "bbox": base.bbox}


## Main icon, modifier 1 and modifier 2 (src/symbolfunctions/icon.js, number based SIDCs).
static func _part_icon(sidc: String, metadata: Dictionary, style: Dictionary, colors: Dictionary,
		state: Dictionary) -> Dictionary:
	var pre: Array = []
	var post: Array = []
	var bbox := {"x1": 50.0, "y1": 50.0, "x2": 150.0, "y2": 150.0}
	if style.icon and metadata.numberSIDC:
		var symbol_set := sidc.substr(4, 2)
		var tables := MilSymbolIcons.get_tables(symbol_set, metadata.get("edition", "D"), not metadata.STD2525)
		var context := MilSymbolIcons.make_context(symbol_set, metadata, style, colors)
		var main_table: Dictionary = tables.get("main", {})
		var functionid: String = metadata.functionid
		var main_code := functionid.substr(0, 6)
		var subtype := functionid.substr(4, 2)

		var main_entry = main_table.get(main_code)
		if main_entry == null and subtype.to_int() >= 95:
			main_entry = main_table.get(functionid.substr(0, 4) + "00")
		if main_entry == null:
			if main_code != "000000" and main_code != "":
				post.append([{"type": "path", "stroke": false,
						"fill": colors.iconColor.get(metadata.affiliation, false), "d": UNDEFINED_ICON_D}])
				state.valid_icon = false
		else:
			var main_icon = MilSymbolIcons.resolve(main_entry, context)
			var code := main_code.to_int()
			if ((symbol_set == "27" and code >= 110301 and code <= 110403)
					or (symbol_set == "15" and not code in EQUIPMENT_NO_SCALE)):
				var has_m1: bool = metadata._modifier1 != "000"
				var has_m2: bool = metadata._modifier2 != "000"
				if has_m1 and has_m2:
					main_icon = [_scale(0.45, main_icon, true)]
				elif has_m2:
					main_icon = [_translate(0, -10, _scale(0.7, main_icon, true))]
				elif has_m1:
					main_icon = [_translate(0, 10, _scale(0.7, main_icon, true))]
				else:
					main_icon = [_scale(1, main_icon, true)]
			post.append(main_icon)

		var special_bbox: Dictionary = tables.get("bbox", {})
		if special_bbox.has(main_code):
			var b: Dictionary = special_bbox[main_code]
			bbox = {"x1": float(b.get("x1", 100)), "y1": float(b.get("y1", 100)),
					"x2": float(b.get("x2", 100)), "y2": float(b.get("y2", 100))}
		if SUBTYPE_PARTS.has(subtype):
			post.append(MilSymbolIcons.resolve_part(SUBTYPE_PARTS[subtype], context))

		for modifier in [["m1", metadata._modifier1, functionid.substr(6, 2)],
				["m2", metadata._modifier2, functionid.substr(8, 2)]]:
			var table: Dictionary = tables.get(modifier[0], {})
			var code_in_sidc: String = modifier[1]
			var code: String = modifier[2] if code_in_sidc.substr(0, 1) == "0" else code_in_sidc
			if code_in_sidc.substr(0, 1) == "0" and code == "00":
				continue
			if table.has(code):
				post.append(MilSymbolIcons.resolve(table[code], context))
			else:
				state.valid_icon = false

	if (not (style.frame and metadata.fill) or style.monoColor != "" or metadata.get("controlMeasure", false)) 			and style.outlineWidth > 0:
		var outline_color = style.outlineColor
		if outline_color is Dictionary:
			outline_color = outline_color.get(metadata.affiliation)
		pre.append(_outline(post, style.outlineWidth, style.strokeWidth, outline_color, style.milsymbolQuirks))
	return {"pre": pre, "post": post, "bbox": bbox}


## Scales an instruction around (100, 100) (ms._scale in src/ms.js).
static func _scale(factor: float, instruction: Variant, non_scaling_stroke: bool) -> Dictionary:
	if non_scaling_stroke:
		_set_non_scaling_stroke(instruction, factor)
	return {"type": "translate", "x": 100 - factor * 100, "y": 100 - factor * 100,
			"draw": [{"type": "scale", "factor": factor, "draw": [instruction]}]}


static func _set_non_scaling_stroke(instruction: Variant, factor: float) -> void:
	if instruction is Array:
		for item in instruction:
			if item is Dictionary:
				item.non_scaling_stroke = 1.0 / factor
				if item.has("draw"):
					_set_non_scaling_stroke(item.draw, factor)
			elif item is Array:
				# milsymbol also sets non_scaling_stroke as a property of the Array itself. outline.js
				# walks arrays with for...in, so that property becomes an extra, typeless outline element.
				# GDScript arrays cannot carry properties: append a marker that _outline understands.
				var marked: bool = (not item.is_empty() and item.back() is Dictionary
						and item.back().get("type") == ARRAY_PROPERTY_MARK)
				for child in item:
					_set_non_scaling_stroke(child, factor)
				if not marked:
					item.append({"type": ARRAY_PROPERTY_MARK})
	elif instruction is Dictionary:
		instruction.non_scaling_stroke = 1.0 / factor


static func _translate(x: float, y: float, instruction: Variant) -> Dictionary:
	return {"type": "translate", "x": x, "y": y, "draw": [instruction]}


## HQ staff, task force, installation, feint/dummy, echelon, mobility, leadership
## (src/symbolfunctions/modifier.js). `symbol_bbox` is the bbox merged from the previous parts.
static func _part_modifier(metadata: Dictionary, style: Dictionary, colors: Dictionary,
		symbol_bbox: Dictionary) -> Dictionary:
	var pre: Array = []
	var post: Array = []
	var base: Dictionary = metadata.baseGeometry.bbox
	var bbox := {"x1": float(base.x1), "y1": float(base.y1), "x2": float(base.x2), "y2": float(base.y2)}
	var gbbox := {"x1": 100.0, "y1": 100.0, "x2": 100.0, "y2": 100.0}
	var affiliation = metadata.affiliation
	var color: Variant
	if style.modifierColor:
		color = style.modifierColor
	elif style.frameColor is Dictionary:
		color = _resolve_color_mode(style.frameColor, style, metadata, true).get(affiliation)
	else:
		color = colors.iconColor.get(affiliation, false)
	var outline_color = _outline_color(style, affiliation)
	var geometry_key := "%s%s" % [metadata.dimension, affiliation]

	var hq_staff_length: float = style.hqStaffLength if style.hqStaffLength else _hq_staff_length
	if metadata.headquarters and hq_staff_length > 0:
		var y: float = bbox.y2 if geometry_key in HQ_STAFF_FROM_BOTTOM else 100.0
		var geom := {"type": "path", "cssClass": "milsymbol-headquarters",
				"d": "M%s,%s L%s,%s" % [_n(bbox.x1), _n(y), _n(bbox.x1), _n(bbox.y2 + hq_staff_length)]}
		if style.outlineWidth > 0:
			pre.append(_outline(geom, style.outlineWidth, style.strokeWidth, outline_color))
		post.append(geom)
		gbbox.y2 = bbox.y2 + hq_staff_length

	if metadata.taskForce:
		var width: float = TASK_FORCE_WIDTHS.get(metadata.echelon, 90)
		var left := 100 - width / 2
		var right := 100 + width / 2
		var geom := {"type": "path", "cssClass": "milsymbol-taskforce",
				"d": "M%s,%s L%s,%s %s,%s %s,%s" % [_n(left), _n(bbox.y1), _n(left), _n(bbox.y1 - 40),
					_n(right), _n(bbox.y1 - 40), _n(right), _n(bbox.y1)]}
		if style.outlineWidth > 0:
			pre.append(_outline(geom, style.outlineWidth, style.strokeWidth, outline_color))
		post.append(geom)
		gbbox.x1 = minf(bbox.x1, left)
		gbbox.x2 = maxf(bbox.x2, right)
		gbbox.y1 = bbox.y1 - 40

	if metadata.installation:
		var gap := 0.0
		if geometry_key in ["AirHostile", "GroundHostile", "SeaHostile"]:
			gap = 14.0
		if geometry_key in ["AirUnknown", "GroundUnknown", "SeaUnknown", "AirFriend", "SeaFriend"]:
			gap = 2.0
		var sw: float = style.strokeWidth
		var geom := {"type": "path", "fill": color, "cssClass": "milsymbol-installation",
				"d": "M85,%s 85,%s 115,%s 115,%s 100,%s Z" % [_n(bbox.y1 + gap - sw / 2), _n(bbox.y1 - 10),
					_n(bbox.y1 - 10), _n(bbox.y1 + gap - sw / 2), _n(bbox.y1 - sw)]}
		if style.outlineWidth > 0:
			pre.append(_outline(geom, style.outlineWidth, style.strokeWidth, outline_color))
		post.append(geom)
		_merge_bbox(gbbox, {"y1": bbox.y1 - 10})

	if metadata.feintDummy:
		var top: float = bbox.y1 - (bbox.x2 - bbox.x1) / 2
		var geom := {"type": "path", "strokedasharray": _dash_arrays.feintDummy, "cssClass": "milsymbol-feintdummy",
				"d": "M100,%s L%s,%s M100,%s L%s,%s" % [_n(top), _n(bbox.x1), _n(bbox.y1), _n(top),
					_n(bbox.x2), _n(bbox.y1)]}
		if style.outlineWidth > 0:
			pre.append(_outline(geom, style.outlineWidth, style.strokeWidth, outline_color))
		post.append(geom)
		_merge_bbox(gbbox, {"y1": top})

	if metadata.echelon and ECHELONS.has(metadata.echelon):
		var echelon: Dictionary = ECHELONS[metadata.echelon]
		var padding := 15.0 if metadata.installation else 0.0
		var geom: Array = []
		for item: Dictionary in echelon.g:
			var g := item.duplicate()
			g.cssClass = "milsymbol-echelon"
			if g.has("fill"):
				if g.fill is bool and g.fill:
					g.fill = color
				g.cssClass = "milsymbol-echelon milsymbol-echelon-fill"
			geom.append(g)
		if style.outlineWidth > 0:
			# milsymbol translates the echelon outline by -padding only, so it lands above the frame.
			var outline_y: float = -padding if style.milsymbolQuirks else bbox.y1 - padding
			pre.append(_outline({"type": "translate", "x": 0, "y": outline_y, "draw": geom},
					style.outlineWidth, style.strokeWidth, outline_color))
		post.append({"type": "translate", "x": 0, "y": bbox.y1 - padding, "draw": geom})
		var eb: Dictionary = echelon.bbox
		_merge_bbox(gbbox, {"x1": eb.get("x1"), "x2": eb.get("x2"), "y1": bbox.y1 + eb.y1 - padding})

	if metadata.mobility and MOBILITIES.has(metadata.mobility):
		if not style.frame:
			bbox.y2 = symbol_bbox.y2
		if affiliation == "Neutral":
			if metadata.mobility in ["Towed", "Short towed array", "Long towed Array"]:
				bbox.y2 += 8
			if metadata.mobility in ["Over snow (prime mover)", "Sled"]:
				bbox.y2 += 18
			if metadata.mobility == "Barge":
				bbox.y2 += 5
		var mobility: Dictionary = MOBILITIES[metadata.mobility]
		var geom: Array = []
		for item: Dictionary in mobility.g:
			var g := item.duplicate()
			if g.get("fill") is bool and g.fill:
				g.fill = color
			geom.append(g)
		if style.outlineWidth > 0:
			pre.append(_outline({"type": "translate", "x": 0, "y": bbox.y2, "draw": geom},
					style.outlineWidth, style.strokeWidth, outline_color))
		post.append({"type": "translate", "x": 0, "y": bbox.y2, "draw": geom})
		_merge_bbox(gbbox, {"x1": mobility.get("x1"), "x2": mobility.get("x2"), "y2": bbox.y2 + mobility.dy})

	if metadata.get("leadership") and affiliation == "Friend":
		pre.append({"type": "path", "d": "m 45,60 55,-25 55,25"})
		_merge_bbox(gbbox, {"y1": bbox.y1 - 20})

	for list in [pre, post]:
		for item in list:
			if not item is Dictionary:
				continue
			if item.get("fill") is bool and item.fill:
				item.fill = color
			if not item.has("fill"):
				item.fill = false
			if not item.has("stroke"):
				item.stroke = color
			if not item.has("strokewidth"):
				item.strokewidth = style.strokeWidth
	return {"pre": pre, "post": post, "bbox": gbbox}


## Operational condition bar or slashes (src/symbolfunctions/statusmodifier.js).
static func _part_status(metadata: Dictionary, style: Dictionary, colors: Dictionary,
		symbol_options: Dictionary) -> Dictionary:
	var pre: Array = []
	var post: Array = []
	var base: Dictionary = metadata.baseGeometry.bbox
	var y1 := float(base.y1)
	var y2 := float(base.y2)
	var affiliation = metadata.affiliation
	var frame_color = colors.frameColor.get(affiliation, false)
	var outline_color = _outline_color(style, affiliation)
	if metadata.condition:
		if metadata.fill and style.monoColor == "" and not style.simpleStatusModifier:
			if not metadata.frame and metadata.get("iconBottom"):
				y2 = metadata.iconBottom
			if symbol_options.get("headquartersElement", ""):
				y2 += 35
			y2 += 25 if metadata.mobility else 5
			var width := float(base.x2) - float(base.x1)
			post.append({"type": "path", "strokewidth": style.strokeWidth,
					"fill": CONDITION_COLORS.get(metadata.condition), "stroke": frame_color,
					"d": "M%s,%s l%s,0 0,25 -%s,0 z" % [_n(base.x1), _n(y2), _n(width), _n(width)]})
			y2 += 25
			if style.outlineWidth > 0:
				pre.append(_outline(post, style.outlineWidth, style.strokeWidth, outline_color))
		else:
			if metadata.condition in ["Damaged", "Destroyed"]:
				post.append({"type": "path", "d": "M150,20 L50,180", "strokewidth": style.strokeWidth * 2,
						"stroke": frame_color})
				y1 = 20
				y2 = 180
			if metadata.condition == "Destroyed":
				post.append({"type": "path", "d": "M50,20 L150,180", "strokewidth": style.strokeWidth * 2,
						"stroke": frame_color})
			if style.outlineWidth > 0:
				pre.append(_outline(post, style.outlineWidth, style.strokeWidth, outline_color))
	return {"pre": pre, "post": post, "bbox": {"y1": y1, "y2": y2}}


## "?" for unknown dimension and X / J / K / S for exercise and simulation contexts
## (src/symbolfunctions/affliationdimension.js).
static func _part_affiliation_dimension(metadata: Dictionary, style: Dictionary, colors: Dictionary) -> Dictionary:
	var pre: Array = []
	var post: Array = []
	var bbox: Dictionary = metadata.baseGeometry.bbox
	var affiliation = metadata.affiliation
	var frame_color = colors.frameColor.get(affiliation, false)
	var has_color: bool = not (frame_color == null or (frame_color is bool and not frame_color) or str(frame_color) == "")
	if metadata.dimensionUnknown and has_color:
		post.append(_text({"type": "text", "text": "?", "x": 100, "y": 127, "fill": frame_color,
				"fontfamily": style.fontfamily, "fontsize": 80, "fontweight": "bold", "textanchor": "middle"}, style))
	if not metadata.baseGeometry.g.is_empty() and has_color:
		var spacing := 10.0
		if affiliation == "Unknown" or (affiliation == "Hostile" and metadata.dimension != "Subsurface"):
			spacing = -10.0
		var x := float(bbox.x2) + spacing
		var letter := {"type": "text", "x": x, "fill": frame_color, "fontfamily": style.fontfamily, "fontsize": 35,
				"fontweight": "bold", "textanchor": "start", "alignmentBaseline": "middle"}
		if metadata.context == "Exercise":
			if not (metadata.joker or metadata.faker):
				post.append(_text(letter.merged({"text": "X", "y": 50}), style))
			if metadata.joker:
				post.append(_text(letter.merged({"text": "J", "y": 40}), style))
			if metadata.faker:
				post.append(_text(letter.merged({"text": "K", "y": 40}), style))
			bbox = {"x2": x + 22, "y1": 15.0}
		if metadata.context == "Simulation":
			post.append(_text(letter.merged({"text": "S", "y": 40}), style))
			bbox = {"x1": 100.0, "y1": 15.0, "x2": x + 22, "y2": 100.0}
	if style.outlineWidth > 0:
		pre.append(_outline(post, style.outlineWidth, style.strokeWidth, _outline_color(style, affiliation)))
	return {"pre": pre, "post": post, "bbox": bbox}


## Text drawn at render time: outlines from glyph data unless textMode is "svg".
static func _text(instruction: Dictionary, style: Dictionary) -> Dictionary:
	if style.textMode == "svg":
		return instruction
	return MilSymbolTextLayout.to_instruction(instruction)


static func _outline_color(style: Dictionary, affiliation: Variant) -> Variant:
	var color = style.outlineColor
	if color is Dictionary:
		return color.get(affiliation)
	return color


static func _n(value: Variant) -> String:
	return MilSymbolSvgWriter.num(value)


static func _clone_geometry(g: Dictionary) -> Dictionary:
	var geom := {"type": g.type}
	match g.type:
		"path":
			geom.d = g.d
		"circle":
			geom.cx = g.cx
			geom.cy = g.cy
			geom.r = g.r
	return geom


## Wider stroke-only copy drawn under a shape (src/ms/outline.js).
## With `quirks`, Array property markers become milsymbol's malformed attribute-only element.
static func _outline(geom: Variant, outline: float, stroke: float, color: Variant,
		quirks := false) -> Variant:
	if geom == null:
		return null
	if geom is Array:
		var list: Array = []
		for item in geom:
			if item is Dictionary and item.get("type") == ARRAY_PROPERTY_MARK:
				if quirks:
					list.append({"type": MilSymbolSvgWriter.ATTRIBUTES_ONLY, "strokewidth": stroke + 2 * outline,
							"stroke": color, "fill": false, "linecap": "round"})
				continue
			list.append(_outline(item, outline, stroke, color, quirks))
		return list
	var clone := {}
	for key in geom:
		if key != "fill" and key != "fillopacity":
			clone[key] = geom[key]
	if geom.get("type") in ["translate", "rotate", "scale"]:
		clone.draw = []
		for item in geom.get("draw", []):
			clone.draw.append(_outline(item, outline, stroke, color, quirks))
	else:
		var has_stroke: bool = not (clone.has("stroke") and clone.stroke is bool and not clone.stroke)
		var width := float(clone.get("strokewidth", 0.0))
		if width == 0.0:
			width = stroke
		clone.strokewidth = width + 2 * outline if has_stroke else 2 * outline
		clone.stroke = color
		clone.fill = false
		clone.linecap = "round"
	return clone

#endregion
