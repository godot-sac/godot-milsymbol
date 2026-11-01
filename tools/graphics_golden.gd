extends SceneTree
## Writes tests/golden/graphics.json: SVG of every control measure test case (tests/helpers/graphics_cases.gd).
## These are regression goldens of our own output (there is no MIT reference renderer for control measures);
## regenerate after an intended change and look at the gallery (demo/graphics_gallery.tscn) first.
## <godot> --headless --path . -s res://tools/graphics_golden.gd

const Cases = preload("res://tests/helpers/graphics_cases.gd")
const OUT_FILE := "res://tests/golden/graphics.json"


func _init() -> void:
	var goldens := {}
	var variants := Cases.golden_variants()
	for key in variants:
		var case := Cases.case_of(key.split(" ")[0])
		var shape := MilGraphic.build(variants[key], Cases.points_of(case), Cases.amplifiers_of(case))
		goldens[key] = MilGraphicRenderer.to_svg(shape)
	var file := FileAccess.open(OUT_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(goldens, "\t", true) + "\n")
	file.close()
	print("wrote %s: %d graphics" % [OUT_FILE, goldens.size()])
	quit()
