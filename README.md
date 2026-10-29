# godot-milsymbol

Military symbols (MIL-STD-2525 / APP-6) for Godot 4 — a GDScript port of
[milsymbol](https://github.com/spatialillusions/milsymbol).

> 🚧 Work in progress. See [PLAN.md](PLAN.md).

## Goals (v0.1.0)
- Number-based SIDCs (2525D/E) for land, air and sea surface units
- Friend / hostile / neutral / unknown frames and color modes
- Echelon, headquarters, task force and status modifiers
- `MilSymbolSprite2D` and `MilSymbolSprite3D` nodes
- Pure GDScript, no native dependencies

## Development
Requires Godot 4.7.x. Node.js is only needed for the data export tools in `tools/export/`.

```sh
# Run tests headless (GUT)
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd

# Inspect milsymbol output for a SIDC
cd tools/export && npm ci
node inspect.mjs 10031000141211000000
```

Notes on milsymbol internals: [docs/draw-instructions.md](docs/draw-instructions.md).

## License
MIT. Includes data derived from milsymbol (MIT) — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
