# Roadmap

## Status
0.1.0 is the first release. Point symbols cover every symbol set milsymbol 3.0.5 supports (MIL-STD-2525D/E,
APP-6D) and match milsymbol's output on its own test lists; multipoint control measures, `TacticalMap2D`, the
symbol nodes, 2525C letter SIDC conversion and SVG / PNG export are in place. Tested with Godot 4.7.2 on
Windows and Linux ([compatibility](docs/compatibility.md)).

## Next (0.2)
- Text amplifier fields around point symbols (unique designation, higher formation, speed, ...) and the
  direction of movement arrow.
- Own geometry for more multipoint control measures (today 76 of 271 2525D codes; the rest are drawn as a
  generic line or area): mission task graphics, remaining fire support and protection graphics.
- Run CI on GitHub (Windows and Linux) and keep the compatibility table up to date from it.
- Try Godot 4.3–4.6 and the Compatibility / Mobile renderers; macOS.
- Submit the add-on to the Godot Asset Library.

## Later
- Meteorological and oceanographic symbol sets (45–47).
- Maritime multipoint graphics beyond the generic depiction.
- APP-6(E) verification once an openly licensed APP-6(E) table is available.
- Letter based APP-6A/B and 2525B SIDCs that 2525C did not keep.
- Background layers for `TacticalMap2D` (raster tiles or imagery under the symbols) as an optional helper.

## Not planned
- A web viewer (milsymbol itself covers that).
- Anything based on GPL / AGPL / non-commercial sources or on standards documents that are not public.

Suggestions and use cases are welcome as issues; they decide the order of the items above.
