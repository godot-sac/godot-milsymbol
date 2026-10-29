extends GutTest
## Smoke test: Godot's SVG loader (ThorVG) can rasterize SVG exactly as milsymbol 3.0.5 writes it.

# milsymbol output for 10031000141211000000 (friendly infantry platoon), default options.
const INFANTRY_PLATOON_SVG := "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.2\" baseProfile=\"tiny\" width=\"158\" height=\"135.5\" viewBox=\"21 18.5 158 135.5\"><path d=\"M25,50 l150,0 0,100 -150,0 z\" stroke-width=\"4\" stroke=\"black\" fill=\"rgb(128,224,255)\" fill-opacity=\"1\" ></path><path d=\"M25,50 L175,150 M25,150 L175,50\" stroke-width=\"3\" stroke=\"black\" fill=\"black\" ></path><g transform=\"translate(0,50)\" stroke-width=\"4\" stroke=\"black\" fill=\"none\" ><circle cx=\"100\" cy=\"-20\" r=\"7.5\" fill=\"black\" class=\"milsymbol-echelon milsymbol-echelon-fill\" ></circle><circle cx=\"70\" cy=\"-20\" r=\"7.5\" fill=\"black\" class=\"milsymbol-echelon milsymbol-echelon-fill\" ></circle><circle cx=\"130\" cy=\"-20\" r=\"7.5\" fill=\"black\" class=\"milsymbol-echelon milsymbol-echelon-fill\" ></circle></g></svg>"


func _load(svg: String) -> Image:
	var image := Image.new()
	var err := image.load_svg_from_string(svg)
	assert_eq(err, OK, "load_svg_from_string failed")
	return image


func test_size_matches_svg_attributes() -> void:
	var image := _load(INFANTRY_PLATOON_SVG)
	# Godot rounds the 135.5 px height.
	assert_eq(image.get_width(), 158)
	assert_between(image.get_height(), 135, 136)


func test_frame_fill_color() -> void:
	var image := _load(INFANTRY_PLATOON_SVG)
	# Pixel inside the frame but away from the icon cross: (40, 100) in SVG units.
	var pixel := image.get_pixel(40 - 21, 100 - 18)
	assert_almost_eq(pixel.r8, 128, 2)
	assert_almost_eq(pixel.g8, 224, 2)
	assert_almost_eq(pixel.b8, 255, 2)


func test_echelon_dot_is_black() -> void:
	var image := _load(INFANTRY_PLATOON_SVG)
	# Centre of the middle echelon dot: (100, 30) in SVG units.
	var pixel := image.get_pixel(100 - 21, 30 - 18)
	assert_almost_eq(pixel.r8, 0, 2)
	assert_eq(pixel.a8, 255)
