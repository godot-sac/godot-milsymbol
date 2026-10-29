// Writes tests/golden/text_layout.json: text instructions with the reference path data from
// textToPathD. tests/unit/test_text_layout.gd compares the GDScript layout against it.
// Turkish letters are not included: textToPathD only loads the latin subset of Arimo.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { textToPathD } from "./text-to-path.mjs";

const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../tests/golden/text_layout.json");
const cases = [];
const add = (text, extra) => cases.push({ type: "text", x: 200, y: 100, text, fill: "black", ...extra });

for (const anchor of ["start", "middle", "end"])
  for (const baseline of [undefined, "alphabetic", "auto", "middle", "central", "hanging", "text-before-edge", "text-top"]) {
    if (anchor !== "middle" && baseline !== undefined && baseline !== "middle" && baseline !== "hanging") continue;
    add("AV To 1", { fontsize: 40, textanchor: anchor, alignmentBaseline: baseline });
  }
add("AVAVA", { fontsize: 60, fontweight: "bold", textanchor: "middle", alignmentBaseline: "central" });
add("To Ty Wa", { fontsize: 50, fontweight: "bold", textanchor: "start" });
add("X", { fontsize: 80, fontweight: "bold", textanchor: "middle", alignmentBaseline: "middle" });
add("0123456789", { fontsize: 30, textanchor: "middle" });
add("quick brown fox", { fontsize: 24, textanchor: "end", x: 380, y: 60 });
add("Test (1) [A/B] 50°", { fontsize: 20, fontweight: "bold", textanchor: "middle" });
add("Hello, World!", { fontsize: 36, textanchor: "start", x: 10 });
add("AV", { fontsize: 70, textanchor: "middle", alignmentBaseline: "central" });

const out = cases.map((instr) => ({ instr, d: textToPathD(instr) }));
fs.writeFileSync(OUT, JSON.stringify(out));
console.log(out.length, "cases ->", OUT);
