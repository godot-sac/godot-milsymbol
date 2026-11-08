@tool
@icon("res://addons/milsymbol/icons/milsymbol_sprite_3d.svg")
class_name MilSymbolSprite3D
extends Sprite3D
## A Sprite3D that draws a military symbol from a SIDC, facing the camera by default.
##
## With `anchor_at_origin` on (default) the node's position is the symbol's anchor point:
## the frame centre, or the foot of the staff for headquarters. Place it on the unit's position.
## Turn on `fixed_size` (a Sprite3D property) to keep the symbol the same size on screen at any
## distance; `pixel_size` then sets that size.

signal symbol_changed

## 20 digit number based SIDC (MIL-STD-2525D/E, APP-6D).
@export var sidc: String = "10031000001211000000":
	set(value):
		sidc = value
		_queue_refresh()
## Texture size in pixels (milsymbol's size: the frame is roughly this wide). World size is
## symbol_size * pixel_size.
@export_range(10.0, 400.0, 1.0, "or_greater") var symbol_size: float = 100.0:
	set(value):
		symbol_size = value
		_queue_refresh()
## Text amplifier fields and direction of movement for this symbol, as MilSymbol options, for example
## {"uniqueDesignation": "A/1-32", "higherFormation": "3 BDE", "speed": "15 KPH", "direction": 45.0}.
## See docs/amplifiers.md for every field and where it is drawn.
@export var amplifiers: Dictionary = {}:
	set(value):
		amplifiers = value
		_queue_refresh()
## Rendering options. Leave empty for milsymbol defaults; share one style between many symbols.
@export var style: MilSymbolStyle:
	set(value):
		if style and style.changed.is_connected(_queue_refresh):
			style.changed.disconnect(_queue_refresh)
		style = value
		if style:
			style.changed.connect(_queue_refresh)
		_queue_refresh()
## Put the symbol's anchor point at the node origin instead of the texture centre.
@export var anchor_at_origin: bool = true:
	set(value):
		anchor_at_origin = value
		_queue_refresh()

## The last render (SVG, size, anchor, metadata). Null until the first refresh.
var symbol: MilSymbolRender

var _refresh_queued := false


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pixel_size = 0.01


# Also after re-entering the tree: changes made while outside it are not queued.
func _enter_tree() -> void:
	refresh()


## Renders now instead of waiting for the end of the frame.
func refresh() -> void:
	_refresh_queued = false
	var options := style.to_options() if style else {}
	options.size = symbol_size
	options.merge(amplifiers, true)
	symbol = MilSymbol.render_cached(sidc, options)
	texture = MilSymbol.create_texture(sidc, options)
	centered = true
	# Sprite3D offsets are in pixels with y pointing up; move the anchor pixel to the origin.
	if anchor_at_origin:
		offset = Vector2(symbol.size.x / 2 - symbol.anchor.x, symbol.anchor.y - symbol.size.y / 2)
	else:
		offset = Vector2.ZERO
	symbol_changed.emit()


## Decoded SIDC fields (affiliation, dimension, echelon, ...).
func get_metadata() -> Dictionary:
	return symbol.metadata if symbol else {}


func _queue_refresh() -> void:
	if _refresh_queued or not is_inside_tree():
		return
	_refresh_queued = true
	refresh.call_deferred()
