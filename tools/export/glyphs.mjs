// Exports Arimo glyph outlines, advances and kerning to addons/milsymbol/data/glyphs.json
// so GDScript can lay out text at render time (see addons/milsymbol/text_layout.gd).
// Font: Arimo, SIL OFL 1.1, via @fontsource/arimo.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";
import opentype from "opentype.js";

const require = createRequire(import.meta.url);
const FONT_DIR = require.resolve("@fontsource/arimo/package.json").replace(/package\.json$/, "files/");
const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../addons/milsymbol/data/glyphs.json");

const EXTRA = ["°", "±", "Ç", "Ğ", "İ", "Ö", "Ş", "Ü", "ç", "ğ", "ı", "ö", "ş", "ü"];
const CHARS = [];
for (let c = 32; c <= 126; c++) CHARS.push(String.fromCharCode(c));
CHARS.push(...EXTRA);

function load(file) {
  const buf = fs.readFileSync(FONT_DIR + file);
  return opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
}

function exportFont(weight) {
  const base = load(`arimo-latin-${weight}-normal.woff`);
  const ext = load(`arimo-latin-ext-${weight}-normal.woff`);
  const os2 = base.tables.os2 || {};
  const out = {
    unitsPerEm: base.unitsPerEm, ascender: base.ascender, descender: base.descender,
    xHeight: os2.sxHeight || 0, capHeight: os2.sCapHeight || 0, glyphs: {}, kerning: {},
  };
  const src = {};
  for (const ch of CHARS) {
    // Prefer the latin subset; fall back to latin-ext for glyphs it lacks.
    let font = null;
    for (const f of [base, ext]) {
      const g = f.charToGlyph(ch);
      if (g && g.index !== 0 && f.unitsPerEm === base.unitsPerEm) { font = f; break; }
    }
    if (!font) { console.warn(`missing ${weight} ${ch}`); continue; }
    const glyph = font.charToGlyph(ch);
    const d = ch === " " ? "" : glyph.getPath(0, 0, base.unitsPerEm).toPathData(1);
    out.glyphs[ch] = { advance: glyph.advanceWidth, d };
    src[ch] = font;
  }
  const chars = Object.keys(out.glyphs);
  for (const a of chars) for (const b of chars) {
    const font = src[a] === src[b] ? src[a] : base;
    const k = font.getKerningValue(font.charToGlyph(a), font.charToGlyph(b));
    if (k) out.kerning[a + b] = k;
  }
  return out;
}

const result = { regular: exportFont(400), bold: exportFont(700) };
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(result));
for (const k of ["regular", "bold"]) {
  console.log(k, Object.keys(result[k].glyphs).length, "glyphs,", Object.keys(result[k].kerning).length, "kerning pairs");
}
console.log(OUT, fs.statSync(OUT).size, "bytes");
