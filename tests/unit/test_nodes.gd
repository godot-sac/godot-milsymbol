extends GutTest
## Texture cache and the MilSymbolSprite2D / MilSymbolSprite3D nodes.

const INFANTRY := "10031000001211000000"
const INFANTRY_HQ := "10031002001211000000"


func before_each() -> void:
	MilSymbol.clear_cache()


func test_cache_returns_same_texture_for_same_options_in_any_order() -> void:
	var a := MilSymbol.create_texture(INFANTRY, {"size": 50, "fill": false})
	var b := MilSymbol.create_texture(INFANTRY, {"fill": false, "size": 50})
	assert_not_null(a)
	assert_same(a, b)
	assert_eq(MilSymbol.cache_size(), 1)


func test_cache_separates_options_and_scale() -> void:
	var a := MilSymbol.create_texture(INFANTRY, {"size": 50})
	var b := MilSymbol.create_texture(INFANTRY, {"size": 51})
	var c := MilSymbol.create_texture(INFANTRY, {"size": 50}, 2.0)
	assert_ne(a, b)
	assert_ne(a, c)
	assert_eq(c.get_width(), a.get_width() * 2)
	assert_eq(MilSymbol.cache_size(), 2, "scale shares the render entry")


func test_cache_limit_drops_least_recently_used() -> void:
	var old_limit := MilSymbol.cache_limit
	MilSymbol.cache_limit = 2
	var first := MilSymbol.render_cached(INFANTRY, {"size": 10})
	MilSymbol.render_cached(INFANTRY, {"size": 20})
	MilSymbol.render_cached(INFANTRY, {"size": 10})  # touch: now most recent
	MilSymbol.render_cached(INFANTRY, {"size": 30})  # evicts size 20
	assert_eq(MilSymbol.cache_size(), 2)
	assert_same(MilSymbol.render_cached(INFANTRY, {"size": 10}), first)
	MilSymbol.cache_limit = old_limit


func test_style_to_options() -> void:
	var style := MilSymbolStyle.new()
	style.color_mode = MilSymbolStyle.ColorMode.DARK
	style.use_mono_color = true
	style.mono_color = Color8(10, 20, 30)
	style.extra_options = {"hqStaffLength": 60}
	var options := style.to_options()
	assert_eq(options.colorMode, "Dark")
	assert_eq(options.monoColor, "rgb(10,20,30)")
	assert_eq(options.hqStaffLength, 60)
	var render := MilSymbol.render(INFANTRY, options)
	assert_true(render.svg.contains("rgb(10,20,30)"))


func test_sprite_2d_renders_and_puts_anchor_at_origin() -> void:
	var sprite := MilSymbolSprite2D.new()
	sprite.sidc = INFANTRY_HQ
	sprite.symbol_size = 80
	add_child_autofree(sprite)
	assert_not_null(sprite.texture)
	assert_not_null(sprite.symbol)
	assert_eq(sprite.texture.get_width(), roundi(sprite.symbol.size.x))
	assert_false(sprite.centered)
	assert_eq(sprite.offset, -sprite.symbol.anchor)
	# HQ anchor is the foot of the staff: the bottom of the image minus the stroke margin.
	var margin := 4.0 * 80 / 100
	assert_almost_eq(sprite.symbol.anchor.y, sprite.symbol.size.y - margin, 0.01)
	assert_eq(sprite.get_metadata().headquarters, true)


func test_sprite_2d_refreshes_once_after_property_changes() -> void:
	var sprite := MilSymbolSprite2D.new()
	add_child_autofree(sprite)
	watch_signals(sprite)
	sprite.sidc = "10061000001211000000"
	sprite.symbol_size = 40
	sprite.anchor_at_origin = false
	await wait_process_frames(2)
	assert_signal_emit_count(sprite, "symbol_changed", 1)
	assert_eq(sprite.get_metadata().affiliation, "Hostile")
	assert_eq(sprite.offset, -sprite.symbol.size / 2)


func test_sprite_2d_follows_shared_style() -> void:
	var style := MilSymbolStyle.new()
	var a := MilSymbolSprite2D.new()
	var b := MilSymbolSprite2D.new()
	a.style = style
	b.style = style
	add_child_autofree(a)
	add_child_autofree(b)
	var before := a.texture
	style.fill = false
	await wait_process_frames(2)
	assert_ne(a.texture, before)
	assert_same(a.texture, b.texture, "same SIDC + style share the cached texture")
	assert_false(a.symbol.svg.contains("rgb(128,224,255)"))


func test_sprite_3d_anchor_maps_to_origin() -> void:
	var sprite := MilSymbolSprite3D.new()
	sprite.sidc = INFANTRY_HQ
	sprite.symbol_size = 100
	add_child_autofree(sprite)
	assert_not_null(sprite.texture)
	assert_eq(sprite.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	# A billboard's AABB is padded for rotation; measure the flat quad instead.
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	await wait_process_frames(1)  # Sprite3D rebuilds its mesh and AABB during the frame.
	var aabb := sprite.get_aabb()
	var px := sprite.pixel_size
	var size := sprite.symbol.size
	var anchor := sprite.symbol.anchor
	# Image left edge is anchor.x pixels left of the origin; image top is anchor.y pixels above it.
	assert_almost_eq(aabb.position.x, -anchor.x * px, 0.01)
	assert_almost_eq(aabb.end.y, anchor.y * px, 0.01)
	assert_almost_eq(aabb.size.x, roundf(size.x) * px, 0.02)


func test_sprite_3d_centered_without_anchor() -> void:
	var sprite := MilSymbolSprite3D.new()
	sprite.anchor_at_origin = false
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child_autofree(sprite)
	await wait_process_frames(1)
	var aabb := sprite.get_aabb()
	assert_gt(aabb.size.x, 0.0)
	assert_almost_eq(aabb.get_center().x, 0.0, 0.01)
	assert_almost_eq(aabb.get_center().y, 0.0, 0.01)


func test_echelon_outline_is_drawn_on_the_frame_unless_quirks() -> void:
	# Hostile platoon with an outline: milsymbol puts the echelon halo at y = 0 (a bug); we put it on the frame top.
	var sidc := "10061000141211000000"
	var fixed := MilSymbol.render(sidc, {"outlineWidth": 2})
	var quirk := MilSymbol.render(sidc, {"outlineWidth": 2, "milsymbolQuirks": true})
	assert_true(fixed.svg.contains("translate(0,28)"), "outline and echelon both at the frame top (y = 28)")
	assert_false(quirk.svg.contains("translate(0,28)") and quirk.svg.count("translate(0,28)") > 1)
	assert_true(quirk.svg.contains("translate(0,0)"))
