// Exports milsymbol's static data (frame geometries, color modes, dash arrays) to JSON
// files that ship with the addon.
// Usage: node data.mjs   (or: npm run data)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

// Internal modules are not in milsymbol's "exports" map, so import them by file path.
const here = path.dirname(fileURLToPath(import.meta.url));
const src = path.join(here, "node_modules", "milsymbol", "src");
const importSrc = (rel) => import(new URL("file:///" + path.join(src, rel).replace(/\\/g, "/")).href);

const { default: geometries } = await importSrc("ms/symbolgeometries.js");
const { default: colorModes } = await importSrc("colormodes.js");
const { default: ms } = await import("milsymbol");
const pkg = JSON.parse(fs.readFileSync(path.join(src, "..", "package.json"), "utf8"));

const outDir = path.resolve(here, "..", "..", "addons", "milsymbol", "data");
fs.mkdirSync(outDir, { recursive: true });

function write(name, data) {
  const json = JSON.stringify({ milsymbol: pkg.version, ...data }, null, 2) + "\n";
  fs.writeFileSync(path.join(outDir, name), json);
  console.log("wrote " + path.relative(path.resolve(here, "..", ".."), path.join(outDir, name)));
}

const geometryOut = {};
for (const [name, geometry] of Object.entries(geometries)) {
  const { x1, y1, x2, y2 } = geometry.bbox;
  geometryOut[name] = { g: geometry.g, bbox: { x1, y1, x2, y2 } };
}

write("geometries.json", { geometries: geometryOut });
write("colormodes.json", {
  colorModes,
  dashArrays: ms.getDashArrays(),
  hqStaffLength: ms.getHqStaffLength(),
});
