class_name MilGraphicShape
extends RefCounted
## The result of MilGraphic.build(): drawing primitives for one multipoint control measure.
##
## Primitives (Dictionaries) are in the same 2D plane and units as the control points (y grows downwards):
##   {"type": "line", "points": PackedVector2Array, "closed": bool, "dashed": bool}
##   {"type": "polygon", "points": PackedVector2Array, "fill_alpha": float}
##   {"type": "text", "text": String, "position": Vector2, "angle": float, "align": int, "size": float}
##       position = centre of the text line (align 0), its start (align -1) or its end (align 1).
##       Optional "boxed": true draws a background box behind the text.
##   {"type": "symbol", "sidc": String, "position": Vector2, "size": float}  (point symbol, drawn by MilSymbol)
## Every primitive uses the shape colour; see MilGraphicRenderer for drawing and SVG output.

## Input SIDC.
var sidc: String
## Entity code (SIDC digits 11-16).
var code: String
## Name from the standard's table, e.g. "Maneuver Lines / Phase Line".
var name: String
## "line", "area", "axis" or "corridor" (geometry type in the standard's table), "" if unknown.
var geometry: String
## Colour role: "friend", "hostile", "neutral", "unknown" or "obstacle" (obstacles are green in every affiliation).
var color_role: String = "friend"
## The outline is dashed (planned / anticipated status).
var dashed: bool
## True when this code has its own geometry; false when it is drawn as a generic line or area.
var specific: bool
## False when the SIDC is not a control measure or there are too few control points.
var valid: bool
var errors: PackedStringArray = []
var primitives: Array[Dictionary] = []


## Bounding box of every primitive point and text anchor.
func get_bounds() -> Rect2:
	var bounds := Rect2()
	var first := true
	for primitive in primitives:
		var points: PackedVector2Array
		if primitive.has("points"):
			points = primitive.points
		else:
			points = PackedVector2Array([primitive.position])
		for p in points:
			if first:
				bounds = Rect2(p, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(p)
	return bounds
