extends Control
## 3D tactical map with billboarded MilSymbolSprite3D units that slowly move along simple paths.
##
## Right-drag: orbit, wheel: zoom, middle-drag or WASD: pan.
##
## Ground units are lifted above the ground instead of sitting at y = 0: a billboard is centred on
## its node, so at y = 0 the lower half of the symbol would clip into the plane. Each unit gets a thin
## drop line to the ground, which also makes the ground position readable. "Always on top" switches
## on Sprite3D.no_depth_test, the alternative for symbols that must never be hidden by terrain.

const SYMBOL_PX: float = 128.0  # Texture size; world size is symbol_size * pixel_size.
const WORLD_WIDTH: float = 10.0  # World width of a symbol at scale 1 (non fixed-size mode).
const FIXED_WIDTH: float = 0.1  # fixed_size: pixel_size acts like a fraction of the view (1.0 is huge).
const GROUND_SIZE: float = 180.0
const PIN_LENGTH: float = 3.0  # Extra lift of ground symbols (on top of half their height).

const LAND: String = "10"
const AIR: String = "01"
const E_INFANTRY: String = "121100"
const E_ARMOUR: String = "120500"
const E_ARTILLERY: String = "130300"
const E_RECON: String = "121000"
const E_ROTARY: String = "110200"
const E_UAV: String = "110300"
const E_FIXED_WING: String = "110100"

const FRIEND_COLOR: Color = Color(0.25, 0.7, 1.0)
const HOSTILE_COLOR: Color = Color(1.0, 0.3, 0.3)
const NEUTRAL_COLOR: Color = Color(0.5, 1.0, 0.5)

## Path kinds: "static", "line" (ping-pong from `a` to `b`) and "circle" (around `a`, radius `r`).
const UNIT_DEFS: Array[Dictionary] = [
	{"id": "3", "set": LAND, "hq": "2", "ech": "18", "ent": E_INFANTRY, "kind": "static", "a": Vector3(-50, 0, 15)},
	{"id": "3", "set": LAND, "hq": "0", "ech": "16", "ent": E_INFANTRY, "kind": "line",
		"a": Vector3(-35, 0, -20), "b": Vector3(-20, 0, -45), "speed": 0.25},
	{"id": "3", "set": LAND, "hq": "0", "ech": "16", "ent": E_ARMOUR, "kind": "line",
		"a": Vector3(-30, 0, 20), "b": Vector3(-5, 0, 30), "speed": 0.3},
	{"id": "3", "set": LAND, "hq": "0", "ech": "16", "ent": E_ARTILLERY, "kind": "static", "a": Vector3(-65, 0, 45)},
	{"id": "3", "set": LAND, "hq": "0", "ech": "15", "ent": E_RECON, "kind": "line",
		"a": Vector3(-8, 0, -50), "b": Vector3(-8, 0, -10), "speed": 0.4},
	{"id": "3", "set": AIR, "hq": "0", "ech": "00", "ent": E_UAV, "kind": "circle",
		"a": Vector3(-20, 0, 0), "r": 30.0, "alt": 28.0, "speed": 0.35},
	{"id": "6", "set": LAND, "hq": "0", "ech": "16", "ent": E_INFANTRY, "kind": "line",
		"a": Vector3(35, 0, -25), "b": Vector3(30, 0, -5), "speed": 0.25},
	{"id": "6", "set": LAND, "hq": "0", "ech": "15", "ent": E_ARMOUR, "kind": "line",
		"a": Vector3(45, 0, 20), "b": Vector3(25, 0, 25), "speed": 0.35},
	{"id": "6", "set": LAND, "hq": "0", "ech": "14", "ent": E_INFANTRY, "kind": "static", "a": Vector3(30, 0, 50)},
	{"id": "6", "set": LAND, "hq": "0", "ech": "16", "ent": E_ARTILLERY, "kind": "static", "a": Vector3(60, 0, -5)},
	{"id": "6", "set": AIR, "hq": "0", "ech": "00", "ent": E_ROTARY, "kind": "circle",
		"a": Vector3(40, 0, 5), "r": 18.0, "alt": 15.0, "speed": 0.6},
	{"id": "4", "set": AIR, "hq": "0", "ech": "00", "ent": E_FIXED_WING, "kind": "circle",
		"a": Vector3(0, 0, 0), "r": 65.0, "alt": 35.0, "speed": -0.25},
]

var _friend_style: MilSymbolStyle = MilSymbolStyle.new()
var _hostile_style: MilSymbolStyle = MilSymbolStyle.new()
var _units: Array[Dictionary] = []  # {sprite, def, phase, pin, disc}
var _time: float = 0.0

# Orbit camera state.
var _target: Vector3 = Vector3(0, 5, 0)
var _yaw: float = 0.5
var _pitch: float = 0.65
var _distance: float = 120.0
var _rotating: bool = false
var _panning: bool = false

var _fixed_check: CheckBox
var _scale_slider: HSlider
var _scale_value: Label
var _pause_check: CheckBox
var _top_check: CheckBox

@onready var _container: SubViewportContainer = $ViewContainer
@onready var _world: Node3D = $ViewContainer/Viewport/World
@onready var _units_root: Node3D = $ViewContainer/Viewport/World/Units
@onready var _camera: Camera3D = $ViewContainer/Viewport/Camera3D
@onready var _panel: PanelContainer = $Panel


func _ready() -> void:
	_friend_style.outline_width = 2.0
	_hostile_style.outline_width = 2.0
	_build_environment()
	_build_terrain()
	_build_panel()
	for def in UNIT_DEFS:
		_add_unit(def)
	_container.gui_input.connect(_on_view_input)
	_apply_scale()
	_update_units()
	_update_camera()


func _process(delta: float) -> void:
	if not _pause_check.button_pressed:
		_time += delta
	_update_units()
	_move_with_keys(delta)


# ---------------------------------------------------------------- scene

func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.35, 0.55, 0.85)
	sky_material.sky_horizon_color = Color(0.7, 0.8, 0.9)
	sky_material.ground_horizon_color = Color(0.7, 0.8, 0.9)
	sky_material.ground_bottom_color = Color(0.45, 0.5, 0.45)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)


func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	ground.mesh = plane
	ground.material_override = _ground_material()
	_world.add_child(ground)

	# A river strip and a few low hills; units stay clear of them.
	var river := MeshInstance3D.new()
	var river_mesh := PlaneMesh.new()
	river_mesh.size = Vector2(7.0, GROUND_SIZE)
	river.mesh = river_mesh
	river.position = Vector3(8.0, 0.03, 0.0)
	river.material_override = _flat_material(Color(0.3, 0.5, 0.8))
	_world.add_child(river)

	var hill_material: StandardMaterial3D = _flat_material(Color(0.5, 0.42, 0.3))
	var hills: Array[Array] = [
		[Vector3(-70, 0, -60), Vector3(28, 4, 18)],
		[Vector3(65, 0, -58), Vector3(22, 5, 20)],
		[Vector3(72, 0, 62), Vector3(26, 3, 16)],
		[Vector3(-30, 0, 72), Vector3(30, 2.5, 12)],
	]
	for hill in hills:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = hill[1]
		box.mesh = mesh
		box.position = hill[0] + Vector3(0, hill[1].y / 2.0, 0)
		box.material_override = hill_material
		_world.add_child(box)


func _ground_material() -> StandardMaterial3D:
	# Procedural 1-cell grid texture, tiled over the ground so motion and distance read well.
	var image := Image.create(64, 64, true, Image.FORMAT_RGB8)
	image.fill(Color(0.42, 0.58, 0.32))
	var line_color := Color(0.34, 0.48, 0.26)
	for i in 64:
		for w in 2:
			image.set_pixel(i, w, line_color)
			image.set_pixel(w, i, line_color)
	image.generate_mipmaps()
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.uv1_scale = Vector3(GROUND_SIZE / 10.0, GROUND_SIZE / 10.0, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.roughness = 1.0
	return material


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


# ---------------------------------------------------------------- units

static func make_sidc(identity: String, symbol_set: String, hq: String, echelon: String, entity: String) -> String:
	return "10" + "0" + identity + symbol_set + "0" + hq + echelon + entity + "0000"


func _add_unit(def: Dictionary) -> void:
	var sprite := MilSymbolSprite3D.new()
	sprite.sidc = make_sidc(def.id, def.set, def.hq, def.ech, def.ent)
	sprite.symbol_size = SYMBOL_PX
	sprite.style = _hostile_style if def.id == "6" else _friend_style
	_units_root.add_child(sprite)

	var color: Color = FRIEND_COLOR
	if def.id == "6":
		color = HOSTILE_COLOR
	elif def.id == "4":
		color = NEUTRAL_COLOR
	var pin := MeshInstance3D.new()
	var pin_mesh := CylinderMesh.new()
	pin_mesh.top_radius = 0.1
	pin_mesh.bottom_radius = 0.1
	pin_mesh.height = 1.0
	pin_mesh.radial_segments = 6
	pin.mesh = pin_mesh
	pin.material_override = _unshaded(color)
	pin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_units_root.add_child(pin)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.3
	disc_mesh.bottom_radius = 1.3
	disc_mesh.height = 0.06
	disc.mesh = disc_mesh
	disc.material_override = _unshaded(color)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_units_root.add_child(disc)

	_units.append({"sprite": sprite, "def": def, "pin": pin, "disc": disc,
			"phase": float(_units.size()) * 1.7})


## Ground position of a unit on its path at the current time.
func _path_position(def: Dictionary, phase: float) -> Vector3:
	var a: Vector3 = def.a
	match def.kind:
		"line":
			var t: float = 0.5 + 0.5 * sin(_time * float(def.speed) + phase)
			return a.lerp(def.b, t)
		"circle":
			var angle: float = _time * float(def.speed) + phase
			return a + Vector3(cos(angle), 0, sin(angle)) * float(def.r)
	return a


func _update_units() -> void:
	var fixed: bool = _fixed_check.button_pressed
	var scale_factor: float = _scale_slider.value
	for unit in _units:
		var def: Dictionary = unit.def
		var ground: Vector3 = _path_position(def, unit.phase)
		var height: float = float(def.get("alt", 0.0))
		if def.set == LAND:
			# Lift ground symbols clear of the plane. Headquarters already stand on their staff.
			if def.hq == "0":
				height = (PIN_LENGTH + 4.0) if fixed else (WORLD_WIDTH * 0.5 * scale_factor + PIN_LENGTH)
			else:
				height = 0.5
		var sprite: MilSymbolSprite3D = unit.sprite
		sprite.position = ground + Vector3(0, height, 0)
		var pin: MeshInstance3D = unit.pin
		var pin_height: float = maxf(height, 0.01)
		pin.scale = Vector3(1, pin_height, 1)
		pin.position = ground + Vector3(0, pin_height / 2.0, 0)
		var disc: MeshInstance3D = unit.disc
		disc.position = ground + Vector3(0, 0.05, 0)


func _apply_scale() -> void:
	var fixed: bool = _fixed_check.button_pressed
	_scale_value.text = "%.1fx" % _scale_slider.value
	# With fixed_size the world distance is cancelled out, so pixel_size becomes a screen fraction.
	var base: float = (FIXED_WIDTH if fixed else WORLD_WIDTH) / SYMBOL_PX
	for unit in _units:
		var sprite: MilSymbolSprite3D = unit.sprite
		sprite.fixed_size = fixed
		sprite.pixel_size = base * _scale_slider.value
		sprite.no_depth_test = _top_check.button_pressed


# ---------------------------------------------------------------- camera

func _update_camera() -> void:
	var offset := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _distance
	_camera.position = _target + offset
	_camera.look_at(_target, Vector3.UP)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_RIGHT:
				_rotating = button.pressed
			MOUSE_BUTTON_MIDDLE:
				_panning = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_distance = clampf(_distance * 0.9, 10.0, 400.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				_distance = clampf(_distance / 0.9, 10.0, 400.0)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _rotating:
			_yaw -= motion.relative.x * 0.005
			_pitch = clampf(_pitch + motion.relative.y * 0.005, 0.05, 1.5)
		elif _panning:
			var right := Vector3(cos(_yaw), 0, -sin(_yaw))
			var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
			_target += (-right * motion.relative.x + forward * motion.relative.y) * _distance * 0.0016
	_update_camera()


func _move_with_keys(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var input := Vector2(_key_axis(KEY_A, KEY_D), _key_axis(KEY_S, KEY_W))
	if input == Vector2.ZERO:
		return
	var right := Vector3(cos(_yaw), 0, -sin(_yaw))
	var forward := Vector3(-sin(_yaw), 0, -cos(_yaw))
	_target += (right * input.x + forward * input.y) * _distance * 0.8 * delta
	_update_camera()


func _key_axis(negative: Key, positive: Key) -> float:
	return float(Input.is_key_pressed(positive)) - float(Input.is_key_pressed(negative))


# ---------------------------------------------------------------- panel

func _build_panel() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Tactical map 3D"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var help := Label.new()
	help.text = "Right-drag: orbit, wheel: zoom\nMiddle-drag / WASD: pan"
	help.modulate = Color(0.75, 0.75, 0.75)
	box.add_child(help)

	_fixed_check = CheckBox.new()
	_fixed_check.text = "Fixed screen size"
	_fixed_check.toggled.connect(func(_on: bool) -> void: _apply_scale())
	box.add_child(_fixed_check)
	_top_check = CheckBox.new()
	_top_check.text = "Always on top (no depth test)"
	_top_check.toggled.connect(func(_on: bool) -> void: _apply_scale())
	box.add_child(_top_check)
	_pause_check = CheckBox.new()
	_pause_check.text = "Pause"
	box.add_child(_pause_check)

	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Symbol scale"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_scale_value = Label.new()
	row.add_child(_scale_value)
	box.add_child(row)
	_scale_slider = HSlider.new()
	_scale_slider.min_value = 0.5
	_scale_slider.max_value = 3.0
	_scale_slider.step = 0.1
	_scale_slider.value = 1.0
	_scale_slider.value_changed.connect(func(_v: float) -> void: _apply_scale())
	box.add_child(_scale_slider)
