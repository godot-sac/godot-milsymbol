@icon("res://addons/milsymbol/icons/milsymbol_sprite_2d.svg")
class_name TacticalMap2D
extends Control
## A 2D tactical map: units (military symbols) and control measures on a Web Mercator plane with a
## latitude/longitude grid, layers, selection, pan and zoom.
##
## Units are drawn from a symbol atlas with one MultiMesh per layer, so thousands of moving symbols cost one
## draw call per layer; panning and zooming only change the layer transform. Control measures (MilGraphic)
## are rebuilt in screen space when the view changes.
##
## Mouse: wheel zooms at the cursor, left-drag on empty map pans, click selects a unit, Shift/Ctrl-click adds
## or removes it, Shift-drag selects with a box. Keyboard (when focused): arrows pan, +/- zoom.
## Geographic positions are WGS84 latitude / longitude in degrees; graphic control points are
## PackedVector2Array with x = longitude, y = latitude.

signal unit_selected(id: Variant)
signal selection_changed(ids: Array)
## `id` is null when the mouse leaves a unit.
signal unit_hovered(id: Variant)
signal map_clicked(latitude: float, longitude: float, button_index: int)
signal view_changed

const EARTH_RADIUS := 6378137.0
const MAX_LATITUDE := 85.0511287798
const DEFAULT_LAYER := "default"
const GRID_STEPS_DEG := [30.0, 20.0, 10.0, 5.0, 2.0, 1.0, 0.5, 1.0 / 4.0, 1.0 / 6.0, 1.0 / 12.0, 1.0 / 30.0,
		1.0 / 60.0, 1.0 / 120.0, 1.0 / 240.0, 1.0 / 360.0, 1.0 / 720.0, 1.0 / 1800.0, 1.0 / 3600.0]
const SYMBOL_SHADER := """
shader_type canvas_item;
// Symbols keep their pixel size while the layer is scaled by the zoom: the quad is divided by the layer scale
// before the instance (position, symbol size) and layer transforms are applied.
uniform vec2 atlas_size = vec2(512.0);
uniform float view_scale = 1.0;
void vertex() {
	VERTEX = VERTEX / view_scale;
	UV = (INSTANCE_CUSTOM.xy + UV * INSTANCE_CUSTOM.zw) / atlas_size;
}
"""

@export var center_latitude: float = 39.93:
	set(value):
		center_latitude = clampf(value, -MAX_LATITUDE, MAX_LATITUDE)
		_update_center()
@export var center_longitude: float = 32.86:
	set(value):
		center_longitude = wrapf(value, -180.0, 180.0)
		_update_center()
## Ground metres per screen pixel at the map centre. The map keeps its Web Mercator scale while panning, so
## this value changes with the centre latitude.
@export_range(0.1, 100000.0, 0.1, "exp") var meters_per_pixel: float = 50.0:
	set(value):
		_mpp = clampf(value, min_meters_per_pixel, max_meters_per_pixel) / _cos_center()
		_update_view()
	get:
		return _mpp * _cos_center()
@export var min_meters_per_pixel: float = 0.5
@export var max_meters_per_pixel: float = 20000.0
@export var background_color: Color = Color(0.11, 0.13, 0.15):
	set(value):
		background_color = value
		queue_redraw()
@export var grid_visible: bool = true:
	set(value):
		grid_visible = value
		queue_redraw()
@export var grid_color: Color = Color(1, 1, 1, 0.12):
	set(value):
		grid_color = value
		queue_redraw()
@export var text_color: Color = Color(1, 1, 1, 0.75):
	set(value):
		text_color = value
		_queue_overlay()
## Symbol size in pixels (milsymbol size: the frame is roughly this wide).
@export_range(10.0, 200.0, 1.0) var symbol_size: float = 36.0:
	set(value):
		symbol_size = value
		_restyle_units()
## Rendering options shared by every unit symbol.
@export var symbol_style: MilSymbolStyle:
	set(value):
		if symbol_style and symbol_style.changed.is_connected(_restyle_units):
			symbol_style.changed.disconnect(_restyle_units)
		symbol_style = value
		if symbol_style:
			symbol_style.changed.connect(_restyle_units)
		_restyle_units()
## Colours of control measures: MilGraphicRenderer.PALETTE_DARK_MAP or PALETTE_LIGHT_MAP (or your own).
@export var graphic_palette: Dictionary = MilGraphicRenderer.PALETTE_DARK_MAP:
	set(value):
		graphic_palette = value
		queue_redraw_layers()
@export_range(0.5, 8.0, 0.5) var graphic_line_width: float = 2.0:
	set(value):
		graphic_line_width = value
		queue_redraw_layers()
## Unit labels are drawn when at most this many units are on screen.
@export var label_limit: int = 300
@export var show_labels: bool = true:
	set(value):
		show_labels = value
		_queue_overlay()
@export var selection_color: Color = Color(1.0, 0.85, 0.2):
	set(value):
		selection_color = value
		_queue_overlay()

## Number of control measures drawn in the last redraw of every layer (after culling), for statistics.
var drawn_graphics: int:
	get:
		var total := 0
		for layer in _layers:
			total += layer.drawn
		return total

var _origin_x := 0.0  # Web Mercator metres of the plane origin (GDScript floats are doubles)
var _origin_y := 0.0
var _center_plane := Vector2.ZERO
var _mpp := 50.0 / cos(deg_to_rad(39.93))  # Web Mercator metres per pixel
var _view_version := 0

var _atlas := MilSymbolAtlas.new()
var _material := ShaderMaterial.new()
var _quad: ArrayMesh
var _layers: Array[Dictionary] = []  # {"name", "visible", "graphics_node", "units_node", "multimesh", "ids", "drawn"}
var _units := {}  # id -> {"sidc", "latitude", "longitude", "label", "layer", "plane", "entry", "index"}
var _graphics := {}  # id -> {"sidc", "points", "amplifiers", "layer", "shape", "version"}
var _selected := {}  # id -> true
var _hovered: Variant = null
var _overlay: Control
var _pressed := false
var _press_position := Vector2.ZERO
var _dragging := false
var _box_selecting := false
var _drag_current := Vector2.ZERO
var _commit_queued := false
var _cursor_lat_lon := PackedFloat64Array()


func _init() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shader := Shader.new()
	shader.code = SYMBOL_SHADER
	_material.shader = shader
	_quad = _make_quad()
	_atlas.texture_changed.connect(_on_atlas_texture_changed)
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay, false, Node.INTERNAL_MODE_BACK)
	_set_origin(center_latitude, center_longitude)
	add_layer(DEFAULT_LAYER)


func _ready() -> void:
	resized.connect(_update_view)
	_update_view()


# ------------------------------------------------------------------------------------------- coordinates

## Screen position (local to this control) of a geographic position.
func lat_lon_to_screen(latitude: float, longitude: float) -> Vector2:
	return _plane_to_screen(_to_plane(latitude, longitude))


## [latitude, longitude] in degrees of a screen position (local to this control).
func screen_to_lat_lon(position: Vector2) -> PackedFloat64Array:
	return _plane_to_lat_lon(_screen_to_plane(position))


## Ground metres per pixel at a latitude (Web Mercator stretches towards the poles).
func meters_per_pixel_at(latitude: float) -> float:
	return _mpp * cos(deg_to_rad(latitude))


func center_on(latitude: float, longitude: float, ground_meters_per_pixel: float = -1.0) -> void:
	center_latitude = latitude
	center_longitude = longitude
	if ground_meters_per_pixel > 0.0:
		meters_per_pixel = ground_meters_per_pixel


## Centres and zooms so that the box (degrees) fills the control, with a margin in pixels.
func zoom_to(lat_min: float, lon_min: float, lat_max: float, lon_max: float, margin: float = 40.0) -> void:
	var a := _to_plane(lat_min, lon_min)
	var b := _to_plane(lat_max, lon_max)
	var span := (b - a).abs()
	var available := (size - Vector2(margin, margin) * 2.0).max(Vector2(10, 10))
	var mpp := maxf(span.x / available.x, span.y / available.y)
	var center := _plane_to_lat_lon((a + b) / 2.0)
	center_latitude = center[0]
	center_longitude = center[1]
	meters_per_pixel = maxf(mpp, 0.001) * cos(deg_to_rad(center_latitude))


## Zooms to fit every unit and graphic.
func zoom_to_content(margin: float = 40.0) -> void:
	var box := Rect2()
	var first := true
	for id in _units:
		var u: Dictionary = _units[id]
		var p := Vector2(u.longitude, u.latitude)
		box = Rect2(p, Vector2.ZERO) if first else box.expand(p)
		first = false
	for id in _graphics:
		for p in _graphics[id].points:
			box = Rect2(p, Vector2.ZERO) if first else box.expand(p)
			first = false
	if not first:
		zoom_to(box.position.y, box.position.x, box.end.y, box.end.x, margin)


# ------------------------------------------------------------------------------------------- layers

## Adds a layer on top of the existing ones (no-op if it exists).
func add_layer(layer_name: String) -> void:
	if _layer(layer_name) != null:
		return
	var graphics_node := Node2D.new()
	graphics_node.name = "Graphics_" + layer_name.validate_node_name()
	var units_node := MultiMeshInstance2D.new()
	units_node.name = "Units_" + layer_name.validate_node_name()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	units_node.multimesh = multimesh
	units_node.material = _material
	units_node.texture = _atlas.texture
	var layer := {"name": layer_name, "visible": true, "graphics_node": graphics_node, "units_node": units_node,
			"multimesh": multimesh, "ids": [], "drawn": 0}
	graphics_node.draw.connect(_draw_layer_graphics.bind(layer))
	add_child(graphics_node)
	add_child(units_node)
	_layers.append(layer)
	_update_view()


func set_layer_visible(layer_name: String, layer_visible: bool) -> void:
	var layer = _layer(layer_name)
	if layer == null:
		return
	layer.visible = layer_visible
	layer.graphics_node.visible = layer_visible
	layer.units_node.visible = layer_visible
	if not layer_visible:
		var changed := false
		for id in layer.ids:
			changed = _selected.erase(id) or changed
		if changed:
			selection_changed.emit(get_selected_units())
	_queue_overlay()


func is_layer_visible(layer_name: String) -> bool:
	var layer = _layer(layer_name)
	return layer != null and layer.visible


func get_layer_names() -> PackedStringArray:
	var names := PackedStringArray()
	for layer in _layers:
		names.append(layer.name)
	return names


# ------------------------------------------------------------------------------------------- units

## Adds or replaces a unit. `id` can be any value usable as a Dictionary key (int, String, ...).
func add_unit(id: Variant, sidc: String, latitude: float, longitude: float, label: String = "",
		layer_name: String = DEFAULT_LAYER) -> void:
	if _units.has(id):
		remove_unit(id)
	add_layer(layer_name)
	var layer: Dictionary = _layer(layer_name)
	var unit := {"sidc": sidc, "latitude": latitude, "longitude": longitude, "label": label, "layer": layer_name,
			"layer_ref": layer, "plane": _to_plane(latitude, longitude),
			"entry": _atlas.get_entry(sidc, _symbol_options()), "index": layer.ids.size()}
	_units[id] = unit
	layer.ids.append(id)
	var multimesh: MultiMesh = layer.multimesh
	if multimesh.instance_count < layer.ids.size():
		_resize_multimesh(layer, maxi(64, multimesh.instance_count * 2))
	else:
		_write_instance(multimesh, unit)
	multimesh.visible_instance_count = layer.ids.size()
	_queue_commit()
	_queue_overlay()


func move_unit(id: Variant, latitude: float, longitude: float) -> void:
	var unit: Dictionary = _units.get(id, {})
	if unit.is_empty():
		return
	unit.latitude = latitude
	unit.longitude = longitude
	unit.plane = _to_plane(latitude, longitude)
	var multimesh: MultiMesh = unit.layer_ref.multimesh
	multimesh.set_instance_transform_2d(unit.index, _instance_transform(unit))
	if _overlay_tracks_units():
		_queue_overlay()


func set_unit_sidc(id: Variant, sidc: String) -> void:
	var unit: Dictionary = _units.get(id, {})
	if unit.is_empty() or unit.sidc == sidc:
		return
	unit.sidc = sidc
	unit.entry = _atlas.get_entry(sidc, _symbol_options())
	_write_instance(unit.layer_ref.multimesh, unit)
	_queue_commit()
	_queue_overlay()


func set_unit_label(id: Variant, label: String) -> void:
	if _units.has(id):
		_units[id].label = label
		_queue_overlay()


func remove_unit(id: Variant) -> void:
	var unit: Dictionary = _units.get(id, {})
	if unit.is_empty():
		return
	var layer: Dictionary = unit.layer_ref
	var ids: Array = layer.ids
	var index: int = unit.index
	var last_id = ids[ids.size() - 1]
	# Swap with the last instance so that the instances stay packed.
	ids[index] = last_id
	_units[last_id].index = index
	ids.pop_back()
	_units.erase(id)
	var multimesh: MultiMesh = layer.multimesh
	if index < ids.size():
		_write_instance(multimesh, _units[last_id])
	multimesh.visible_instance_count = ids.size()
	if _selected.erase(id):
		selection_changed.emit(get_selected_units())
	if _hovered == id:
		_hovered = null
	_queue_overlay()


func clear_units() -> void:
	for layer in _layers:
		layer.ids.clear()
		layer.multimesh.visible_instance_count = 0
	_units.clear()
	if not _selected.is_empty():
		_selected.clear()
		selection_changed.emit([])
	_hovered = null
	_queue_overlay()


func has_unit(id: Variant) -> bool:
	return _units.has(id)


## {"sidc", "latitude", "longitude", "label", "layer"} or {} if there is no such unit.
func get_unit(id: Variant) -> Dictionary:
	var unit: Dictionary = _units.get(id, {})
	if unit.is_empty():
		return {}
	return {"sidc": unit.sidc, "latitude": unit.latitude, "longitude": unit.longitude, "label": unit.label,
			"layer": unit.layer}


func get_unit_ids() -> Array:
	return _units.keys()


func get_unit_count() -> int:
	return _units.size()


func get_selected_units() -> Array:
	return _selected.keys()


func select_units(ids: Array, add: bool = false) -> void:
	if not add:
		_selected.clear()
	for id in ids:
		if _units.has(id) and _units[id].layer_ref.visible:
			_selected[id] = true
	selection_changed.emit(get_selected_units())
	_queue_overlay()


## The unit under a screen position (topmost layer first), or null.
func unit_at(position: Vector2) -> Variant:
	for l in range(_layers.size() - 1, -1, -1):
		var layer: Dictionary = _layers[l]
		if not layer.visible:
			continue
		var ids: Array = layer.ids
		for i in range(ids.size() - 1, -1, -1):
			var unit: Dictionary = _units[ids[i]]
			if unit.entry.is_empty():
				continue
			var bounds: Rect2 = unit.entry.bounds
			if bounds.has_point(position - _plane_to_screen(unit.plane)):
				return ids[i]
	return null


# ------------------------------------------------------------------------------------------- graphics

## Adds or replaces a control measure. `points`: x = longitude, y = latitude. Distance amplifiers ("AM")
## are in metres.
func add_graphic(id: Variant, sidc: String, points: PackedVector2Array, amplifiers: Dictionary = {},
		layer_name: String = DEFAULT_LAYER) -> void:
	if _graphics.has(id):
		remove_graphic(id)
	add_layer(layer_name)
	_graphics[id] = {"sidc": sidc, "points": points, "amplifiers": amplifiers, "layer": layer_name, "shape": null,
			"version": -1}
	_layer(layer_name).graphics_node.queue_redraw()


func remove_graphic(id: Variant) -> void:
	var graphic: Dictionary = _graphics.get(id, {})
	if graphic.is_empty():
		return
	_graphics.erase(id)
	var layer = _layer(graphic.layer)
	if layer != null:
		layer.graphics_node.queue_redraw()


func clear_graphics() -> void:
	_graphics.clear()
	queue_redraw_layers()


func has_graphic(id: Variant) -> bool:
	return _graphics.has(id)


## The control measure built for the current view (screen coordinates), or null before it is drawn.
func get_graphic_shape(id: Variant) -> MilGraphicShape:
	return _graphics.get(id, {}).get("shape")


func queue_redraw_layers() -> void:
	for layer in _layers:
		layer.graphics_node.queue_redraw()


# ------------------------------------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	if grid_visible:
		_draw_grid()


func _draw_grid() -> void:
	var font := get_theme_default_font()
	var top_left := screen_to_lat_lon(Vector2.ZERO)
	var bottom_right := screen_to_lat_lon(size)
	var step := GRID_STEPS_DEG[0] as float
	for candidate in GRID_STEPS_DEG:
		# Pixel spacing of one candidate step in longitude at the centre.
		if lat_lon_to_screen(center_latitude, center_longitude + candidate).x - size.x / 2.0 < 90.0:
			break
		step = candidate
	var label_color := Color(text_color, 0.6)
	var lon := floorf(top_left[1] / step) * step
	while lon <= bottom_right[1] + step:
		var x := lat_lon_to_screen(center_latitude, lon).x
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color)
		draw_string(font, Vector2(x + 3, 13), _format_angle(lon, "E", "W", step), HORIZONTAL_ALIGNMENT_LEFT,
				-1, 11, label_color)
		lon += step
	var lat := floorf(bottom_right[0] / step) * step
	while lat <= top_left[0] + step:
		var y := lat_lon_to_screen(lat, center_longitude).y
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color)
		draw_string(font, Vector2(4, y - 3), _format_angle(lat, "N", "S", step), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
				label_color)
		lat += step


func _draw_layer_graphics(layer: Dictionary) -> void:
	var node: Node2D = layer.graphics_node
	layer.drawn = 0
	var screen := Rect2(Vector2.ZERO, size).grow(200.0)
	var style := {"palette": graphic_palette, "width": graphic_line_width, "halo": 1.5,
			"halo_color": Color(background_color, 0.85), "font": get_theme_default_font(),
			"dash": graphic_line_width * 4.0}
	for id in _graphics:
		var graphic: Dictionary = _graphics[id]
		if graphic.layer != layer.name:
			continue
		var points := PackedVector2Array()
		var box := Rect2()
		for p in graphic.points:
			var s := lat_lon_to_screen(p.y, p.x)
			points.append(s)
			box = Rect2(s, Vector2.ZERO) if points.size() == 1 else box.expand(s)
		var amplifiers: Dictionary = graphic.amplifiers
		if amplifiers.has("AM") and not graphic.points.is_empty():
			box = box.grow(float(amplifiers.AM) / meters_per_pixel_at(graphic.points[0].y))
		if not screen.intersects(box):
			continue
		if graphic.version != _view_version or graphic.shape == null:
			if amplifiers.has("AM") and not graphic.points.is_empty():
				amplifiers = amplifiers.duplicate()
				amplifiers.AM = float(amplifiers.AM) / meters_per_pixel_at(graphic.points[0].y)
			graphic.shape = MilGraphic.build(graphic.sidc, points, amplifiers)
			graphic.version = _view_version
		MilGraphicRenderer.draw(node, graphic.shape, style)
		layer.drawn += 1


func _draw_overlay() -> void:
	var font := get_theme_default_font()
	# Labels and selection boxes. With many units only the selected and hovered ones are visited.
	var visible_units: Array = []
	var screen := Rect2(Vector2.ZERO, size)
	var candidates: Array = []
	if _overlay_tracks_units():
		for layer in _layers:
			if layer.visible:
				candidates.append_array(layer.ids)
	else:
		candidates = _selected.keys()
		if _hovered != null and not _selected.has(_hovered):
			candidates.append(_hovered)
	for id in candidates:
		var unit: Dictionary = _units[id]
		if not unit.layer_ref.visible:
			continue
		var p := _plane_to_screen(unit.plane)
		if screen.has_point(p):
			visible_units.append([id, unit, p])
	var labels := show_labels and _overlay_tracks_units() and visible_units.size() <= label_limit
	for item in visible_units:
		var unit: Dictionary = item[1]
		var p: Vector2 = item[2]
		var bounds: Rect2 = unit.entry.get("bounds", Rect2(-8, -8, 16, 16))
		if _selected.has(item[0]):
			_overlay.draw_rect(Rect2(p + bounds.position, bounds.size).grow(3.0), selection_color, false, 2.0)
		elif _hovered == item[0]:
			_overlay.draw_rect(Rect2(p + bounds.position, bounds.size).grow(3.0), Color(selection_color, 0.5), false, 1.0)
		if labels and unit.label != "":
			var y := p.y + bounds.end.y + 12.0
			_overlay.draw_string_outline(font, Vector2(p.x - 80, y), unit.label, HORIZONTAL_ALIGNMENT_CENTER, 160, 11,
					3, Color(background_color, 0.8))
			_overlay.draw_string(font, Vector2(p.x - 80, y), unit.label, HORIZONTAL_ALIGNMENT_CENTER, 160, 11, text_color)
	if _box_selecting:
		var box := Rect2(_press_position, _drag_current - _press_position).abs()
		_overlay.draw_rect(box, Color(selection_color, 0.12))
		_overlay.draw_rect(box, selection_color, false, 1.0)
	_draw_scale_bar(font)
	_draw_north_arrow(font)
	if _cursor_lat_lon.size() == 2:
		var text := "%s  %s" % [_format_coordinate(_cursor_lat_lon[0], "N", "S"),
				_format_coordinate(_cursor_lat_lon[1], "E", "W")]
		_overlay.draw_string(font, Vector2(size.x - 230, size.y - 10), text, HORIZONTAL_ALIGNMENT_RIGHT, 220, 12,
				text_color)


func _draw_scale_bar(font: Font) -> void:
	var ground := meters_per_pixel_at(center_latitude)
	var target := ground * 120.0
	var magnitude := pow(10.0, floorf(log(target) / log(10.0)))
	var length_m := magnitude
	for factor in [1.0, 2.0, 5.0, 10.0]:
		if magnitude * factor <= target:
			length_m = magnitude * factor
	var length := length_m / ground
	var start := Vector2(16, size.y - 22)
	var color := text_color
	_overlay.draw_line(start, start + Vector2(length, 0), color, 2.0)
	_overlay.draw_line(start, start + Vector2(0, -6), color, 2.0)
	_overlay.draw_line(start + Vector2(length, 0), start + Vector2(length, -6), color, 2.0)
	var text := ("%d km" % roundi(length_m / 1000.0)) if length_m >= 1000.0 else ("%d m" % roundi(length_m))
	_overlay.draw_string(font, start + Vector2(length + 6, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


func _draw_north_arrow(font: Font) -> void:
	var n := Vector2(size.x - 24, 34)
	_overlay.draw_colored_polygon(PackedVector2Array([n + Vector2(0, -14), n + Vector2(6, 6), n + Vector2(-6, 6)]),
			text_color)
	_overlay.draw_string(font, n + Vector2(-4, 20), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)


static func _format_angle(value: float, positive: String, negative: String, step: float) -> String:
	var hemisphere := positive if value >= 0.0 else negative
	var total_seconds := roundi(absf(value) * 3600.0)
	var degrees := total_seconds / 3600
	var minutes := (total_seconds / 60) % 60
	var seconds := total_seconds % 60
	if step >= 1.0:
		return "%d°%s" % [degrees, hemisphere]
	if step >= 1.0 / 60.0:
		return "%d°%02d'%s" % [degrees, minutes, hemisphere]
	return "%d°%02d'%02d\"%s" % [degrees, minutes, seconds, hemisphere]


static func _format_coordinate(value: float, positive: String, negative: String) -> String:
	return "%.5f°%s" % [absf(value), positive if value >= 0.0 else negative]


# ------------------------------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.0 / 1.2 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.2
			_zoom_at(button.position, factor)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_pressed = true
				_press_position = button.position
				_drag_current = button.position
				_box_selecting = button.shift_pressed and unit_at(button.position) == null
				_dragging = false
			else:
				if _box_selecting:
					_finish_box_selection(button.ctrl_pressed)
				elif not _dragging:
					_click(button.position, button.shift_pressed or button.ctrl_pressed, MOUSE_BUTTON_LEFT)
				_pressed = false
				_dragging = false
				_box_selecting = false
				_queue_overlay()
			accept_event()
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			var at := screen_to_lat_lon(button.position)
			map_clicked.emit(at[0], at[1], MOUSE_BUTTON_RIGHT)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_cursor_lat_lon = screen_to_lat_lon(motion.position)
		if _pressed:
			_drag_current = motion.position
			if not _dragging and motion.position.distance_to(_press_position) > 4.0:
				_dragging = true
			if _dragging and not _box_selecting:
				_pan_pixels(motion.relative)
		else:
			var hovered = unit_at(motion.position)
			if hovered != _hovered:
				_hovered = hovered
				unit_hovered.emit(hovered)
		_queue_overlay()
	elif event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		match key.keycode:
			KEY_LEFT:
				_pan_pixels(Vector2(80, 0))
			KEY_RIGHT:
				_pan_pixels(Vector2(-80, 0))
			KEY_UP:
				_pan_pixels(Vector2(0, 80))
			KEY_DOWN:
				_pan_pixels(Vector2(0, -80))
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
				_zoom_at(size / 2.0, 1.0 / 1.5)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_at(size / 2.0, 1.5)
			_:
				return
		accept_event()


func _click(position: Vector2, toggle: bool, button_index: int) -> void:
	var id = unit_at(position)
	if id == null:
		if not toggle and not _selected.is_empty():
			_selected.clear()
			selection_changed.emit([])
		var at := screen_to_lat_lon(position)
		map_clicked.emit(at[0], at[1], button_index)
		return
	if toggle:
		if _selected.has(id):
			_selected.erase(id)
		else:
			_selected[id] = true
	else:
		_selected.clear()
		_selected[id] = true
	unit_selected.emit(id)
	selection_changed.emit(get_selected_units())


func _finish_box_selection(add: bool) -> void:
	var box := Rect2(_press_position, _drag_current - _press_position).abs()
	if not add:
		_selected.clear()
	for layer in _layers:
		if not layer.visible:
			continue
		for id in layer.ids:
			if box.has_point(_plane_to_screen(_units[id].plane)):
				_selected[id] = true
	selection_changed.emit(get_selected_units())


func _pan_pixels(delta: Vector2) -> void:
	_center_plane -= delta * _mpp
	_sync_center_from_plane()


func _zoom_at(position: Vector2, factor: float) -> void:
	var before := _screen_to_plane(position)
	meters_per_pixel = meters_per_pixel * factor
	# Keep the point under the cursor in place.
	_center_plane += before - _screen_to_plane(position)
	_sync_center_from_plane()


# ------------------------------------------------------------------------------------------- internals

func _layer(layer_name: String) -> Variant:
	for layer in _layers:
		if layer.name == layer_name:
			return layer
	return null


func _symbol_options() -> Dictionary:
	var options := symbol_style.to_options() if symbol_style else {}
	options.size = symbol_size
	return options


func _instance_transform(unit: Dictionary) -> Transform2D:
	var entry: Dictionary = unit.entry
	if entry.is_empty():
		return Transform2D(Vector2.ZERO, Vector2.ZERO, unit.plane)
	var region: Rect2i = entry.region
	return Transform2D(Vector2(region.size.x, 0), Vector2(0, region.size.y), unit.plane)


func _write_instance(multimesh: MultiMesh, unit: Dictionary) -> void:
	multimesh.set_instance_transform_2d(unit.index, _instance_transform(unit))
	var region: Rect2i = unit.entry.get("region", Rect2i())
	multimesh.set_instance_custom_data(unit.index, Color(region.position.x, region.position.y, region.size.x,
			region.size.y))


func _resize_multimesh(layer: Dictionary, count: int) -> void:
	var multimesh: MultiMesh = layer.multimesh
	multimesh.instance_count = count  # clears the buffer
	for id in layer.ids:
		_write_instance(multimesh, _units[id])
	multimesh.visible_instance_count = layer.ids.size()


func _restyle_units() -> void:
	if not is_node_ready():
		return
	_atlas.clear()
	for id in _units:
		var unit: Dictionary = _units[id]
		unit.entry = _atlas.get_entry(unit.sidc, _symbol_options())
		_write_instance(unit.layer_ref.multimesh, unit)
	_queue_commit()
	_queue_overlay()


func _queue_commit() -> void:
	if _commit_queued:
		return
	_commit_queued = true
	_commit_atlas.call_deferred()


func _commit_atlas() -> void:
	_commit_queued = false
	_atlas.commit()
	_material.set_shader_parameter("atlas_size", Vector2(_atlas.image.get_size()))
	for layer in _layers:
		layer.units_node.texture = _atlas.texture


func _on_atlas_texture_changed() -> void:
	for layer in _layers:
		layer.units_node.texture = _atlas.texture


func _queue_overlay() -> void:
	if _overlay:
		_overlay.queue_redraw()


## Labels are considered (and the overlay follows every unit move) only below this many units.
func _overlay_tracks_units() -> bool:
	return show_labels and _units.size() <= label_limit * 10


func _make_quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5),
			Vector2(-0.5, 0.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Web Mercator plane relative to the origin (metres, y down). GDScript floats are doubles, so the large
## absolute Mercator values are subtracted before converting to 32-bit Vector2.
func _to_plane(latitude: float, longitude: float) -> Vector2:
	var lat := deg_to_rad(clampf(latitude, -MAX_LATITUDE, MAX_LATITUDE))
	var x := EARTH_RADIUS * deg_to_rad(longitude) - _origin_x
	var y := EARTH_RADIUS * log(tan(PI / 4.0 + lat / 2.0)) - _origin_y
	return Vector2(x, -y)


func _plane_to_lat_lon(p: Vector2) -> PackedFloat64Array:
	var x := float(p.x) + _origin_x
	var y := -float(p.y) + _origin_y
	var longitude := rad_to_deg(x / EARTH_RADIUS)
	var latitude := rad_to_deg(2.0 * atan(exp(y / EARTH_RADIUS)) - PI / 2.0)
	return PackedFloat64Array([latitude, longitude])


func _set_origin(latitude: float, longitude: float) -> void:
	var lat := deg_to_rad(latitude)
	_origin_x = EARTH_RADIUS * deg_to_rad(longitude)
	_origin_y = EARTH_RADIUS * log(tan(PI / 4.0 + lat / 2.0))


func _plane_to_screen(p: Vector2) -> Vector2:
	return (p - _center_plane) / _mpp + size / 2.0


func _screen_to_plane(s: Vector2) -> Vector2:
	return (s - size / 2.0) * _mpp + _center_plane


func _update_center() -> void:
	_center_plane = _to_plane(center_latitude, center_longitude)
	_update_view()


func _sync_center_from_plane() -> void:
	var at := _plane_to_lat_lon(_center_plane)
	center_latitude = at[0]
	center_longitude = at[1]


func _cos_center() -> float:
	return maxf(cos(deg_to_rad(center_latitude)), 0.01)


func _update_view() -> void:
	_view_version += 1
	var scale := 1.0 / _mpp
	_material.set_shader_parameter("view_scale", scale)
	for layer in _layers:
		var node: MultiMeshInstance2D = layer.units_node
		node.scale = Vector2(scale, scale)
		node.position = size / 2.0 - _center_plane * scale
		layer.graphics_node.queue_redraw()
	queue_redraw()
	_queue_overlay()
	view_changed.emit()
