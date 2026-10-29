# milsymbol draw instruction format

Notes from reading milsymbol **3.0.5** (`tools/export/node_modules/milsymbol/src/`).
milsymbol does not draw directly. Every symbol part produces a tree of plain JS objects
("draw instructions"), and two back ends turn that tree into output:
`src/ms/symbol/assvg.js` (SVG string) and `src/ms/symbol/canvasdraw.js` (Canvas 2D).
Our GDScript renderer is a third back end that must match `asSVG()`.

Use `node tools/export/inspect.mjs <sidc> ['{"size":80}']` to dump metadata, bbox,
draw instructions and SVG for any SIDC.

## 1. Pipeline

```
new ms.Symbol(sidc, options)
  └─ setOptions()                         src/ms/symbol/setoptions.js
       ├─ getMetadata()                   decode SIDC → metadata (affiliation, dimension, echelon, …)
       ├─ getColors()                     colorMode + affiliation → fill/frame/icon colors
       ├─ for each symbol part (in order):
       │    stack, basegeometry, icon, modifier, statusmodifier,
       │    engagmentbar, affliationdimension, textfields, directionarrow
       │    → { pre: [...], post: [...], bbox }
       │    pre  is PREPENDED to drawInstructions (drawn first, e.g. outlines)
       │    post is APPENDED  to drawInstructions
       │    bbox is merged into symbol.bbox (only if pre/post not empty)
       ├─ padding / square adjustments to bbox
       └─ width, height, anchor computed from bbox
asSVG()                                   src/ms/symbol/assvg.js
  └─ processInstructions(drawInstructions) → "<svg …>…</svg>"
```

Symbol parts live in `src/symbolfunctions/`:

| File | Responsibility |
|---|---|
| `stack-extension.js` | Stacked frames (multiple units) |
| `basegeometry.js` | Frame from `ms._symbolGeometries` (+ space/activity/cyberspace marks, dashed "not present" overlay) |
| `icon.js` | Main icon + modifier 1 / modifier 2 from `iconparts/*`, scaling for some dimensions |
| `modifier.js` (+ `modifier-echelon-json.js`) | Echelon, HQ staff, task force, feint/dummy, mobility |
| `statusmodifier.js` | Operational condition bar / slash |
| `textfields.js` | Text amplifiers around the frame |
| `directionarrow.js` | Direction of movement arrow, speed leader |

## 2. Coordinate system

- Everything is drawn in a fixed **200 × 200 unit space** with the octagon centre at **(100, 100)**.
  Ground friend frame is `M25,50 l150,0 0,100 -150,0 z` (150 × 100).
- `style.size` (default 100) is the size of `L`, so 1 unit = `size / 100` pixels.
- The bbox starts as `{x1:100, y1:100, x2:100, y2:100}` and grows by merging each part's bbox.
- Final SVG:
  ```
  pad      = strokeWidth + outlineWidth
  viewBox  = (bbox.x1 - pad) (bbox.y1 - pad) (bbox.width + 2*pad) (bbox.height + 2*pad)
  width    = viewBox.w * size / 100
  height   = viewBox.h * size / 100
  ```
- `getAnchor()`: pixel position of (100, 100) inside the image; for HQ symbols it is the end of the staff
  `(baseGeometry.bbox.x1, baseGeometry.bbox.y2 + hqStaffLength)`. Needed for placing sprites on a map.

## 3. Instruction tree

`drawInstructions` is an array. Each element is either:

- a nested **array** → processed recursively (empty arrays are skipped), or
- an **object** with a `type`.

`undefined` entries can appear in the tree on purpose (`isValid()` uses them to detect missing icons);
the SVG writer ignores anything that is not an object or array.

### Shape types

| `type` | Fields | SVG output |
|---|---|---|
| `path` | `d` | `<path d="…">` |
| `circle` | `cx`, `cy`, `r` | `<circle cx cy r>` |
| `text` | `x`, `y`, `text`, `fontsize` (12), `fontfamily` ("sans-serif"), `fontweight`, `textanchor` ("start"), `alignmentBaseline` | `<text x y text-anchor font-size font-family [font-weight] [dominant-baseline]>text</text>` |
| `svg` | `svg` (raw string) | Fragment inserted as-is (blocklist: script, foreignObject, `on*=` …) |

### Container types (have a `draw` array of children)

| `type` | Fields | SVG output |
|---|---|---|
| `translate` | `x`, `y`, `draw` | `<g transform="translate(x,y)">…</g>` |
| `rotate` | `degree`, `x`, `y`, `draw` | `<g transform="rotate(degree,x,y)">…</g>` |
| `scale` | `factor`, `draw` | `<g transform="scale(factor)">…</g>` |
| `clip` | `d`, `clipId?`, `draw` | `<clipPath id><path d clip-rule="nonzero"/></clipPath><g clip-path="url(#id)">…</g>` |

Any non-`clip` instruction may also have `clipPath: "<d>"`; the writer then emits an inline
`<clipPath id="clip-inline-N">` before the element and adds `clip-path="url(#clip-inline-N)"`.

Helpers in `src/ms.js`:
- `ms._translate(x, y, instr)` → `{type:"translate", x, y, draw:[instr]}`
- `ms._scale(f, instr, nonScalingStroke)` → translate(100-100f, 100-100f) › scale(f) › instr, i.e. scale around (100,100).
  With `nonScalingStroke`, every child gets `non_scaling_stroke = 1/f` so lines keep their width.

### Style fields (any type)

| Field | Meaning in `asSVG()` |
|---|---|
| `stroke` | If the key is **present**: emits `stroke-width`, optional `stroke-dasharray`, optional linecap/linejoin, then `stroke` (`false`/`""` → `"none"`). If the key is **absent**, none of these are written (inherited from parent `<g>`). |
| `strokewidth` | Width; default `style.strokeWidth` (4). Final value = `non_scaling_stroke * strokewidth`. Only written when `stroke` key exists. |
| `non_scaling_stroke` | Multiplier set by `ms._scale` (default 1). |
| `strokedasharray` | e.g. `"4,4"` (pending/planned), `"8,12"` (anticipated), `"8,8"` (feint/dummy). Validated against `/^[0-9.,\s-]+$/`. |
| `linecap` | `butt`/`round`/`square`; written as **both** `stroke-linecap` and `stroke-linejoin`. |
| `fill` | If key present: color, or `false` → `"none"`. `styleFill && style.styleFill` → `rgba(255,255,255,0.4)`. |
| `fillopacity` | Clamped to [0,1], `fill-opacity`. |
| `cssClass` | `class` attribute (e.g. `milsymbol-echelon`, `milsymbol-headquarters`, `milsymbol-textfields`). |
| `icon` | Internal marker set by `defaultProperties()` on icon parts. Not rendered. |

**Attribute order** (matters for golden-test normalisation, though we should compare parsed attributes):
element-specific attrs → `clip-path` → `stroke-width` → `stroke-dasharray` → `stroke-linecap` →
`stroke-linejoin` → `stroke` → `fill` → `fill-opacity` → `class`. Every element is written as
`<tag … ></tag>` (space before `>`, explicit close tag). Numbers are JS `String(Number)` output,
e.g. `203.16666666666663`.

## 4. Icon data (`src/iconparts/*`, `src/numbersidc/*`)

Two layers:

1. **Icon parts** (`src/iconparts/ground.js`, `air.js`, `sea.js`, …). Each file exports a function
   `(icn, metadata, colors, STD2525, monoColor, alternateMedal)` that fills `icn` with named parts:
   ```js
   icn["GR.IC.MILITARY"] = text("MIL");
   icn["GR.IC.FERRY"] = [ {type:"path", fill: STD2525 ? iconFillColor : …, d:"…"}, {type:"text", …} ];
   ```
   Parts are **computed**, not static: colors, frame on/off, 2525 vs APP6 and affiliation change the result.
   After the function runs, `defaultProperties()` fills missing `fill`/`stroke` with `iconColor`,
   `strokewidth` with 3, and text defaults (`Arial`, `bold`, `middle`, no stroke).
   Text helpers in `iconparts-functions.js`: `text(str)` (y=103, size 45/39/33 by length),
   `textm1(str)` (y=71), `textm2(str)` (y=134).

2. **SIDC → parts mapping** (`src/numbersidc/sidc/landunit.js`, `air.js`, `sea.js`, …).
   Keyed by the 6-digit entity code (SIDC chars 11–16), separate tables for modifier 1/2 and special bboxes:
   ```js
   if (symbolSet == "10") {
     sId["121100"] = [icn["GR.IC.INFANTRY"]];
     sId["110501"] = [icn["GR.IC.LIAISON"], icn["GR.IC.FF.RECONNAISSANCE"]];
   }
   ```
   Some entries wrap parts with `ms._scale` / `ms._translate`.

**Export implication (Phase 3):** because parts depend on colors and options, the exporter should run
the icon functions with **placeholder colors** (e.g. `"@icon"`, `"@iconFill"`, `"@white"`, `"@black"`,
`"@none"`) and let GDScript substitute real colors at render time. Variants that change geometry
(STD2525 vs APP6, `frame`, `alternateMedal`) must be exported separately or limited to the defaults we support.

Raw instruction counts in `src/` (rough, regex based): ~1250 `path`, ~490 `text`, ~190 `circle`,
10 `translate`, 1 `scale`, 1 `rotate`; `svg`/`clip` appear mostly in letter-SIDC and equipment tables.

## 5. Colors (`src/colormodes.js`, `src/ms/symbol/getcolors.js`)

Color modes per affiliation (Civilian, Friend, Hostile, Neutral, Unknown, Suspect):
`Light` (default fill), `Medium`, `Dark`, plus helper modes `FrameColor`, `IconColor`, `Black`, `White`,
`OffWhite`, `None`. In the default filled style the frame stroke and icon are **black** and the frame fill
is the `Light` color, e.g. Friend `rgb(128,224,255)`, Hostile `rgb(255,128,128)`.
With `fill: false` / `monoColor` the frame and icon take the affiliation color instead.

## 6. Things that need care in the port

- **Outlines** (`style.outlineWidth > 0`): `ms.outline()` produces a wider stroke-only copy of the frame /
  text in the `pre` list (drawn underneath). Frame outline path gets an extra `" Z"`.
- **Not present (planned/anticipated):** an extra white dashed copy of the frame is drawn on top
  (`strokewidth + 1`, `strokedasharray = metadata.notpresent`).
- **Text**: depends on fonts. ThorVG in Godot may not render SVG `<text>` without an embedded font.
  Test early (Phase 2); fall back to drawing text with Godot `Font` / `Label` if needed.
- **Package entry**: `import ms from "milsymbol"` returns `ms` with all icon sets registered.
  The package `exports` map does **not** expose `src/…` subpaths, so the Phase 3 exporter must import
  internal modules by file path (`./node_modules/milsymbol/src/iconparts/ground.js`). The version is pinned
  (`3.0.5`) because this is not public API.

## 7. Example (`10031000141211000000`, friendly infantry platoon)

```json
[
  {"type":"path","d":"M25,50 l150,0 0,100 -150,0 z","fill":"rgb(128,224,255)","fillopacity":1,"stroke":"black","strokewidth":4},
  {"type":"path","d":"M25,50 L175,150 M25,150 L175,50","icon":true,"fill":"black","stroke":"black","strokewidth":3},
  {"type":"translate","x":0,"y":50,"fill":false,"stroke":"black","strokewidth":4,"draw":[
    {"type":"circle","cx":100,"cy":-20,"r":7.5,"fill":"black","cssClass":"milsymbol-echelon milsymbol-echelon-fill"},
    {"type":"circle","cx":70, "cy":-20,"r":7.5,"fill":"black","cssClass":"milsymbol-echelon milsymbol-echelon-fill"},
    {"type":"circle","cx":130,"cy":-20,"r":7.5,"fill":"black","cssClass":"milsymbol-echelon milsymbol-echelon-fill"}
  ]}
]
```

```xml
<svg xmlns="http://www.w3.org/2000/svg" version="1.2" baseProfile="tiny" width="158" height="135.5" viewBox="21 18.5 158 135.5">
  <path d="M25,50 l150,0 0,100 -150,0 z" stroke-width="4" stroke="black" fill="rgb(128,224,255)" fill-opacity="1" ></path>
  <path d="M25,50 L175,150 M25,150 L175,50" stroke-width="3" stroke="black" fill="black" ></path>
  <g transform="translate(0,50)" stroke-width="4" stroke="black" fill="none" >
    <circle cx="100" cy="-20" r="7.5" fill="black" class="milsymbol-echelon milsymbol-echelon-fill" ></circle>
    …
  </g>
</svg>
```
bbox `{x1:25, y1:22.5, x2:175, y2:150}` (echelon dots raise y1 above the frame), anchor `(79, 81.5)`.

## 7b. Known milsymbol 3.0.5 quirks

- `modifier.js` writes `fill = color` into the shared echelon objects from `modifier-echelon-json.js`, so the
  first echelon symbol's color sticks for the rest of the process. Golden scripts reset them
  (`tools/export/milsymbol-fresh.mjs`); the port builds fresh instructions every time.
- The echelon outline is translated by `-installationPadding` instead of `bbox.y1 - installationPadding`, so it is
  drawn far above the frame. Kept as-is for parity.
- `modifier.js` checks `metadata.dimensionType + metadata.affiliationType == "SubsurfaceFriend"`; those keys never
  exist, so that branch is dead. Not ported.

## 8. Exported icon data (`addons/milsymbol/data/icons_<symbolset>.json`)

Written by `tools/export/icons.mjs`, read by `addons/milsymbol/icons.gd`.

```jsonc
{
  "milsymbol": "3.0.5",
  "symbolSet": "10",
  "tables": {
    "D": {
      "main": { "121100": [{ "$ref": "GR.IC.FF.INFANTRY" }], ... },   // entity code -> instructions
      "m1":   { "01": [...] }, "m2": { ... },                          // modifier 1 / 2 codes
      "bbox": { "<entity>": { "x1": .., "y1": .., "x2": .., "y2": .. } } // icons that extend the bbox
    },
    "E": "D"            // or a full table when 2525E differs
  },
  "parts": {
    "GR.IC.MILITARY": { "value": <instructions> },                    // same for every variant
    "GR.IC.FF.INFANTRY": {                                            // differs by variant
      "values": [<instructions>, <instructions>],
      "variants": { "Friend|1|0|D": 1, "Unknown|1|0|D": 0, ... }      // affiliation|frame|mono|edition -> index
    }
  }
}
```

- Instructions use the format of §3. `{"$ref": name}` points to another part.
- Colors are placeholders: `"@iconColor"` = `colors.iconColor[affiliation]`, `"@fillColor.Unknown"` =
  `colors.fillColor.Unknown`, `"@mono"` = `style.monoColor`. `@none` resolves to `false` (no paint).
- Text instructions carry an extra `"d"`: the label outlined with Arimo (`tools/export/text-to-path.mjs`).
  With `textMode: "path"` (default) the renderer draws that path, because Godot's SVG loader ignores `<text>`.
