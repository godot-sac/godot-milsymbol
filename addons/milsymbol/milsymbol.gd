class_name MilSymbol
extends RefCounted
## Renders MIL-STD-2525 / APP-6 symbols from number based SIDCs.
##
##   var texture := MilSymbol.create_texture("10031000141211000000", {"size": 60})
##   var render := MilSymbol.render("10061000000000000000")  # SVG, size, anchor, metadata
##
## Port of milsymbol 3.0.5 (src/ms/symbol/setoptions.js and the symbol parts in src/symbolfunctions/).
## Phase 2: frames only (base geometry, colors, outline, dashed "not present" frames).

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
}

const AFFILIATIONS := ["Civilian", "Friend", "Hostile", "Neutral", "Unknown", "Suspect"]

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

	var result := MilSymbolRender.new()
	result.sidc = sidc
	result.style = style
	result.metadata = metadata

	var instructions: Array = []
	var bbox := {"x1": 100.0, "y1": 100.0, "x2": 100.0, "y2": 100.0}
	# Symbol parts in milsymbol's order: pre is drawn underneath everything so far, post on top.
	var parts: Array[Dictionary] = [
		_part_base_geometry(metadata, style, colors),
	]
	for m in parts:
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
	result.valid = _is_valid(metadata)
	var view_box := Rect2(bbox.x1 - margin, bbox.y1 - margin, base_size.x, base_size.y)
	result.svg = MilSymbolSvgWriter.write(instructions, style, view_box, result.size)
	return result


## Shortcut for render(sidc, options).to_texture().
static func create_texture(sidc: String, options: Dictionary = {}) -> ImageTexture:
	return render(sidc, options).to_texture()


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
	return not metadata.baseGeometry.g.is_empty()


static func _merge_bbox(bbox: Dictionary, other: Dictionary) -> void:
	bbox.x1 = minf(bbox.x1, other.x1)
	bbox.y1 = minf(bbox.y1, other.y1)
	bbox.x2 = maxf(bbox.x2, other.x2)
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
static func _outline(geom: Variant, outline: float, stroke: float, color: Variant) -> Variant:
	if geom is Array:
		var list: Array = []
		for item in geom:
			list.append(_outline(item, outline, stroke, color))
		return list
	var clone := {}
	for key in geom:
		if key != "fill" and key != "fillopacity":
			clone[key] = geom[key]
	if geom.get("type") in ["translate", "rotate", "scale"]:
		clone.draw = []
		for item in geom.get("draw", []):
			clone.draw.append(_outline(item, outline, stroke, color))
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
