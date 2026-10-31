# godot-milsymbol

Military symbols (MIL-STD-2525 / APP-6) for Godot 4 — a GDScript port of
[milsymbol](https://github.com/spatialillusions/milsymbol).

> 🚧 Work in progress, not released yet. See [PLAN.md](PLAN.md).

![Icon browser demo](docs/images/phase4-modifiers.png)

## Features
- Number-based SIDCs (2525D/E, APP-6D) for air (01), land unit (10) and sea surface (30) icons;
  frames for every dimension
- Friend / hostile / neutral / unknown / pending / suspect frames, Light / Medium / Dark color modes,
  unfilled, mono color and outline styles
- Echelon, headquarters, task force, feint/dummy, installation, mobility, condition and
  exercise / simulation amplifiers
- `MilSymbolSprite2D` and `MilSymbolSprite3D` nodes with live preview in the editor
- Pure GDScript, no native dependencies
- Output checked against milsymbol 3.0.5 for ~3000 symbols

## Usage
Copy `addons/milsymbol/` into your project. Enabling the plugin is optional; the classes are global.

### Nodes
Add a **MilSymbolSprite2D** (or **MilSymbolSprite3D**) node and set `sidc` in the inspector.
The node's position is the symbol's anchor point (frame centre, or the foot of the staff for
headquarters), so put the node where the unit is.

```gdscript
var unit := MilSymbolSprite2D.new()
unit.sidc = "10031002161211000000"  # friendly infantry battalion HQ
unit.symbol_size = 60
unit.position = Vector2(400, 300)
add_child(unit)
```

Share a **MilSymbolStyle** resource between many symbols to change color mode, fill, outline etc.
for all of them at once.

### Textures
```gdscript
var texture := MilSymbol.create_texture("10061000001211000000", {"size": 80, "colorMode": "Dark"})
var render := MilSymbol.render("10061000001211000000")  # svg, size, anchor, metadata, valid
```
Option names follow milsymbol (`size`, `colorMode`, `fill`, `frame`, `monoColor`, `outlineWidth`,
`hqStaffLength`, ...). `create_texture` and `render_cached` cache results.

### Text
Godot's SVG loader does not draw `<text>`. Labels are drawn as outlines from the bundled Arimo glyph
data (`textMode: "path"`, default). `textMode: "svg"` writes `<text>` like milsymbol, for use outside Godot.

## Demo
Open the project and press F5: tabs for frames, an icon browser, and 2D / 3D tactical maps.

## Development
Requires Godot 4.7.x. Node.js is only needed for the data export tools in `tools/export/`.

```sh
# Run tests headless (GUT)
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd

# Regenerate data and reference SVGs from milsymbol
cd tools/export && npm ci
npm run data && npm run icons && npm run glyphs
npm run golden && npm run golden:bulk

# Inspect milsymbol output for a SIDC
node inspect.mjs 10031000141211000000
```

Notes on milsymbol internals: [docs/draw-instructions.md](docs/draw-instructions.md).

## Contributing
Bug reports, questions and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[code of conduct](CODE_OF_CONDUCT.md).

## License
MIT. Includes data derived from milsymbol (MIT) and glyph outlines from the Arimo font (OFL 1.1) —
see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
