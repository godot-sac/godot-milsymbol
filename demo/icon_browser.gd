extends Control
## Icon browser: every exported icon of a symbol set as a card, plus a detail panel with modifiers.

const SYMBOL_SETS: Array[String] = ["01", "05", "10", "15", "30", "35"]
const SYMBOL_SET_NAMES: Array[String] = ["Air (01)", "Space (05)", "Land unit (10)", "Land equipment (15)",
		"Sea surface (30)", "Sea subsurface (35)"]
const EDITIONS: Array[String] = ["D", "E"]
const EDITION_NAMES: Array[String] = ["2525D", "2525E"]
const EDITION_VERSIONS: Array[String] = ["10", "13"]
const IDENTITY_NAMES: Array[String] = ["Unknown", "Friend", "Neutral", "Hostile"]
const IDENTITY_CODES: Array[String] = ["1", "3", "4", "6"]
const CONTEXT_NAMES: Array[String] = ["Reality", "Exercise", "Simulation"]
const DETAIL_STATUS_NAMES: Array[String] = [
	"Present", "Planned", "Fully capable", "Damaged", "Destroyed", "Full to capacity"]
const HQ_NAMES: Array[String] = [
	"None", "Feint/Dummy", "Headquarters", "Feint/Dummy + HQ", "Task force",
	"Feint/Dummy + TF", "TF + HQ", "Feint/Dummy + TF + HQ"]
const ECHELONS: Array[String] = [
	"11 Team/Crew", "12 Squad", "13 Section", "14 Platoon/Detachment", "15 Company/Battery/Troop",
	"16 Battalion/Squadron", "17 Regiment/Group", "18 Brigade", "21 Division", "22 Corps/MEF",
	"23 Army", "24 Army Group/Front", "25 Region/Theater", "26 Command"]
const MOBILITY: Array[String] = [
	"31 Wheeled limited cross country", "32 Wheeled cross country", "33 Tracked",
	"34 Wheeled and tracked", "35 Towed", "36 Rail", "37 Pack animals", "41 Over snow", "42 Sled",
	"51 Barge", "52 Amphibious", "61 Short towed array", "62 Long towed array"]
const DEFAULT_ENTITY: String = "121100"
const CARD_WIDTH: float = 150.0
const THUMB_SIZE: float = 110.0
const DEBOUNCE_SEC: float = 0.15

var _set_opt: OptionButton
var _edition_opt: OptionButton
var _identity_opt: OptionButton
var _status_opt: OptionButton
var _color_mode: OptionButton
var _fill: CheckBox
var _frame: CheckBox
var _mono_check: CheckBox
var _mono_picker: ColorPickerButton
var _size_slider: HSlider
var _size_label: Label
var _outline_slider: HSlider
var _outline_label: Label
var _search: LineEdit
var _count_label: Label
var _flow: HFlowContainer
var _debounce: Timer

var _m1_opt: OptionButton
var _m2_opt: OptionButton
var _sidc_edit: LineEdit
var _preview_row: HBoxContainer
var _context_opt: OptionButton
var _detail_status_opt: OptionButton
var _hq_opt: OptionButton
var _amp_opt: OptionButton
var _show_anchor: CheckBox
var _hq_staff: SpinBox
var _selected_label: Label
var _preview_render: MilSymbolRender  # Render of the current identity, used by Copy SVG.

var _tables: Dictionary = {}
var _entities: Array[Dictionary] = []  # {code, label, card}
var _selected_code: String = ""


func _ready() -> void:
	_build_ui()
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = DEBOUNCE_SEC
	_debounce.timeout.connect(_rebuild_cards)
	add_child(_debounce)
	_reload_tables()
	_rebuild_cards()


# ---------------------------------------------------------------- UI construction

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
	title.text = "godot-milsymbol — Icons"
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	# Top bar (wraps when the window is narrow).
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 10)
	bar.add_theme_constant_override("v_separation", 4)
	root.add_child(bar)

	_set_opt = _option(SYMBOL_SET_NAMES, 1)
	_set_opt.item_selected.connect(_on_set_or_edition_changed)
	bar.add_child(_labeled("Set", _set_opt))
	_edition_opt = _option(EDITION_NAMES, 0)
	_edition_opt.item_selected.connect(_on_set_or_edition_changed)
	bar.add_child(_labeled("Edition", _edition_opt))
	_identity_opt = _option(IDENTITY_NAMES, 1)
	_identity_opt.item_selected.connect(_on_setting_int)
	bar.add_child(_labeled("Identity", _identity_opt))
	_status_opt = _option(["Present", "Planned"], 0)
	_status_opt.item_selected.connect(_on_setting_int)
	bar.add_child(_labeled("Status", _status_opt))
	_color_mode = _option(["Light", "Medium", "Dark"], 0)
	_color_mode.item_selected.connect(_on_setting_int)
	bar.add_child(_labeled("Color", _color_mode))

	_fill = _check("Fill", true)
	bar.add_child(_fill)
	_frame = _check("Frame", true)
	bar.add_child(_frame)
	_mono_check = _check("Mono", false)
	_mono_picker = ColorPickerButton.new()
	_mono_picker.color = Color.BLACK
	_mono_picker.custom_minimum_size = Vector2(44, 0)
	_mono_picker.color_changed.connect(_on_setting_color)
	var mono_box := HBoxContainer.new()
	mono_box.add_child(_mono_check)
	mono_box.add_child(_mono_picker)
	bar.add_child(mono_box)

	_size_slider = _slider(40, 160, 1, 80)
	_size_label = Label.new()
	_size_label.custom_minimum_size = Vector2(28, 0)
	bar.add_child(_labeled("Size", _size_slider, _size_label))
	_outline_slider = _slider(0, 6, 0.5, 0)
	_outline_label = Label.new()
	_outline_label.custom_minimum_size = Vector2(28, 0)
	bar.add_child(_labeled("Outline", _outline_slider, _outline_label))

	_search = LineEdit.new()
	_search.placeholder_text = "Search label or code"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(200, 0)
	_search.text_changed.connect(_on_search_changed)
	bar.add_child(_search)
	_count_label = Label.new()
	bar.add_child(_count_label)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 10)
	root.add_child(split)

	# Card grid.
	var grid_bg := ColorRect.new()
	grid_bg.color = Color(0.2, 0.22, 0.25)
	grid_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(grid_bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_bg.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 6)
	scroll.add_child(pad)
	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 6)
	_flow.add_theme_constant_override("v_separation", 6)
	pad.add_child(_flow)

	# Side panel.
	var panel_scroll := ScrollContainer.new()
	panel_scroll.custom_minimum_size = Vector2(440, 0)
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(panel_scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(panel)

	_selected_label = Label.new()
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_selected_label)

	var preview_bg := ColorRect.new()
	preview_bg.color = Color(0.2, 0.22, 0.25)
	preview_bg.custom_minimum_size = Vector2(0, 220)
	panel.add_child(preview_bg)
	_preview_row = HBoxContainer.new()
	_preview_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_row.add_theme_constant_override("separation", 0)
	preview_bg.add_child(_preview_row)

	# Preview-only settings; the grid cards stay plain.
	_context_opt = _option(CONTEXT_NAMES, 1)
	_context_opt.item_selected.connect(_on_modifier_changed)
	panel.add_child(_labeled("Context", _context_opt))
	_detail_status_opt = _option(DETAIL_STATUS_NAMES, 2)
	_detail_status_opt.item_selected.connect(_on_modifier_changed)
	panel.add_child(_labeled("Status", _detail_status_opt))
	_hq_opt = _option(HQ_NAMES, 6)
	_hq_opt.item_selected.connect(_on_modifier_changed)
	panel.add_child(_labeled("HQ/TF/Dummy", _hq_opt))
	_amp_opt = OptionButton.new()
	_amp_opt.fit_to_longest_item = false
	_amp_opt.clip_text = true
	_amp_opt.add_item("00 None")
	_amp_opt.set_item_metadata(0, "00")
	_amp_opt.add_separator("Echelon")
	_add_amplifiers(ECHELONS)
	_amp_opt.add_separator("Mobility")
	_add_amplifiers(MOBILITY)
	_amp_opt.selected = 7  # 16 Battalion/Squadron
	_amp_opt.item_selected.connect(_on_modifier_changed)
	panel.add_child(_labeled("Amplifier", _amp_opt))
	_show_anchor = CheckBox.new()
	_show_anchor.text = "Show anchor"
	_show_anchor.button_pressed = true
	_show_anchor.toggled.connect(func(_on: bool) -> void: _refresh_detail())
	panel.add_child(_show_anchor)
	_hq_staff = SpinBox.new()
	_hq_staff.min_value = 0
	_hq_staff.max_value = 200
	_hq_staff.step = 1
	_hq_staff.value_changed.connect(func(_v: float) -> void: _refresh_detail())
	panel.add_child(_labeled("HQ staff length (0 = default)", _hq_staff))

	_m1_opt = OptionButton.new()
	_m1_opt.fit_to_longest_item = false
	_m1_opt.clip_text = true
	_m1_opt.item_selected.connect(_on_modifier_changed)
	panel.add_child(_labeled("Modifier 1", _m1_opt))
	_m2_opt = OptionButton.new()
	_m2_opt.fit_to_longest_item = false
	_m2_opt.clip_text = true
	_m2_opt.item_selected.connect(_on_modifier_changed)
	panel.add_child(_labeled("Modifier 2", _m2_opt))

	_sidc_edit = LineEdit.new()
	_sidc_edit.editable = false
	panel.add_child(_labeled("SIDC", _sidc_edit))

	var copy := Button.new()
	copy.text = "Copy SVG"
	copy.pressed.connect(_on_copy_svg)
	panel.add_child(copy)


func _add_amplifiers(items: Array[String]) -> void:
	for text in items:
		_amp_opt.add_item(text)
		_amp_opt.set_item_metadata(_amp_opt.item_count - 1, text.substr(0, 2))


func _option(items: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	for i in items:
		o.add_item(str(i))
	o.selected = selected
	return o


func _labeled(text: String, a: Control, b: Control = null) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = text
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
	c.toggled.connect(_on_setting_bool)
	return c


func _slider(lo: float, hi: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(110, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(_on_setting_float)
	return s


# ---------------------------------------------------------------- signals

func _on_set_or_edition_changed(_i: int) -> void:
	_reload_tables()
	_debounce.start()


func _on_setting_int(_v: int) -> void:
	_debounce.start()


func _on_setting_bool(_v: bool) -> void:
	_debounce.start()


func _on_setting_float(_v: float) -> void:
	_size_label.text = str(int(_size_slider.value))
	_outline_label.text = str(_outline_slider.value)
	_debounce.start()


func _on_setting_color(_v: Color) -> void:
	_debounce.start()


func _on_search_changed(_t: String) -> void:
	_apply_filter()


func _on_modifier_changed(_i: int) -> void:
	_refresh_detail()


func _on_copy_svg() -> void:
	if _preview_render != null:
		DisplayServer.clipboard_set(_preview_render.svg)


# ---------------------------------------------------------------- data

func _symbol_set() -> String:
	return SYMBOL_SETS[_set_opt.selected]


func _version() -> String:
	return EDITION_VERSIONS[_edition_opt.selected]


func _status() -> String:
	return str(_status_opt.selected)


func _options(size: float) -> Dictionary:
	var opts: Dictionary = {
		"size": size,
		"colorMode": _color_mode.get_item_text(_color_mode.selected),
		"fill": _fill.button_pressed,
		"frame": _frame.button_pressed,
		"outlineWidth": _outline_slider.value,
	}
	if _mono_check.button_pressed:
		opts["monoColor"] = "#" + _mono_picker.color.to_html(false)
	return opts


## Grid cards use the plain form; the detail preview passes `detail = true` to add the side panel settings.
func _make_sidc(identity: String, entity: String, m1: String, m2: String, detail: bool = false) -> String:
	if detail:
		var amp: String = str(_amp_opt.get_item_metadata(_amp_opt.selected))
		return "%s%d%s%s%d%d%s%s%s%s" % [_version(), _context_opt.selected, identity, _symbol_set(),
			_detail_status_opt.selected, _hq_opt.selected, amp, entity, m1, m2]
	return "%s0%s%s%s0" % [_version(), identity, _symbol_set(), _status()] + "00" + entity + m1 + m2


## Reloads the SIDC tables and rebuilds the entity list and the modifier option buttons.
func _reload_tables() -> void:
	_tables = MilSymbolIcons.get_tables(_symbol_set(), EDITIONS[_edition_opt.selected])
	_entities.clear()
	var main: Dictionary = _tables.get("main", {})
	var codes: Array = main.keys()
	codes.sort()
	for code in codes:
		_entities.append({"code": str(code), "label": _label_of(main[code], "(" + str(code) + ")")})
	if _selected_code == "" or not main.has(_selected_code):
		_selected_code = DEFAULT_ENTITY if main.has(DEFAULT_ENTITY) else _entities[0].code if not _entities.is_empty() else ""
	_fill_modifier_option(_m1_opt, _tables.get("m1", {}))
	_fill_modifier_option(_m2_opt, _tables.get("m2", {}))


func _fill_modifier_option(opt: OptionButton, table: Dictionary) -> void:
	opt.clear()
	opt.add_item("00 none")
	opt.set_item_metadata(0, "00")
	var codes: Array = table.keys()
	codes.sort()
	for code in codes:
		if str(code) == "00":
			continue
		opt.add_item("%s %s" % [code, _label_of(table[code], "(" + str(code) + ")")])
		opt.set_item_metadata(opt.item_count - 1, str(code))
	opt.selected = 0


func _label_of(entry: Variant, fallback: String) -> String:
	var ref: String = _first_ref(entry)
	if ref == "":
		return fallback
	var base: String = ref.substr(ref.rfind(".") + 1)
	var out: PackedStringArray = []
	for w in base.split(" ", false):
		# Keep mixed-case tokens such as "DSymbol" intact.
		out.append(w.to_lower().capitalize() if w == w.to_upper() else w)
	return " ".join(out)


func _first_ref(v: Variant) -> String:
	if v is Dictionary:
		if v.has("$ref"):
			return str(v["$ref"])
		for k in v:
			var r: String = _first_ref(v[k])
			if r != "":
				return r
	elif v is Array:
		for item in v:
			var r: String = _first_ref(item)
			if r != "":
				return r
	return ""


# ---------------------------------------------------------------- cards

func _rebuild_cards() -> void:
	_size_label.text = str(int(_size_slider.value))
	_outline_label.text = str(_outline_slider.value)
	for c in _flow.get_children():
		_flow.remove_child(c)
		c.queue_free()
	var opts: Dictionary = _options(_size_slider.value)
	var identity: String = IDENTITY_CODES[_identity_opt.selected]
	for e in _entities:
		var card: PanelContainer = _make_card(e, identity, opts)
		e["card"] = card
		_flow.add_child(card)
	_apply_filter()
	_update_card_styles()
	_refresh_detail()


func _make_card(e: Dictionary, identity: String, opts: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.tooltip_text = "%s\n%s" % [e.code, e.label]
	var code: String = e.code
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select(code))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)

	var render: MilSymbolRender = MilSymbol.render(_make_sidc(identity, e.code, "00", "00"), opts)
	var tex: Texture2D = render.to_texture(1.0) if render != null else null
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(0, THUMB_SIZE)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = tex
	box.add_child(rect)

	var code_label := Label.new()
	code_label.text = e.code
	code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_label.add_theme_font_size_override("font_size", 12)
	code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(code_label)

	var name_label := Label.new()
	name_label.text = e.label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.modulate = Color(0.8, 0.8, 0.8)
	name_label.custom_minimum_size = Vector2(CARD_WIDTH - 16, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)

	if render == null or not render.valid:
		var tag := Label.new()
		tag.text = "invalid"
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tag)
	return card


func _apply_filter() -> void:
	var q: String = _search.text.strip_edges().to_lower()
	var shown: int = 0
	for e in _entities:
		var card: Control = e.get("card")
		if card == null:
			continue
		var ok: bool = q == "" or String(e.label).to_lower().contains(q) or String(e.code).contains(q)
		card.visible = ok
		if ok:
			shown += 1
	_count_label.text = "%d / %d icons" % [shown, _entities.size()]


func _select(code: String) -> void:
	_selected_code = code
	_update_card_styles()
	_refresh_detail()


func _update_card_styles() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.16, 0.19)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	var selected := normal.duplicate() as StyleBoxFlat
	selected.bg_color = Color(0.2, 0.3, 0.45)
	selected.set_border_width_all(2)
	selected.border_color = Color(0.4, 0.7, 1.0)
	for e in _entities:
		var card: Control = e.get("card")
		if card != null:
			card.add_theme_stylebox_override("panel", selected if e.code == _selected_code else normal)


# ---------------------------------------------------------------- detail panel

func _modifier_code(opt: OptionButton) -> String:
	var meta: Variant = opt.get_item_metadata(opt.selected)
	return str(meta) if meta != null else "00"


func _refresh_detail() -> void:
	for c in _preview_row.get_children():
		_preview_row.remove_child(c)
		c.queue_free()
	_preview_render = null
	if _selected_code == "":
		_selected_label.text = "No icon selected"
		_sidc_edit.text = ""
		return
	var label := ""
	for e in _entities:
		if e.code == _selected_code:
			label = e.label
	var m1: String = _modifier_code(_m1_opt)
	var m2: String = _modifier_code(_m2_opt)
	_selected_label.text = "%s — %s" % [_selected_code, label]
	var opts: Dictionary = _options(100.0)
	if _hq_staff.value > 0:
		opts["hqStaffLength"] = _hq_staff.value
	var current: String = IDENTITY_CODES[_identity_opt.selected]
	for i in IDENTITY_CODES.size():
		var sidc: String = _make_sidc(IDENTITY_CODES[i], _selected_code, m1, m2, true)
		var render: MilSymbolRender = MilSymbol.render(sidc, opts)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rect := TextureRect.new()
		rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if render != null:
			rect.texture = render.to_texture(1.0)
			_add_anchor_overlay(rect, render)
		col.add_child(rect)
		var id_label := Label.new()
		id_label.text = IDENTITY_NAMES[i]
		id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		id_label.add_theme_font_size_override("font_size", 11)
		col.add_child(id_label)
		_preview_row.add_child(col)
		if IDENTITY_CODES[i] == current:
			_preview_render = render
			_sidc_edit.text = sidc


## Adds a full-rect overlay to a preview TextureRect that draws a red cross at the render's anchor.
func _add_anchor_overlay(target: TextureRect, render: MilSymbolRender) -> void:
	if not _show_anchor.button_pressed or target.texture == null:
		return
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.draw.connect(func() -> void:
		var ts: Vector2 = target.texture.get_size()
		if ts.x <= 0 or ts.y <= 0:
			return
		var s: float = minf(o.size.x / ts.x, o.size.y / ts.y)
		var p: Vector2 = (o.size - ts * s) * 0.5 + render.anchor * s
		o.draw_line(p - Vector2(5, 0), p + Vector2(5, 0), Color.RED, 1.5)
		o.draw_line(p - Vector2(0, 5), p + Vector2(0, 5), Color.RED, 1.5))
	target.add_child(o)
