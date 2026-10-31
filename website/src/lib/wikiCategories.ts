// Per-category presentation for the wiki index (icon + subtitle). Categories are free
// text set by editors; known ones get a themed icon/subtitle, the rest fall back.
export interface WikiCatMeta { icon: string; subtitle: string }

const META: Record<string, WikiCatMeta> = {
  "server rules": { icon: "Scale", subtitle: "Know the rules before you play." },
  "rules": { icon: "Scale", subtitle: "Know the rules before you play." },
  "police / maxsec": { icon: "Shield", subtitle: "Law enforcement guide." },
  "police/maxsec": { icon: "Shield", subtitle: "Law enforcement guide." },
  "maxsec": { icon: "Shield", subtitle: "Law enforcement guide." },
  "police": { icon: "Shield", subtitle: "Law enforcement guide." },
  "trauma team": { icon: "Stethoscope", subtitle: "Trauma Team guide." },
  "getting started": { icon: "Rocket", subtitle: "New here? Start with these." },
  "economy": { icon: "Landmark", subtitle: "Making money & the market." },
  "gangs": { icon: "Users", subtitle: "Gangs, turfs & cartels." },
  "medical": { icon: "Stethoscope", subtitle: "EMS & the medical system." },
  "civilian": { icon: "User", subtitle: "Life as a civilian." },
  "general": { icon: "BookOpen", subtitle: "General information." },
};

export function wikiCatMeta(category: string): WikiCatMeta {
  return META[(category || "").trim().toLowerCase()] ?? { icon: "BookOpen", subtitle: "" };
}

export function catAnchor(category: string): string {
  return "category-" + (category || "general").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}
