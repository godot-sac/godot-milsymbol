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
