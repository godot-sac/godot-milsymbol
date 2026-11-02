extends SceneTree
## Scripted runs of the tactical map demo for the README media. Called by tools/capture_media.py, which also
## turns the frames into a GIF.
##
##   <godot> --path . --fixed-fps 10 --write-movie <dir>/frame.png -s res://tools/capture_media.gd -- --tour --size 960x540
##       16 s tour: overview with moving units, zoom to the main attack, selection, layer toggle, light map.
##   <godot> --path . --resolution 1280x640 -s res://tools/capture_media.gd -- --social <file.png>
##       1280 x 640 social preview image (map with a title bar).
##   <godot> --headless --path . -s res://tools/capture_media.gd -- --icon <file.png>
##       res://icon.svg rendered at 256 x 256.

const TOUR_SECONDS := 16.0
const DEMO := "res://demo/tactical_map.tscn"

var _demo: Control
var _map: TacticalMap2D
var _time := 0.0
var _steps: Array = []  # [time, Callable], sorted
var _zoom: Dictionary = {}  # from / to view and start / length of a running zoom


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--icon")
	if i >= 0:
		quit(_save_icon(args[i + 1]))
		return
	# Draw at the window size (the project stretches a 1600 x 900 canvas).
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_demo = load(DEMO).instantiate()
	root.add_child(_demo)
	# The root enters the tree after _initialize(), so the demo's _ready() has not run yet.
	_start.call_deferred(args)


func _start(args: PackedStringArray) -> void:
	_map = _demo.get("_map")
	_demo.get("_help").visible = false
	var i := args.find("--size")
	if i >= 0:
		# --write-movie records at the project's window size (1600 x 900) and ignores --resolution, so the
		# picture is drawn larger to look like a window of this width once capture_media.py scales it down.
		root.content_scale_factor = root.size.x / float(args[i + 1].get_slice("x", 0))
	i = args.find("--social")
	if i >= 0:
		_social(args[i + 1])
	elif args.has("--tour"):
		_tour()
	else:
		push_error("capture_media.gd: pass --tour, --social <png> or --icon <png>")
		quit(1)


func _process(delta: float) -> bool:
	_time += delta
	while not _steps.is_empty() and _steps[0][0] <= _time:
		var step: Callable = _steps.pop_front()[1]
		step.call()
	if not _zoom.is_empty():
		var t := clampf((_time - _zoom.start) / _zoom.length, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		var lat := lerpf(_zoom.from.x, _zoom.to.x, t)
		var lon := lerpf(_zoom.from.y, _zoom.to.y, t)
		# Interpolate the scale logarithmically so that zooming looks even.
		var mpp := exp(lerpf(log(_zoom.from.z), log(_zoom.to.z), t))
		_map.center_on(lat, lon, mpp)
		if t >= 1.0:
			_zoom = {}
	return false


func _tour() -> void:
	# The frame rate in the info line means nothing in a recording.
	_demo.get("_info").visible = false
	var start := Vector3(_map.center_latitude, _map.center_longitude, 60.0)
	_map.center_on(start.x, start.y, start.z)
	var close := Vector3(39.972, 32.795, 22.0)  # 1st brigade crossing the LD towards PL BLUE
	_steps = [
		[3.5, func() -> void: _zoom_to(start, close, 1.5)],
		[5.5, func() -> void: _map.select_units(["1-1", "1-2"])],
		[8.5, func() -> void: _zoom_to(close, start, 1.5)],
		[8.6, func() -> void: _map.select_units([])],
		[10.0, func() -> void: _key(KEY_1)],  # control measures off
		[11.5, func() -> void: _key(KEY_1)],
		[12.5, func() -> void: _key(KEY_D)],  # light map
		[TOUR_SECONDS, func() -> void: quit()],
	]


func _social(path: String) -> void:
	_demo.set("_moving", false)
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.92)
	style.content_margin_left = 40
	style.content_margin_top = 18
	style.content_margin_bottom = 20
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	bar.add_child(box)
	var title := Label.new()
	title.text = "godot-milsymbol"
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "MIL-STD-2525D/E and APP-6D symbols, control measures and a 2D tactical map for Godot 4"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(1, 1, 1, 0.8)
	box.add_child(subtitle)
	root.add_child(bar)
	# The demo's own HUD would cover the map in the small picture.
	for child in _demo.get_children():
		if child is PanelContainer:
			child.visible = false
	_map.center_on(39.931, 32.842, 56.0)
	_steps = [[1.0, func() -> void:
		root.get_texture().get_image().save_png(path)
		print("social preview: ", path)
		quit()]]


func _zoom_to(from: Vector3, to: Vector3, seconds: float) -> void:
	_zoom = {"from": from, "to": to, "start": _time, "length": seconds}


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_demo.call("_unhandled_key_input", event)


func _save_icon(path: String) -> int:
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var image := Image.new()
	if svg.is_empty() or image.load_svg_from_string(svg, 2.0) != OK:
		push_error("cannot render res://icon.svg")
		return 1
	image.save_png(path)
	print("icon: ", path)
	return 0
