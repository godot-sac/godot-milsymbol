// Generates tests/golden/coverage.json: the symbol lists of milsymbol's own test suite, rendered by milsymbol.
// milsymbol's test/number-sidc.js walks every point main icon, modifier 1 and modifier 2 in the standards data
// packages (mil-std-2525 for 2525D, milstandard-e for 2525E, stanag-app6 for APP-6D; all MIT, same author)
// and checks that milsymbol can draw it. We build the same SIDCs here; test_coverage.gd checks that our
// renderer gives the same SVG, size, anchor and validity, and tools/coverage_report.gd writes docs/coverage.md.
// Differences from milsymbol's test: 2525E SIDCs use version 13 (milsymbol's test uses 10 for all
// standards), so that the 2525E icon tables are the ones exercised.
// Usage: node coverage.mjs   (or: npm run coverage)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ms from "milsymbol";
import { ms2525d } from "mil-std-2525";
import { ms2525e } from "milstandard-e";
import { app6d } from "stanag-app6";
import { resetEchelons, resetIconCache } from "./milsymbol-fresh.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const outFile = path.resolve(here, "..", "..", "tests", "golden", "coverage.json");

const STANDARDS = [
  { name: "2525D", data: ms2525d, version: "10", options: {} },
  { name: "2525E", data: ms2525e, version: "13", options: {} },
  { name: "APP-6D", data: app6d, version: "10", options: { standard: "APP6" } },
];

const entries = [];
function add(standard, symbolSet, kind, code, name, sidc) {
  resetEchelons();
  resetIconCache(ms);
  const symbol = new ms.Symbol(sidc, standard.options);
  const size = symbol.getSize();
  const anchor = symbol.getAnchor();
  entries.push({
    standard: standard.name, set: symbolSet, kind, code, name, sidc, options: standard.options,
    valid: symbol.isValid(), width: size.width, height: size.height, anchor: { x: anchor.x, y: anchor.y },
    svg: symbol.asSVG(),
  });
}

// Mirrors milsymbol test/number-sidc.js.
function modifierSidc(standard, symbolSet, code, first) {
  if (code.length == 2 && code != 99) {
    const amp = first ? `${code}00` : `00${code}`;
    return `${standard.version}03${symbolSet}0000000000${amp}`;
  }
  if (code.length == 3) {
    // Common modifiers (2525E): the first digit goes to SIDC position 21 or 22.
    const extra = first ? `${code.substr(0, 1)}0` : `0${code.substr(0, 1)}`;
    const amp = first ? `${code.substr(1, 2)}00` : `00${code.substr(1, 2)}`;
    return `${standard.version}03${symbolSet || "10"}0000000000${amp}${extra}`;
  }
  return null;
}

for (const standard of STANDARDS) {
  for (const [key, table] of Object.entries(standard.data)) {
    const symbolSet = table.symbolset;
    if (!symbolSet) continue; // "common" modifiers of 2525E are exercised through the sets
    for (const icon of table.mainIcon) {
      if (icon["Geometric Rendering"] && icon["Geometric Rendering"] != "Point") continue;
      if (!/^\d{6}$/.test(icon.Code)) continue; // data errors such as "Area" in stanag-app6 set 25
      const name = icon["Entity Subtype"] || icon["Entity Type"] || icon["Entity"];
      add(standard, symbolSet, "main", icon.Code, name, `${standard.version}03${symbolSet}0000${icon.Code}0000`);
    }
    for (const [kind, list, column] of [["m1", table.modifier1, "First Modifier"], ["m2", table.modifier2, "Second Modifier"]]) {
      for (const modifier of list) {
        if (kind == "m1" && symbolSet == "25" && modifier.Code <= 12) continue; // milsymbol: unsupported
        if (modifier[column] == "{Disused}") continue;
        const sidc = modifierSidc(standard, symbolSet, modifier.Code || "", kind == "m1");
        if (sidc) add(standard, symbolSet, kind, modifier.Code, modifier[column], sidc);
      }
    }
    if (key != symbolSet) console.warn(`${standard.name}: table key ${key} != symbol set ${symbolSet}`);
  }
}

fs.writeFileSync(outFile, JSON.stringify(entries) + "\n");
const valid = entries.filter((e) => e.valid).length;
console.log(`coverage.json: ${entries.length} symbols (${valid} valid in milsymbol), ${(fs.statSync(outFile).size / 1024).toFixed(0)} KB`);
