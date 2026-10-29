extends GutTest
## Tests for the golden-test SVG comparator itself.

const SvgCompare = preload("res://tests/helpers/svg_compare.gd")

const BASE := "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"158\" height=\"135.5\" viewBox=\"21 18.5 158 135.5\"><path d=\"M25,50 l150,0 0,100 -150,0 z\" stroke-width=\"4\" stroke=\"black\" fill=\"rgb(128,224,255)\" fill-opacity=\"1\" ></path><g transform=\"translate(0,50)\" stroke=\"black\" fill=\"none\" ><circle cx=\"100\" cy=\"-20\" r=\"7.5\" fill=\"black\" class=\"milsymbol-echelon\" ></circle></g><text x=\"10\" y=\"160\">A</text></svg>"


func test_identical_documents_match() -> void:
	assert_eq(SvgCompare.diff(BASE, BASE), PackedStringArray())


func test_formatting_differences_are_ignored() -> void:
	# Attribute order, self-closing tags, path separators, number noise, color spelling, class.
	var other := """<svg viewBox="21 18.5 158 135.50000001" height="135.5" width="158" xmlns="http://www.w3.org/2000/svg">
	  <path fill-opacity="1.0" fill="#80e0ff" stroke="#000" stroke-width="4.000" d="M 25 50 l 150 0 0 100 -150 0 z"/>
	  <g fill="none" stroke="rgb(0, 0, 0)" transform="translate(0, 50)">
	    <circle r="7.5" cy="-20" cx="100.004" fill="black"/>
	  </g>
	  <text y="160" x="10"> A </text>
	</svg>"""
	assert_eq(SvgCompare.diff(BASE, other), PackedStringArray())


func test_detects_changed_number() -> void:
	var other := BASE.replace("r=\"7.5\"", "r=\"8\"")
	var problems := SvgCompare.diff(BASE, other)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "circle[0]@r")


func test_detects_changed_color() -> void:
	var other := BASE.replace("rgb(128,224,255)", "rgb(255,128,128)")
	var problems := SvgCompare.diff(BASE, other)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "@fill")


func test_none_is_not_a_color() -> void:
	var other := BASE.replace("fill=\"none\"", "fill=\"black\"")
	assert_eq(SvgCompare.diff(BASE, other).size(), 1)


func test_detects_missing_and_extra_attributes() -> void:
	var other := BASE.replace(" fill-opacity=\"1\"", " stroke-dasharray=\"4,4\"")
	var problems := SvgCompare.diff(BASE, other)
	assert_eq(problems.size(), 2)


func test_detects_missing_element() -> void:
	var other := BASE.replace("<text x=\"10\" y=\"160\">A</text>", "")
	var problems := SvgCompare.diff(BASE, other)
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "children")


func test_detects_changed_text_and_path_command() -> void:
	var other := BASE.replace(">A<", ">B<").replace("l150,0", "L150,0")
	assert_eq(SvgCompare.diff(BASE, other).size(), 2)


func test_class_can_be_compared_when_not_ignored() -> void:
	var other := BASE.replace("milsymbol-echelon", "other")
	assert_eq(SvgCompare.diff(BASE, other).size(), 0)
	var no_ignore: Array[String] = []
	assert_eq(SvgCompare.diff(BASE, other, 0.01, no_ignore).size(), 1)


func test_invalid_svg_is_reported() -> void:
	var problems := SvgCompare.diff(BASE, "not xml at all")
	assert_eq(problems.size(), 1)
	assert_string_contains(problems[0], "actual")


func test_pixel_mismatch_ratio() -> void:
	var a := SvgCompare.rasterize(BASE)
	assert_not_null(a)
	assert_eq(SvgCompare.pixel_mismatch_ratio(a, a), 0.0)
	var b := SvgCompare.rasterize(BASE.replace("rgb(128,224,255)", "rgb(255,128,128)"))
	var ratio := SvgCompare.pixel_mismatch_ratio(a, b)
	assert_gt(ratio, 0.3, "most of the frame fill changed")
	assert_lt(ratio, 1.0)
	var c := SvgCompare.rasterize(BASE, 2.0)
	assert_eq(SvgCompare.pixel_mismatch_ratio(a, c), 1.0, "different size")
