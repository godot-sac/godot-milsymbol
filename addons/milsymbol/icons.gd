class_name MilSymbolIcons
extends RefCounted
## Loads exported icon data (data/icons_<symbolset>.json, written by tools/export/icons.mjs)
## and turns it into draw instructions with real colors.
##
## Parts that differ by affiliation / frame / monoColor / edition are stored as variants.
## Color values are placeholders ("@iconColor", "@fillColor.Unknown", "@mono") resolved here.

const DATA_DIR := "res://addons/milsymbol/data/"

static var _sets: Dictionary = {}  # symbol set -> parsed JSON, or {} when there is no file


## Context for resolving parts of one symbol.
class Context:
	var data: Dictionary
	var variant_key: String
	var affiliation: String
	var colors: Dictionary
	var mono_color: String
	var text_as_path: bool


## Returns the SIDC tables {main, m1, m2, bbox} for a symbol set and edition, or {} if none were exported.
static func get_tables(symbol_set: String, edition: String) -> Dictionary:
	var data := _load(symbol_set)
	if data.is_empty():
		return {}
	var tables: Dictionary = data.tables
	var entry = tables.get(edition, tables.D)
	if entry is String:
		entry = tables[entry]
	return entry


static func make_context(symbol_set: String, metadata: Dictionary, style: Dictionary,
		colors: Dictionary) -> Context:
	var context := Context.new()
	context.data = _load(symbol_set)
	context.affiliation = str(metadata.affiliation)
	context.variant_key = "%s|%d|%d|%s" % [context.affiliation, 1 if metadata.frame else 0,
			1 if style.monoColor != "" else 0, metadata.get("edition", "D")]
	context.colors = colors
	context.mono_color = style.monoColor
	context.text_as_path = style.textMode != "svg"
	return context


## Resolves a table entry (part references, inline instructions, nested arrays) into fresh
## draw instructions with colors applied. Missing parts become null, like undefined in milsymbol.
static func resolve(value: Variant, context: Context) -> Variant:
	if value is Array:
		var list: Array = []
		for item in value:
			list.append(resolve(item, context))
		return list
	if value is Dictionary:
		if value.has("$ref"):
			return resolve_part(value["$ref"], context)
		var out := {}
		for key in value:
			out[key] = resolve(value[key], context)
		if out.get("type") == "text" and out.has("d"):
			if context.text_as_path:
				return _text_to_path(out)
			out.erase("d")
		return out
	if value is String and value.begins_with("@"):
		return _color(value, context)
	return value


static func resolve_part(name: String, context: Context) -> Variant:
	var part: Dictionary = context.data.get("parts", {}).get(name, {})
	if part.is_empty():
		return null
	if part.has("value"):
		return resolve(part.value, context)
	var index: int = part.variants.get(context.variant_key, 0)
	return resolve(part["values"][index], context)


static func _color(placeholder: String, context: Context) -> Variant:
	if placeholder == "@mono":
		return context.mono_color
	var dot := placeholder.find(".")
	var key := placeholder.substr(1, dot - 1) if dot != -1 else placeholder.substr(1)
	var affiliation := placeholder.substr(dot + 1) if dot != -1 else context.affiliation
	var mode: Dictionary = context.colors.get(key, {})
	return mode.get(affiliation, false)


## Godot's SVG loader cannot draw <text>, so labels are drawn from outlines made at export time.
static func _text_to_path(text: Dictionary) -> Dictionary:
	var path := {"type": "path", "d": text.d}
	for key in ["fill", "stroke", "strokewidth", "fillopacity", "non_scaling_stroke", "cssClass", "clipPath"]:
		if text.has(key):
			path[key] = text[key]
	return path


static func _load(symbol_set: String) -> Dictionary:
	if _sets.has(symbol_set):
		return _sets[symbol_set]
	var file := DATA_DIR + "icons_%s.json" % symbol_set
	var data := {}
	if FileAccess.file_exists(file):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
		if parsed is Dictionary:
			data = parsed
		else:
			push_error("milsymbol: could not parse %s" % file)
	_sets[symbol_set] = data
	return data
