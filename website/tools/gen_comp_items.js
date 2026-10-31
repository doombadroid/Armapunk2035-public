// Regenerate src/lib/compItems.ts from the live mission item price config.
// Run from repo root:  node website/tools/gen_comp_items.js
// Price used = index-8 of each item entry (the in-server value, matches fn_virtItemCfg).
const fs = require("fs");
const path = require("path");

const CFG = path.resolve(__dirname, "../../mission/Armapunk2035.Malden/core/config/fn_virtItemCfg.sqf");
const OUT = path.resolve(__dirname, "../src/lib/compItems.ts");

const src = fs.readFileSync(CFG, "utf8");
const re = /\[\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,(?:\s*[^,\]]+,){6}\s*(-?\d+(?:\.\d+)?)/g;
const seen = new Set();
const items = [];
let m;
while ((m = re.exec(src))) {
  const classname = m[1], name = m[2];
  const price = Math.max(0, Math.round(Number(m[3]) || 0));
  if (seen.has(classname)) continue;
  seen.add(classname);
  items.push({ classname, name, price });
}
items.sort((a, b) => a.name.localeCompare(b.name));

const body =
  "// AUTO-GENERATED from mission fn_virtItemCfg.sqf (in-server item prices, idx8 value).\n" +
  "// Regenerate: node website/tools/gen_comp_items.js  — do not hand-edit.\n" +
  "export interface CompItem { classname: string; name: string; price: number }\n" +
  "export const COMP_ITEMS: CompItem[] = " + JSON.stringify(items) + ";\n";
fs.writeFileSync(OUT, body);
console.log("wrote", items.length, "items ->", OUT);
