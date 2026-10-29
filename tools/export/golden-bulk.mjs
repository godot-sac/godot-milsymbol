// Generates a large reference set for icon coverage: tests/golden/bulk_icons.json.
// Every main icon, modifier 1 and modifier 2 of the exported symbol sets, for all four
// affiliations, plus option variants on a sample.
// Usage: node golden-bulk.mjs   (or: npm run golden:bulk)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ms from "milsymbol";

const here = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(here, "..", "..", "addons", "milsymbol", "data");
const outFile = path.resolve(here, "..", "..", "tests", "golden", "bulk_icons.json");

const SYMBOL_SETS = ["01", "10", "30"];
const IDENTITIES = ["1", "3", "4", "6"];
const SAMPLE_VARIANTS = [{ frame: false }, { monoColor: "rgb(0,0,128)" }, { fill: false }, { outlineWidth: 3, fill: false }];
const SAMPLE_EVERY = 7;

const entries = [];
function add(sidc, options = {}) {
  const symbol = new ms.Symbol(sidc, options);
  const size = symbol.getSize();
  const anchor = symbol.getAnchor();
  entries.push({ sidc, options, valid: symbol.isValid(), width: size.width, height: size.height, anchor: { x: anchor.x, y: anchor.y }, svg: symbol.asSVG() });
}

for (const symbolSet of SYMBOL_SETS) {
  const data = JSON.parse(fs.readFileSync(path.join(dataDir, `icons_${symbolSet}.json`), "utf8"));
  const tableD = data.tables.D;
  const tableE = data.tables.E === "D" ? null : data.tables.E;
  const mains = Object.keys(tableD.main).sort();
  mains.forEach((code, i) => {
    for (const identity of IDENTITIES) add(`100${identity}${symbolSet}0000${code}0000`);
    if (i % SAMPLE_EVERY === 0) for (const options of SAMPLE_VARIANTS) add(`1003${symbolSet}0000${code}0000`, options);
  });
  for (const code of Object.keys(tableD.m1).sort()) add(`1003${symbolSet}0000000000${code}00`);
  for (const code of Object.keys(tableD.m2).sort()) add(`1003${symbolSet}000000000000${code}`);
  if (tableE) {
    // 2525E: every main icon and modifier whose table entry differs from 2525D.
    for (const kind of ["main", "m1", "m2"]) {
      for (const code of Object.keys(tableE[kind]).sort()) {
        if (JSON.stringify(tableE[kind][code]) === JSON.stringify(tableD[kind][code])) continue;
        const entity = kind === "main" ? `${code}0000` : kind === "m1" ? `000000${code}00` : `00000000${code}`;
        add(`1303${symbolSet}0000${entity}`);
      }
    }
  }
}

fs.writeFileSync(outFile, JSON.stringify(entries) + "\n");
console.log(`bulk_icons.json: ${entries.length} symbols, ${(fs.statSync(outFile).size / 1024).toFixed(0)} KB`);
