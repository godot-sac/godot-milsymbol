class_name MilGraphicRenderer
extends RefCounted
## Draws a MilGraphicShape on a CanvasItem (call from its _draw()) or writes it as SVG.
##
## `style` keys (all optional): "palette" (colour role -> Color, see PALETTE_LIGHT_MAP / PALETTE_DARK_MAP),
## "width" (line width, px), "halo" (outline width around lines and text, 0 = none), "halo_color",
## "font" (Font), "dash" (dash length), "transform" (Transform2D applied to every point, e.g. map -> screen).

## 2525 colours on a light map background: friendly black, hostile red, obstacles green.
const PALETTE_LIGHT_MAP := {
	"friend": Color(0, 0, 0),
	"hostile": Color(0.9, 0, 0),
	"neutral": Color(0, 0.6, 0),
	"unknown": Color(0.85, 0.75, 0),
	"obstacle": Color(0, 0.6, 0),
}
## For dark map backgrounds (friendly graphics may be drawn in blue).
const PALETTE_DARK_MAP := {
	"friend": Color(0.45, 0.75, 1.0),
	"hostile": Color(1.0, 0.4, 0.4),
	"neutral": Color(0.45, 1.0, 0.45),
	"unknown": Color(1.0, 1.0, 0.45),
	"obstacle": Color(0.35, 0.95, 0.35),
}
const DEFAULT_STYLE := {
	"palette": PALETTE_LIGHT_MAP,
	"width": 2.0,
	"halo": 0.0,
	"halo_color": Color(1, 1, 1, 0.8),
	"font": null,
	"dash": 8.0,
	"transform": Transform2D.IDENTITY,
}


static func color_of(shape: MilGraphicShape, style: Dictionary = {}) -> Color:
	var palette: Dictionary = style.get("palette", PALETTE_LIGHT_MAP)
	return palette.get(shape.color_role, Color.BLACK)


## Draws the shape. Must be called while `canvas` is drawing (inside _draw or a draw signal).
static func draw(canvas: CanvasItem, shape: MilGraphicShape, style: Dictionary = {}) -> void:
	var s := DEFAULT_STYLE.merged(style, true)
	var color := color_of(shape, s)
	var xf: Transform2D = s.transform
	var font: Font = s.font if s.font is Font else ThemeDB.fallback_font
	var width: float = s.width
	var halo: float = s.halo
	if halo > 0.0:
		for primitive in shape.primitives:
			if primitive.type == "line":
				for part in _line_parts(primitive, xf, s.dash):
					canvas.draw_polyline(part, s.halo_color, width + halo * 2.0, true)
	for primitive in shape.primitives:
		match primitive.type:
			"polygon":
				canvas.draw_colored_polygon(xf * primitive.points, Color(color, primitive.get("fill_alpha", 0.3)))
	for primitive in shape.primitives:
		match primitive.type:
			"line":
				for part in _line_parts(primitive, xf, s.dash):
					canvas.draw_polyline(part, color, width, true)
			"symbol":
				var options := {"size": primitive.size, "monoColor": _css(color)}
				if halo > 0.0:
					options.outlineWidth = halo
					options.outlineColor = _css(s.halo_color)
				var texture := MilSymbol.create_texture(primitive.sidc, options)
				if texture != null:
					var anchor := MilSymbol.render_cached(primitive.sidc, options).anchor
					canvas.draw_texture(texture, (xf * primitive.position - anchor).round())
	for primitive in shape.primitives:
		if primitive.type != "text":
			continue
		var size := int(round(primitive.size))
		var text: String = primitive.text
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := -text_width / 2.0
		if primitive.align < 0:
			x = 0.0
		elif primitive.align > 0:
			x = -text_width
		var baseline := (font.get_ascent(size) - font.get_descent(size)) / 2.0
		var angle: float = primitive.angle + xf.get_rotation()
		canvas.draw_set_transform(xf * primitive.position, angle)
		if primitive.get("boxed", false):
			var box_color: Color = s.halo_color if halo > 0.0 else Color(1, 1, 1, 0.85)
			var pad := size * 0.2
			canvas.draw_rect(Rect2(x - pad, -size * 0.6 - pad, text_width + pad * 2.0, size * 1.2 + pad * 2.0),
					Color(box_color, maxf(box_color.a, 0.85)))
		if halo > 0.0:
			canvas.draw_string_outline(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
					int(ceil(halo * 2.0)), s.halo_color)
		canvas.draw_string(font, Vector2(x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		canvas.draw_set_transform(Vector2.ZERO)


## SVG document for the shape (for documentation and tests). Text uses the SVG font, sans-serif.
static func to_svg(shape: MilGraphicShape, style: Dictionary = {}, margin: float = 20.0) -> String:
	var s := DEFAULT_STYLE.merged(style, true)
	var color := _css(color_of(shape, s))
	var bounds := shape.get_bounds().grow(margin)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="%s %s %s %s">' % [
			_n(bounds.size.x), _n(bounds.size.y), _n(bounds.position.x), _n(bounds.position.y),
			_n(bounds.size.x), _n(bounds.size.y)]
	for primitive in shape.primitives:
		match primitive.type:
			"line":
				var tag := "polygon" if primitive.closed else "polyline"
				svg += '<%s points="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round"' % [
						tag, _points(primitive.points), color, _n(s.width)]
				if primitive.dashed:
					svg += ' stroke-dasharray="%s %s"' % [_n(s.dash), _n(s.dash)]
				svg += "/>"
			"polygon":
				svg += '<polygon points="%s" fill="%s" fill-opacity="%s" stroke="none"/>' % [
						_points(primitive.points), color, _n(primitive.get("fill_alpha", 0.3))]
			"symbol":
				var render := MilSymbol.render_cached(primitive.sidc, {"size": primitive.size, "monoColor": color})
				var origin: Vector2 = primitive.position - render.anchor
				svg += render.svg.replace("<svg ", '<svg x="%s" y="%s" ' % [_n(origin.x), _n(origin.y)])
			"text":
				var anchor := "middle" if primitive.align == 0 else ("start" if primitive.align < 0 else "end")
				var p: Vector2 = primitive.position
				if primitive.get("boxed", false):
					var w: float = primitive.size * 0.62 * primitive.text.length() + primitive.size * 0.4
					var left := p.x - w / 2.0 if primitive.align == 0 else (p.x if primitive.align < 0 else p.x - w)
					svg += '<rect x="%s" y="%s" width="%s" height="%s" fill="white" fill-opacity="0.85"/>' % [
							_n(left), _n(p.y - primitive.size * 0.8), _n(w), _n(primitive.size * 1.6)]
				svg += ('<text x="%s" y="%s" font-family="sans-serif" font-size="%s" fill="%s" text-anchor="%s"'
						+ ' dominant-baseline="central" transform="rotate(%s %s %s)">%s</text>') % [
						_n(p.x), _n(p.y), _n(primitive.size), color, anchor, _n(rad_to_deg(primitive.angle)),
						_n(p.x), _n(p.y), primitive.text.xml_escape()]
	return svg + "</svg>"


## Splits a polyline into dashes of `dash` on / `dash` off, continuing the pattern across vertices.
static func dash_polyline(points: PackedVector2Array, dash: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var current := PackedVector2Array()
	var drawing := true
	var left := dash
	if points.size() > 0:
		current.append(points[0])
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var segment := a.distance_to(b)
		var travelled := 0.0
		while segment - travelled > left:
			travelled += left
			var p := a.lerp(b, travelled / segment)
			if drawing:
				current.append(p)
				result.append(current)
				current = PackedVector2Array()
			else:
				current = PackedVector2Array([p])
			drawing = not drawing
			left = dash
		left -= segment - travelled
		if drawing:
			current.append(b)
	if drawing and current.size() > 1:
		result.append(current)
	return result


static func _line_parts(primitive: Dictionary, xf: Transform2D, dash: float) -> Array[PackedVector2Array]:
	var points: PackedVector2Array = xf * primitive.points
	if primitive.closed and points.size() > 2:
		points.append(points[0])
	if primitive.dashed:
		return dash_polyline(points, dash)
	return [points]


static func _css(color: Color) -> String:
	return "rgb(%d,%d,%d)" % [color.r8, color.g8, color.b8]


static func _points(points: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for p in points:
		parts.append("%s,%s" % [_n(p.x), _n(p.y)])
	return " ".join(parts)


static func _n(value: float) -> String:
	return MilSymbolSvgWriter.num(snappedf(value, 0.01))
