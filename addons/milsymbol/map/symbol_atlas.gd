class_name MilSymbolAtlas
extends RefCounted
## Packs rendered symbols into one texture so that thousands of symbols can be drawn in one batch
## (see TacticalMap2D). Each symbol is padded so that its anchor point is at the centre of its region.
##
## The image grows (512 -> 1024 -> ... -> max_size) when full; regions are in pixels and stay valid.
## Call commit() once per frame after adding symbols to upload the image.

signal texture_changed

const PADDING := 2

var max_size := 4096
var image: Image
## The atlas texture; replaced (texture_changed) when the image grows.
var texture: ImageTexture

var _entries := {}  # key -> {"region": Rect2i, "bounds": Rect2} (bounds: symbol rect relative to the anchor)
var _shelf_x := 0
var _shelf_y := 0
var _shelf_height := 0
var _dirty := false


func _init(initial_size: int = 512) -> void:
	image = Image.create_empty(initial_size, initial_size, false, Image.FORMAT_RGBA8)


## Atlas entry for a symbol: {"region": Rect2i (pixels, anchor at its centre), "bounds": Rect2 (visible
## symbol relative to the anchor)}. Empty if the symbol cannot be rasterized or the atlas is full.
func get_entry(sidc: String, options: Dictionary) -> Dictionary:
	var key := sidc + "|" + MilSymbol._options_key(options)
	if _entries.has(key):
		return _entries[key]
	var render := MilSymbol.render_cached(sidc, options)
	var symbol := render.to_image()
	if symbol == null:
		_entries[key] = {}
		return {}
	symbol.convert(Image.FORMAT_RGBA8)
	var anchor := render.anchor
	var half := Vector2(maxf(anchor.x, symbol.get_width() - anchor.x), maxf(anchor.y, symbol.get_height() - anchor.y))
	var region_size := Vector2i(ceili(half.x * 2.0), ceili(half.y * 2.0))
	var position := _allocate(region_size)
	if position.x < 0:
		push_warning("MilSymbolAtlas: atlas is full (%d px), symbol %s is not drawn" % [max_size, sidc])
		_entries[key] = {}
		return {}
	var offset := Vector2i(roundi(region_size.x / 2.0 - anchor.x), roundi(region_size.y / 2.0 - anchor.y))
	image.blit_rect(symbol, Rect2i(Vector2i.ZERO, symbol.get_size()), position + offset)
	_dirty = true
	var entry := {
		"region": Rect2i(position, region_size),
		"bounds": Rect2(-anchor, Vector2(symbol.get_size())),
	}
	_entries[key] = entry
	return entry


## Number of distinct symbols in the atlas.
func size() -> int:
	return _entries.size()


## Uploads the image if symbols were added since the last call.
func commit() -> void:
	if not _dirty and texture != null:
		return
	_dirty = false
	if texture != null and texture.get_size() == Vector2(image.get_size()):
		texture.update(image)
	else:
		texture = ImageTexture.create_from_image(image)
		texture_changed.emit()


## Forgets every symbol (e.g. after a style change).
func clear() -> void:
	_entries.clear()
	image.fill(Color(0, 0, 0, 0))
	_shelf_x = 0
	_shelf_y = 0
	_shelf_height = 0
	_dirty = true


# Shelf packing: left to right in rows; a new row starts below the tallest region of the current one.
func _allocate(region_size: Vector2i) -> Vector2i:
	var needed := region_size + Vector2i(PADDING, PADDING)
	while true:
		if _shelf_x + needed.x > image.get_width():
			_shelf_y += _shelf_height
			_shelf_x = 0
			_shelf_height = 0
		if _shelf_y + needed.y <= image.get_height() and needed.x <= image.get_width():
			var position := Vector2i(_shelf_x, _shelf_y)
			_shelf_x += needed.x
			_shelf_height = maxi(_shelf_height, needed.y)
			return position
		if not _grow():
			return Vector2i(-1, -1)
	return Vector2i(-1, -1)


func _grow() -> bool:
	var current := image.get_width()
	if current >= max_size:
		return false
	var grown := Image.create_empty(current * 2, current * 2, false, Image.FORMAT_RGBA8)
	grown.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	image = grown
	# Packing continues on the current row (now wider) and on new rows below; earlier rows keep their width.
	_dirty = true
	return true
