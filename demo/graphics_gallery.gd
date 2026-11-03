extends Control
## Control measure gallery: every multipoint graphic with its own geometry, one per cell.
##
## Drag the small squares (control points) to reshape a graphic. The bar on top switches the standard
## identity, planned status, dark background and halo. F12 saves a screenshot to user://.
## Command line: -- --screenshot <file.png> saves one picture after the first frames and quits;
## --scroll <pixels> scrolls the gallery down first.

const CELL := Vector2(250, 190)
const COLUMNS := 6
const HANDLE := 5.0

# title, entity code, points (cell coordinates), amplifiers, echelon
const ITEMS: Array[Array] = [
	["Boundary", "110100", [Vector2(15, 120), Vector2(120, 90), Vector2(235, 115)], {"T": "1 BDE", "T1": "2 BDE"}, "18"],
	["Phase line", "140300", [Vector2(55, 110), Vector2(130, 90), Vector2(195, 105)], {"T": "BLUE"}, "00"],
	["Line of departure", "141000", [Vector2(20, 105), Vector2(230, 95)], {}, "00"],
	["LD / line of contact", "141100", [Vector2(20, 100), Vector2(120, 115), Vector2(230, 95)], {}, "00"],
	["FLOT", "140100", [Vector2(50, 110), Vector2(130, 95), Vector2(200, 110)], {}, "00"],
	["Area (general)", "150100", [Vector2(40, 60), Vector2(200, 50), Vector2(215, 150), Vector2(55, 160)], {}, "00"],
	["Area of operations", "120100", [Vector2(30, 55), Vector2(215, 45), Vector2(225, 160), Vector2(40, 165)], {"T": "1 BN"}, "00"],
	["Named area of interest", "120200", [Vector2(50, 60), Vector2(190, 55), Vector2(200, 150), Vector2(60, 155)], {"T": "12"}, "00"],
	["Targeted area of interest", "120300", [Vector2(50, 60), Vector2(200, 70), Vector2(185, 155), Vector2(45, 145)], {"T": "4"}, "00"],
	["Assembly area", "150200", [Vector2(60, 55), Vector2(180, 50), Vector2(210, 110), Vector2(170, 160), Vector2(55, 150)], {"T": "EAGLE"}, "00"],
	["Objective", "151700", [Vector2(70, 50), Vector2(190, 65), Vector2(200, 150), Vector2(60, 160), Vector2(40, 100)], {"T": "STEEL"}, "00"],
	["Engagement area", "151300", [Vector2(40, 60), Vector2(210, 55), Vector2(200, 160), Vector2(50, 150)], {"T": "HAMMER"}, "00"],
	["Axis of advance, supporting", "151404", [Vector2(225, 70), Vector2(120, 110), Vector2(25, 100), Vector2(185, 112)], {"T": "SPT"}, "00"],
	["Axis of advance, main", "151403", [Vector2(225, 70), Vector2(120, 110), Vector2(25, 100), Vector2(185, 112)], {"T": "MAIN"}, "00"],
	["Axis of advance, aviation", "151401", [Vector2(225, 70), Vector2(120, 110), Vector2(25, 100), Vector2(185, 112)], {}, "00"],
	["Axis of advance, attack helicopter", "151402", [Vector2(225, 70), Vector2(120, 110), Vector2(25, 100), Vector2(185, 112)], {}, "00"],
	["Direction of attack, supporting", "140603", [Vector2(225, 80), Vector2(110, 120), Vector2(25, 110)], {"T": "B"}, "00"],
	["Direction of attack, main", "140602", [Vector2(225, 80), Vector2(110, 120), Vector2(25, 110)], {"T": "A"}, "00"],
	["Direction of attack, aviation", "140601", [Vector2(225, 80), Vector2(110, 120), Vector2(25, 110)], {}, "00"],
	["FSCL", "260100", [Vector2(15, 110), Vector2(235, 100)], {"T": "V CORPS", "W": "0600Z", "W1": "1800Z"}, "00"],
	["Coordinated fire line", "260200", [Vector2(15, 110), Vector2(235, 100)], {"T": "1 DIV"}, "00"],
	["No-fire line", "260300", [Vector2(15, 110), Vector2(235, 100)], {"T": "2"}, "00"],
	["Restrictive fire line", "260500", [Vector2(15, 110), Vector2(235, 100)], {"T": "3"}, "00"],
	["Free fire area", "240201", [Vector2(50, 55), Vector2(200, 60), Vector2(205, 155), Vector2(45, 150)], {"T": "1", "W": "0600Z"}, "00"],
	["No-fire area, rectangular", "240302", [Vector2(55, 105), Vector2(195, 105)], {"T": "7", "AM": 90.0}, "00"],
	["Restricted fire area, circular", "240403", [Vector2(125, 105)], {"T": "9", "AM": 55.0}, "00"],
	["Obstacle line", "290100", [Vector2(20, 110), Vector2(120, 95), Vector2(230, 110)], {"T": "O1"}, "00"],
	["Obstacle belt", "270100", [Vector2(45, 55), Vector2(205, 55), Vector2(205, 155), Vector2(45, 155)], {"T": "B1"}, "00"],
	["Obstacle restricted zone", "270400", [Vector2(45, 55), Vector2(205, 55), Vector2(205, 155), Vector2(45, 155)], {"T": "Z2"}, "00"],
	["Minefield, dynamic depiction", "270707", [Vector2(50, 60), Vector2(200, 55), Vector2(205, 150), Vector2(45, 155)], {}, "00"],
	["Mined area", "270800", [Vector2(50, 60), Vector2(200, 55), Vector2(205, 150), Vector2(45, 155)], {"H": "AT", "W": "0600Z"}, "00"],
	["Mined area, fenced", "270801", [Vector2(50, 60), Vector2(200, 55), Vector2(205, 150), Vector2(45, 155)], {}, "00"],
	["Main supply route, one way", "330301", [Vector2(15, 120), Vector2(125, 90), Vector2(235, 110)], {"T": "IRON"}, "00"],
	["Alternate supply route, two way", "330402", [Vector2(15, 120), Vector2(125, 90), Vector2(235, 110)], {"T": "COPPER"}, "00"],
	["Air corridor", "170100", [Vector2(25, 130), Vector2(125, 100), Vector2(225, 125)], {"T": "AC1", "AM": 26.0, "X": "500FT"}, "00"],
	["Engineer work line (generic)", "110300", [Vector2(20, 110), Vector2(230, 100)], {"T": "EWL"}, "00"],
]

var _items: Array[Dictionary] = []
var _identity := "3"
var _planned := false
var _dark := false
var _halo := true
var _drag_item := -1
var _drag_point := -1
var _canvas: Control
var _scroll: ScrollContainer
var _info: Label
var _screenshot := ""
var _frames := 0


func _ready() -> void:
	for def in ITEMS:
		var points := PackedVector2Array()
		for p in def[2]:
			points.append(p)
		_items.append({"title": def[0], "code": def[1], "points": points, "amp": def[3], "echelon": def[4]})
	_build_ui()
	_rebuild()
	var args := OS.get_cmdline_user_args()
	var i := args.find("--screenshot")
	if i >= 0 and i + 1 < args.size():
		_screenshot = args[i + 1]
	i = args.find("--scroll")
	if i >= 0 and i + 1 < args.size():
		_scroll.set_deferred("scroll_vertical", int(args[i + 1]))


func _process(_delta: float) -> void:
	if _screenshot == "":
		return
	_frames += 1
	if _frames == 5:
		_save_screenshot(_screenshot)
		get_tree().quit()


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	var bar := HBoxContainer.new()
	box.add_child(bar)
	var identity := OptionButton.new()
	for item in [["Friend", "3"], ["Hostile", "6"], ["Neutral", "4"], ["Unknown", "1"]]:
		identity.add_item(item[0])
		identity.set_item_metadata(identity.item_count - 1, item[1])
	identity.item_selected.connect(func(index: int) -> void:
		_identity = identity.get_item_metadata(index)
		_rebuild())
	bar.add_child(identity)
	for toggle in [["Planned (dashed)", "_planned"], ["Dark background", "_dark"], ["Halo", "_halo"]]:
		var check := CheckBox.new()
		check.text = toggle[0]
		check.button_pressed = get(toggle[1])
		var property: String = toggle[1]
		check.toggled.connect(func(on: bool) -> void:
			set(property, on)
			_rebuild())
		bar.add_child(check)
	_info = Label.new()
	_info.text = "Drag the squares to move control points. F12: screenshot."
	bar.add_child(_info)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_scroll)
	_canvas = Control.new()
	var rows := ceili(float(ITEMS.size()) / COLUMNS)
	_canvas.custom_minimum_size = Vector2(CELL.x * COLUMNS, CELL.y * rows)
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	_scroll.add_child(_canvas)


func _sidc(item: Dictionary) -> String:
	return "10%s%s25%s0%s%s0000" % ["0", _identity, "1" if _planned else "0", item.echelon, item.code]


func _rebuild() -> void:
	for item in _items:
		item.shape = MilGraphic.build(_sidc(item), item.points, item.amp)
	_canvas.queue_redraw()


func _cell_origin(index: int) -> Vector2:
	return Vector2(index % COLUMNS, index / COLUMNS) * CELL


func _draw_canvas() -> void:
	var font := ThemeDB.fallback_font
	var background := Color(0.13, 0.15, 0.17) if _dark else Color(0.93, 0.92, 0.86)
	var text_color := Color(0.8, 0.8, 0.8) if _dark else Color(0.25, 0.25, 0.25)
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), background)
	var style := {
		"palette": MilGraphicRenderer.PALETTE_DARK_MAP if _dark else MilGraphicRenderer.PALETTE_LIGHT_MAP,
		"halo": 1.5 if _halo else 0.0,
		"halo_color": Color(background, 0.85),
	}
	for i in _items.size():
		var item: Dictionary = _items[i]
		var origin := _cell_origin(i)
		_canvas.draw_rect(Rect2(origin + Vector2(2, 2), CELL - Vector2(4, 4)), Color(text_color, 0.25), false)
		var title := "%s  %s" % [item.code, item.title]
		_canvas.draw_string(font, origin + Vector2(8, 18), title, HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 16, 12, text_color)
		var shape: MilGraphicShape = item.shape
		style.transform = Transform2D(0.0, origin)
		MilGraphicRenderer.draw(_canvas, shape, style)
		if not shape.valid:
			_canvas.draw_string(font, origin + Vector2(8, 36), "; ".join(shape.errors), HORIZONTAL_ALIGNMENT_LEFT,
					CELL.x - 16, 11, Color.ORANGE_RED)
		for p in item.points:
			var r := Rect2(origin + p - Vector2(HANDLE, HANDLE), Vector2(HANDLE, HANDLE) * 2)
			_canvas.draw_rect(r, Color(0.9, 0.5, 0.1, 0.7), false, 1.0)


func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pick(event.position)
		else:
			_drag_item = -1
	elif event is InputEventMouseMotion and _drag_item >= 0:
		var item: Dictionary = _items[_drag_item]
		var points: PackedVector2Array = item.points
		points[_drag_point] = event.position - _cell_origin(_drag_item)
		item.points = points
		item.shape = MilGraphic.build(_sidc(item), points, item.amp)
		_info.text = "%s: %s" % [item.title, points]
		_canvas.queue_redraw()


func _pick(position: Vector2) -> void:
	for i in _items.size():
		var points: PackedVector2Array = _items[i].points
		for k in points.size():
			if (_cell_origin(i) + points[k]).distance_to(position) <= HANDLE + 2.0:
				_drag_item = i
				_drag_point = k
				return


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var path := "user://graphics_gallery_%d.png" % Time.get_unix_time_from_system()
		_save_screenshot(path)
		_info.text = "Saved %s" % path


func _save_screenshot(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(path)
	print("screenshot: ", ProjectSettings.globalize_path(path))
