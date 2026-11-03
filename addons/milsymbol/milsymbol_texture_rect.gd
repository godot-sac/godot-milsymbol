@tool
@icon("res://addons/milsymbol/icons/milsymbol_sprite_2d.svg")
class_name MilSymbolTextureRect
extends TextureRect
## A military symbol as a UI control (HUDs, lists, order of battle panels, legends).
##
## The symbol is rendered at `symbol_size` and shown with the TextureRect stretch mode (default: keep aspect,
## centred), so it lays out like any other control in containers.

signal symbol_changed

## 20 digit number based SIDC (MIL-STD-2525D/E, APP-6D) or a letter based 2525C SIDC.
@export var sidc: String = "10031000001211000000":
	set(value):
		sidc = value
		_queue_refresh()
## Symbol size in pixels (milsymbol's size: the frame is roughly this wide).
@export_range(10.0, 400.0, 1.0, "or_greater") var symbol_size: float = 48.0:
	set(value):
		symbol_size = value
		_queue_refresh()
## Rendering options; share one style between many symbols.
@export var style: MilSymbolStyle:
	set(value):
		if style and style.changed.is_connected(_queue_refresh):
			style.changed.disconnect(_queue_refresh)
		style = value
		if style:
			style.changed.connect(_queue_refresh)
		_queue_refresh()

## The last render (SVG, size, anchor, metadata). Null until the first refresh.
var symbol: MilSymbolRender

var _refresh_queued := false


func _init() -> void:
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE


# Also after re-entering the tree: changes made while outside it are not queued.
func _enter_tree() -> void:
	refresh()


## Renders now instead of waiting for the end of the frame.
func refresh() -> void:
	_refresh_queued = false
	var options := style.to_options() if style else {}
	options.size = symbol_size
	symbol = MilSymbol.render_cached(sidc, options)
	texture = MilSymbol.create_texture(sidc, options)
	custom_minimum_size = symbol.size.ceil()
	tooltip_text = sidc if symbol.valid else "%s (invalid)" % sidc
	symbol_changed.emit()


func _queue_refresh() -> void:
	if _refresh_queued or not is_inside_tree():
		return
	_refresh_queued = true
	refresh.call_deferred()
