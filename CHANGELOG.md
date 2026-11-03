# Changelog

All notable changes to this project are documented here. Versions follow [semver](https://semver.org/).

## [0.1.0] - Unreleased
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
- `TacticalMap2D`: reusable 2D tactical map control (Web Mercator, latitude/longitude grid, scale bar, pan and
  zoom at the cursor, named layers, click / Shift-click / box selection, unit labels, control measures with
  distances in metres). The plane origin follows the view, so it works anywhere on Earth and across the
  antimeridian. Unit symbols are packed into a `MilSymbolAtlas` texture and drawn with one MultiMesh per
  layer: 20,000 static units cost 0.33 ms per frame, 5,000 units moving every frame 8.6 ms (RTX 4080, Windows).
- Letter based MIL-STD-2525C SIDCs: `MilSymbolLegacy` converts them to 2525D using Esri's
  joint-military-symbology-xml mapping table (Apache-2.0); `MilSymbol.render()` and `MilGraphic.build()` accept
  them directly.
- `MilSymbolTextureRect`: a symbol as a UI control.
- `MilSymbol.save_svg()` / `save_png()`, `MilGraphicRenderer.to_image()` / `save_svg()` / `save_png()`; control
  measure labels are written as glyph outlines in PNG output.
- Tactical map demo (`demo/tactical_map.tscn`, first tab of `demo/main.tscn`): a fictional brigade attack with
  units, control measures, debug keys and a 5,000-unit stress test (`-- --stress 5000`).
- Release zip: `tools/package_addon.py` packs `addons/milsymbol/` with the licence and notices
  (Asset Library layout), `tools/check_package.py` installs it into a new, empty project and uses it there.
  CI checks the zip on every push and attaches it to the GitHub release of a `v*` tag.
- `docs/getting-started.md`: from an empty project to a tactical map with units and control measures.
- `docs/compatibility.md`: Godot versions and platforms that were actually tested.
- Add-on icon (`icon.svg`, `docs/images/icon-256.png`); `tools/capture_media.py` makes the README GIF, the social
  preview image and the icon PNG (`docs/media.md`).

### Fixed
- Control measure point symbols (set 25) were reported invalid.
- Unknown `text-anchor` values are written as `start`, like milsymbol.
