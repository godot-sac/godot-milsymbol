extends GutTest
## Letter based 2525C SIDCs converted to 2525D (MilSymbolLegacy).


func test_detects_letter_sidcs() -> void:
	assert_true(MilSymbolLegacy.is_letter_sidc("SFGPUCI----D---"))
	assert_true(MilSymbolLegacy.is_letter_sidc("gfgpglb----h---"), "case does not matter")
	assert_false(MilSymbolLegacy.is_letter_sidc("10031000141211000000"))
	assert_false(MilSymbolLegacy.is_letter_sidc("SFG"), "too short")
	assert_false(MilSymbolLegacy.is_letter_sidc("XFGPUCI----D---"), "unknown coding scheme")


func test_units_identity_status_and_echelon() -> void:
	var cases := {
		"SFGPUCI----D---": "10031000141211000000",  # friendly infantry platoon
		"SHAPMF---------": "10060100001101000000",  # hostile military fixed wing
		"SFGPUCI---AH---": "10031002181211000000",  # brigade HQ
		"SFGAUCI----D---": "10031010141211000000",  # anticipated
		"SDGPUCI--------": "10131000001211000000",  # exercise friend
		"SKGPUCI--------": "10161000001211000000",  # faker
		"SNGPEVAT-------": "10041500001202000000",  # neutral tank (equipment)
		"SFGPUCI---MO---": "10031000311211000000",  # mobility: wheeled, limited cross country
		"SFGPUCI---F----": "10031001001211000000",  # feint / dummy
		"sfgpuci****d***": "10031000141211000000",  # lower case and "*" placeholders
	}
	for letter in cases:
		var result := MilSymbolLegacy.convert_2525c(letter)
		assert_eq(result.sidc, cases[letter], letter)
		assert_true(result.exact, letter)


func test_modifiers_come_from_the_table() -> void:
	# Signal unit, communications contingency package: 2525D puts it in sector modifier 1.
	assert_eq(MilSymbolLegacy.to_number_sidc("SFGPUUSC-------"), "10031000001110001100")


func test_tactical_graphics_and_metoc() -> void:
	assert_eq(MilSymbolLegacy.to_number_sidc("GFGPGLB----H---"), "10032500181101000000", "brigade boundary")
	assert_eq(MilSymbolLegacy.to_number_sidc("GHGAGLP--------"), "10062510001403000000", "planned hostile PL")
	assert_eq(MilSymbolLegacy.to_number_sidc("WAS-PL----P----"), "10004500001101000000", "low pressure centre")


func test_unknown_or_retired_function_falls_back_to_the_parent() -> void:
	var retired := MilSymbolLegacy.convert_2525c("SFGPUUSCL------")  # retired in 2525D
	assert_eq(retired.sidc, "10031000001110001100", "parent: contingency package")
	assert_false(retired.exact)
	var unknown := MilSymbolLegacy.convert_2525c("SFGPUCI999-----")  # digits are never used
	assert_eq(unknown.sidc, "10031000001211000000")
	assert_false(unknown.exact)
	var nothing := MilSymbolLegacy.convert_2525c("SFQP-----------")
	assert_eq(nothing.sidc, "")
	assert_ne(nothing.error, "")


func test_render_draws_letter_sidcs_as_their_2525d_equivalent() -> void:
	var letter := MilSymbol.render("SFGPUCI----D---")
	var number := MilSymbol.render("10031000141211000000")
	assert_true(letter.valid)
	assert_eq(letter.sidc, "SFGPUCI----D---", "the input SIDC is kept")
	assert_eq(letter.svg, number.svg)
	var graphic := MilGraphic.build("GFGPGLP--------", PackedVector2Array([Vector2.ZERO, Vector2(100, 0)]), {"T": "BLUE"})
	assert_true(graphic.valid)
	assert_eq(graphic.code, "140300")
	assert_eq(graphic.sidc, "GFGPGLP--------")


func test_every_table_entry_converts_to_a_known_symbol() -> void:
	# Every mapped key, as a friendly present symbol, gives a 20 digit SIDC that MilSymbol decodes.
	var table := MilSymbolLegacy._data()
	assert_gt(table.size(), 1800)
	var failures := PackedStringArray()
	for key: String in table:
		var letter := key.substr(0, 1) + ("F" if key[1] == "*" else key[1]) + key.substr(2, 1) + "P" + key.substr(4)
		if key.begins_with("W"):
			letter = key
		var sidc := MilSymbolLegacy.to_number_sidc(letter.rpad(15, "-"))
		if sidc.length() != 20 or not sidc.is_valid_int():
			failures.append("%s -> %s" % [key, sidc])
	assert_eq(failures.size(), 0, "\n".join(failures.slice(0, 10)))
