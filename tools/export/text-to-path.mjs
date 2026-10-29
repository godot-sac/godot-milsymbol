// Converts milsymbol "text" draw instructions into SVG path data (outlines),
// because Godot's SVG loader (ThorVG) cannot render <text> elements.
// Font: Arimo (metric-compatible with Arial), SIL OFL 1.1, via @fontsource/arimo.
import fs from "node:fs";
import { createRequire } from "node:module";
import opentype from "opentype.js";

const require = createRequire(import.meta.url);
const FONT_DIR = require.resolve("@fontsource/arimo/package.json").replace(/package\.json$/, "files/");

const cache = {};
function loadFont(bold) {
  const key = bold ? "bold" : "regular";
  if (!cache[key]) {
    const buf = fs.readFileSync(FONT_DIR + `arimo-latin-${bold ? 700 : 400}-normal.woff`);
    cache[key] = opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
  }
  return cache[key];
}

/** Font metrics in font units (exposed for reporting/debugging). */
export function fontMetrics(bold = false) {
  const f = loadFont(bold);
  const os2 = f.tables.os2 || {};
  return {
    unitsPerEm: f.unitsPerEm,
    ascender: f.ascender,
    descender: f.descender,
    xHeight: os2.sxHeight || 0,
    capHeight: os2.sCapHeight || 0,
  };
}

/**
 * Returns an SVG path "d" string outlining `instr.text` the way a browser would draw
 * <text x y font-size text-anchor dominant-baseline font-weight>.
 */
export function textToPathD(instr) {
  const text = instr.text == null ? "" : String(instr.text);
  if (!text.trim()) return "";
  const size = instr.fontsize || 12;
  const font = loadFont(instr.fontweight === "bold");
  const m = fontMetrics(instr.fontweight === "bold");
  const scale = size / font.unitsPerEm;

  // Horizontal: advance width including kerning.
  const width = font.getAdvanceWidth(text, size, { kerning: true });
  let x = instr.x || 0;
  if (instr.textanchor === "middle") x -= width / 2;
  else if (instr.textanchor === "end") x -= width;

  // Vertical: map dominant-baseline to a baseline y.
  const xHeight = m.xHeight || (m.capHeight ? m.capHeight / 2 : m.unitsPerEm * 0.26);
  let y = instr.y || 0;
  switch (instr.alignmentBaseline) {
    case "middle": y += (xHeight * scale) / 2; break;           // baseline + 0.5 * x-height
    case "central": y += ((m.ascender + m.descender) * scale) / 2; break; // descender is negative
    case "hanging":
    case "text-before-edge":
    case "text-top": y += m.ascender * scale; break;            // approximation: top = ascender
    default: break;                                             // alphabetic / auto / undefined
  }
  return font.getPath(text, x, y, size, { kerning: true }).toPathData(2);
}
