@tool
@icon("res://addons/milsymbol/icons/milsymbol_style.svg")
class_name MilSymbolStyle
extends Resource
## Shared rendering options for MilSymbolSprite2D / MilSymbolSprite3D.
## One style can be shared by many symbols (e.g. every unit on a map).

enum ColorMode { LIGHT, MEDIUM, DARK }

const COLOR_MODE_NAMES := ["Light", "Medium", "Dark"]

## Frame fill colors (milsymbol colorMode).
@export var color_mode: ColorMode = ColorMode.LIGHT:
	set(value):
		color_mode = value
		emit_changed()
## Fill the frame. When off, frame and icon use the affiliation color.
@export var fill: bool = true:
	set(value):
		fill = value
		emit_changed()
## Draw the frame.
@export var frame: bool = true:
	set(value):
		frame = value
		emit_changed()
## Draw the icon.
@export var icon: bool = true:
	set(value):
		icon = value
		emit_changed()
## Opacity of the frame fill.
@export_range(0.0, 1.0) var fill_opacity: float = 1.0:
	set(value):
		fill_opacity = value
		emit_changed()
## Line width in symbol units (the frame is about 150 units wide).
@export_range(0.5, 12.0, 0.5) var stroke_width: float = 4.0:
	set(value):
		stroke_width = value
		emit_changed()
## Draw the whole symbol in one color.
@export var use_mono_color: bool = false:
	set(value):
		use_mono_color = value
		emit_changed()
@export var mono_color: Color = Color.BLACK:
	set(value):
		mono_color = value
		emit_changed()
## Halo around the symbol, useful on busy maps. 0 = off.
@export_range(0.0, 10.0, 0.5) var outline_width: float = 0.0:
	set(value):
		outline_width = value
		emit_changed()
@export var outline_color: Color = Color8(239, 239, 239):
	set(value):
		outline_color = value
		emit_changed()
## Any other milsymbol option, e.g. {"hqStaffLength": 60, "simpleStatusModifier": true}.
@export var extra_options: Dictionary = {}:
	set(value):
		extra_options = value
		emit_changed()


## Options dictionary for MilSymbol.render().
func to_options() -> Dictionary:
	var options := {
		"colorMode": COLOR_MODE_NAMES[color_mode],
		"fill": fill,
		"frame": frame,
		"icon": icon,
		"fillOpacity": fill_opacity,
		"strokeWidth": stroke_width,
		"outlineWidth": outline_width,
		"outlineColor": _css(outline_color),
	}
	if use_mono_color:
		options.monoColor = _css(mono_color)
	options.merge(extra_options, true)
	return options


static func _css(color: Color) -> String:
	return "rgb(%d,%d,%d)" % [color.r8, color.g8, color.b8]
