// milsymbol 3.0.5 mutates its shared echelon geometry the first time a symbol with an echelon is
// drawn (modifier.js sets `fill = color` on the module-level objects), so the first symbol's color
// leaks into every later one. Golden scripts call resetEchelons() before each symbol so every
// reference is drawn as if it were the first. The Godot port does not have this bug.
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const modulePath = path.join(here, "node_modules", "milsymbol", "src", "symbolfunctions", "modifier-echelon-json.js");
const { default: echelons } = await import(pathToFileURL(modulePath).href);
const pristine = JSON.parse(JSON.stringify(echelons));

export function resetEchelons() {
  for (const [name, value] of Object.entries(pristine)) {
    echelons[name].g = JSON.parse(JSON.stringify(value.g));
  }
}
