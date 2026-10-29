extends Control
## Interactive frame explorer: standard identities x symbol sets.

const IDENTITIES: Array[String] = ["Pending", "Unknown", "Assumed Friend", "Friend", "Neutral", "Suspect", "Hostile"]
const SYMBOL_SETS: Array[String] = ["10", "15", "27", "01", "05", "30", "35"]
const SYMBOL_SET_NAMES: Array[String] = [
	"Land unit", "Land equipment", "Dismounted", "Air", "Space", "Sea surface", "Sea subsurface",
]
const CELL_SIZE: Vector2 = Vector2(120, 120)
const DEFAULT_SIDC: String = "10031000000000000000"

var _grid_bg: ColorRect
var _grid: GridContainer
var _color_mode: OptionButton
var _fill: CheckBox
var _frame: CheckBox
var _status: OptionButton
var _size_slider: HSlider
var _size_label: Label
var _outline_slider: HSlider
var _outline_label: Label
var _mono_check: CheckBox
var _mono_picker: ColorPickerButton
var _bg_picker: ColorPickerButton
var _show_anchor: CheckBox
var _sidc_edit: LineEdit
var _preview: TextureRect
var _preview_overlay: Control
var _info: Label
var _custom_render: MilSymbolRender
var _custom_tex: Texture2D


func _ready() -> void:
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var title := Label.new()
	title.text = "godot-milsymbol — Frames"
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	root.add_child(split)

	# Grid area with adjustable background.
	_grid_bg = ColorRect.new()
	_grid_bg.color = Color(0.2, 0.22, 0.25)
	_grid_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_grid_bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid_bg.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = SYMBOL_SETS.size() + 1
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)

	# Control panel.
	var panel_scroll := ScrollContainer.new()
	panel_scroll.custom_minimum_size = Vector2(360, 0)
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(panel_scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(panel)

	_color_mode = OptionButton.new()
	for m in ["Light", "Medium", "Dark"]:
		_color_mode.add_item(m)
	_color_mode.item_selected.connect(_on_changed_int)
	panel.add_child(_row("Color mode", _color_mode))

	_status = OptionButton.new()
	_status.add_item("Present")
	_status.add_item("Planned")
	_status.item_selected.connect(_on_changed_int)
	panel.add_child(_row("Status", _status))

	_fill = _check("Fill", true)
	panel.add_child(_fill)
	_frame = _check("Frame", true)
	panel.add_child(_frame)

	_size_slider = _slider(30, 200, 1, 100)
	_size_label = Label.new()
	panel.add_child(_row("Size", _size_slider, _size_label))
	_outline_slider = _slider(0, 8, 0.5, 0)
	_outline_label = Label.new()
	panel.add_child(_row("Outline", _outline_slider, _outline_label))

	_mono_check = _check("Mono color", false)
	_mono_picker = ColorPickerButton.new()
	_mono_picker.color = Color(0.0, 0.0, 0.0)
	_mono_picker.custom_minimum_size = Vector2(60, 0)
	_mono_picker.color_changed.connect(_on_changed_color)
	panel.add_child(_row("", _mono_check, _mono_picker))

	_bg_picker = ColorPickerButton.new()
	_bg_picker.color = _grid_bg.color
	_bg_picker.custom_minimum_size = Vector2(60, 0)
	_bg_picker.color_changed.connect(_on_changed_color)
	panel.add_child(_row("Background", _bg_picker))

	_show_anchor = _check("Show anchor", false)
	panel.add_child(_show_anchor)

	panel.add_child(HSeparator.new())
	var sidc_title := Label.new()
	sidc_title.text = "Custom SIDC"
	panel.add_child(sidc_title)
	_sidc_edit = LineEdit.new()
	_sidc_edit.text = DEFAULT_SIDC
	_sidc_edit.max_length = 20
	_sidc_edit.text_changed.connect(_on_changed_text)
	panel.add_child(_sidc_edit)

	var preview_bg := ColorRect.new()
	preview_bg.color = Color(0.2, 0.22, 0.25)
	preview_bg.custom_minimum_size = Vector2(240, 240)
	panel.add_child(preview_bg)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_bg.add_child(_preview)
	_preview_overlay = _make_overlay(_preview, func() -> Array: return [_custom_tex, _custom_render])

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info.custom_minimum_size = Vector2(300, 0)
	panel.add_child(_info)

	var copy := Button.new()
	copy.text = "Copy SVG"
	copy.pressed.connect(_on_copy_svg)
	panel.add_child(copy)


func _row(text: String, a: Control, b: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(90, 0)
	h.add_child(l)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	if b != null:
		h.add_child(b)
	return h


func _check(text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.toggled.connect(_on_changed_bool)
	return c


func _slider(lo: float, hi: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(140, 0)
	s.value_changed.connect(_on_changed_float)
	return s


func _on_changed_int(_v: int) -> void:
	_refresh()


func _on_changed_bool(_v: bool) -> void:
	_refresh()


func _on_changed_float(_v: float) -> void:
	_refresh()


func _on_changed_color(_v: Color) -> void:
	_refresh()


func _on_changed_text(_v: String) -> void:
	_refresh()


func _options() -> Dictionary:
	var opts: Dictionary = {
		"size": _size_slider.value,
		"colorMode": _color_mode.get_item_text(_color_mode.selected),
		"fill": _fill.button_pressed,
		"frame": _frame.button_pressed,
		"outlineWidth": _outline_slider.value,
	}
	if _mono_check.button_pressed:
		opts["monoColor"] = "#" + _mono_picker.color.to_html(false)
	return opts


## Adds a full-rect overlay to a TextureRect that draws a red cross at the anchor.
## `getter` returns [texture, render].
func _make_overlay(target: TextureRect, getter: Callable) -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.draw.connect(func() -> void:
		if not _show_anchor.button_pressed:
			return
		var data: Array = getter.call()
		var tex: Texture2D = data[0]
		var r: MilSymbolRender = data[1]
		if tex == null or r == null:
			return
		var ts: Vector2 = tex.get_size()
		var rs: Vector2 = o.size
		if ts.x <= 0 or ts.y <= 0:
			return
		var s: float = minf(rs.x / ts.x, rs.y / ts.y)
		var p: Vector2 = (rs - ts * s) * 0.5 + r.anchor * s
		o.draw_line(p - Vector2(5, 0), p + Vector2(5, 0), Color.RED, 1.5)
		o.draw_line(p - Vector2(0, 5), p + Vector2(0, 5), Color.RED, 1.5))
	target.add_child(o)
	return o


func _refresh() -> void:
	_size_label.text = str(int(_size_slider.value))
	_outline_label.text = str(_outline_slider.value)
	_grid_bg.color = _bg_picker.color
	var opts := _options()
	var status: String = str(_status.selected)

	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_grid.add_child(Control.new())
	for n in SYMBOL_SET_NAMES:
		_grid.add_child(_header(n, Vector2(CELL_SIZE.x, 30)))
	for i in IDENTITIES.size():
		_grid.add_child(_header(IDENTITIES[i], Vector2(110, CELL_SIZE.y)))
		for ss in SYMBOL_SETS:
			var sidc: String = "100%d%s%s0000000000000" % [i, ss, status]
			_grid.add_child(_make_cell(sidc, opts))

	_refresh_custom(opts)


func _header(text: String, min_size: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = min_size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _make_cell(sidc: String, opts: Dictionary) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.tooltip_text = sidc
	var render: MilSymbolRender = MilSymbol.render(sidc, opts)
	var tex: Texture2D = null
	if render != null and render.valid:
		tex = render.to_texture(1.0)
	if tex == null:
		cell.add_child(_na_label())
		return cell
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cell.add_child(rect)
	_make_overlay(rect, func() -> Array: return [tex, render])
	return cell


func _na_label() -> Label:
	var l := Label.new()
	l.text = "n/a"
	l.modulate = Color(0.6, 0.6, 0.6)
	l.add_theme_font_size_override("font_size", 11)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _refresh_custom(opts: Dictionary) -> void:
	var sidc: String = _sidc_edit.text.strip_edges()
	_custom_render = null
	_custom_tex = null
	if sidc.length() != 20 or not sidc.is_valid_int():
		_preview.texture = null
		_info.text = "Invalid SIDC: expected exactly 20 digits (got %d characters)." % sidc.length()
		_preview_overlay.queue_redraw()
		return
	var render: MilSymbolRender = MilSymbol.render(sidc, opts)
	_custom_render = render
	if render == null:
		_info.text = "Render failed."
		_preview.texture = null
		_preview_overlay.queue_redraw()
		return
	if render.valid:
		_custom_tex = render.to_texture(1.0)
	_preview.texture = _custom_tex
	var md: Dictionary = render.metadata
	_info.text = "valid: %s\nsize: %s\nanchor: %s\naffiliation: %s\ndimension: %s\nnotpresent: %s" % [
		render.valid, render.size, render.anchor,
		md.get("affiliation", "-"), md.get("dimension", "-"), md.get("notpresent", "-"),
	]
	if _custom_tex == null:
		_info.text += "\n(n/a: no texture)"
	_preview_overlay.queue_redraw()


func _on_copy_svg() -> void:
	if _custom_render != null:
		DisplayServer.clipboard_set(_custom_render.svg)
