@tool
@icon("res://addons/milsymbol/icons/milsymbol_sprite_2d.svg")
class_name MilGraphic2D
extends Node2D
## A multipoint control measure (boundary, phase line, axis of advance, fire area, ...) drawn from a SIDC
## and control points in the node's local coordinates. See MilGraphic for point order and amplifiers.

signal graphic_changed

## 20 digit number based SIDC, symbol set 25 (e.g. 10031000001403000000 is not one; 10032500001403000000 is a
## friendly phase line).
@export var sidc: String = "10032500001403000000":
	set(value):
		sidc = value
		_rebuild()
## Control points in local coordinates.
@export var points: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(200, 0)]):
	set(value):
		points = value
		_rebuild()
## Text and distance amplifiers: "T", "T1", "W", "W1", "H", "X", "X1", "AM" (AM in local units).
@export var amplifiers: Dictionary = {}:
	set(value):
		amplifiers = value
		_rebuild()
@export_range(0.25, 4.0, 0.05) var graphic_scale: float = 1.0:
	set(value):
		graphic_scale = value
		_rebuild()
@export_range(0.5, 12.0, 0.5) var line_width: float = 2.0:
	set(value):
		line_width = value
		_rebuild()  # hatch spacing depends on the line width
## Halo around lines and text for busy backgrounds. 0 = none.
@export_range(0.0, 8.0, 0.5) var halo: float = 0.0:
	set(value):
		halo = value
		queue_redraw()
@export var halo_color: Color = Color(1, 1, 1, 0.8):
	set(value):
		halo_color = value
		queue_redraw()
## Use the colours for a dark background.
@export var dark_background: bool = false:
	set(value):
		dark_background = value
		queue_redraw()

## The last build. Null until the node enters the tree.
var shape: MilGraphicShape


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	shape = MilGraphic.build(sidc, points, amplifiers, {"scale": graphic_scale, "line_width": line_width})
	queue_redraw()
	graphic_changed.emit()


func _draw() -> void:
	if shape == null:
		return
	MilGraphicRenderer.draw(self, shape, {
		"palette": MilGraphicRenderer.PALETTE_DARK_MAP if dark_background else MilGraphicRenderer.PALETTE_LIGHT_MAP,
		"width": line_width,
		"halo": halo,
		"halo_color": halo_color,
		"dash": 4.0 * line_width,
	})
