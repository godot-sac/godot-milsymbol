extends GutTest
## SVG / PNG export of symbols and control measures, and the MilSymbolTextureRect control.

const DIR := "user://test_export/"


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func _opaque_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.5:
				count += 1
	return count


func test_symbol_svg_and_png() -> void:
	var sidc := "10031000161211000000"
	assert_eq(MilSymbol.save_svg(sidc, DIR + "unit.svg"), OK)
	assert_true(FileAccess.get_file_as_string(DIR + "unit.svg").begins_with("<svg"))
	assert_eq(MilSymbol.save_png(sidc, DIR + "unit.png", {"size": 60}, 2.0), OK)
	var image := Image.load_from_file(ProjectSettings.globalize_path(DIR + "unit.png"))
	var expected := MilSymbol.render(sidc, {"size": 60}).size * 2.0
	assert_almost_eq(Vector2(image.get_size()), expected, Vector2(1.5, 1.5))


func test_graphic_png_keeps_labels_as_glyph_outlines() -> void:
	var shape := MilGraphic.build("10032500001403000000", PackedVector2Array([Vector2(0, 0), Vector2(300, 0)]),
			{"T": "BLUE"})
	var path_svg := MilGraphicRenderer.to_svg(shape, {}, 20.0, true)
	assert_false(path_svg.contains("<text"))
	var with_text := MilGraphicRenderer.to_image(shape)
	var without_text := Image.new()
	without_text.load_svg_from_string(MilGraphicRenderer.to_svg(shape))  # ThorVG skips <text>
	assert_eq(with_text.get_size(), without_text.get_size())
	assert_gt(_opaque_pixels(with_text), _opaque_pixels(without_text) + 100, "the two PL BLUE labels are drawn")
	assert_eq(MilGraphicRenderer.save_png(shape, DIR + "pl.png"), OK)
	assert_eq(MilGraphicRenderer.save_svg(shape, DIR + "pl.svg"), OK)
	assert_true(FileAccess.get_file_as_string(DIR + "pl.svg").contains("PL BLUE"))


func test_graphic_png_draws_embedded_symbols() -> void:
	var area := PackedVector2Array([Vector2(0, 0), Vector2(120, 0), Vector2(120, 120), Vector2(0, 120)])
	var image := MilGraphicRenderer.to_image(MilGraphic.build("10032500002707070000", area), {}, 1.0, 20.0)
	# The mine symbol is at the centre of the area (60, 60) + margin.
	var center := Vector2i(80, 80)
	var found := false
	for dy in range(-16, 17):
		for dx in range(-16, 17):
			if image.get_pixelv(center + Vector2i(dx, dy)).a > 0.5:
				found = true
	assert_true(found, "mine symbol drawn")


func test_texture_rect_control() -> void:
	var rect := MilSymbolTextureRect.new()
	rect.sidc = "SFGPUCI----D---"  # letter SIDC is converted
	rect.symbol_size = 40
	add_child_autofree(rect)
	assert_not_null(rect.texture)
	assert_true(rect.symbol.valid)
	assert_eq(rect.custom_minimum_size, rect.symbol.size.ceil())
	rect.sidc = "10061000001211000000"
	rect.refresh()
	assert_eq(rect.symbol.metadata.affiliation, "Hostile")
