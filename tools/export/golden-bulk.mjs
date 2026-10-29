// Generates a large reference set: tests/golden/bulk_icons.json.
// Every main icon, modifier 1 and modifier 2 of the exported symbol sets, for all four
// affiliations, plus option variants on a sample, plus amplifier/modifier combinations
// (HQ / task force / dummy, echelons, mobility, leadership, condition, context).
// Usage: node golden-bulk.mjs   (or: npm run golden:bulk)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ms from "milsymbol";
import { resetEchelons } from "./milsymbol-fresh.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.resolve(here, "..", "..", "addons", "milsymbol", "data");
const outFile = path.resolve(here, "..", "..", "tests", "golden", "bulk_icons.json");

const SYMBOL_SETS = ["01", "10", "30"];
const IDENTITIES = ["1", "3", "4", "6"];
const SAMPLE_VARIANTS = [{ frame: false }, { monoColor: "rgb(0,0,128)" }, { fill: false }, { outlineWidth: 3, fill: false }];
const SAMPLE_EVERY = 7;

const entries = [];
function add(sidc, options = {}) {
  resetEchelons();
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

// Amplifiers and modifiers (Phase 4). SIDC: version, context, identity, set, status, HQ/TF/dummy, amplifier.
const sidcOf = (context, identity, set, status, hq, amp, entity = "121100") =>
  `10${context}${identity}${set}${status}${hq}${amp}${entity}0000`;
const ECHELON_CODES = ["11", "12", "13", "14", "15", "16", "17", "18", "21", "22", "23", "24", "25", "26"];
const MOBILITY_CODES = ["31", "32", "33", "34", "35", "36", "37", "41", "42", "51", "52", "61", "62"];
const AMP_VARIANTS = [{ outlineWidth: 3 }, { fill: false }, { monoColor: "rgb(0,0,128)" }, { frame: false }, { hqStaffLength: 60 }];
for (const identity of IDENTITIES) {
  for (const hq of ["0", "1", "2", "3", "4", "5", "6", "7"]) {
    for (const amp of ["00", ...ECHELON_CODES]) add(sidcOf("0", identity, "10", "0", hq, amp));
  }
  for (const set of ["01", "30", "35", "05"]) for (const hq of ["1", "2", "4", "6"]) add(sidcOf("0", identity, set, "0", hq, "00", "000000"));
  for (const amp of MOBILITY_CODES) add(sidcOf("0", identity, "15", "0", "0", amp, "000000"));
  for (const amp of ["71", "72"]) add(sidcOf("0", identity, "27", "0", "0", amp, "000000"));
  for (const status of ["2", "3", "4", "5"]) {
    add(sidcOf("0", identity, "10", status, "0", "00"));
    add(sidcOf("0", identity, "15", status, "0", "33", "000000"));
  }
  for (const context of ["1", "2"]) for (const set of ["10", "01", "30", "35"]) add(sidcOf(context, identity, set, "0", "0", "00", "000000"));
  add(sidcOf("0", identity, "20", "0", "0", "00", "000000"));
  add(sidcOf("0", identity, "20", "0", "0", "14", "000000"));
  add(sidcOf("0", identity, "00", "0", "0", "00", "000000"));
}
// Joker / faker (exercise + suspect / hostile identity), installation with echelon, HQ+TF+dummy on air/sea.
for (const identity of ["5", "6"]) add(sidcOf("1", identity, "10", "0", "0", "00"));
for (const [i, sidc] of [sidcOf("0", "3", "10", "0", "7", "16"), sidcOf("0", "6", "10", "1", "6", "21"),
  sidcOf("0", "3", "15", "2", "0", "33", "000000"), sidcOf("1", "4", "10", "4", "2", "15"),
  sidcOf("0", "1", "15", "3", "0", "35", "000000"), sidcOf("0", "3", "27", "0", "0", "71", "000000")].entries()) {
  for (const options of AMP_VARIANTS) add(sidc, options);
  if (i === 0) add(sidc, { simpleStatusModifier: true });
}
for (const status of ["2", "3", "4", "5"]) {
  add(sidcOf("0", "3", "10", status, "0", "00"), { simpleStatusModifier: true });
  add(sidcOf("0", "3", "10", status, "0", "00"), { monoColor: "black" });
}
add(sidcOf("0", "3", "10", "0", "2", "14"), { modifierColor: "rgb(200,0,200)" });

fs.writeFileSync(outFile, JSON.stringify(entries) + "\n");
console.log(`bulk_icons.json: ${entries.length} symbols, ${(fs.statSync(outFile).size / 1024).toFixed(0)} KB`);
