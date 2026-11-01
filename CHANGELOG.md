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

### Fixed
- Control measure point symbols (set 25) were reported invalid.
- Unknown `text-anchor` values are written as `start`, like milsymbol.
