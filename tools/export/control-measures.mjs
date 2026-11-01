// Exports the multipoint control measure table (symbol set 25 lines, areas, axes and corridors) to
// addons/milsymbol/data/control_measures.json, from the standards data packages mil-std-2525 (2525D),
// milstandard-e (2525E) and stanag-app6 (APP-6D), all MIT. Point control measures are drawn by the icon
// renderer (icons_25.json) and are not listed here.
// Output: {"<code>": {"name": "...", "D": "line", "E": "axis", "A": "area"}, ...}; a missing key means that
// standard has no multipoint symbol with this code.
// Usage: node control-measures.mjs   (or: npm run control-measures)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { ms2525d } from "mil-std-2525";
import { ms2525e } from "milstandard-e";
import { app6d } from "stanag-app6";

const here = path.dirname(fileURLToPath(import.meta.url));
const outFile = path.resolve(here, "..", "..", "addons", "milsymbol", "data", "control_measures.json");
const GEOMETRIES = { Line: "line", Area: "area", Axis: "axis", Corridor: "corridor" };

const table = {};
for (const [key, data] of [["D", ms2525d], ["E", ms2525e], ["A", app6d]]) {
  for (const icon of data["25"].mainIcon) {
    const geometry = GEOMETRIES[(icon["Geometric Rendering"] || "").trim()];
    if (!geometry || !/^\d{6}$/.test(icon.Code)) continue;
    const name = [icon.Entity, icon["Entity Type"], icon["Entity Subtype"]].map((s) => (s || "").trim()).filter(Boolean).join(" / ");
    table[icon.Code] ??= { name };
    table[icon.Code][key] = geometry;
  }
}
const sorted = Object.fromEntries(Object.entries(table).sort(([a], [b]) => a.localeCompare(b)));
fs.writeFileSync(outFile, JSON.stringify(sorted, null, 0).replace(/\},"/g, '},\n"') + "\n");
console.log(`control_measures.json: ${Object.keys(sorted).length} multipoint control measures`);
