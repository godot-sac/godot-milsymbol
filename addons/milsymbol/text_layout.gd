class_name MilSymbolTextLayout
extends RefCounted
## Lays out text with exported Arimo glyph outlines (data/glyphs.json, written by tools/export/glyphs.mjs).
##
## Godot's SVG loader ignores <text>, so strings that are only known at render time are converted
## to path instructions here. Alignment rules mirror tools/export/text-to-path.mjs (textToPathD).

const DATA_PATH := "res://addons/milsymbol/data/glyphs.json"
const STYLE_KEYS: Array[String] = ["fill", "fillopacity", "cssClass"]

static var _fonts: Dictionary = {}  # "regular" / "bold" -> font data, {} until loaded


## Converts a milsymbol text instruction ({type:"text", x, y, text, fontsize, fontweight, textanchor,
## alignmentBaseline, fill, stroke, strokewidth, ...}) into an equivalent drawable instruction:
## translate(anchor position) > scale(fontsize / unitsPerEm) > one translate per glyph > path.
## Returns {} for empty text. Unknown characters use the advance of "?" and draw nothing.
static func to_instruction(text_instruction: Dictionary) -> Dictionary:
	var text := str(text_instruction.get("text", ""))
	if text.strip_edges() == "":
		return {}
	var size := float(text_instruction.get("fontsize", 12))
	var bold: bool = text_instruction.get("fontweight", "") == "bold"
	var font := _font(bold)
	if font.is_empty():
		return {}
	var units: float = font.unitsPerEm
	var factor := size / units

	var x := float(text_instruction.get("x", 0))
	var y := float(text_instruction.get("y", 0))
	var width := _width_units(text, font) * factor
	match str(text_instruction.get("textanchor", "start")):
		"middle":
			x -= width / 2.0
		"end":
			x -= width

	var x_height: float = font.xHeight
	if x_height == 0.0:
		x_height = font.capHeight / 2.0 if font.capHeight != 0.0 else units * 0.26
	match str(text_instruction.get("alignmentBaseline", "")):
		"middle":
			y += x_height * factor / 2.0
		"central":
			y += (font.ascender + font.descender) * factor / 2.0
		"hanging", "text-before-edge", "text-top":
			y += font.ascender * factor

	var style := {}
	for key in STYLE_KEYS:
		if text_instruction.has(key):
			style[key] = text_instruction[key]
	var stroke = text_instruction.get("stroke")
	if stroke is String and stroke != "":
		style["stroke"] = stroke
		if text_instruction.has("strokewidth"):
			style["strokewidth"] = text_instruction["strokewidth"]
		# The scale group would scale the stroke width, so compensate.
		style["non_scaling_stroke"] = 1.0 / factor

	var glyphs: Dictionary = font.glyphs
	var kerning: Dictionary = font.kerning
	var draw: Array = []
	var pen := 0.0
	var previous := ""
	for ch in text:
		var glyph = glyphs.get(ch)
		if glyph == null:
			pen += float(glyphs["?"].advance)
			previous = ""
			continue
		pen += float(kerning.get(previous + ch, 0.0))
		if glyph.d != "":
			var path := style.duplicate()
			path["type"] = "path"
			path["d"] = glyph.d
			draw.append({"type": "translate", "x": pen, "y": 0, "draw": [path]})
		pen += float(glyph.advance)
		previous = ch
	return {"type": "translate", "x": x, "y": y,
			"draw": [{"type": "scale", "factor": factor, "draw": draw}]}


## Width of the string in user units (with kerning), for anchoring and later layout.
static func measure(text: String, fontsize: float, bold: bool) -> float:
	var font := _font(bold)
	if font.is_empty():
		return 0.0
	return _width_units(text, font) * fontsize / float(font.unitsPerEm)


static func _width_units(text: String, font: Dictionary) -> float:
	var glyphs: Dictionary = font.glyphs
	var kerning: Dictionary = font.kerning
	var width := 0.0
	var previous := ""
	for ch in text:
		var glyph = glyphs.get(ch)
		if glyph == null:
			width += float(glyphs["?"].advance)
			previous = ""
			continue
		width += float(kerning.get(previous + ch, 0.0)) + float(glyph.advance)
		previous = ch
	return width


static func _font(bold: bool) -> Dictionary:
	if _fonts.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_fonts = parsed if parsed is Dictionary else {}
	return _fonts.get("bold" if bold else "regular", {})
