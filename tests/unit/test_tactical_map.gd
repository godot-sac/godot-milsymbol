extends GutTest
## TacticalMap2D (projection, units, selection, layers, graphics) and MilSymbolAtlas.

const FRIEND_INF := "10031000161211000000"
const HOSTILE_ARMOUR := "10061000151205000000"
const HQ := "10031002181211000000"

var _map: TacticalMap2D


func before_each() -> void:
	_map = TacticalMap2D.new()
	_map.size = Vector2(800, 600)
	add_child_autofree(_map)
	_map.center_on(39.93, 32.86, 50.0)


func _click(position: Vector2, shift: bool = false) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.shift_pressed = shift
		_map._gui_input(event)


func _drag(from: Vector2, to: Vector2, shift: bool = false) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.shift_pressed = shift
	_map._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = to
	motion.relative = to - from
	_map._gui_input(motion)
	var release := press.duplicate()
	release.pressed = false
	release.position = to
	_map._gui_input(release)


func test_projection_round_trip_and_scale() -> void:
	assert_almost_eq(_map.lat_lon_to_screen(39.93, 32.86), Vector2(400, 300), Vector2(0.01, 0.01), "centre")
	for point in [Vector2(10, 20), Vector2(790, 590), Vector2(400, 0)]:
		var ll := _map.screen_to_lat_lon(point)
		assert_almost_eq(_map.lat_lon_to_screen(ll[0], ll[1]), point, Vector2(0.01, 0.01))
	# 1 km east of the centre is 20 px at 50 m/px.
	var east := 32.86 + 1.0 / (111.32 * cos(deg_to_rad(39.93)))
	assert_almost_eq(_map.lat_lon_to_screen(39.93, east).x - 400.0, 20.0, 0.1)
	assert_almost_eq(_map.meters_per_pixel, 50.0, 0.0001)


func test_panning_north_keeps_the_mercator_scale() -> void:
	var before := _map.meters_per_pixel_at(45.0)
	_map.center_latitude = 45.0
	assert_almost_eq(_map.meters_per_pixel_at(45.0), before, 0.0001)
	assert_lt(_map.meters_per_pixel, 50.0, "ground resolution at the centre changes with latitude")


func test_wheel_zoom_keeps_the_point_under_the_cursor() -> void:
	var cursor := Vector2(650, 120)
	var before := _map.screen_to_lat_lon(cursor)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = cursor
	_map._gui_input(wheel)
	assert_lt(_map.meters_per_pixel, 50.0)
	assert_almost_eq(_map.lat_lon_to_screen(before[0], before[1]), cursor, Vector2(0.05, 0.05))


func test_drag_pans_the_map() -> void:
	var start := _map.screen_to_lat_lon(Vector2(400, 300))
	_drag(Vector2(400, 300), Vector2(500, 350))
	assert_almost_eq(_map.lat_lon_to_screen(start[0], start[1]), Vector2(500, 350), Vector2(0.05, 0.05))
	assert_eq(_map.get_selected_units(), [], "dragging does not select")


func test_units_add_move_remove() -> void:
	for i in 10:
		_map.add_unit(i, FRIEND_INF, 39.9 + i * 0.01, 32.8, "U%d" % i)
	assert_eq(_map.get_unit_count(), 10)
	_map.remove_unit(3)
	_map.remove_unit(9)
	_map.remove_unit(0)
	assert_eq(_map.get_unit_count(), 7)
	# Instances stay packed and every remaining unit still points at its own instance.
	var layer: Dictionary = _map._layer(TacticalMap2D.DEFAULT_LAYER)
	var multimesh: MultiMesh = layer.multimesh
	assert_eq(multimesh.visible_instance_count, 7)
	for id in _map.get_unit_ids():
		var unit: Dictionary = _map._units[id]
		assert_eq(layer.ids[unit.index], id, "unit %s" % id)
		# The headless (dummy) renderer does not keep MultiMesh data, so it is only read back with a renderer.
		if DisplayServer.get_name() != "headless":
			var origin := multimesh.get_instance_transform_2d(unit.index).origin
			assert_almost_eq(origin, unit.plane, Vector2(0.01, 0.01), "unit %s" % id)
	_map.move_unit(5, 40.0, 33.0)
	assert_eq(_map.get_unit(5).latitude, 40.0)
	assert_almost_eq(_map._units[5].plane, _map._to_plane(40.0, 33.0), Vector2(0.01, 0.01))
	_map.add_unit(5, HOSTILE_ARMOUR, 39.95, 32.9)  # replaces
	assert_eq(_map.get_unit_count(), 7)
	assert_eq(_map.get_unit(5).sidc, HOSTILE_ARMOUR)


func test_many_units_grow_the_multimesh() -> void:
	for i in 300:
		_map.add_unit(i, [FRIEND_INF, HOSTILE_ARMOUR, HQ][i % 3], 39.9 + (i % 20) * 0.003, 32.8 + (i / 20) * 0.004)
	var multimesh: MultiMesh = _map._layer(TacticalMap2D.DEFAULT_LAYER).multimesh
	assert_gte(multimesh.instance_count, 300)
	assert_eq(multimesh.visible_instance_count, 300)
	assert_eq(_map._atlas.size(), 3, "three distinct symbols in the atlas")


func test_click_and_box_selection() -> void:
	_map.add_unit("a", FRIEND_INF, 39.93, 32.86)
	_map.add_unit("b", HOSTILE_ARMOUR, 39.94, 32.88)
	_map.add_unit("c", HQ, 39.90, 32.80)
	watch_signals(_map)
	var a := _map.lat_lon_to_screen(39.93, 32.86)
	var b := _map.lat_lon_to_screen(39.94, 32.88)
	_click(a)
	assert_eq(_map.get_selected_units(), ["a"])
	assert_signal_emitted_with_parameters(_map, "unit_selected", ["a"])
	_click(b, true)
	assert_eq(_map.get_selected_units().size(), 2, "shift-click adds")
	_click(Vector2(5, 5))
	assert_eq(_map.get_selected_units(), [], "click on empty map clears")
	assert_signal_emitted(_map, "map_clicked")
	# Box around a and b but not c (which is south-west); it starts on empty map.
	_drag(a + Vector2(-40, 40), b + Vector2(40, -40), true)
	var selected := _map.get_selected_units()
	selected.sort()
	assert_eq(selected, ["a", "b"])


func test_hidden_layers_are_not_hit() -> void:
	_map.add_unit("h", FRIEND_INF, 39.93, 32.86, "", "Hidden")
	var p := _map.lat_lon_to_screen(39.93, 32.86)
	assert_eq(_map.unit_at(p), "h")
	_map.set_layer_visible("Hidden", false)
	assert_null(_map.unit_at(p))
	assert_eq(Array(_map.get_layer_names()), [TacticalMap2D.DEFAULT_LAYER, "Hidden"])


func test_hq_symbol_is_hit_around_its_anchor() -> void:
	_map.add_unit("hq", HQ, 39.93, 32.86)
	var p := _map.lat_lon_to_screen(39.93, 32.86)
	assert_eq(_map.unit_at(p + Vector2(0, -20)), "hq", "the frame is above the staff foot")
	assert_null(_map.unit_at(p + Vector2(0, 30)), "nothing below the foot")


func test_graphics_are_built_in_screen_space() -> void:
	var a := Vector2(32.80, 39.90)
	var b := Vector2(32.90, 39.95)
	_map.add_graphic("pl", "10032500001403000000", PackedVector2Array([a, b]), {"T": "X"})
	_map.add_graphic("nfa", "10032500002403030000", PackedVector2Array([a]), {"AM": 1000.0})
	await wait_process_frames(2)
	var line := _map.get_graphic_shape("pl")
	assert_not_null(line)
	assert_true(line.valid)
	assert_almost_eq(line.primitives[0].points[0], _map.lat_lon_to_screen(a.y, a.x), Vector2(0.01, 0.01))
	var circle := _map.get_graphic_shape("nfa")
	var radius: float = circle.primitives[0].points[0].distance_to(_map.lat_lon_to_screen(a.y, a.x))
	assert_almost_eq(radius, 1000.0 / _map.meters_per_pixel_at(a.y), 0.05, "AM is converted from metres")
	assert_eq(_map.drawn_graphics, 2)
	_map.remove_graphic("pl")
	assert_false(_map.has_graphic("pl"))


func test_zoom_to_content() -> void:
	_map.add_unit("w", FRIEND_INF, 39.0, 32.0)
	_map.add_unit("e", FRIEND_INF, 40.0, 34.0)
	_map.zoom_to_content(50.0)
	var w := _map.lat_lon_to_screen(39.0, 32.0)
	var e := _map.lat_lon_to_screen(40.0, 34.0)
	assert_true(Rect2(Vector2.ZERO, _map.size).grow(0.5).has_point(w) and Rect2(Vector2.ZERO, _map.size).grow(0.5).has_point(e))
	assert_almost_eq(maxf(e.x - w.x, w.y - e.y), maxf(800.0, 600.0) - 100.0, 1.0, "fills the larger fitting side")


func test_atlas_centres_the_anchor_and_grows() -> void:
	var atlas := MilSymbolAtlas.new(64)
	var entry := atlas.get_entry(HQ, {"size": 40})
	var region: Rect2i = entry.region
	var bounds: Rect2 = entry.bounds
	assert_true(bounds.has_point(Vector2(0, -5)), "the frame is above the HQ anchor")
	# The region is centred on the anchor: it covers the symbol on both sides.
	assert_gte(region.size.x / 2.0, maxf(-bounds.position.x, bounds.end.x) - 1.0)
	assert_gte(region.size.y / 2.0, maxf(-bounds.position.y, bounds.end.y) - 1.0)
	assert_eq(atlas.get_entry(HQ, {"size": 40}), entry, "cached")
	for i in 20:
		atlas.get_entry("1003100000%s0000000000" % ["11", "12", "13", "14", "15"][i % 5], {"size": 40 + i})
	assert_gt(atlas.image.get_width(), 64, "grew")
	atlas.commit()
	assert_not_null(atlas.texture)
	assert_eq(atlas.texture.get_size(), Vector2(atlas.image.get_size()))
