extends Control
## TacticalMap2D demo: a fictional brigade attack east of Ankara with units and control measures.
##
## Keys: G grid, 1-4 layer on/off, M movement on/off, N 5000-unit stress test on/off, F fit to content,
## L labels, D light/dark map, F12 screenshot (user://), H help. Mouse: wheel zoom, drag pan, click select,
## Shift-drag box select.
## Command line (after --): --screenshot <file.png> [--seconds <s>] saves a picture and quits; --stress <n> starts
## with n extra moving units; --static starts with movement off; --seconds alone quits after s seconds and
## prints frame statistics.

const ORIGIN := Vector2(32.86, 39.93)  # longitude, latitude (Ankara)
const KM_PER_DEG_LAT := 111.32

# Units: id, SIDC, east km, north km, label, layer, route (east/north km points; moves back and forth), speed km/h
const UNITS: Array[Array] = [
	["1BDE", "10031002181211000000", -16.0, 4.0, "1 BDE HQ", "Friendly", [], 0.0],
	["1-1", "10031000161205000000", -11.5, 6.0, "1-1 AR", "Friendly", [Vector2(-11.5, 6.0), Vector2(-2, 6.4), Vector2(9, 5.6)], 18.0],
	["1-2", "10031000161211000000", -12.5, 4.0, "1-2 IN", "Friendly", [Vector2(-12.5, 4.0), Vector2(-2, 4.6), Vector2(8, 4.4)], 12.0],
	["1-3", "10031000161211000000", -8.5, 9.0, "1-3 IN", "Friendly", [], 0.0],
	["1-FA", "10031000161303000000", -17.0, 7.5, "1-4 FA", "Friendly", [], 0.0],
	["1-RC", "10031000151210000000", -6.5, 11.0, "A/1-5 CAV", "Friendly", [Vector2(-6.5, 11.0), Vector2(4, 11.5)], 20.0],
	["2BDE", "10031002181211000000", -16.0, -5.0, "2 BDE HQ", "Friendly", [], 0.0],
	["2-1", "10031000161211000000", -10.0, -4.5, "2-1 IN", "Friendly", [Vector2(-10.0, -4.5), Vector2(0, -5.6), Vector2(9, -5.4)], 10.0],
	["2-2", "10031000161205000000", -11.0, -7.0, "2-2 AR", "Friendly", [Vector2(-11.0, -7.0), Vector2(0, -7.4), Vector2(8, -6.6)], 16.0],
	["2-FA", "10031000161303000000", -17.5, -8.0, "2-4 FA", "Friendly", [], 0.0],
	["UAV", "10030100001103000000", -4.0, 0.0, "UAV 1", "Friendly", [Vector2(-4, 0), Vector2(16, 9), Vector2(16, -9), Vector2(-4, 0)], 90.0],
	["HEL", "10030100001102000000", -14.0, 0.5, "AH 1", "Friendly", [], 0.0],
	["E1", "10061000161211000000", 15.6, 3.4, "", "Hostile", [], 0.0],
	["E2", "10061000151205000000", 15.8, -7.2, "", "Hostile", [], 0.0],
	["E3", "10061000151211000000", 11.5, 1.0, "", "Hostile", [], 0.0],
	["E4", "10061000161303000000", 19.5, 0.0, "", "Hostile", [], 0.0],
	["E5", "10061000141211000000", 10.5, -9.5, "", "Hostile", [], 0.0],
	["E6", "10061002181211000000", 21.0, 6.0, "", "Hostile", [], 0.0],
	["E7", "10061500001101000000", 13.0, -1.5, "", "Hostile", [], 0.0],
]

# Control measures: id, entity code, identity, points (east/north km), amplifiers (AM in metres), echelon
const GRAPHICS: Array[Array] = [
	["ao", "120100", "3", [Vector2(-26, 17), Vector2(23, 17), Vector2(23, -13), Vector2(-26, -13)], {"T": "1 DIV"}, "00"],
	["bdy", "110100", "3", [Vector2(-20, 0), Vector2(0, 0.6), Vector2(23, 0)], {"T": "1", "T1": "2"}, "18"],
	["ld", "141100", "3", [Vector2(-7, 13), Vector2(-7.5, 0), Vector2(-7, -13)], {}, "00"],
	["flot", "140100", "3", [Vector2(-6.5, -13), Vector2(-6.0, 0), Vector2(-6.5, 13)], {}, "00"],
	["plblue", "140300", "3", [Vector2(2, 13), Vector2(2.5, 0), Vector2(2, -13)], {"T": "BLUE"}, "00"],
	["plred", "140300", "3", [Vector2(10.2, 13), Vector2(9.9, 0), Vector2(10.2, -13)], {"T": "RED"}, "00"],
	["fscl", "260100", "3", [Vector2(22, 13), Vector2(22, -13)], {"T": "1 DIV", "W": "0600Z"}, "00"],
	["aa", "150200", "3", [Vector2(-15, 8), Vector2(-10, 8.5), Vector2(-9, 3), Vector2(-14.5, 2.5)], {"T": "EAGLE"}, "00"],
	["obj1", "151700", "3", [Vector2(12, 8.5), Vector2(17, 8.5), Vector2(17.5, 3), Vector2(12.5, 2.5)], {"T": "STEEL"}, "00"],
	["obj2", "151700", "3", [Vector2(12, -2.5), Vector2(17, -3), Vector2(17.5, -8.5), Vector2(12.5, -8)], {"T": "IRON"}, "00"],
	["axmain", "151403", "3", [Vector2(11.5, 5.5), Vector2(2, 6.2), Vector2(-8.5, 5.5), Vector2(9.2, 6.8)], {"T": "1 BDE"}, "00"],
	["axspt", "151404", "3", [Vector2(11.5, -5.5), Vector2(1, -6.3), Vector2(-8.5, -5.8), Vector2(9.5, -4.6)], {"T": "2 BDE"}, "00"],
	["doa", "140603", "3", [Vector2(9, 11.5), Vector2(-5, 11)], {}, "00"],
	["nai", "120200", "3", [Vector2(18.5, 11.5), Vector2(21, 11.5), Vector2(21, 9.5), Vector2(18.5, 9.5)], {"T": "1"}, "00"],
	["tai", "120300", "3", [Vector2(18.5, -1.5), Vector2(21, -1.5), Vector2(21, 1.5), Vector2(18.5, 1.5)], {"T": "2"}, "00"],
	["nfa", "240303", "3", [Vector2(5, -10.5)], {"T": "HOSP", "AM": 1200.0}, "00"],
	["rfa", "240402", "3", [Vector2(-3, 9.0), Vector2(1, 9.0)], {"T": "3", "AM": 1500.0}, "00"],
	["belt", "270100", "6", [Vector2(7.2, 12), Vector2(8.2, 12), Vector2(8.2, -12), Vector2(7.2, -12)], {"T": "B1"}, "00"],
	["mines", "270800", "6", [Vector2(11, 1.5), Vector2(12.5, 1.5), Vector2(12.5, -0.5), Vector2(11, -0.5)], {}, "00"],
	["flote", "140100", "6", [Vector2(11.6, -13), Vector2(11.9, 0), Vector2(11.6, 13)], {}, "00"],
	["msr", "330301", "3", [Vector2(-20, -11), Vector2(-14, -9.5), Vector2(-9, -2), Vector2(-4, -1)], {"T": "IRON"}, "00"],
	["corridor", "170100", "3", [Vector2(-20, 11.5), Vector2(-8, 12), Vector2(6, 12.3)], {"T": "AC1", "AM": 900.0, "X": "300M"}, "00"],
]

var _map: TacticalMap2D
var _info: Label
var _help: Label
var _routes := {}  # unit id -> {"route": PackedVector2Array (km), "speed": km/h, "distance": km}
var _moving := true
var _stress_ids: Array = []
var _stress_position := PackedVector2Array()  # longitude, latitude
var _stress_velocity := PackedVector2Array()
var _rng := RandomNumberGenerator.new()
var _screenshot := ""
var _quit_after := 0.0
var _elapsed := 0.0
var _frame_times: Array[float] = []


func _ready() -> void:
	_rng.seed = 7
	_map = TacticalMap2D.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_map)
	for layer in ["Control measures", "Friendly", "Hostile", "Stress"]:
		_map.add_layer(layer)
	# Centre a little west of the scenario so that the HUD (top left) does not cover it.
	var center := _km_to_lon_lat(Vector2(-4.5, 2.0))
	_map.center_on(center.y, center.x, 52.0)
	for def in GRAPHICS:
		var points := PackedVector2Array()
		for p in def[3]:
			points.append(_km_to_lon_lat(p))
		var sidc := "100%s2500%s%s0000" % [def[2], def[5], def[1]]
		_map.add_graphic(def[0], sidc, points, def[4], "Control measures")
	for def in UNITS:
		var p := _km_to_lon_lat(Vector2(def[2], def[3]))
		_map.add_unit(def[0], def[1], p.y, p.x, def[4], def[5])
		if not def[6].is_empty():
			_routes[def[0]] = {"route": PackedVector2Array(def[6]), "speed": def[7], "distance": 0.0}
	_map.selection_changed.connect(_on_selection_changed)
	_map.map_clicked.connect(func(lat: float, lon: float, _button: int) -> void:
		_info.tooltip_text = "%.5f, %.5f" % [lat, lon])
	_build_hud()
	_parse_arguments()
	_map.grab_focus()


func _parse_arguments() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--screenshot")
	if i >= 0 and i + 1 < args.size():
		_screenshot = args[i + 1]
		_quit_after = 1.5
	i = args.find("--seconds")
	if i >= 0 and i + 1 < args.size():
		_quit_after = float(args[i + 1])
	if args.has("--static"):
		_moving = false
	i = args.find("--stress")
	if i >= 0 and i + 1 < args.size():
		_toggle_stress(int(args[i + 1]))


func _build_hud() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 24)
	panel.modulate = Color(1, 1, 1, 0.9)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	for i in _map.get_layer_names().size():
		var layer_name: String = _map.get_layer_names()[i]
		if layer_name == TacticalMap2D.DEFAULT_LAYER:
			continue
		var check := CheckBox.new()
		check.text = "%d  %s" % [i, layer_name]
		check.button_pressed = _map.is_layer_visible(layer_name)
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(on: bool) -> void: _map.set_layer_visible(layer_name, on))
		check.name = "Layer_" + layer_name.validate_node_name()
		box.add_child(check)
	_info = Label.new()
	box.add_child(_info)
	_help = Label.new()
	_help.text = ("G grid · 1-4 layers · M movement · N 5000 units · F fit · L labels · D light/dark\n"
			+ "Wheel zoom · drag pan · click select · Shift-drag box select · F12 screenshot · H help")
	box.add_child(_help)


func _process(delta: float) -> void:
	_elapsed += delta
	_frame_times.append(delta)
	if _moving:
		_move_units(delta)
	_update_info()
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		if _screenshot != "":
			_save_screenshot(_screenshot)
		_print_statistics()
		get_tree().quit()


func _move_units(delta: float) -> void:
	# Demo time runs 60x faster than real time so that the movement is visible.
	var hours := delta * 60.0 / 3600.0
	for id in _routes:
		var r: Dictionary = _routes[id]
		var route: PackedVector2Array = r.route
		var total := 0.0
		for k in range(1, route.size()):
			total += route[k - 1].distance_to(route[k])
		r.distance = fmod(r.distance + r.speed * hours, total * 2.0)
		var along: float = r.distance if r.distance <= total else total * 2.0 - r.distance
		var p := _point_along(route, along)
		var ll := _km_to_lon_lat(p)
		_map.move_unit(id, ll.y, ll.x)
	for i in _stress_ids.size():
		var p := _stress_position[i] + _stress_velocity[i] * delta
		_stress_position[i] = p
		_map.move_unit(_stress_ids[i], p.y, p.x)


func _point_along(route: PackedVector2Array, distance: float) -> Vector2:
	for k in range(1, route.size()):
		var segment := route[k - 1].distance_to(route[k])
		if distance <= segment:
			return route[k - 1].lerp(route[k], distance / segment)
		distance -= segment
	return route[route.size() - 1]


func _toggle_stress(count: int = 5000) -> void:
	if not _stress_ids.is_empty():
		for id in _stress_ids:
			_map.remove_unit(id)
		_stress_ids.clear()
		_stress_position.clear()
		_stress_velocity.clear()
		return
	var identities := ["3", "6", "4", "1"]
	var entities := ["121100", "120500", "130300", "121000", "110000", "140700"]
	var start := Time.get_ticks_usec()
	for i in count:
		var id := "S%d" % i
		var sidc := "100%s1000%s%s0000" % [identities[i % 4], ["14", "15", "16"][i % 3], entities[i % entities.size()]]
		var p := _km_to_lon_lat(Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-20, 20)))
		_map.add_unit(id, sidc, p.y, p.x, "", "Stress")
		_stress_ids.append(id)
		_stress_position.append(p)
		_stress_velocity.append(Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.0004)
	print("stress: added %d units in %.1f ms" % [count, (Time.get_ticks_usec() - start) / 1000.0])


func _update_info() -> void:
	var selected := _map.get_selected_units()
	var text := "%d FPS · %d units · %d graphics drawn · %.0f m/px" % [Engine.get_frames_per_second(),
			_map.get_unit_count(), _map.drawn_graphics, _map.meters_per_pixel]
	if selected.size() == 1:
		var unit := _map.get_unit(selected[0])
		text += "\nSelected: %s  %s  (%.4f, %.4f)" % [selected[0], unit.label, unit.latitude, unit.longitude]
	elif selected.size() > 1:
		text += "\nSelected: %d units" % selected.size()
	_info.text = text


func _on_selection_changed(ids: Array) -> void:
	if ids.size() == 1:
		print("selected ", ids[0], " ", _map.get_unit(ids[0]))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_G:
			_map.grid_visible = not _map.grid_visible
		KEY_1, KEY_2, KEY_3, KEY_4:
			var names := _map.get_layer_names()
			var index: int = event.keycode - KEY_0
			if index < names.size():
				var on := not _map.is_layer_visible(names[index])
				_map.set_layer_visible(names[index], on)
				var check := find_child("Layer_" + names[index].validate_node_name(), true, false) as CheckBox
				if check:
					check.set_pressed_no_signal(on)
		KEY_M:
			_moving = not _moving
		KEY_N:
			_toggle_stress()
		KEY_F:
			_map.zoom_to_content()
		KEY_L:
			_map.show_labels = not _map.show_labels
		KEY_D:
			var light := _map.background_color.v < 0.5
			_map.background_color = Color(0.93, 0.92, 0.86) if light else Color(0.11, 0.13, 0.15)
			_map.grid_color = Color(0, 0, 0, 0.15) if light else Color(1, 1, 1, 0.12)
			_map.text_color = Color(0.1, 0.1, 0.1, 0.85) if light else Color(1, 1, 1, 0.75)
			_map.graphic_palette = MilGraphicRenderer.PALETTE_LIGHT_MAP if light else MilGraphicRenderer.PALETTE_DARK_MAP
		KEY_H:
			_help.visible = not _help.visible
		KEY_F12:
			_save_screenshot("user://tactical_map_%d.png" % Time.get_unix_time_from_system())
		_:
			return
	get_viewport().set_input_as_handled()


func _save_screenshot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot: ", ProjectSettings.globalize_path(path))


func _print_statistics() -> void:
	var frames := _frame_times.slice(mini(10, _frame_times.size() - 1))
	if frames.is_empty():
		return
	var total := 0.0
	var worst := 0.0
	for t in frames:
		total += t
		worst = maxf(worst, t)
	print("frames: %d, average %.2f ms, worst %.2f ms, units %d" % [frames.size(), total / frames.size() * 1000.0,
			worst * 1000.0, _map.get_unit_count()])


func _km_to_lon_lat(km: Vector2) -> Vector2:
	var lat := ORIGIN.y + km.y / KM_PER_DEG_LAT
	var lon := ORIGIN.x + km.x / (KM_PER_DEG_LAT * cos(deg_to_rad(ORIGIN.y)))
	return Vector2(lon, lat)
