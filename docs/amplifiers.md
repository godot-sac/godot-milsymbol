# Text amplifiers and direction of movement

Point symbols can carry text fields around the frame (unique designation, higher formation, speed, ...) and a
direction of movement indicator or speed leader. They are passed as options, like every other milsymbol option:

```gdscript
var texture := MilSymbol.create_texture("10031000001211000000", {
	"size": 60,
	"uniqueDesignation": "A/1-32",
	"higherFormation": "3 BDE",
	"speed": "15 KPH",
	"direction": 45.0,
})

# Nodes: one Dictionary per symbol, merged over the shared MilSymbolStyle.
$Unit.amplifiers = {"uniqueDesignation": "A/1-32", "direction": 45.0}

# TacticalMap2D: per unit.
map.set_unit_amplifiers("A", {"uniqueDesignation": "A/1-32", "higherFormation": "3 BDE"})
```

The layout is a port of milsymbol 3.0.5 (`textfields.js`, `directionarrow.js`) and is checked against milsymbol's
output in the golden tests (`tests/golden/tf_*.svg`, `dir_*.svg`): the same rows, positions, symbol size and
anchor. Values are strings; numbers are accepted and written without a trailing `.0`. Empty strings, `0`, `false`
and `null` count as not set.

## Fields
Field IDs are the MIL-STD-2525D amplifier letters. Where a field is drawn depends on the symbol's dimension:
**L1–L5** are the rows left of the frame (top to bottom), **R1–R5** the rows right of it. Several options in one
row are joined with `/`.

| Option | Field | Land unit | Land equipment / installation | Dismounted individual | Air / space | Sea surface | Subsurface |
|---|---|---|---|---|---|---|---|
| `quantity` | C | above | above | below | – | – | – |
| `reinforcedReduced` | F | R1 | – | – | – | – | – |
| `staffComments` | G | R2 | R2 | R2 | R5 | R4 | R4 |
| `additionalInformation` | H | R3 | R3 | R3 | R5 | R4 | R5 |
| `evaluationRating` | J | R5 | R5 | R5 | – | – | – |
| `combatEffectiveness` | K | R5 | R5 | R5 | – | – | – |
| `signatureEquipment` | L | R5 | R5 | R5 | – | – | – |
| `higherFormation` | M | R4 | R4 | R4 | – | – | – |
| `hostile` | N | R5 | R5 | R5 | – | – | – |
| `iffSif` | P | R5 | R5 | R5 | R2 | R3 | – |
| `uniqueDesignation` | T | L4 | L4 | L4 | R1 | R1 | R1 |
| `type` | V | L3 | L3 | L3 | R3 | R2 | R2 |
| `dtg` | W | L1 | L1 | L1 | – | – | – |
| `altitudeDepth` | X | L2 | L2 | L2 | R4 | – | R3 |
| `location` | Y | L2 | L2 | L2 | – | R5 | – |
| `speed` | Z | L5 | L5 | L5 | R4 | R5 | – |
| `platformType` | AD | L3 | L3 | L3 | – | – | – |
| `equipmentTeardownTime` | AE | L3 | R3 | – | – | – | – |
| `commonIdentifier` | AF | R3 | L3 | L3 | – | – | – |
| `installationComposition` | AI | – | L3 | – | – | – | – |
| `country` | AS | R1 (activities) | R1 | R1 | – | – | – |
| `guardedUnit` | AQ | – | – | – | – | L1 | – |
| `specialDesignator` | AR | – | – | – | – | L1 | L1 |
| `headquartersElement` | AH | below the frame, bold | | | | | |
| `specialHeadquarters` | AA | inside the frame, bold | | | | | |

Letter based 2525C SIDCs are laid out like land symbols, as milsymbol does.

## Direction of movement
- `direction`: degrees clockwise from north (field Q). Ground symbols get an arrow on a staff below the frame
  (headquarters: from the foot of the staff); air, sea and space symbols an arrow from the centre.
- `speedLeader`: with a value other than 0, a plain line from the centre of that length in pixels at the
  symbol's `size` (field AJ) instead of the arrow.

The arrow is drawn in the icon colour and gets the symbol's outline (`outlineWidth`).

## Style options
| Option | Default | |
|---|---|---|
| `infoFields` | `true` | `false` hides all text fields and the direction indicator |
| `infoSize` | `40` | font size in symbol units (the frame is about 150 wide) |
| `infoColor` | icon colour | text colour; a String or a Dictionary by affiliation (`{"Friend": ..., "Hostile": ...}`) |
| `infoBackground` | none | colour of boxes behind the left and right rows |
| `infoOutlineWidth` | `outlineWidth` | outline around the text; `false` uses `outlineWidth` |
| `infoOutlineColor` | `rgb(239, 239, 239)` | |

## Notes
- In the default `textMode: "path"` the text is drawn as outlines from the bundled Arimo glyphs (Godot's SVG loader
  has no text support). The glyphs cover printable ASCII and the Turkish letters; other characters take
  room but are not drawn (use `textMode: "svg"` and your own renderer for other scripts). The room reserved for a string
  uses milsymbol's per-character width table, not the font, so very wide or unknown characters can extend a little
  past the symbol bounds, exactly as in milsymbol.
- Every distinct set of fields is a separate render and texture. On a `TacticalMap2D` each one also takes space in
  the map's atlas, which is not trimmed while the map exists: set fields that change rarely, and do not put a
  heading that changes every frame into `direction`.
- Not ported: country flags, the engagement bar (AO), stack extension and label overrides for control measures
  (milsymbol's optional extension packages).
