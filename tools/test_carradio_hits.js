// Run the page's OWN slots()/pickAt() headlessly and click the ring at known angles/radii.
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const src = html.split("<script>").map(s => s.split("</script>")[0]).find(s => s.includes("function slots("));
const el = () => ({ textContent: "", innerHTML: "", style: {}, classList: { add(){}, remove(){}, toggle(){} },
  addEventListener(){}, getBoundingClientRect: () => ({ left: 0, top: 0, width: 640, height: 496 }) });
global.window = global; global.document = { getElementById: el, addEventListener(){} };
global.setTimeout = (f) => f();   // stub pushes synchronously
const _err = console.error.bind(console); global.console = { log(){}, error: _err };
eval(src);
const CX = 320, CY = 252;
const at = (ang, r) => { const q = ang * Math.PI / 180; return pickAt({ clientX: CX + r * Math.sin(q), clientY: CY - r * Math.cos(q) }); };
const sl = slots(), name = (i) => i < 0 ? "nothing" : sl[i].k + (sl[i].m ? ":" + sl[i].m : "") + (sl[i].k === "st" ? ":" + sl[i].i : "");
const cases = [
  [180, 76,  "ap:normal"], [180, 122, "skin"], [180, 150, "skin"],
  [160, 76,  "ap:madmax"], [160, 122, "skin"], [200, 76, "ap:sloth"], [200, 122, "skin"],
  [144, 76,  "ap:madmax"], [216, 76, "ap:sloth"], [145, 122, "nothing"], [215, 122, "nothing"],
  [108, 122, "off"], [108, 76, "off"], [0, 122, "st:2"], [-72, 122, "st:0"], [180, 170, "nothing"],
];
let bad = 0;
for (const [a, r, want] of cases) { const got = name(at(a, r)); const ok = got === want; if (!ok) bad++;
  console.error((ok ? "PASS" : "FAIL") + `  angle ${a} r ${r} -> ${got}` + (ok ? "" : `  (want ${want})`)); }
console.error(bad ? `${bad} FAIL` : "all hits correct");
process.exit(bad ? 1 : 0);
