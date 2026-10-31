// Generates reference (oracle) SVGs and a manifest from milsymbol for the golden tests.
// Usage: node golden.mjs   (or: npm run golden)
// Reads golden-sidcs.json, writes tests/golden/<id>.svg and tests/golden/manifest.json.
import ms from "milsymbol";
import { resetEchelons, resetIconCache } from "./milsymbol-fresh.mjs";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const listPath = path.join(here, "golden-sidcs.json");
const outDir = path.resolve(here, "..", "..", "tests", "golden");

function fail(msg) {
  console.error("golden: ERROR: " + msg);
  process.exit(1);
}

const entries = JSON.parse(fs.readFileSync(listPath, "utf8"));
if (!Array.isArray(entries)) fail("golden-sidcs.json must be an array");

const seen = new Set();
const manifest = [];
const svgs = new Map();

for (const e of entries) {
  if (typeof e.id !== "string" || !/^[A-Za-z0-9_-]+$/.test(e.id)) fail(`bad id: ${JSON.stringify(e.id)}`);
  if (seen.has(e.id)) fail(`duplicate id: ${e.id}`);
  seen.add(e.id);
  if (typeof e.sidc !== "string" || !/^\d{20}$/.test(e.sidc)) fail(`${e.id}: SIDC is not 20 digits: ${e.sidc}`);
  const options = e.options ?? {};
  resetEchelons();
  resetIconCache(ms);
  const symbol = new ms.Symbol(e.sidc, options);
  const valid = symbol.isValid();
  if (valid === false) fail(`${e.id}: milsymbol reports the SIDC as invalid`);
  const size = symbol.getSize();
  const anchor = symbol.getAnchor();
  svgs.set(e.id, symbol.asSVG());
  manifest.push({
    id: e.id,
    sidc: e.sidc,
    options,
    description: e.description ?? "",
    valid,
    width: size.width,
    height: size.height,
    anchor: { x: anchor.x, y: anchor.y },
  });
}

fs.mkdirSync(outDir, { recursive: true });
for (const f of fs.readdirSync(outDir)) {
  if (f.endsWith(".svg") && !seen.has(f.slice(0, -4))) {
    fs.unlinkSync(path.join(outDir, f));
    console.log("removed stale " + f);
  }
}
for (const [id, svg] of svgs) fs.writeFileSync(path.join(outDir, id + ".svg"), svg);
fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log(`golden: wrote ${svgs.size} SVGs + manifest.json to ${outDir}`);
