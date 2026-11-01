// Exports milsymbol's icon data for number based SIDCs to addons/milsymbol/data/icons_<symbolset>.json.
// Usage: node icons.mjs [symbolSet ...]   (default: every set milsymbol supports; or: npm run icons)
//
// milsymbol builds icon parts at runtime from colors and symbol properties
// (src/iconparts/*.js), then maps entity codes to parts (src/numbersidc/sidc/*.js).
// We run that code for every combination of the properties that can change geometry
// (affiliation, frame, monoColor, edition, standard) with placeholder colors, then store each part once
// per distinct result. GDScript substitutes the placeholders at render time:
//   "@iconColor"         -> colors.iconColor[affiliation]
//   "@fillColor.Unknown" -> colors.fillColor.Unknown
//   "@mono"              -> style.monoColor
// See docs/draw-instructions.md §4.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ms from "milsymbol";

const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.resolve(here, "..", "..", "addons", "milsymbol", "data");
const pkg = JSON.parse(fs.readFileSync(path.join(here, "node_modules", "milsymbol", "package.json"), "utf8"));

const AFFILIATIONS = ["Unknown", "Friend", "Neutral", "Hostile"];
const COLOR_AFFILIATIONS = ["Civilian", "Friend", "Hostile", "Neutral", "Unknown", "Suspect"];
const COLOR_KEYS = ["fillColor", "frameColor", "iconColor", "iconFillColor", "none", "black", "white"];
const IDENTITY_DIGIT = { Unknown: "1", Friend: "3", Neutral: "4", Hostile: "6" };
const EDITION_VERSION = { D: "10", E: "13" };
const MONO_PLACEHOLDER = "@mono";
// Parts icon.js adds for entity subtypes 95-98, outside the SIDC tables.
const ALWAYS_PARTS = [
  "GR.IC.FF.HEADQUARTERS OR HEADQUARTERS ELEMENT",
  "GR.IC.FF.DIVISION AND BELOW SUPPORT",
  "GR.IC.FF.CORPS SUPPORT",
  "GR.IC.FF.THEATRE SUPPORT",
];

// Optional: outlines for text labels (Godot's SVG loader cannot draw <text>).
let textToPathD = null;
try {
  ({ textToPathD } = await import("./text-to-path.mjs"));
} catch {
  console.warn("icons: text-to-path.mjs not available, text labels are exported without outlines");
}

function placeholderColors() {
  const colors = {};
  for (const key of COLOR_KEYS) {
    colors[key] = {};
    for (const a of COLOR_AFFILIATIONS) colors[key][a] = `@${key}.${a}`;
  }
  return colors;
}

// Builds icon parts and SIDC tables for one combination of geometry-relevant properties.
// `app6`: milsymbol's APP-6 standard option (some icons and modifiers differ from 2525).
function build(symbolSet, affiliation, frame, mono, edition, app6) {
  const sidc = `${EDITION_VERSION[edition]}0${IDENTITY_DIGIT[affiliation]}${symbolSet}0000000000000000`;
  const options = { frame, monoColor: mono ? MONO_PLACEHOLDER : "" };
  if (app6) options.standard = "APP6";
  const symbol = new ms.Symbol(sidc, options);
  const metadata = symbol.metadata;
  const monoColor = mono ? MONO_PLACEHOLDER : "";
  const parts = ms._getIconParts(metadata, placeholderColors(), metadata.STD2525, monoColor, false);
  const tables = ms._getIcons.number(ms, symbolSet, parts, metadata.STD2525, metadata.edition);
  return { parts, tables, affiliation };
}

// Serializes a value, replacing known icon part objects by {"$ref": name}.
function makeSerializer(refs, affiliation) {
  const own = new RegExp(`^(@[A-Za-z]+)\\.${affiliation}$`);
  function ser(value, top = false) {
    if (value === undefined || value === null) return null;
    if (typeof value === "string") return value.replace(own, "$1");
    if (typeof value !== "object") return value;
    if (!top && refs.has(value)) return { $ref: refs.get(value) };
    if (Array.isArray(value)) return value.map((v) => ser(v));
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      if (k === "icon" || typeof v === "function" || v === undefined) continue;
      out[k] = ser(v);
    }
    if (out.type === "text" && textToPathD && typeof out.text === "string") {
      const d = textToPathD(out);
      if (d) out.d = d;
    }
    return out;
  }
  return ser;
}

function collectRefs(value, into) {
  if (value === null || typeof value !== "object") return;
  if (value.$ref !== undefined) {
    into.add(value.$ref);
    return;
  }
  for (const v of Array.isArray(value) ? value : Object.values(value)) collectRefs(v, into);
}

function exportSymbolSet(symbolSet) {
  const variants = [];
  // Variant key: affiliation|frame|mono|edition, plus "|A" for APP-6. Table key: edition, "A" + edition for APP-6.
  for (const app6 of [false, true])
    for (const edition of ["D", "E"])
      for (const affiliation of AFFILIATIONS)
        for (const frame of [true, false])
          for (const mono of [false, true])
            variants.push({
              key: `${affiliation}|${frame ? 1 : 0}|${mono ? 1 : 0}|${edition}${app6 ? "|A" : ""}`,
              table: `${app6 ? "A" : ""}${edition}`,
              ...build(symbolSet, affiliation, frame, mono, edition, app6),
            });

  // Tables: serialized per edition and standard; they must not depend on affiliation/frame/mono.
  const tables = {};
  for (const v of variants) {
    const refs = new Map();
    for (const [name, part] of Object.entries(v.parts)) if (part && typeof part === "object" && !refs.has(part)) refs.set(part, name);
    v.ser = makeSerializer(refs, v.affiliation);
    const t = { main: v.ser(v.tables.icons, true), m1: v.ser(v.tables.m1, true), m2: v.ser(v.tables.m2, true), bbox: v.tables.bbox };
    const json = JSON.stringify(t);
    if (!tables[v.table]) tables[v.table] = { t, json };
    else if (tables[v.table].json !== json) {
      throw new Error(`symbol set ${symbolSet}: tables differ between variants of table ${v.table} (${v.key})`);
    }
  }

  // Parts referenced by the tables, transitively.
  const needed = new Set();
  for (const { t } of Object.values(tables)) collectRefs(t, needed);
  for (const name of ALWAYS_PARTS) if (name in variants[0].parts) needed.add(name);
  const parts = {};
  const queue = [...needed];
  while (queue.length) {
    const name = queue.pop();
    const values = [];
    const byKey = {};
    for (const v of variants) {
      const serialized = v.ser(v.parts[name], true);
      const json = JSON.stringify(serialized);
      let index = values.findIndex((x) => x.json === json);
      if (index === -1) {
        index = values.length;
        values.push({ json, value: serialized });
        const inner = new Set();
        collectRefs(serialized, inner);
        for (const r of inner) if (!needed.has(r)) { needed.add(r); queue.push(r); }
      }
      byKey[v.key] = index;
    }
    parts[name] = values.length === 1 ? { value: values[0].value } : { values: values.map((x) => x.value), variants: byKey };
  }

  const sortedParts = Object.fromEntries(Object.entries(parts).sort(([a], [b]) => a.localeCompare(b)));
  // A table equal to an earlier one is stored as that table's key.
  const outTables = {};
  for (const key of ["D", "E", "AD", "AE"]) {
    const same = Object.keys(outTables).find((k) => typeof outTables[k] !== "string" && tables[k].json === tables[key].json);
    outTables[key] = same ?? tables[key].t;
  }
  const data = { milsymbol: pkg.version, symbolSet, tables: outTables, parts: sortedParts };
  const file = path.join(outDir, `icons_${symbolSet}.json`);
  fs.writeFileSync(file, JSON.stringify(data) + "\n");
  const variantCount = Object.values(parts).filter((p) => p.values).length;
  console.log(`icons_${symbolSet}.json: ${Object.keys(tables.D.t.main).length} entities, ${Object.keys(parts).length} parts (${variantCount} with variants), ${(fs.statSync(file).size / 1024).toFixed(0)} KB`);
}

fs.mkdirSync(outDir, { recursive: true });
const symbolSets = process.argv.slice(2).length ? process.argv.slice(2) : ["01", "02", "05", "06", "10", "11", "15", "20", "25", "27", "30", "35", "36", "40", "50", "51", "52", "53", "54", "60"];
for (const s of symbolSets) exportSymbolSet(s);
