extends RefCounted
## Compares two SVG documents structurally, the way golden tests need it.
##
## Both documents are parsed into element trees. Attribute order, whitespace,
## number formatting (203.16666666666663 vs 203.167) and color spelling
## (black / #000000 / rgb(0,0,0)) are ignored. Numbers match within a tolerance.
## Usage:
##   const SvgCompare = preload("res://tests/helpers/svg_compare.gd")
##   var problems := SvgCompare.diff(expected_svg, actual_svg)
##   assert_eq(problems.size(), 0, "\n".join(problems))

const DEFAULT_TOLERANCE := 0.01
const DEFAULT_IGNORED_ATTRS: Array[String] = ["class"]
const COLOR_ATTRS: Array[String] = ["fill", "stroke"]
const MAX_REPORTED := 20

static var _number_regex: RegEx


## Parses an SVG string into {tag, attrs, text, children}. Returns {} on parse error.
static func parse(svg: String) -> Dictionary:
	var parser := XMLParser.new()
	if parser.open_buffer(svg.to_utf8_buffer()) != OK:
		return {}
	var root := {}
	var stack: Array[Dictionary] = []
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node := {"tag": parser.get_node_name(), "attrs": {}, "text": "", "children": []}
				for i in parser.get_attribute_count():
					node.attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
				if stack.is_empty():
					root = node
				else:
					stack.back().children.append(node)
				if not parser.is_empty():
					stack.push_back(node)
			XMLParser.NODE_ELEMENT_END:
				if not stack.is_empty():
					stack.pop_back()
			XMLParser.NODE_TEXT:
				if not stack.is_empty():
					stack.back().text += parser.get_node_data()
	return root


## Returns a list of human-readable differences; empty means the documents match.
static func diff(
		expected: String,
		actual: String,
		tolerance: float = DEFAULT_TOLERANCE,
		ignored_attrs: Array[String] = DEFAULT_IGNORED_ATTRS) -> PackedStringArray:
	var problems := PackedStringArray()
	var a := parse(expected)
	var b := parse(actual)
	if a.is_empty():
		problems.append("expected SVG could not be parsed")
	if b.is_empty():
		problems.append("actual SVG could not be parsed")
	if problems.is_empty():
		_diff_node(a, b, a.tag, tolerance, ignored_attrs, problems)
	if problems.size() > MAX_REPORTED:
		var extra := problems.size() - MAX_REPORTED
		problems = problems.slice(0, MAX_REPORTED)
		problems.append("... and %d more" % extra)
	return problems


## Fraction (0..1) of pixels whose RGBA differs by more than channel_tolerance (0..255).
## Images of different size return 1.0.
static func pixel_mismatch_ratio(expected: Image, actual: Image, channel_tolerance: int = 8) -> float:
	if expected.get_size() != actual.get_size():
		return 1.0
	var width := expected.get_width()
	var height := expected.get_height()
	if width == 0 or height == 0:
		return 0.0
	var bad := 0
	for y in height:
		for x in width:
			var p := expected.get_pixel(x, y)
			var q := actual.get_pixel(x, y)
			if (absi(p.r8 - q.r8) > channel_tolerance or absi(p.g8 - q.g8) > channel_tolerance
					or absi(p.b8 - q.b8) > channel_tolerance or absi(p.a8 - q.a8) > channel_tolerance):
				bad += 1
	return float(bad) / float(width * height)


## Rasterizes an SVG with Godot's loader. Returns null if loading fails.
static func rasterize(svg: String, scale: float = 1.0) -> Image:
	var image := Image.new()
	if image.load_svg_from_string(svg, scale) != OK:
		return null
	return image


static func _diff_node(
		a: Dictionary, b: Dictionary, path: String, tolerance: float,
		ignored_attrs: Array[String], problems: PackedStringArray) -> void:
	if a.tag != b.tag:
		problems.append("%s: tag <%s> != <%s>" % [path, a.tag, b.tag])
		return

	var names := {}
	for key in a.attrs:
		names[key] = true
	for key in b.attrs:
		names[key] = true
	var sorted_names := names.keys()
	sorted_names.sort()
	for name: String in sorted_names:
		if name in ignored_attrs:
			continue
		if not a.attrs.has(name):
			problems.append("%s@%s: unexpected (actual \"%s\")" % [path, name, b.attrs[name]])
		elif not b.attrs.has(name):
			problems.append("%s@%s: missing (expected \"%s\")" % [path, name, a.attrs[name]])
		elif not _values_match(name, a.attrs[name], b.attrs[name], tolerance):
			problems.append("%s@%s: \"%s\" != \"%s\"" % [path, name, a.attrs[name], b.attrs[name]])

	var text_a: String = a.text.strip_edges()
	var text_b: String = b.text.strip_edges()
	if text_a != text_b:
		problems.append("%s: text \"%s\" != \"%s\"" % [path, text_a, text_b])

	var children_a: Array = a.children
	var children_b: Array = b.children
	if children_a.size() != children_b.size():
		problems.append("%s: %d children != %d" % [path, children_a.size(), children_b.size()])
	for i in mini(children_a.size(), children_b.size()):
		var child_path := "%s/%s[%d]" % [path, children_a[i].tag, i]
		_diff_node(children_a[i], children_b[i], child_path, tolerance, ignored_attrs, problems)


static func _values_match(name: String, a: String, b: String, tolerance: float) -> bool:
	if name in COLOR_ATTRS:
		var color_a = _parse_color(a)
		var color_b = _parse_color(b)
		if color_a != null and color_b != null:
			return _colors_match(color_a, color_b)
	var tokens_a := _tokenize(a)
	var tokens_b := _tokenize(b)
	if tokens_a.size() != tokens_b.size():
		return false
	for i in tokens_a.size():
		var ta = tokens_a[i]
		var tb = tokens_b[i]
		if typeof(ta) != typeof(tb):
			return false
		if ta is float:
			if absf(ta - tb) > tolerance:
				return false
		elif ta != tb:
			return false
	return true


## Splits a value into numbers (float) and the non-separator text between them (String).
## Whitespace and commas are separators: "M25,50 l150,0" and "M 25 50 l 150 0" tokenize the same.
static func _tokenize(value: String) -> Array:
	if _number_regex == null:
		_number_regex = RegEx.create_from_string("[-+]?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
	var tokens := []
	var pos := 0
	for m in _number_regex.search_all(value):
		_append_text_tokens(value.substr(pos, m.get_start() - pos), tokens)
		tokens.append(m.get_string().to_float())
		pos = m.get_end()
	_append_text_tokens(value.substr(pos), tokens)
	return tokens


static func _append_text_tokens(text: String, tokens: Array) -> void:
	var cleaned := text.replace(",", " ").strip_edges()
	for part in cleaned.split(" ", false):
		tokens.append(part)


## Returns a Color, "none" for no paint, or null if the value is not a recognizable color.
static func _parse_color(value: String) -> Variant:
	var v := value.strip_edges().to_lower()
	if v == "none" or v == "transparent":
		return "none"
	if (v.begins_with("rgb(") or v.begins_with("rgba(")) and v.ends_with(")"):
		var open := v.find("(")
		var parts := v.substr(open + 1, v.length() - open - 2).split(",")
		if parts.size() < 3:
			return null
		var alpha := 1.0 if parts.size() < 4 else parts[3].strip_edges().to_float()
		return Color8(parts[0].strip_edges().to_int(), parts[1].strip_edges().to_int(),
				parts[2].strip_edges().to_int(), roundi(alpha * 255.0))
	# Hex (#rgb, #rrggbb) and named colors (black, white, ...).
	var sentinel := Color(0, 0, 0, -1)
	var parsed := Color.from_string(v, sentinel)
	return null if parsed == sentinel else parsed


static func _colors_match(a: Variant, b: Variant) -> bool:
	if a is String or b is String:
		return a is String and b is String
	return (absi(a.r8 - b.r8) <= 1 and absi(a.g8 - b.g8) <= 1
			and absi(a.b8 - b.b8) <= 1 and absi(a.a8 - b.a8) <= 1)
