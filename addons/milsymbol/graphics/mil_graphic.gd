class_name MilGraphic
extends RefCounted
## Multipoint control measures (tactical graphics): MIL-STD-2525D/E and APP-6D symbol set 25 lines and areas.
##
## MilGraphic.build(sidc, points, amplifiers, options) turns control points into drawing primitives
## (MilGraphicShape); MilGraphicRenderer draws them on a CanvasItem or writes SVG. Points are in any 2D plane
## with y growing downwards (normally screen pixels); distances in amplifiers ("AM") use the same units.
##
## Control point order follows the standard: lines from the first to the last point; areas are closed
## automatically; Axis of Advance: tip, then the centreline to the rear, then one point on the edge of the
## arrowhead that sets its width and length; Direction of Attack: tip first; rectangular fire areas: two points on
## the centre line + AM (width); circular fire areas: centre + AM (radius).
## Geometry is our own; the shapes follow the mil-sym-ts renderer (Apache-2.0) as an algorithm reference,
## see THIRD_PARTY_NOTICES.md and docs/control-measures.md.

const Geo = preload("res://addons/milsymbol/graphics/graphic_geometry.gd")
const DATA_FILE := "res://addons/milsymbol/data/control_measures.json"

## Options for build().
const DEFAULTS := {
	"scale": 1.0,  # multiplies every pixel-size constant (teeth, scallops, arrowheads, text)
	"text_size": 14.0,
	"line_width": 2.0,  # used for hatch spacing; the renderer draws with its own width
	"standard": "",  # "APP6" selects the APP-6D table for version 10/11 SIDCs
	"font": null,  # Font used to measure labels; default ThemeDB.fallback_font
}

## APP-6D subtypes that 2525D Ch1 / 2525E express with standard identity and status instead:
## code -> [code drawn, colour role ("" = from the SIDC), dashed, feint].
const SUBTYPE_ALIASES := {
	"140101": ["140100", "friend", false, false],
	"140102": ["140100", "friend", true, false],
	"140103": ["140100", "hostile", false, false],
	"140104": ["140100", "hostile", true, false],
	"140604": ["140603", "friend", true, false],
	"140605": ["140603", "", false, true],
	"140606": ["140603", "hostile", false, false],
	"140607": ["140603", "hostile", true, false],
	"150101": ["150100", "friend", false, false],
	"150102": ["150100", "friend", true, false],
	"150103": ["150100", "hostile", false, false],
	"150104": ["150100", "hostile", true, false],
	"151405": ["151404", "friend", true, false],
	"151406": ["151404", "", false, true],
	"151407": ["151404", "hostile", false, false],
	"151408": ["151404", "hostile", true, false],
	"110101": ["110100", "", false, false],
	"110102": ["110100", "", false, false],
	"110103": ["110100", "", false, false],
	"150300": ["150200", "", false, false],
	"170101": ["170100", "", false, false],
}

## Echelon amplifier text on boundaries (SIDC digits 9-10).
const ECHELON_TEXT := {
	"11": "Ø", "12": "•", "13": "••", "14": "•••", "15": "I", "16": "II", "17": "III", "18": "X",
	"21": "XX", "22": "XXX", "23": "XXXX", "24": "XXXXX", "25": "XXXXXX", "26": "++",
}

## Areas labelled "<text> T" at the centre.
const AREA_LABELS := {
	"120100": "AO", "120200": "NAI", "120300": "TAI", "150200": "AA", "151300": "EA", "151700": "OBJ",
	"150600": "DZ", "150700": "EZ", "150800": "LZ", "150900": "PZ", "151500": "ASLT", "151600": "ATK",
	"270100": "", "270200": "", "270300": "FREE", "270400": "",
}
## Lines labelled at both ends, just above the line.
const END_LABELS := {
	"110200": "LL", "140700": "FCL", "140900": "LOA", "141000": "LD", "141100": "LD/LC", "141200": "PLD",
	"141400": "BL", "141500": "HOLDING LINE", "141600": "RL", "300100": "ICL",
}
## Fire support lines: label "<text> T" at both ends (CFL: once, dashed).
const FIRE_LINES := {"260100": "FSCL", "260200": "CFL", "260300": "NFL", "260400": "BCL", "260500": "RFL"}
## Fire support areas: kind prefix and shape (irregular / rectangular / circular).
const FIRE_AREAS := {"2402": "FFA", "2403": "NFA", "2404": "RFA", "2401": "ACA"}
const SUPPLY_ROUTES := {"3303": "MSR", "3304": "ASR"}
const CORRIDORS := {"170100": "AC", "170200": "LLTR", "170300": "MRR", "170400": "SL", "170500": "SAAFR",
	"170600": "TC", "170700": ""}
## Entity code prefixes drawn in green whatever the affiliation (obstacles and mines).
const OBSTACLE_PREFIXES := ["2701", "2702", "2703", "2704", "2705", "2707", "2708", "2709", "2710", "2712", "28", "29"]
## Point symbol drawn inside minefields and mined areas (unspecified mine).
const MINE_SIDC := "10032500002806000000"

static var _table: Dictionary


## Builds the drawing primitives of a control measure. `amplifiers`: "T", "T1", "W", "W1", "H", "X", "X1",
## "AM" (distance in point units). See DEFAULTS for `options`.
static func build(sidc: String, points: PackedVector2Array, amplifiers: Dictionary = {},
		options: Dictionary = {}) -> MilGraphicShape:
	var shape := MilGraphicShape.new()
	shape.sidc = sidc
	var opts := DEFAULTS.merged(options, true)
	if MilSymbolLegacy.is_letter_sidc(sidc):
		var converted := MilSymbolLegacy.to_number_sidc(sidc)
		if converted != "":
			sidc = converted  # 2525C tactical graphic ("G...") -> 2525D symbol set 25
	if sidc.length() < 20 or not sidc.substr(0, 20).is_valid_int() or sidc.substr(4, 2) != "25":
		shape.errors.append("not a number based control measure SIDC (symbol set 25)")
		return shape

	var version := sidc.substr(0, 2)
	var identity := sidc.substr(3, 1)
	var status := sidc.substr(6, 1)
	var hq_tf_dummy := sidc.substr(7, 1)
	var echelon := sidc.substr(8, 2)
	var code := sidc.substr(10, 6)
	shape.code = code

	# Like the point symbols (MilSymbolSidc): versions 13 and 14 are 2525E, every other version 2525D / APP-6D.
	var standard := "E" if version in ["13", "14"] else ("A" if opts.standard == "APP6" else "D")
	var entry: Dictionary = _data().get(code, {})
	shape.name = entry.get("name", "")
	shape.geometry = entry.get(standard, entry.get("D", entry.get("E", entry.get("A", ""))))

	match identity:
		"2", "3":
			shape.color_role = "friend"
		"4":
			shape.color_role = "neutral"
		"5", "6":
			shape.color_role = "hostile"
		_:
			shape.color_role = "unknown"
	shape.dashed = status == "1"
	var feint := hq_tf_dummy in ["1", "3", "5", "7"]
	var drawn := code
	if SUBTYPE_ALIASES.has(code):
		var alias: Array = SUBTYPE_ALIASES[code]
		drawn = alias[0]
		if alias[1] != "":
			shape.color_role = alias[1]
		shape.dashed = shape.dashed or alias[2]
		feint = feint or alias[3]
	for prefix in OBSTACLE_PREFIXES:
		if drawn.begins_with(prefix):
			shape.color_role = "obstacle"

	var ctx := {
		"code": drawn,
		"scale": float(opts.scale),
		"size": float(opts.text_size) * float(opts.scale),
		"line_width": float(opts.line_width),
		"font": opts.font if opts.font is Font else ThemeDB.fallback_font,
		"hostile": shape.color_role == "hostile" or identity in ["5", "6"],
		"echelon": ECHELON_TEXT.get(echelon, ""),
		"feint": feint,
		"amp": amplifiers,
	}
	var pts := Geo.clean(points)
	shape.specific = true
	var ok := _build_specific(shape, pts, ctx)
	if not ok and shape.errors.is_empty():
		shape.specific = false
		ok = _build_generic(shape, pts, ctx)
	shape.valid = ok and shape.errors.is_empty()
	return shape


## Every multipoint control measure in the standards' tables: {code: {"name", "D", "E", "A"}}.
static func table() -> Dictionary:
	return _data()


## True when the code has its own geometry (not a generic line or area).
static func is_specific(code: String) -> bool:
	var probe := build("1003250000%s0000" % code, PackedVector2Array(
			[Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]), {"AM": 40.0})
	return probe.specific and probe.valid


static func _data() -> Dictionary:
	if _table.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
		_table = parsed if parsed is Dictionary else {}
		if _table.is_empty():
			push_error("milsymbol: could not load %s" % DATA_FILE)
	return _table


# ------------------------------------------------------------------------------------------- dispatch

static func _build_specific(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary) -> bool:
	var code: String = ctx.code
	var prefix4 := code.substr(0, 4)
	if code == "110100":
		return _need(shape, pts, 2) and _boundary(shape, pts, ctx)
	if code == "140300":
		return _need(shape, pts, 2) and _end_label_line(shape, pts, ctx, _join("PL", ctx.amp.get("T", "")), true)
	if END_LABELS.has(code):
		return _need(shape, pts, 2) and _end_label_line(shape, pts, ctx, END_LABELS[code], false)
	if code == "140100":
		return _need(shape, pts, 2) and _flot(shape, pts, ctx)
	if FIRE_LINES.has(code):
		return _need(shape, pts, 2) and _fire_line(shape, pts, ctx, FIRE_LINES[code])
	if code == "150100":
		return _need(shape, pts, 3) and _area(shape, pts, ctx, [])
	if AREA_LABELS.has(code):
		var lines := [_join(AREA_LABELS[code], ctx.amp.get("T", ""))]
		if code in ["270100", "270200", "270300", "270400"]:
			return _need(shape, pts, 3) and _obstacle_zone(shape, pts, ctx, lines, code != "270100" and code != "270200")
		return _need(shape, pts, 3) and _area(shape, pts, ctx, lines)
	if FIRE_AREAS.has(prefix4) and code.substr(4, 2) in ["01", "02", "03"]:
		return _fire_area(shape, pts, ctx, FIRE_AREAS[prefix4], code.substr(4, 2))
	if code in ["151401", "151402", "151403", "151404"]:
		return _need(shape, pts, 3) and _axis(shape, pts, ctx, code)
	if code in ["140601", "140602", "140603"]:
		return _need(shape, pts, 2) and _direction_of_attack(shape, pts, ctx, code)
	if code in ["290100", "290101"]:
		return _need(shape, pts, 2) and _obstacle_line(shape, pts, ctx)
	if code in ["270707", "270800", "270801"]:
		return _need(shape, pts, 3) and _minefield(shape, pts, ctx, code)
	if SUPPLY_ROUTES.has(prefix4) and code.substr(4, 2) in ["00", "01", "02", "03"]:
		return _need(shape, pts, 2) and _supply_route(shape, pts, ctx, SUPPLY_ROUTES[prefix4], code.substr(4, 2))
	if CORRIDORS.has(code):
		return _need(shape, pts, 2) and _corridor(shape, pts, ctx, CORRIDORS[code])
	return false


static func _build_generic(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary) -> bool:
	var label := _join(ctx.amp.get("T", ""), "")
	match shape.geometry:
		"line":
			if not _need(shape, pts, 2):
				return false
			_add_line(shape, pts, shape.dashed)
			if label != "":
				var mid: Dictionary = Geo.point_at(pts, Geo.length(pts) / 2.0)
				_segment_label(shape, pts[mid.segment], pts[mid.segment + 1], mid.point, label, ctx, 0.9)
			return true
		"area":
			return _need(shape, pts, 3) and _area(shape, pts, ctx, [label] if label != "" else [])
		"axis":
			return _need(shape, pts, 3) and _axis(shape, pts, ctx, "151404")
		"corridor":
			return _need(shape, pts, 2) and _corridor(shape, pts, ctx, "")
	shape.errors.append("unknown control measure code %s" % ctx.code)
	return false


static func _need(shape: MilGraphicShape, pts: PackedVector2Array, count: int) -> bool:
	if pts.size() < count:
		shape.errors.append("needs at least %d distinct control points, got %d" % [count, pts.size()])
		return false
	return true


# ------------------------------------------------------------------------------------------- lines

static func _boundary(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary) -> bool:
	var size: float = ctx.size
	var mid: Dictionary = Geo.point_at(pts, Geo.length(pts) / 2.0)
	var seg: int = mid.segment
	var a := pts[seg]
	var b := pts[seg + 1]
	var direction := (b - a).normalized()
	var center: Vector2 = mid.point
	var angle := Geo.upright(direction.angle())
	var up := Geo.text_up(angle)
	var echelon: String = ctx.echelon
	if echelon != "":
		# The line is broken around the echelon text.
		var half := (_text_width(echelon, ctx) + size * 0.6) / 2.0
		half = minf(half, minf(center.distance_to(a), center.distance_to(b)))
		var first := pts.slice(0, seg + 1)
		first.append(center - direction * half)
		var second := PackedVector2Array([center + direction * half])
		second.append_array(pts.slice(seg + 1))
		_add_line(shape, first, shape.dashed)
		_add_line(shape, second, shape.dashed)
		_add_text(shape, echelon, center, angle, 0, size)
	else:
		_add_line(shape, pts, shape.dashed)
	var t := str(ctx.amp.get("T", ""))
	var t1 := str(ctx.amp.get("T1", ""))
	if t != "":
		_add_text(shape, t, center + up * size * 1.25, angle, 0, size)
	if t1 != "":
		_add_text(shape, t1, center - up * size * 1.25, angle, 0, size)
	return true


## Line with a label at both ends: past the ends (`beyond`, phase lines) or above the line next to them.
static func _end_label_line(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, label: String,
		beyond: bool) -> bool:
	_add_line(shape, pts, shape.dashed)
	for at_start in [true, false]:
		if beyond:
			_label_beyond_end(shape, pts, at_start, label, ctx, 0.0)
		else:
			_label_inside_end(shape, pts, at_start, label, ctx, 0.75)
	_feint_mark(shape, pts, ctx)
	return true


static func _flot(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary) -> bool:
	_add_line(shape, Geo.scallops(pts, 20.0 * ctx.scale), shape.dashed)
	for at_start in [true, false]:
		_label_beyond_end(shape, pts, at_start, "FLOT", ctx, 0.0)
		if ctx.hostile:
			_label_beyond_end(shape, pts, at_start, "ENY", ctx, -1.15)
	return true


static func _fire_line(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, kind: String) -> bool:
	var label := _join(kind, ctx.amp.get("T", ""))
	var dtg := _dtg(ctx)
	if kind == "CFL":
		_add_line(shape, pts, true)
		var mid: Dictionary = Geo.point_at(pts, Geo.length(pts) / 2.0)
		_segment_label(shape, pts[mid.segment], pts[mid.segment + 1], mid.point, label, ctx, 0.75)
		if dtg != "":
			_segment_label(shape, pts[mid.segment], pts[mid.segment + 1], mid.point, dtg, ctx, -0.75)
		return true
	_add_line(shape, pts, shape.dashed)
	for at_start in [true, false]:
		_label_inside_end(shape, pts, at_start, label, ctx, 0.75)
		if dtg != "":
			_label_inside_end(shape, pts, at_start, dtg, ctx, -0.75)
	return true


static func _obstacle_line(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary) -> bool:
	var s: float = ctx.scale
	_add_line(shape, Geo.teeth(pts, 20.0 * s, 10.0 * s, 10.0 * s, 1.0), shape.dashed)
	var t := str(ctx.amp.get("T", ""))
	if t != "":
		var mid: Dictionary = Geo.point_at(pts, Geo.length(pts) / 2.0)
		_segment_label(shape, pts[mid.segment], pts[mid.segment + 1], mid.point, t, ctx, -1.0)
	return true


static func _supply_route(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, kind: String,
		traffic: String) -> bool:
	var s: float = ctx.scale
	var size: float = ctx.size
	_add_line(shape, pts, shape.dashed)
	var label := _join(kind, ctx.amp.get("T", ""))
	var width := _text_width(label, ctx)
	var labelled := false
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var segment := a.distance_to(b)
		var direction := (b - a) / segment
		var angle := Geo.upright(direction.angle())
		var up := Geo.text_up(angle)
		if segment >= width * 1.5:
			_add_text(shape, label, (a + b) / 2.0 + up * size * 0.9, angle, 0, size)
			labelled = true
		if traffic == "00" or segment < 20.0 * s:
			continue
		# Traffic arrows run parallel to the segment on the side away from the label.
		for lane in ([0, 1] if traffic == "02" else [0]):
			var off: Vector2 = -up * (10.0 + 15.0 * lane) * s
			var p: Vector2 = a.lerp(b, 0.25) + off
			var q: Vector2 = a.lerp(b, 0.75) + off
			var forward := direction if lane == 0 else -direction
			if lane == 1:
				var swap := p
				p = q
				q = swap
			_add_line(shape, PackedVector2Array([p, q]), false)
			_add_line(shape, Geo.arrowhead(q, forward, 8.0 * s, 4.0 * s), false)
			if traffic == "03":
				_add_line(shape, Geo.arrowhead(p, -forward, 8.0 * s, 4.0 * s), false)
	if not labelled:
		var mid: Dictionary = Geo.point_at(pts, Geo.length(pts) / 2.0)
		_segment_label(shape, pts[mid.segment], pts[mid.segment + 1], mid.point, label, ctx, 0.9)
	return true


static func _corridor(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, kind: String) -> bool:
	if not ctx.amp.has("AM") or float(ctx.amp.AM) <= 0.0:
		shape.errors.append("needs the width amplifier AM")
		return false
	var half := float(ctx.amp.AM) / 2.0
	_add_line(shape, Geo.offset(pts, half), shape.dashed)
	_add_line(shape, Geo.offset(pts, -half), shape.dashed)
	_add_line(shape, pts, true)
	for p in pts:
		_add_line(shape, Geo.circle(p, half, 32), shape.dashed, true)
	var lines: Array = []
	for item in [[_join(kind, ctx.amp.get("T", "")), ""], [ctx.amp.get("X", ""), "MIN ALT: "],
			[ctx.amp.get("X1", ""), "MAX ALT: "], [_dtg(ctx), ""]]:
		if str(item[0]) != "":
			lines.append(item[1] + str(item[0]))
	var mid: Dictionary = Geo.point_at(pts, Geo.length(pts) / 2.0)
	for i in lines.size():
		var offset: float = (half + ctx.size * 0.4) / ctx.size + 1.15 * (lines.size() - 1 - i) + 0.5
		_segment_label(shape, pts[mid.segment], pts[mid.segment + 1], mid.point, lines[i], ctx, offset)
	return true


# ------------------------------------------------------------------------------------------- areas

static func _area(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, lines: Array) -> bool:
	_add_line(shape, pts, shape.dashed, true)
	_center_labels(shape, pts, lines, ctx)
	if ctx.code == "150100" and ctx.hostile:
		_outline_labels(shape, pts, "ENY", ctx, ["left", "right"])
	_feint_mark(shape, pts, ctx)
	return true


static func _obstacle_zone(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, lines: Array,
		inward: bool) -> bool:
	var s: float = ctx.scale
	var outward := 1.0 if Geo.signed_area2(pts) > 0.0 else -1.0
	var side := -outward if inward else outward
	_add_line(shape, Geo.teeth(pts, 20.0 * s, 10.0 * s, 10.0 * s, side, true), shape.dashed, true)
	_center_labels(shape, pts, lines, ctx)
	return true


static func _fire_area(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, kind: String,
		form: String) -> bool:
	var polygon := pts
	if form == "02" or form == "03":
		var am := float(ctx.amp.get("AM", 0.0))
		if am <= 0.0:
			shape.errors.append("needs the %s amplifier AM" % ("width" if form == "02" else "radius"))
			return false
		if form == "02":
			if not _need(shape, pts, 2):
				return false
			var normal := Geo.left_normal((pts[1] - pts[0]).normalized()) * am / 2.0
			polygon = PackedVector2Array([pts[0] + normal, pts[1] + normal, pts[1] - normal, pts[0] - normal])
		else:
			if not _need(shape, pts, 1):
				return false
			polygon = Geo.circle(pts[0], am)
	elif not _need(shape, pts, 3):
		return false
	_add_line(shape, polygon, shape.dashed, true)
	if kind == "NFA":
		for hatch_line in Geo.hatch(polygon, maxf(4.0, 0.75 * ctx.line_width * 6.0 * ctx.scale)):
			_add_line(shape, hatch_line, false)
	var lines := [kind]
	if str(ctx.amp.get("T", "")) != "":
		lines.append(str(ctx.amp.T))
	if _dtg(ctx) != "":
		lines.append(_dtg(ctx))
	var first_text := shape.primitives.size()
	_center_labels(shape, polygon, lines, ctx, 0)
	if kind == "NFA":
		for i in range(first_text, shape.primitives.size()):
			shape.primitives[i].boxed = true  # readable over the hatching
	return true


static func _minefield(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, code: String) -> bool:
	var size: float = ctx.size
	_add_line(shape, pts, shape.dashed, true)
	var center := Geo.bounds_center(pts)
	shape.primitives.append({"type": "symbol", "sidc": MINE_SIDC, "position": center, "size": size * 2.0})
	if code == "270800" or code == "270801":
		_outline_labels(shape, pts, "M", ctx, ["left", "right", "top", "bottom"])
	if code == "270801":
		for mark in Geo.crosses(Geo.closed(pts), 30.0 * ctx.scale, 8.0 * ctx.scale):
			_add_line(shape, mark, false)
	if code == "270800":
		var box := _bounds(pts)
		if str(ctx.amp.get("H", "")) != "":
			_add_text(shape, str(ctx.amp.H), Vector2(center.x, box.position.y - size * 0.9), 0.0, 0, size)
		if _dtg(ctx) != "":
			_add_text(shape, _dtg(ctx), Vector2(center.x, box.end.y + size * 0.9), 0.0, 0, size)
	if ctx.hostile:
		_add_text(shape, "ENY", center + Vector2(0, size * 1.9), 0.0, 0, size)
	return true


# ------------------------------------------------------------------------------------------- arrows

## Axis of Advance. pts: tip, centreline to the rear, then the arrowhead edge point.
static func _axis(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary, code: String) -> bool:
	var centre := pts.slice(0, pts.size() - 1)
	var edge := pts[pts.size() - 1]
	if centre.size() < 2:
		shape.errors.append("needs a tip, a rear point and an arrowhead width point")
		return false
	var tip := centre[0]
	var to_tip := (tip - centre[1]).normalized()
	var normal := Geo.left_normal(to_tip)
	var first_length := tip.distance_to(centre[1])
	var head_length := clampf((tip - edge).dot(to_tip), first_length * 0.05, first_length * 0.9)
	var half := absf((edge - tip).dot(normal))
	if half < 1.0:
		half = 15.0 * ctx.scale
	var base := tip - to_tip * head_length
	# Shaft from the rear to the base of the arrowhead, `half` wide in total.
	var shaft := PackedVector2Array([base])
	shaft.append_array(centre.slice(1))
	shaft.reverse()
	var left := Geo.offset(shaft, half / 2.0)
	var right := Geo.offset(shaft, -half / 2.0)
	# offset() is relative to the rear-to-tip direction, which is also to_tip at the head.
	var shaft_left := left[left.size() - 1]
	var shaft_right := right[right.size() - 1]
	var wing_left := base + normal * half
	var wing_right := base - normal * half
	var outline := PackedVector2Array()
	if code == "151401" or code == "151402":
		# Aviation: the two shaft lines cross over just before the arrowhead (bow tie).
		var last := shaft[shaft.size() - 2].distance_to(base)
		var cross := minf(half * 1.5, last * 0.5)
		var cross_left := base - to_tip * cross + normal * half / 2.0
		var cross_right := base - to_tip * cross - normal * half / 2.0
		outline = left.slice(0, left.size() - 1)
		outline.append_array([cross_left, shaft_right, wing_right, tip, wing_left, shaft_left, cross_right])
		var rest := right.slice(0, right.size() - 1)
		rest.reverse()
		outline.append_array(rest)
		_add_line(shape, outline, shape.dashed)
		_add_line(shape, PackedVector2Array([cross_left, cross_right]), shape.dashed)
		_add_line(shape, PackedVector2Array([shaft_left, shaft_right]), shape.dashed)
		if code == "151402":
			# Attack helicopter: a small rotor mark over the crossing.
			var x := base - to_tip * cross / 2.0
			var top := x + normal * half * 0.9
			_add_line(shape, PackedVector2Array([x, top]), false)
			_add_line(shape, Geo.arrowhead(top, normal, half * 0.3, half * 0.2), false)
	else:
		outline = left.duplicate()
		outline.append_array([wing_left, tip, wing_right])
		var rest := right.duplicate()
		rest.reverse()
		outline.append_array(rest)
		_add_line(shape, outline, shape.dashed)
		if code == "151403":
			var inner := tip - to_tip * minf(half / 2.0, head_length * 0.5)
			_add_line(shape, PackedVector2Array([shaft_left, inner, shaft_right]), shape.dashed)
	if ctx.feint:
		_add_line(shape, PackedVector2Array([wing_left + normal * half * 0.25, tip + to_tip * head_length * 0.5,
				wing_right - normal * half * 0.25]), true)
	# T inside the shaft on its longest segment, DTG under it.
	var longest := 0
	for i in range(1, shaft.size()):
		if shaft[i - 1].distance_to(shaft[i]) > shaft[longest].distance_to(shaft[longest + 1]):
			longest = i - 1
	var a := shaft[longest]
	var b := shaft[longest + 1]
	var t := str(ctx.amp.get("T", ""))
	if t != "":
		_segment_label(shape, a, b, (a + b) / 2.0, t, ctx, 0.0)
	if _dtg(ctx) != "":
		_segment_label(shape, a, b, (a + b) / 2.0, _dtg(ctx), ctx, -half / ctx.size - 0.8)
	return true


## Direction of Attack. pts: tip first.
static func _direction_of_attack(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary,
		code: String) -> bool:
	var box := _bounds(pts)
	var diagonal := box.size.length()
	var head := clampf(diagonal, 150.0 * ctx.scale, (250.0 if code == "140601" else 500.0) * ctx.scale) / 20.0
	var tip := pts[0]
	var to_tip := (tip - pts[1]).normalized()
	var line := pts.duplicate()
	if code == "140602":
		line[0] = tip - to_tip * head * 0.5
		var outer := Geo.arrowhead(tip, to_tip, head * 1.5, head * 0.9)
		var inner := Geo.arrowhead(tip - to_tip * head * 0.5, to_tip, head, head * 0.6)
		_add_line(shape, outer, false)
		_add_line(shape, inner, false)
		_add_line(shape, PackedVector2Array([outer[0], inner[0]]), false)
		_add_line(shape, PackedVector2Array([outer[2], inner[2]]), false)
	else:
		_add_line(shape, Geo.arrowhead(tip, to_tip, head, head * 0.6), false)
	_add_line(shape, line, shape.dashed)
	if code == "140601":
		# Bow tie on the line, at least 60 px from the tip.
		var at: Dictionary = Geo.point_at(pts, minf(60.0 * ctx.scale + head, Geo.length(pts) * 0.6))
		var d := (pts[at.segment + 1] - pts[at.segment]).normalized()
		var n := Geo.left_normal(d)
		var x: Vector2 = at.point
		var h := head * 0.6
		_add_line(shape, PackedVector2Array([x - d * head + n * h, x + d * head - n * h, x + d * head + n * h,
				x - d * head - n * h]), false, true)
	if ctx.feint:
		var n := Geo.left_normal(to_tip)
		_add_line(shape, PackedVector2Array([tip - to_tip * head + n * head, tip + to_tip * head * 0.6,
				tip - to_tip * head - n * head]), true)
	var labels := [str(ctx.amp.get("T", "")), _dtg(ctx)]
	var a := pts[0]
	var b := pts[1]
	var anchor := a.lerp(b, 0.5)
	for i in labels.size():
		if labels[i] != "":
			_segment_label(shape, a, b, anchor, labels[i], ctx, 0.9 + 1.15 * i)
	return true


# ------------------------------------------------------------------------------------------- text

static func _join(a: Variant, b: Variant) -> String:
	var parts := PackedStringArray()
	for item in [a, b]:
		if str(item) != "":
			parts.append(str(item))
	return " ".join(parts)


static func _dtg(ctx: Dictionary) -> String:
	var w := str(ctx.amp.get("W", ""))
	var w1 := str(ctx.amp.get("W1", ""))
	if w != "" and w1 != "":
		return "%s - %s" % [w, w1]
	return w + w1


static func _text_width(text: String, ctx: Dictionary) -> float:
	var font: Font = ctx.font
	if font == null:
		return text.length() * ctx.size * 0.6
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(ctx.size)).x


static func _add_text(shape: MilGraphicShape, text: String, position: Vector2, angle: float, align: int,
		size: float) -> void:
	shape.primitives.append({"type": "text", "text": text, "position": position, "angle": angle, "align": align,
			"size": size})


static func _add_line(shape: MilGraphicShape, points: PackedVector2Array, dashed: bool,
		is_closed: bool = false) -> void:
	shape.primitives.append({"type": "line", "points": points, "closed": is_closed, "dashed": dashed})


## Label centred at `anchor` on the segment a-b, `lines` text lines above it (negative: below).
static func _segment_label(shape: MilGraphicShape, a: Vector2, b: Vector2, anchor: Vector2, text: String,
		ctx: Dictionary, lines: float) -> void:
	var angle := Geo.upright((b - a).angle())
	_add_text(shape, text, anchor + Geo.text_up(angle) * ctx.size * lines, angle, 0, ctx.size)


## Label just past one end of the line, continuing its direction (phase lines, FLOT).
static func _label_beyond_end(shape: MilGraphicShape, pts: PackedVector2Array, at_start: bool, text: String,
		ctx: Dictionary, lines: float) -> void:
	var end := pts[0] if at_start else pts[pts.size() - 1]
	var neighbour := pts[1] if at_start else pts[pts.size() - 2]
	var outward := (end - neighbour).normalized()
	var angle := Geo.upright(outward.angle())
	var gap: float = ctx.size * 0.5 + _text_width(text, ctx) / 2.0
	_add_text(shape, text, end + outward * gap + Geo.text_up(angle) * ctx.size * lines, angle, 0, ctx.size)


## Label above the line next to one end, running along the line inwards.
static func _label_inside_end(shape: MilGraphicShape, pts: PackedVector2Array, at_start: bool, text: String,
		ctx: Dictionary, lines: float) -> void:
	var end := pts[0] if at_start else pts[pts.size() - 1]
	var neighbour := pts[1] if at_start else pts[pts.size() - 2]
	var inward := (neighbour - end).normalized()
	var angle := Geo.upright(inward.angle())
	var along := minf(ctx.size * 0.5 + _text_width(text, ctx) / 2.0, end.distance_to(neighbour) / 2.0)
	_add_text(shape, text, end + inward * along + Geo.text_up(angle) * ctx.size * lines, angle, 0, ctx.size)


## Horizontal text lines stacked around the centre of the bounding box. `first_line` is the index of the line
## placed on the centre (default: the block is centred).
static func _center_labels(shape: MilGraphicShape, pts: PackedVector2Array, lines: Array, ctx: Dictionary,
		first_line: int = -1) -> void:
	var visible: Array = []
	for line in lines:
		if str(line) != "":
			visible.append(str(line))
	if visible.is_empty():
		return
	var center := Geo.bounds_center(pts)
	var step: float = ctx.size * 1.2
	var start := -(visible.size() - 1) / 2.0 if first_line < 0 else -float(first_line)
	if first_line >= 0 and visible.size() > 1:
		start = -1.0  # first line (the area kind) above the centre, the rest below
	for i in visible.size():
		_add_text(shape, visible[i], center + Vector2(0, (start + i) * step), 0.0, 0, ctx.size)


## Text at the middle of the left-, right-, top- and/or bottom-most edges of an area.
static func _outline_labels(shape: MilGraphicShape, pts: PackedVector2Array, text: String, ctx: Dictionary,
		sides: Array) -> void:
	var ring := Geo.closed(pts)
	var best := {}
	for i in range(1, ring.size()):
		var mid := (ring[i - 1] + ring[i]) / 2.0
		for side in sides:
			var value: float
			match side:
				"left":
					value = mid.x
				"right":
					value = -mid.x
				"top":
					value = mid.y
				_:
					value = -mid.y
			if not best.has(side) or value < best[side].value:
				best[side] = {"value": value, "point": mid}
	var used: Array[Vector2] = []
	for side in sides:
		if best.has(side) and not used.has(best[side].point):
			used.append(best[side].point)
			_add_text(shape, text, best[side].point, 0.0, 0, ctx.size)


## Feint / dummy indicator for graphics without an arrowhead: a dashed "^" above the bounding box.
static func _feint_mark(shape: MilGraphicShape, pts: PackedVector2Array, ctx: Dictionary) -> void:
	if not ctx.feint:
		return
	var box := _bounds(pts)
	var top: float = box.position.y - ctx.size
	_add_line(shape, PackedVector2Array([Vector2(box.position.x, box.position.y),
			Vector2(box.get_center().x, top - box.size.x * 0.15), Vector2(box.end.x, box.position.y)]), true)


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	return box
