// Prints milsymbol's draw instructions, metadata and SVG for one SIDC.
// Usage: node inspect.mjs <sidc> [jsonOptions]
// Example: node inspect.mjs 10031000141211000000 '{"size":80}'
// The default export already has every icon set registered.
import ms from "milsymbol";

const sidc = process.argv[2] || "10031000001211000000";
const options = process.argv[3] ? JSON.parse(process.argv[3]) : {};
const symbol = new ms.Symbol(sidc, options);

// Strip noisy fields so the structure is easy to read.
function replacer(key, value) {
  if (key === "non_scaling_stroke" && value === 1) return undefined;
  if (typeof value === "function") return undefined;
  return value;
}

const { baseGeometry, ...meta } = symbol.getMetadata();
console.log("== metadata ==");
console.log(JSON.stringify(meta, replacer, 2));
console.log("== bbox / anchor ==");
console.log(JSON.stringify({ bbox: symbol.bbox, anchor: symbol.getAnchor(), size: symbol.getSize() }, replacer));
console.log("== valid ==", symbol.isValid());
console.log("== drawInstructions ==");
console.log(JSON.stringify(symbol.drawInstructions, replacer, 2));
console.log("== svg ==");
console.log(symbol.asSVG());
