// Writes docs/images/text-to-path-sample.svg to eyeball textToPathD() output (dev artifact).
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { textToPathD } from "./text-to-path.mjs";

const mid = { textanchor: "middle", alignmentBaseline: "middle", fontweight: "bold" };
const samples = [
  { x: 100, y: 103, text: "LO", fontsize: 45, ...mid },
  { x: 300, y: 103, text: "MIL", fontsize: 39, ...mid },
  { x: 100, y: 71, text: "HQ", fontsize: 28, ...mid },
  { x: 300, y: 71, text: "ABCD", fontsize: 33, ...mid },
  { x: 20, y: 180, text: "Start anchored", fontsize: 24, textanchor: "start" },
  { x: 380, y: 230, text: "End anchored", fontsize: 24, textanchor: "end", fontweight: "bold" },
  { x: 200, y: 280, text: "Central Hxg", fontsize: 24, textanchor: "middle", alignmentBaseline: "central" },
];
let body = "";
for (const s of samples) {
  body += `<path d="M${s.x - 6} ${s.y}H${s.x + 6}M${s.x} ${s.y - 6}V${s.y + 6}" stroke="red" stroke-width="0.5" fill="none"/>\n`;
  body += `<path d="${textToPathD(s)}" fill="black"/>\n`;
}
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300" viewBox="0 0 400 300">\n<rect width="400" height="300" fill="white"/>\n${body}</svg>\n`;
const out = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "..", "docs", "images", "text-to-path-sample.svg");
fs.mkdirSync(path.dirname(out), { recursive: true });
fs.writeFileSync(out, svg);
console.log("wrote", out);
