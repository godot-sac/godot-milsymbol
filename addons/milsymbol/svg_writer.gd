class_name MilSymbolSvgWriter
extends RefCounted
## Turns milsymbol draw instructions (nested Arrays / Dictionaries) into SVG text.
## Port of milsymbol src/ms/symbol/assvg.js. See docs/draw-instructions.md for the format.

const SVG_NS := "http://www.w3.org/2000/svg"
const CONTAINER_TYPES := ["translate", "rotate", "scale", "clip"]
## Writes only the style attributes and " >", without a tag, like assvg.js does for an instruction
## without a type (milsymbolQuirks output of outline.js).
const ATTRIBUTES_ONLY := "milsymbolAttributesOnly"


## `style` needs strokeWidth and styleFill. `view_box` is (x, y, w, h); `size` is width/height in pixels.
static func write(instructions: Array, style: Dictionary, view_box: Rect2, size: Vector2) -> String:
	var state := {"clip_counter": 0}
	var xml := "<svg"
	xml += _attr("xmlns", SVG_NS)
	xml += _attr("version", "1.2")
	xml += _attr("baseProfile", "tiny")
	xml += _attr("width", num(size.x))
	xml += _attr("height", num(size.y))
	xml += _attr("viewBox", "%s %s %s %s" % [num(view_box.position.x), num(view_box.position.y),
			num(view_box.size.x), num(view_box.size.y)])
	xml += ">"
	xml += _process(instructions, style, state)
	xml += "</svg>"
	return xml


## Formats a number the way JavaScript's String(number) does for typical values: 25, 18.5, 203.1666.
static func num(value: Variant) -> String:
	var f := float(value)
	if f == roundf(f) and absf(f) < 1e15:
		return str(int(f))
	return String.num(f, 12)


static func _process(instructions: Array, style: Dictionary, state: Dictionary) -> String:
	var out := ""
	for item in instructions:
		if item is Array:
			if not item.is_empty():
				out += _process(item, style, state)
		elif item is Dictionary:
			out += _element(item, style, state)
	return out


static func _element(i: Dictionary, style: Dictionary, state: Dictionary) -> String:
	var type: String = i.get("type", "")
	if type == "svg":
		return str(i.get("svg", ""))

	var svg := ""
	var inline_clip_id := ""
	if i.has("clipPath") and type != "clip":
		inline_clip_id = "clip-inline-%d" % state.clip_counter
		state.clip_counter += 1
		svg += "<clipPath" + _attr("id", inline_clip_id) + ">"
		svg += "<path" + _attr("d", i.clipPath) + _attr("clip-rule", "nonzero") + " />"
		svg += "</clipPath>"

	var clip_attr := _attr("clip-path", "url(#%s)" % inline_clip_id) if inline_clip_id != "" else ""
	match type:
		"path":
			svg += "<path" + _attr("d", i.get("d", "")) + clip_attr
		"circle":
			svg += "<circle" + _attr("cx", num(i.get("cx", 0))) + _attr("cy", num(i.get("cy", 0)))
			svg += _attr("r", num(i.get("r", 0))) + clip_attr
		"text":
			svg += "<text" + _attr("x", num(i.get("x", 0))) + _attr("y", num(i.get("y", 0)))
			svg += _attr("text-anchor", i.get("textanchor", "start"))
			svg += _attr("font-size", num(i.get("fontsize", 12)))
			svg += _attr("font-family", i.get("fontfamily", "sans-serif"))
			if i.get("fontweight"):
				svg += _attr("font-weight", i.fontweight)
			if i.get("alignmentBaseline"):
				svg += _attr("dominant-baseline", i.alignmentBaseline)
			svg += clip_attr
		"translate":
			svg += "<g" + _attr("transform", "translate(%s,%s)" % [num(i.get("x", 0)), num(i.get("y", 0))]) + clip_attr
		"rotate":
			svg += "<g" + _attr("transform", "rotate(%s,%s,%s)" % [num(i.get("degree", 0)),
					num(i.get("x", 0)), num(i.get("y", 0))]) + clip_attr
		"scale":
			svg += "<g" + _attr("transform", "scale(%s)" % num(i.get("factor", 1))) + clip_attr
		ATTRIBUTES_ONLY:
			pass
		"clip":
			var clip_id: String = i.get("clipId", "")
			if clip_id == "":
				clip_id = "clip-custom-%d" % state.clip_counter
				state.clip_counter += 1
			svg += "<clipPath" + _attr("id", clip_id) + ">"
			svg += "<path" + _attr("d", i.get("d", "")) + _attr("clip-rule", "nonzero") + " />"
			svg += "</clipPath>"
			svg += "<g" + _attr("clip-path", "url(#%s)" % clip_id)
		_:
			return ""

	if i.has("stroke"):
		var width_setting := float(i.get("strokewidth", style.strokeWidth))
		svg += _attr("stroke-width", num(float(i.get("non_scaling_stroke", 1)) * width_setting))
		if i.get("strokedasharray"):
			svg += _attr("stroke-dasharray", i.strokedasharray)
		if i.get("linecap"):
			svg += _attr("stroke-linecap", i.linecap)
			svg += _attr("stroke-linejoin", i.linecap)
		svg += _attr("stroke", _paint(i.stroke))
	if i.has("fill"):
		var fill = i.fill
		if i.get("styleFill") and style.styleFill:
			fill = "rgba(255,255,255,0.4)"
		svg += _attr("fill", _paint(fill))
	if i.has("fillopacity"):
		svg += _attr("fill-opacity", num(clampf(float(i.fillopacity), 0.0, 1.0)))
	if i.get("cssClass"):
		svg += _attr("class", i.cssClass)
	svg += " >"

	match type:
		"path":
			svg += "</path>"
		"circle":
			svg += "</circle>"
		"text":
			svg += _escape_text(str(i.get("text", ""))) + "</text>"
		_:
			if type in CONTAINER_TYPES:
				svg += _process(i.get("draw", []), style, state) + "</g>"
	return svg


## false, null and "" mean "no paint".
static func _paint(value: Variant) -> String:
	if value == null or (value is bool and not value) or (value is String and value == ""):
		return "none"
	return str(value)


static func _attr(name: String, value: Variant) -> String:
	return " %s=\"%s\"" % [name, _escape_attr(str(value))]


static func _escape_attr(value: String) -> String:
	return value.replace("&", "&amp;").replace("\"", "&quot;").replace("'", "&apos;") \
			.replace("<", "&lt;").replace(">", "&gt;").replace("\r", " ").replace("\n", " ").replace("\t", " ")


static func _escape_text(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
