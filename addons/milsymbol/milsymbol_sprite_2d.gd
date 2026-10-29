@tool
@icon("res://addons/milsymbol/icons/milsymbol_sprite_2d.svg")
class_name MilSymbolSprite2D
extends Sprite2D
## A Sprite2D that draws a military symbol from a SIDC.
##
## With `anchor_at_origin` on (default) the node's position is the symbol's anchor point:
## the frame centre, or the foot of the staff for headquarters. Place it on the map position.

signal symbol_changed

## 20 digit number based SIDC (MIL-STD-2525D/E, APP-6D).
@export var sidc: String = "10031000001211000000":
	set(value):
		sidc = value
		_queue_refresh()
## Symbol size in pixels (milsymbol's size: the frame is roughly this wide).
@export_range(10.0, 400.0, 1.0, "or_greater") var symbol_size: float = 60.0:
	set(value):
		symbol_size = value
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


func _ready() -> void:
	refresh()


## Renders now instead of waiting for the end of the frame.
func refresh() -> void:
	_refresh_queued = false
	var options := style.to_options() if style else {}
	options.size = symbol_size
	symbol = MilSymbol.render_cached(sidc, options)
	texture = MilSymbol.create_texture(sidc, options)
	centered = false
	offset = -symbol.anchor if anchor_at_origin else -symbol.size / 2
	symbol_changed.emit()


## Decoded SIDC fields (affiliation, dimension, echelon, ...).
func get_metadata() -> Dictionary:
	return symbol.metadata if symbol else {}


func _queue_refresh() -> void:
	if _refresh_queued or not is_inside_tree():
		return
	_refresh_queued = true
	refresh.call_deferred()
