// Exports the MIL-STD-2525C -> 2525D mapping to addons/milsymbol/data/legacy_2525c.json.
// Source: Esri joint-military-symbology-xml, samples/legacy_support/LegacyMappingTableCtoD.csv (Apache-2.0),
// downloaded at a fixed commit and checked against a SHA-256 hash; cached in tools/export/.cache/.
// Output: {"<key>": [symbolSet, entity, modifier1, modifier2], ...} where key is the first ten characters of a
// 2525C SIDC with the standard identity replaced by "*" and the status by "P" (the table's key format).
// Rows the table marks "Retired" are left out.
// Usage: node legacy.mjs   (or: npm run legacy)
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const COMMIT = "155b41a04ee9cf62de30906360b9c0fb9f2167f2";
const URL = `https://raw.githubusercontent.com/Esri/joint-military-symbology-xml/${COMMIT}/samples/legacy_support/LegacyMappingTableCtoD.csv`;
const SHA256 = "6baddff3d226a34278e634fed997f74767d9a72b56e685e646d335a539b53809";
const cacheFile = path.join(here, ".cache", "LegacyMappingTableCtoD.csv");
const outFile = path.resolve(here, "..", "..", "addons", "milsymbol", "data", "legacy_2525c.json");

async function source() {
  if (!fs.existsSync(cacheFile)) {
    const response = await fetch(URL);
    if (!response.ok) throw new Error(`download failed: ${response.status} ${URL}`);
    fs.mkdirSync(path.dirname(cacheFile), { recursive: true });
    fs.writeFileSync(cacheFile, Buffer.from(await response.arrayBuffer()));
  }
  const data = fs.readFileSync(cacheFile);
  const hash = crypto.createHash("sha256").update(data).digest("hex");
  if (hash !== SHA256) throw new Error(`unexpected SHA-256 ${hash} for ${cacheFile}`);
  return data.toString("utf8");
}

const lines = (await source()).split(/\r?\n/).filter((line) => line.trim() !== "");
const header = lines.shift().split(",");
const column = (name) => header.indexOf(name);
const [KEY, SET, ENTITY, MOD1, MOD2, REMARKS] = ["2525Charlie1stTen", "2525DeltaSymbolSet", "2525DeltaEntity",
  "2525DeltaMod1", "2525DeltaMod2", "Remarks"].map(column);

const table = {};
let retired = 0;
for (const line of lines) {
  const cells = line.split(",");
  if (cells[REMARKS] === "Retired") {
    retired++;
    continue;
  }
  const key = cells[KEY];
  if (table[key]) continue; // a few keys appear twice; the first row is the table's preferred mapping
  table[key] = [cells[SET], cells[ENTITY], cells[MOD1], cells[MOD2]];
}
const sorted = Object.fromEntries(Object.entries(table).sort(([a], [b]) => a.localeCompare(b)));
fs.writeFileSync(outFile, JSON.stringify(sorted).replace(/\],"/g, '],\n"') + "\n");
console.log(`legacy_2525c.json: ${Object.keys(sorted).length} mappings (${retired} retired rows left out)`);
