# Changelog

All notable changes to this project are documented here. Versions follow [semver](https://semver.org/).

## [Unreleased]
### Added
- Number-based SIDC parsing (MIL-STD-2525D/E, APP-6D) and frames for every dimension, in all standard identities,
  colour modes, fill and outline styles.
- Icons for air, land unit, land equipment, sea surface, sea subsurface and space symbol sets, exported from
  milsymbol 3.0.5.
- Amplifiers and modifiers: echelon, headquarters, task force, feint / dummy, installation, mobility, condition,
  exercise / simulation marks; text labels drawn as outlines (Arimo glyphs).
- `MilSymbol.render`, `create_texture` with a cache, `MilSymbolStyle`, `MilSymbolSprite2D` and `MilSymbolSprite3D`.
- Golden tests against milsymbol output; demo scenes.
- Icons for every symbol set milsymbol supports in number based SIDCs: also 02, 06, 11, 20, 25 (control measure
  points), 27, 36, 40, 50-54 and 60.
- APP-6 icon and modifier variants (`standard: "APP6"`).
- Coverage test against the symbol lists of milsymbol's own test suite (2525D, 2525E, APP-6D; 6293 symbols, all
  identical to milsymbol) and the generated report `docs/coverage.md`.
- Multipoint control measures (symbol set 25 lines and areas): `MilGraphic.build()` turns a SIDC and control
  points into drawing primitives, `MilGraphicRenderer` draws them on a `CanvasItem` or writes SVG, `MilGraphic2D`
  node. Own geometry for boundary, phase line, LD, LD/LC, FLOT, fire support lines (FSCL, CFL, NFL, RFL), labelled
  areas (AO, NAI, TAI, AA, OBJ, EA), FFA / NFA / RFA (irregular, rectangular, circular; NFA hatched), Axis of
  Advance (main, supporting, aviation, attack helicopter), Direction of Attack, obstacle line / belt / zones,
  minefield and mined areas, MSR / ASR with traffic arrows, air corridor and minimum-risk route; every other
  line or area code of 2525D, 2525E and APP-6D is drawn as a generic line or area. Planned status, hostile "ENY",
  feint / dummy marks and APP-6D subtypes are handled.
- Control measure gallery demo (`demo/graphics_gallery.tscn`).

### Fixed
- Control measure point symbols (set 25) were reported invalid.
- Unknown `text-anchor` values are written as `start`, like milsymbol.
