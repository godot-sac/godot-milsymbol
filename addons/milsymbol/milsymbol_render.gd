class_name MilSymbolRender
extends RefCounted
## The result of MilSymbol.render(): SVG text plus the geometry needed to place it.

var sidc: String
## SVG document text.
var svg: String
## Image size in pixels at scale 1.
var size: Vector2
## Pixel position of the symbol's anchor point inside the image (frame centre, or HQ staff foot).
var anchor: Vector2
## Pixel position of the octagon centre inside the image.
var octagon_anchor: Vector2
## Decoded SIDC (milsymbol metadata keys: affiliation, dimension, echelon, notpresent, ...).
var metadata: Dictionary
## Resolved style options.
var style: Dictionary
## Draw instructions the SVG was written from.
var draw_instructions: Array
## False when the SIDC could not be decoded or has no frame geometry.
var valid: bool


## Rasterizes the SVG. Returns null if Godot cannot load it.
func to_image(scale: float = 1.0) -> Image:
	var image := Image.new()
	if image.load_svg_from_string(svg, scale) != OK:
		return null
	return image


## Rasterizes the SVG into a texture. Returns null if Godot cannot load it.
func to_texture(scale: float = 1.0) -> ImageTexture:
	var image := to_image(scale)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)
