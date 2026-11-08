class_name MilSymbolAmplifiers
extends RefCounted
## Text amplifier fields and the direction of movement indicator around point symbols.
##
## Ports of milsymbol 3.0.5 src/symbolfunctions/textfields.js, directionarrow.js and string-width.js,
## used by MilSymbol.render(). Text is laid out like milsymbol does it: fixed rows left and right of the frame,
## widths estimated from a per-character table (not from the font), so symbols match milsymbol's bounds exactly.

## Distance between the frame and the text fields.
const SPACE_TEXT_ICON := 20.0
const CSS_CLASS := "milsymbol-textfields"
## Length of the direction of movement indicator in symbol units (one frame height).
const ARROW_LENGTH := 95.0
## Character widths at font size 30 (src/symbolfunctions/string-width.js), grouped by width.
## Characters that are not listed count as 28.5, the width of "W".
const STRING_WIDTH_GROUPS := {
	"'": 7,
	"ijl": 8,
	"|": 9,
	" !,./:;[]Ift": 10,
	"()-`r": 11,
	"\"{}": 12,
	"*г": 13,
	"к": 15,
	"^зт": 16,
	"Jcksvxyzсухэ": 17,
	"вГпчья": 18,
	"0123456789#$?_Labdeghnopquабеёийнорц": 19,
	"+<=>~дЗКл": 20,
	"FTZТУъ": 21,
	"БЛЧЬ": 22,
	"&ABEKPSVXYАВДЕЁжмРХ": 23,
	"CDHNRUwИЙНПСыЭЯ": 24,
	"Цю": 25,
	"GOQОФ": 26,
	"шЪ": 27,
	"MmМфщ": 28,
	"%Ы": 30,
	"ЖШЩ": 31,
	"W": 32,
	"@Ю": 34,
}
const UNKNOWN_CHAR_WIDTH := 28.5

## Option names that make text fields appear (milsymbol's list).
const TEXT_FIELD_OPTIONS: Array[String] = ["quantity", "reinforcedReduced", "staffComments", "additionalInformation",
	"evaluationRating", "combatEffectiveness", "signatureEquipment", "higherFormation", "hostile", "iffSif", "sigint",
	"uniqueDesignation", "type", "dtg", "altitudeDepth", "location", "speed", "specialHeadquarters", "platformType",
	"equipmentTeardownTime", "commonIdentifier", "auxiliaryEquipmentIndicator", "headquartersElement",
	"installationComposition", "guardedUnit", "specialDesignator"]

static var _char_widths: Dictionary = {}


## Width of `text` in symbol units at `font_size`, plus `space` (milsymbol's strWidth). Empty text is 0.
static func string_width(text: String, font_size: float, space: float) -> float:
	if text.is_empty():
		return 0.0
	if _char_widths.is_empty():
		for chars: String in STRING_WIDTH_GROUPS:
			for c in chars:
				_char_widths[c] = float(STRING_WIDTH_GROUPS[chars])
	var w := 0.0
	for c in text:
		w += font_size / 30.0 * float(_char_widths.get(c, UNKNOWN_CHAR_WIDTH))
	return w + space


## Text value of an option as milsymbol sees it: "" for missing, null, false, 0 and empty strings.
static func option(options: Dictionary, key: String) -> String:
	var value = options.get(key)
	if value == null or (value is bool and not value) or ((value is int or value is float) and value == 0):
		return ""
	if value is float and value == roundf(value):
		return str(int(value))
	return str(value)


static func _join(options: Dictionary, keys: Array) -> String:
	var parts: PackedStringArray = []
	for key in keys:
		var value := option(options, key)
		if value != "":
			parts.append(value)
	return "/".join(parts)


## Text fields part (textfields.js). `letter_sidc` is true when the caller passed a letter based SIDC
## (milsymbol lays those out like land symbols).
static func text_fields(metadata: Dictionary, style: Dictionary, colors: Dictionary, options: Dictionary,
		letter_sidc: bool) -> Dictionary:
	var pre: Array = []
	var post: Array = []
	var bbox: Dictionary = metadata.baseGeometry.bbox
	var gbbox := {"x1": 100.0, "y1": 100.0, "x2": 100.0, "y2": 100.0}
	var affiliation = metadata.affiliation

	var flag := 70.0 if option(options, "country_flag") != "" else 0.0
	if option(options, "full_frame_flag") != "" and affiliation == "Friend" and metadata.dimension == "Ground":
		flag = 0.0
	flag += 30.0 if option(options, "signature") == "!" else 0.0
	var stack := float(options.get("stack", 0)) * 15.0 if option(options, "stack") != "" else 0.0

	var font_color = _by_affiliation(style.infoColor, affiliation)
	if _empty_color(font_color):
		font_color = colors.iconColor.get(affiliation)
	if _empty_color(font_color):
		font_color = colors.iconColor.get("Friend")
	var font_family = style.fontfamily
	var font_size := float(style.infoSize)
	var info_background = _by_affiliation(style.infoBackground, affiliation)
	# milsymbol 3.0.5 takes the frame color of the background boxes from infoBackground too.
	var info_background_frame = info_background

	var any_field := false
	for key in TEXT_FIELD_OPTIONS:
		if option(options, key) != "":
			any_field = true
			break
	if not (style.infoFields and any_field):
		return {"pre": pre, "post": post, "bbox": gbbox}

	var x1 := float(bbox.x1)
	var x2 := float(bbox.x2)
	var y1 := float(bbox.y1)
	var y2 := float(bbox.y2)
	var frame_width := x2 - x1
	var number_sidc := not letter_sidc

	var special_hq := option(options, "specialHeadquarters")
	if special_hq != "":
		var size := 45.0
		if special_hq.length() == 3:
			size = 39.0
		elif special_hq.length() >= 4:
			size = 33.0
		post.append({"type": "text", "stroke": false, "textanchor": "middle", "alignmentBaseline": "middle",
				"x": 100, "y": 103, "fontsize": size, "text": special_hq, "fontweight": "bold",
				"fontfamily": font_family, "fill": font_color})
	var quantity := option(options, "quantity")
	if quantity != "" and not metadata.get("dismounted", false):
		post.append(_field(quantity, 100, y1 - 10, "middle", font_size, font_family, font_color))
		gbbox.y1 = y1 - 10 - font_size
	var hq_element := option(options, "headquartersElement")
	if hq_element != "":
		post.append({"type": "text", "text": hq_element, "x": 100, "y": y2 + 35, "textanchor": "middle",
				"fontsize": 35, "fontfamily": font_family, "fontweight": "bold", "fill": font_color, "stroke": false})
		gbbox.y2 = y2 + 35

	var g := {"L1": "", "L2": "", "L3": "", "L4": "", "L5": "", "R1": "", "R2": "", "R3": "", "R4": "", "R5": ""}
	var base_dimension = metadata.baseDimension
	if number_sidc and base_dimension == "Air":
		g.R1 = option(options, "uniqueDesignation")
		g.R2 = option(options, "iffSif")
		g.R3 = option(options, "type")
		g.R4 = _join(options, ["speed", "altitudeDepth"])
		g.R5 = _join(options, ["staffComments", "additionalInformation"])
	if letter_sidc or base_dimension == "Ground":
		g.L1 = option(options, "dtg")
		g.L2 = _join(options, ["altitudeDepth", "location"])
		g.L4 = option(options, "uniqueDesignation")
		g.L5 = option(options, "speed")
		g.R2 = option(options, "staffComments")
		g.R4 = option(options, "higherFormation")
		g.R5 = _join(options, ["evaluationRating", "combatEffectiveness", "signatureEquipment", "hostile", "iffSif"])
		if letter_sidc or metadata.get("unit", false):
			g.L3 = _join(options, ["type", "platformType", "equipmentTeardownTime"])
			g.R1 = option(options, "reinforcedReduced")
			if metadata.get("activity", false):
				g.R1 = option(options, "country")
			g.R3 = _join(options, ["additionalInformation", "commonIdentifier"])
		else:
			g.L3 = _join(options, ["type", "platformType", "commonIdentifier", "installationComposition"])
			g.R1 = option(options, "country")
			g.R3 = _join(options, ["additionalInformation", "equipmentTeardownTime"])
	if metadata.get("dismounted", false):
		if quantity != "":
			post.append(_field(quantity, 100, y2 + font_size, "middle", font_size, font_family, font_color))
			gbbox.y2 = y2 + font_size
		g.L1 = option(options, "dtg")
		g.L2 = _join(options, ["altitudeDepth", "location"])
		g.L3 = _join(options, ["type", "platformType", "commonIdentifier"])
		g.L4 = option(options, "uniqueDesignation")
		g.L5 = option(options, "speed")
		g.R1 = option(options, "country")
		g.R2 = option(options, "staffComments")
		g.R3 = option(options, "additionalInformation")
		g.R4 = option(options, "higherFormation")
		g.R5 = _join(options, ["evaluationRating", "combatEffectiveness", "signatureEquipment", "hostile", "iffSif"])
	if number_sidc and base_dimension == "Sea":
		g.L1 = _join(options, ["guardedUnit", "specialDesignator"])
		g.R1 = option(options, "uniqueDesignation")
		g.R2 = option(options, "type")
		g.R3 = option(options, "iffSif")
		g.R4 = _join(options, ["staffComments", "additionalInformation"])
		g.R5 = _join(options, ["location", "speed"])
	if number_sidc and base_dimension == "Subsurface":
		g.L1 = option(options, "specialDesignator")
		g.R1 = option(options, "uniqueDesignation")
		g.R2 = option(options, "type")
		g.R3 = option(options, "altitudeDepth")
		g.R4 = option(options, "staffComments")
		g.R5 = option(options, "additionalInformation")

	# Room for the fields left and right of the frame.
	var centered := 0.0
	if special_hq != "":
		centered = (string_width(special_hq, font_size, SPACE_TEXT_ICON) - frame_width) / 2.0
	if quantity != "":
		centered = maxf(centered, (string_width(quantity, font_size, SPACE_TEXT_ICON) - frame_width) / 2.0)
	var left := centered
	var right := centered
	for row in ["L1", "L2", "L3", "L4", "L5"]:
		left = maxf(left, string_width(g[row], font_size, SPACE_TEXT_ICON))
	for row in ["R1", "R2", "R3"]:
		right = maxf(right, string_width(g[row], font_size, SPACE_TEXT_ICON + stack))
	for row in ["R4", "R5"]:
		right = maxf(right, string_width(g[row], font_size, SPACE_TEXT_ICON + stack + flag * 1.5))
	gbbox.x1 = x1 - left
	gbbox.x2 = x2 + right
	if g.L1 != "" or g.R1 != "":
		gbbox.y1 = minf(gbbox.y1, 100 - 2.5 * font_size)
	if g.L2 != "" or g.R2 != "":
		gbbox.y1 = minf(gbbox.y1, 100 - 1.5 * font_size)
	if g.L4 != "" or g.R4 != "":
		gbbox.y2 = maxf(gbbox.y2, 100 + 1.7 * font_size)
	if g.L5 != "" or g.R5 != "":
		gbbox.y2 = maxf(gbbox.y2, 100 + 2.7 * font_size)

	# Rows 1-5 sit at these offsets (times the font size) from the symbol center.
	var row_y: Array[float] = [-1.5, -0.5, 0.5, 1.5, 2.5]
	if not _empty_color(info_background):
		var left_box := {}
		var right_box := {}
		for i in 5:
			var top: float = 100 + (row_y[i] - 1.0) * font_size
			var bottom: float = 100 + row_y[i] * font_size + SPACE_TEXT_ICON / 2.0
			var l: String = g["L%d" % (i + 1)]
			if l != "":
				left_box = {"x1": minf(left_box.get("x1", 100.0), x1 - string_width(l, font_size, SPACE_TEXT_ICON)),
						"x2": x1 - SPACE_TEXT_ICON / 2.0, "y1": minf(left_box.get("y1", 1000.0), top),
						"y2": maxf(left_box.get("y2", 0.0), bottom)}
			var r: String = g["R%d" % (i + 1)]
			if r != "":
				right_box = {"x1": x2 + SPACE_TEXT_ICON / 2.0,
						"x2": maxf(right_box.get("x2", 100.0), x2 + string_width(r, font_size, SPACE_TEXT_ICON)),
						"y1": minf(right_box.get("y1", 1000.0), top), "y2": maxf(right_box.get("y2", 0.0), bottom)}
		var half := font_size / 2.0
		if not left_box.is_empty():
			gbbox.x1 -= half
			post.append({"type": "path", "fill": info_background,
					"stroke": info_background_frame if not _empty_color(info_background_frame) else false,
					"d": "M %s,%s %s,%s %s,%s %s,%s %s,%sz" % [_n(left_box.x1 - half), _n(left_box.y1 + half),
						_n(left_box.x1), _n(left_box.y1), _n(left_box.x2), _n(left_box.y1), _n(left_box.x2),
						_n(left_box.y2), _n(left_box.x1 - half), _n(left_box.y2)]})
		if not right_box.is_empty():
			gbbox.x2 += half
			post.append({"type": "path", "fill": info_background,
					"stroke": info_background_frame if not _empty_color(info_background_frame) else false,
					"d": "M %s,%s %s,%s %s,%s %s,%s %s,%sz" % [_n(right_box.x1), _n(right_box.y1),
						_n(right_box.x2 + half), _n(right_box.y1), _n(right_box.x2 + half), _n(right_box.y2 - half),
						_n(right_box.x2), _n(right_box.y2), _n(right_box.x1), _n(right_box.y2)]})

	for i in 5:
		var l: String = g["L%d" % (i + 1)]
		if l != "":
			post.append(_field(l, x1 - SPACE_TEXT_ICON, 100 + row_y[i] * font_size, "end", font_size, font_family,
					font_color))
	for i in 5:
		var r: String = g["R%d" % (i + 1)]
		if r != "":
			var x := x2 + SPACE_TEXT_ICON + stack + (flag if i >= 3 else 0.0)
			post.append(_field(r, x, 100 + row_y[i] * font_size, "start", font_size, font_family, font_color))

	for i in post.size():
		if post[i].get("type") == "text":
			post[i] = MilSymbol._text(post[i], style)

	var info_outline = style.infoOutlineWidth
	var outline_width := 0.0
	if info_outline is bool:
		if not info_outline:
			outline_width = float(style.outlineWidth)
	else:
		outline_width = float(info_outline)
	if outline_width > 0:
		var outline_color = style.infoOutlineColor
		if _empty_color(outline_color):
			outline_color = MilSymbol._outline_color(style, affiliation)
		pre.append(MilSymbol._outline(post, outline_width, style.strokeWidth, outline_color))
	return {"pre": pre, "post": post, "bbox": gbbox}


## Direction of movement indicator or speed leader (directionarrow.js). `symbol_bbox` is the bounds of the parts
## drawn so far, used when the symbol has no frame.
static func direction_arrow(metadata: Dictionary, style: Dictionary, colors: Dictionary, options: Dictionary,
		symbol_bbox: Dictionary) -> Dictionary:
	var pre: Array = []
	var post: Array = []
	var gbbox := {"x1": 100.0, "y1": 100.0, "x2": 100.0, "y2": 100.0}
	var direction = options.get("direction")
	if not style.infoFields or direction == null or (direction is String and direction == ""):
		return {"pre": pre, "post": post, "bbox": gbbox}
	var degrees := float(direction)
	var bbox: Dictionary = metadata.baseGeometry.bbox
	if metadata.baseGeometry.g.is_empty():
		bbox = symbol_bbox
	var color = colors.iconColor.get(metadata.affiliation)
	if _empty_color(color):
		color = colors.iconColor.get("Friend")
	var stroke_width := float(style.strokeWidth)
	var speed_leader := float(options.get("speedLeader", 0))
	var arrow: Variant
	if speed_leader == 0:
		arrow = [{"type": "rotate", "degree": degrees, "x": 100, "y": 100, "draw": [
			{"type": "path", "fill": color, "stroke": color, "strokewidth": style.strokeWidth,
				"d": "M100,100 l0,-%s -5,3 5,-15 5,15 -5,-3" % _n(ARROW_LENGTH - 20)}]}]
		var tip := Vector2(100 + sin(degrees / 360.0 * TAU) * ARROW_LENGTH,
				100 - cos(degrees / 360.0 * TAU) * ARROW_LENGTH)
		gbbox = {"x1": minf(tip.x, 100), "y1": minf(tip.y, 100), "x2": maxf(tip.x, 100), "y2": maxf(tip.y, 100)}
		if metadata.baseDimension == "Ground" or metadata.baseDimension == "":
			if not metadata.get("headquarters", false):
				arrow = [{"type": "translate", "x": 0, "y": bbox.y2, "draw": arrow},
					{"type": "path", "fill": color, "stroke": color, "strokewidth": style.strokeWidth,
						"d": "M 100,%sl0,100" % _n(bbox.y2)}]
			else:
				var staff: float = style.hqStaffLength if style.hqStaffLength else MilSymbol._hq_staff_length
				arrow = [{"type": "translate", "x": float(bbox.x1) - 100, "y": float(bbox.y2) - (100 - staff),
					"draw": arrow}]
				gbbox.x1 += float(bbox.x1) - 100
				gbbox.x2 += float(bbox.x1) - 100
		gbbox.y2 += float(bbox.y2) + stroke_width
		post.append(arrow)
	else:
		var length := speed_leader * (100.0 / float(style.size))
		var rad := deg_to_rad(degrees)
		var y := -length * cos(rad)
		var x := length * sin(rad)
		gbbox = {"x1": minf(100, 100 + x), "x2": maxf(100, 100 + x), "y1": minf(100, 100 + y),
			"y2": maxf(100, 100 + y)}
		arrow = {"type": "path", "fill": color, "stroke": color, "strokewidth": style.strokeWidth,
			"d": "M 100,100  l%s,%s" % [_n(x), _n(y)]}
		pre.append(arrow)
	if style.outlineWidth > 0:
		pre.push_front(MilSymbol._outline(arrow, style.outlineWidth, style.strokeWidth,
				MilSymbol._outline_color(style, metadata.affiliation)))
	return {"pre": pre, "post": post, "bbox": gbbox}


static func _field(text: String, x: float, y: float, anchor: String, font_size: float, font_family: Variant,
		fill: Variant) -> Dictionary:
	return {"type": "text", "text": text, "x": x, "y": y, "textanchor": anchor, "fontsize": font_size,
		"fontfamily": font_family, "fill": fill, "stroke": false, "cssClass": CSS_CLASS}


static func _by_affiliation(value: Variant, affiliation: Variant) -> Variant:
	if value is Dictionary:
		return value.get(affiliation)
	return value


static func _empty_color(value: Variant) -> bool:
	return value == null or (value is bool and not value) or (value is String and value == "")


static func _n(value: Variant) -> String:
	return MilSymbolSvgWriter.num(value)
