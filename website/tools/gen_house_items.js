// Regenerate src/lib/houseItems.ts — the catalogs for the admin "place item in house" tool.
//   - Virtual items + weights from mission fn_virtItemCfg.sqf   (getItemWeight = row index 2)
//   - Physical item weights from mission Config_physWeights.hpp (class CfgWeights, inherited)
// House storage total = Σ(qty × weight); the game recomputes it the same way on save, so these
// weights must match exactly. Run from repo root:  node website/tools/gen_house_items.js
const fs = require("fs");
const path = require("path");

const MISSION = path.resolve(__dirname, "../../mission/Armapunk2035.Malden");
const OUT = path.resolve(__dirname, "../src/lib/houseItems.ts");

// ---- virtual items (classname, display name, weight = index 2) ----
const vsrc = fs.readFileSync(path.join(MISSION, "core/config/fn_virtItemCfg.sqf"), "utf8");
const vre = /\[\s*"([^"]+)"\s*,\s*"([^"]*)"\s*,\s*(-?\d+)/g;
const seen = new Set();
const virt = [];
let m;
while ((m = vre.exec(vsrc))) {
  const classname = m[1];
  if (seen.has(classname)) continue;
  seen.add(classname);
  virt.push({ classname, name: m[2] || classname, weight: Math.max(0, Number(m[3]) || 0) });
}
virt.sort((a, b) => a.name.localeCompare(b.name));

// ---- physical weights (CfgWeights with single/multi-level inheritance) ----
const hsrc = fs.readFileSync(path.join(MISSION, "Config_physWeights.hpp"), "utf8");
// each class: `class NAME[:PARENT]{BODY}` — bodies are flat (no nested braces)
const cre = /class\s+([A-Za-z0-9_]+)\s*(?::\s*([A-Za-z0-9_]+))?\s*\{([^{}]*)\}/g;
const own = {}, parent = {};
let c;
while ((c = cre.exec(hsrc))) {
  const name = c[1], par = c[2], body = c[3] || "";
  if (par) parent[name] = par;
  const w = /weight\s*=\s*([0-9.]+)/.exec(body);
  if (w) own[name] = Math.round(Number(w[1]) || 0);
}
const memo = {};
function weightOf(name, depth = 0) {
  if (name in memo) return memo[name];
  if (depth > 20) return 1;
  let w;
  if (name in own) w = own[name];
  else if (name in parent) w = weightOf(parent[name], depth + 1);
  else w = 1; // CfgWeights root default
  memo[name] = w;
  return w;
}
// keep the real item classes (those that inherit from a base) — skip the *Weight_NI/IL templates + root
const TEMPLATE = /(OneWeight|TwoWeight|ThreeWeight|FourWeight|FiveWeight)_(NI|IL)$/;
const phys = {};
for (const name of Object.keys(parent)) {
  if (name === "CfgWeights" || TEMPLATE.test(name)) continue;
  phys[name] = weightOf(name);
}

// ---- physical ITEMS catalog (classname -> searchable display name) ----
// Real names for clothing/gear come from the fn_clothing_*.sqf shops; weapons/mags (weaponShopCfg
// stores nil names, resolved from the Arma engine at runtime) get a derived readable name. Search
// in the UI matches name OR classname, so derived names are fine as a search aid.
function prettify(cls) {
  let s = cls
    .replace(/^(arifle_|srifle_|hgun_|LMG_|MMG_|SMG_|sgun_|launch_)/i, "")
    .replace(/^(U_|V_|H_|G_|B_)/, "")
    .replace(/^(optic_|muzzle_|bipod_|acc_|Item)/, "")
    .replace(/_F$/, "")
    .replace(/_/g, " ")
    .trim();
  return s || cls;
}
const physName = {};
// clothing/gear shops = REAL display names: ["classname","Display Name",price,...]
for (const f of fs.readdirSync(path.join(MISSION, "core/config"))) {
  if (!/^fn_clothing_.*\.sqf$/.test(f)) continue;
  const src = fs.readFileSync(path.join(MISSION, "core/config", f), "utf8");
  const re = /\[\s*"([A-Za-z0-9_]+)"\s*,\s*"([^"]+)"\s*,\s*-?\d/g;
  let mm;
  while ((mm = re.exec(src))) {
    const cn = mm[1], nm = mm[2];
    if (cn.startsWith("_") || nm.startsWith("_")) continue;
    if (!(cn in physName)) physName[cn] = nm; // first shop wins
  }
}
// weaponShopCfg = weapons/mags/attachments/items: ["classname",(nil|"name"),price,[shops...]]
{
  const src = fs.readFileSync(path.join(MISSION, "core/config/fn_weaponShopCfg.sqf"), "utf8");
  const re = /\[\s*"([A-Za-z0-9_]+)"\s*,\s*(nil|"[^"]*")\s*,\s*-?\d/g;
  let mm;
  while ((mm = re.exec(src))) {
    const cn = mm[1];
    if (cn.startsWith("_")) continue;
    const nm = mm[2] !== "nil" ? mm[2].slice(1, -1) : "";
    if (!(cn in physName)) physName[cn] = nm || prettify(cn);
  }
}
// backfill every CfgWeights classname (gear that isn't in a shop) with a derived name
for (const cn of Object.keys(phys)) if (!(cn in physName)) physName[cn] = prettify(cn);
const physItems = Object.keys(physName).sort((a, b) => physName[a].localeCompare(physName[b]))
  .map((cn) => ({ classname: cn, name: physName[cn] }));

const body =
  "// AUTO-GENERATED from mission fn_virtItemCfg.sqf + Config_physWeights.hpp — do not hand-edit.\n" +
  "// Regenerate: node website/tools/gen_house_items.js\n" +
  "// House storage total = Σ(qty × weight); virtual weight = virtItemCfg[2], physical = CfgWeights (0 if absent).\n" +
  "export interface HouseVirtItem { classname: string; name: string; weight: number }\n" +
  "export const HOUSE_VIRT_ITEMS: HouseVirtItem[] = " + JSON.stringify(virt) + ";\n" +
  "// classname -> physical weight (resolved through CfgWeights inheritance). Unknown gear => 0.\n" +
  "export const PHYS_WEIGHT: Record<string, number> = " + JSON.stringify(phys) + ";\n" +
  "// searchable physical-item catalog: real names for clothing/gear (shops), derived for weapons/mags.\n" +
  "export interface HousePhysItem { classname: string; name: string }\n" +
  "export const PHYS_ITEMS: HousePhysItem[] = " + JSON.stringify(physItems) + ";\n";
fs.writeFileSync(OUT, body);
console.log(`wrote ${virt.length} virtual items + ${Object.keys(phys).length} physical weights + ${physItems.length} physical items -> ${OUT}`);
