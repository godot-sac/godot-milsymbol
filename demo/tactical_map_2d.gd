extends Control
## Fictional 2D tactical map with draggable MilSymbolSprite2D units.
##
## Left-drag a unit to move it, right-click a unit for a context menu, wheel to zoom,
## middle-drag to pan. The sliders edit the shared styles used by every unit.

const MAP_SIZE: Vector2 = Vector2(1200.0, 700.0)
const GRID_STEP: float = 100.0
const COAST_X: float = 960.0

const LAND_COLOR: Color = Color(0.76, 0.80, 0.60)
const SEA_COLOR: Color = Color(0.55, 0.72, 0.86)
const COAST_COLOR: Color = Color(0.45, 0.42, 0.30)
const RIVER_COLOR: Color = Color(0.40, 0.62, 0.82)
const GRID_COLOR: Color = Color(0.2, 0.25, 0.2, 0.35)

const ID_IDENTITY_BASE: int = 100  # + SIDC identity digit
const ID_TOGGLE_HQ: int = 200
const ID_ECHELON_BASE: int = 300  # + index into ECHELONS

const IDENTITIES: Array[Dictionary] = [
	{"name": "Friend", "digit": "3"},
	{"name": "Hostile", "digit": "6"},
	{"name": "Neutral", "digit": "4"},
	{"name": "Unknown", "digit": "1"},
]
const ECHELONS: Array[Dictionary] = [
	{"name": "None", "code": "00"},
	{"name": "Platoon", "code": "14"},
	{"name": "Company", "code": "15"},
	{"name": "Battalion", "code": "16"},
	{"name": "Brigade", "code": "18"},
]

# Symbol sets and entity codes (verified against addons/milsymbol/data/icons_*.json).
const LAND: String = "10"
const AIR: String = "01"
const SEA: String = "30"
const E_INFANTRY: String = "121100"
const E_ARMOUR: String = "120500"
const E_ARTILLERY: String = "130300"
const E_RECON: String = "121000"
const E_ROTARY: String = "110200"
const E_UAV: String = "110300"
const E_FIXED_WING: String = "110100"
const E_SURFACE: String = "120100"

# identity, symbol set, HQ digit, echelon, entity, position, name
const UNITS: Array[Array] = [
	["3", LAND, "2", "18", E_INFANTRY, Vector2(210, 350), "1st Brigade HQ"],
	["3", LAND, "0", "16", E_INFANTRY, Vector2(330, 190), "1st Inf Bn"],
	["3", LAND, "0", "16", E_ARMOUR, Vector2(340, 360), "2nd Armour Bn"],
	["3", LAND, "0", "16", E_ARTILLERY, Vector2(120, 500), "Field Artillery Bn"],
	["3", LAND, "0", "15", E_RECON, Vector2(440, 120), "Recon Coy"],
	["3", LAND, "0", "15", E_INFANTRY, Vector2(430, 540), "A Coy"],
	["3", AIR, "0", "00", E_UAV, Vector2(620, 80), "Friendly UAV"],
	["3", SEA, "0", "00", E_SURFACE, Vector2(1080, 330), "Patrol Ship"],
	["6", LAND, "0", "16", E_INFANTRY, Vector2(700, 230), "Hostile Inf Bn"],
	["6", LAND, "0", "15", E_ARMOUR, Vector2(760, 400), "Hostile Armour Coy"],
	["6", LAND, "0", "14", E_INFANTRY, Vector2(680, 540), "Hostile Platoon"],
	["6", LAND, "0", "16", E_ARTILLERY, Vector2(870, 300), "Hostile Artillery Bn"],
	["6", AIR, "0", "00", E_ROTARY, Vector2(820, 130), "Hostile Helicopter"],
	["4", AIR, "0", "00", E_FIXED_WING, Vector2(1060, 560), "Neutral Aircraft"],
]

var _friend_style: MilSymbolStyle = MilSymbolStyle.new()
var _hostile_style: MilSymbolStyle = MilSymbolStyle.new()
var _selected: MilSymbolSprite2D
var _hovered: MilSymbolSprite2D
var _dragged: MilSymbolSprite2D
var _drag_offset: Vector2 = Vector2.ZERO
var _panning: bool = false
var _menu_target: MilSymbolSprite2D
var _fitted: bool = false

var _size_slider: HSlider
var _size_value: Label
var _outline_slider: HSlider
var _outline_value: Label
var _dark_check: CheckBox
var _info: Label
var _menu: PopupMenu

@onready var _container: SubViewportContainer = $Split/ViewContainer
@onready var _viewport: SubViewport = $Split/ViewContainer/Viewport
@onready var _world: Node2D = $Split/ViewContainer/Viewport/World
@onready var _units: Node2D = $Split/ViewContainer/Viewport/World/Units
@onready var _camera: Camera2D = $Split/ViewContainer/Viewport/Camera2D
@onready var _side_panel: PanelContainer = $Split/SidePanel


func _ready() -> void:
	_friend_style.outline_width = 2.0
	_hostile_style.outline_width = 2.0
	_world.draw.connect(_draw_world)
	_container.gui_input.connect(_on_view_input)
	_container.mouse_exited.connect(_on_view_mouse_exited)
	_container.resized.connect(_fit_camera)
	_build_panel()
	_build_menu()
	for def in UNITS:
		_add_unit(def)
	_update_info()
	_fit_camera.call_deferred()


# ---------------------------------------------------------------- units

static func make_sidc(identity: String, symbol_set: String, hq: String, echelon: String, entity: String) -> String:
	return "10" + "0" + identity + symbol_set + "0" + hq + echelon + entity + "0000"


func _add_unit(def: Array) -> void:
	var sprite := MilSymbolSprite2D.new()
	sprite.sidc = make_sidc(def[0], def[1], def[2], def[3], def[4])
	sprite.symbol_size = _size_slider.value
	sprite.style = _style_for(def[0])
	sprite.position = def[5]
	sprite.set_meta("unit_name", def[6])
	sprite.symbol_changed.connect(_world.queue_redraw)
	_units.add_child(sprite)


func _style_for(identity: String) -> MilSymbolStyle:
	return _hostile_style if identity == "6" else _friend_style


## Texture rectangle of a unit in world space (anchor-aware through the sprite's offset).
func _unit_rect(sprite: MilSymbolSprite2D) -> Rect2:
	if sprite.texture == null:
		return Rect2()
	return Rect2(sprite.position + sprite.offset, sprite.texture.get_size())


func _unit_at(world_pos: Vector2) -> MilSymbolSprite2D:
	var children: Array[Node] = _units.get_children()
	children.reverse()
	for child in children:
		var sprite := child as MilSymbolSprite2D
		if sprite != null and _unit_rect(sprite).has_point(world_pos):
			return sprite
	return null


func _set_sidc_part(sprite: MilSymbolSprite2D, index: int, part: String) -> void:
	var sidc: String = sprite.sidc
	sprite.sidc = sidc.substr(0, index) + part + sidc.substr(index + part.length())
	sprite.style = _style_for(sprite.sidc.substr(3, 1))


# ---------------------------------------------------------------- input

func _to_world(view_pos: Vector2) -> Vector2:
	return _viewport.get_canvas_transform().affine_inverse() * view_pos


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	var world_pos: Vector2 = _to_world(event.position)
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragged = _unit_at(world_pos)
				_select(_dragged)
				if _dragged != null:
					_drag_offset = _dragged.position - world_pos
					_units.move_child(_dragged, -1)  # Bring to front.
			else:
				_dragged = null
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var sprite: MilSymbolSprite2D = _unit_at(world_pos)
				if sprite != null:
					_select(sprite)
					_open_menu(sprite)
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1.0 / 1.1)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		_camera.position -= event.relative / _camera.zoom.x
		return
	var world_pos: Vector2 = _to_world(event.position)
	if _dragged != null:
		_dragged.position = world_pos + _drag_offset
		_world.queue_redraw()
	var hover: MilSymbolSprite2D = _unit_at(world_pos)
	if hover != _hovered:
		_hovered = hover
		_container.mouse_default_cursor_shape = \
			Control.CURSOR_POINTING_HAND if hover != null else Control.CURSOR_ARROW
		_update_info()


func _on_view_mouse_exited() -> void:
	_hovered = null
	_update_info()


func _zoom_at(view_pos: Vector2, factor: float) -> void:
	var before: Vector2 = _to_world(view_pos)
	var z: float = clampf(_camera.zoom.x * factor, 0.4, 4.0)
	_camera.zoom = Vector2(z, z)
	# Keep the point under the cursor fixed.
	var after: Vector2 = _to_world(view_pos)
	_camera.position += before - after


func _fit_camera() -> void:
	if _fitted or _container.size.x < 100.0 or _container.size.y < 100.0:
		return
	_fitted = true
	var z: float = minf(_container.size.x / MAP_SIZE.x, _container.size.y / MAP_SIZE.y)
	_camera.zoom = Vector2(z, z)
	_camera.position = MAP_SIZE / 2.0


func _select(sprite: MilSymbolSprite2D) -> void:
	_selected = sprite
	_world.queue_redraw()
	_update_info()


# ---------------------------------------------------------------- context menu

func _build_menu() -> void:
	_menu = PopupMenu.new()
	_menu.add_separator("Identity")
	for identity in IDENTITIES:
		_menu.add_radio_check_item(identity.name, ID_IDENTITY_BASE + int(identity.digit))
	_menu.add_separator("Headquarters")
	_menu.add_check_item("Headquarters", ID_TOGGLE_HQ)
	_menu.add_separator("Echelon")
	for i in ECHELONS.size():
		_menu.add_radio_check_item(ECHELONS[i].name, ID_ECHELON_BASE + i)
	_menu.id_pressed.connect(_on_menu_id)
	add_child(_menu)


func _open_menu(sprite: MilSymbolSprite2D) -> void:
	_menu_target = sprite
	var sidc: String = sprite.sidc
	for identity in IDENTITIES:
		var idx: int = _menu.get_item_index(ID_IDENTITY_BASE + int(identity.digit))
		_menu.set_item_checked(idx, sidc.substr(3, 1) == identity.digit)
	_menu.set_item_checked(_menu.get_item_index(ID_TOGGLE_HQ), int(sidc.substr(7, 1)) & 2 != 0)
	for i in ECHELONS.size():
		_menu.set_item_checked(_menu.get_item_index(ID_ECHELON_BASE + i), sidc.substr(8, 2) == ECHELONS[i].code)
	_menu.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i.ZERO))


func _on_menu_id(id: int) -> void:
	if _menu_target == null:
		return
	if id >= ID_ECHELON_BASE:
		_set_sidc_part(_menu_target, 8, ECHELONS[id - ID_ECHELON_BASE].code)
	elif id == ID_TOGGLE_HQ:
		# HQ/TF digit: bit value 2 is "headquarters", bit value 4 is "task force".
		_set_sidc_part(_menu_target, 7, str(int(_menu_target.sidc.substr(7, 1)) ^ 2))
	elif id >= ID_IDENTITY_BASE:
		_set_sidc_part(_menu_target, 3, str(id - ID_IDENTITY_BASE))
	_update_info.call_deferred()


# ---------------------------------------------------------------- side panel

func _build_panel() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_side_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Tactical map (fictional)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var help := Label.new()
	help.text = "Left-drag: move unit\nRight-click: edit unit\nWheel: zoom, middle-drag: pan"
	help.modulate = Color(0.75, 0.75, 0.75)
	box.add_child(help)
	box.add_child(HSeparator.new())

	_size_value = Label.new()
	_size_slider = _add_slider(box, "Symbol size", 30.0, 120.0, 1.0, 60.0, _size_value)
	_size_slider.value_changed.connect(_on_size_changed)
	_outline_value = Label.new()
	_outline_slider = _add_slider(box, "Outline width", 0.0, 6.0, 0.5, 2.0, _outline_value)
	_outline_slider.value_changed.connect(_on_outline_changed)
	_dark_check = CheckBox.new()
	_dark_check.text = "Dark color mode"
	_dark_check.toggled.connect(_on_dark_toggled)
	box.add_child(_dark_check)
	box.add_child(HSeparator.new())

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_info)


func _add_slider(parent: Control, text: String, lo: float, hi: float, step: float, value: float,
		value_label: Label) -> HSlider:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	value_label.custom_minimum_size = Vector2(32, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	parent.add_child(row)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	value_label.text = str(value)
	parent.add_child(slider)
	return slider


func _on_size_changed(value: float) -> void:
	_size_value.text = str(int(value))
	for child in _units.get_children():
		(child as MilSymbolSprite2D).symbol_size = value


func _on_outline_changed(value: float) -> void:
	_outline_value.text = str(value)
	_friend_style.outline_width = value
	_hostile_style.outline_width = value


func _on_dark_toggled(on: bool) -> void:
	var mode: MilSymbolStyle.ColorMode = MilSymbolStyle.ColorMode.DARK if on else MilSymbolStyle.ColorMode.LIGHT
	_friend_style.color_mode = mode
	_hostile_style.color_mode = mode


func _update_info() -> void:
	if _info == null:
		return
	var sprite: MilSymbolSprite2D = _hovered if _hovered != null else _selected
	if sprite == null:
		_info.text = "Hover or click a unit."
		return
	var meta: Dictionary = sprite.get_metadata()
	var echelon: Variant = meta.get("echelon", "")
	var lines: PackedStringArray = []
	lines.append(("Hovered" if sprite == _hovered else "Selected") + ": " + str(sprite.get_meta("unit_name")))
	lines.append("SIDC: " + sprite.sidc)
	lines.append("Affiliation: " + str(meta.get("affiliation", "?")))
	lines.append("Dimension: " + str(meta.get("dimension", "?")))
	lines.append("Echelon: " + (str(echelon) if echelon != null and str(echelon) != "" else "none"))
	lines.append("Headquarters: " + str(meta.get("headquarters", false)))
	_info.text = "\n".join(lines)


# ---------------------------------------------------------------- map drawing

func _draw_world() -> void:
	var font: Font = ThemeDB.fallback_font
	_world.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), LAND_COLOR)

	# Sea east of a wobbly coastline.
	var coast: PackedVector2Array = [
		Vector2(COAST_X + 40, 0), Vector2(COAST_X, 90), Vector2(COAST_X + 30, 190),
		Vector2(COAST_X - 20, 280), Vector2(COAST_X - 10, 400), Vector2(COAST_X + 35, 490),
		Vector2(COAST_X + 5, 600), Vector2(COAST_X + 30, MAP_SIZE.y)]
	var sea: PackedVector2Array = coast.duplicate()
	sea.append(Vector2(MAP_SIZE.x, MAP_SIZE.y))
	sea.append(Vector2(MAP_SIZE.x, 0))
	_world.draw_colored_polygon(sea, SEA_COLOR)
	_world.draw_polyline(coast, COAST_COLOR, 4.0, true)

	# River running north to south between the two sides.
	var river: PackedVector2Array = [
		Vector2(540, 0), Vector2(520, 90), Vector2(560, 170), Vector2(520, 270), Vector2(500, 360),
		Vector2(545, 450), Vector2(530, 560), Vector2(560, MAP_SIZE.y)]
	_world.draw_polyline(river, RIVER_COLOR, 14.0, true)

	# Grid with MGRS-like labels (purely visual).
	var cols: int = int(MAP_SIZE.x / GRID_STEP)
	var rows: int = int(MAP_SIZE.y / GRID_STEP)
	for c in range(1, cols):
		_world.draw_line(Vector2(c * GRID_STEP, 0), Vector2(c * GRID_STEP, MAP_SIZE.y), GRID_COLOR, 1.5)
	for r in range(1, rows):
		_world.draw_line(Vector2(0, r * GRID_STEP), Vector2(MAP_SIZE.x, r * GRID_STEP), GRID_COLOR, 1.5)
	for c in cols:
		for r in rows:
			var label: String = "%02d%02d" % [40 + c, 20 + (rows - 1 - r)]
			_world.draw_string(font, Vector2(c * GRID_STEP + 4, r * GRID_STEP + 14), label,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.25, 0.2, 0.7))
	_world.draw_string(font, Vector2(8, MAP_SIZE.y - 8), "38T MK  (fictional grid)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.15, 0.2, 0.15))
	_world.draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.1, 0.1, 0.1), false, 3.0)

	# Selection highlight behind the selected unit.
	if _selected != null:
		var r: Rect2 = _unit_rect(_selected).grow(4.0)
		_world.draw_rect(r, Color(1.0, 0.9, 0.2, 0.25))
		_world.draw_rect(r, Color(1.0, 0.8, 0.0), false, 2.0)
