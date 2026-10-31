// Turn an untrusted JSON body into an Action, or null. The reference vocabulary: lowercase types with
// their payload keys (deminify_report.json actionCalls plus the casino calls). Ids are checked
// against the content tables (own properties only: `in` would accept "__proto__") so the engine
// never sees an unknown key.
import { CITY, LICENSE, SITE, SKILL, STAR_PERK, TALENT } from "./content";
import type { Action, ChestRarity, CityId, Faction, RouletteChoice, ToolKind } from "./types";

const ID = /^[A-Za-z0-9_]{1,40}$/;
const RARITIES: ChestRarity[] = ["common", "rare", "epic", "legendary"];
const ROULETTE: RouletteChoice[] = ["red", "black", "even", "odd", "green", "number"];

function amount(v: unknown): number | "all" | null {
  if (v === "all") return "all";
  const n = typeof v === "number" ? v : Number(v);
  return Number.isInteger(n) && n >= 1 && n <= 1_000_000 ? n : null;
}
function id(v: unknown, table: Record<string, unknown>): string | null {
  const s = String(v ?? "");
  return ID.test(s) && Object.hasOwn(table, s) ? s : null;
}
function kind(v: unknown): ToolKind | null {
  return v === "gather" || v === "process" ? v : null;
}
function faction(v: unknown): Faction | null {
  return v === "civ" || v === "cop" ? v : null;
}
function int(v: unknown, min: number, max: number): number | null {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : null;
}
function str(v: unknown, max: number): string | null {
  return typeof v === "string" && v.length <= max ? v : null;
}
function uuid(v: unknown): string | null {
  return typeof v === "string" && /^[0-9a-f-]{1,40}$/i.test(v) ? v : null;
}

export function parseAction(body: unknown): Action | null {
  if (!body || typeof body !== "object") return null;
  const b = body as Record<string, unknown>;
  switch (b.type) {
    case "work":
    case "crew": {
      const siteId = id(b.siteId, SITE);
      return siteId ? { type: b.type, siteId } : null;
    }
    case "crewpause": {
      if (typeof b.paused !== "boolean") return null;
      if (b.siteId === null || b.siteId === undefined) return { type: "crewpause", siteId: null, paused: b.paused };
      const siteId = id(b.siteId, SITE);
      return siteId ? { type: "crewpause", siteId, paused: b.paused } : null;
    }
    case "sell":
    case "drop": {
      const itemId = String(b.itemId ?? "");
      const n = amount(b.amount);
      return ID.test(itemId) && n !== null ? { type: b.type, itemId, amount: n } : null;
    }
    case "travel": {
      const cityId = id(b.cityId, CITY);
      return cityId ? { type: "travel", cityId: cityId as CityId } : null;
    }
    case "license": { const v = id(b.licenseId, LICENSE); return v ? { type: "license", licenseId: v } : null; }
    case "skill": { const v = id(b.skillId, SKILL); return v ? { type: "skill", skillId: v } : null; }
    case "talent": { const v = id(b.talentId, TALENT); return v ? { type: "talent", talentId: v } : null; }
    case "starperk": { const v = id(b.perkId, STAR_PERK); return v ? { type: "starperk", perkId: v } : null; }
    case "tool": { const k = kind(b.kind); return k ? { type: "tool", kind: k } : null; }
    case "worker": {
      const siteId = id(b.siteId, SITE);
      const k = kind(b.kind);
      const minutes = int(b.minutes, 1, 600);
      return siteId && k && minutes !== null ? { type: "worker", siteId, minutes, kind: k } : null;
    }
    case "craftcontract": {
      const qty = int(b.qty, 1, 100);
      return qty !== null ? { type: "craftcontract", qty } : null;
    }
    case "openchest": {
      const r = String(b.rarity ?? "") as ChestRarity;
      return RARITIES.includes(r) ? { type: "openchest", rarity: r } : null;
    }
    case "faction":
    case "switch": {
      const f = faction(b.faction);
      return f ? { type: b.type, faction: f } : null;
    }
    case "bust":
    case "gangkick": {
      const targetId = str(b.targetId, 32);
      return targetId && /^\d{1,20}$/.test(targetId) ? { type: b.type, targetId } : null;
    }
    case "casestart":
      return typeof b.practice === "boolean" ? { type: "casestart", practice: b.practice } : null;
    case "caseanswer":
    case "pursuitanswer": {
      const caseId = uuid(b.id);
      const round = int(b.round, 0, 2);
      const choice = int(b.choice, 0, 2);
      return caseId && round !== null && choice !== null ? { type: b.type, id: caseId, round, choice } : null;
    }
    case "prisonrotate": {
      const custodyId = uuid(b.custodyId);
      const jobId = uuid(b.jobId);
      const tile = int(b.tile, 0, 8);
      return custodyId && jobId && tile !== null ? { type: "prisonrotate", custodyId, jobId, tile } : null;
    }
    case "prisoncomplete": {
      const custodyId = uuid(b.custodyId);
      const jobId = uuid(b.jobId);
      return custodyId && jobId ? { type: "prisoncomplete", custodyId, jobId } : null;
    }
    case "pursuitready":
    case "pursuitsurrender": {
      const v = uuid(b.id);
      return v ? { type: b.type, id: v } : null;
    }
    case "verify": {
      const v = uuid(b.id);
      const answer = str(b.answer, 32);
      return v && answer !== null ? { type: "verify", id: v, answer } : null;
    }
    case "chat": {
      const text = str(b.text, 4000);
      return text !== null ? { type: "chat", text } : null;
    }
    case "gangcreate": {
      const name = str(b.name, 40);
      const tag = str(b.tag, 8);
      return name !== null && tag !== null ? { type: "gangcreate", name, tag } : null;
    }
    case "gangjoin": {
      const gangId = str(b.gangId, 40);
      const code = str(b.code ?? "", 16);
      return gangId && /^[a-z0-9]+$/.test(gangId) && code !== null ? { type: "gangjoin", gangId, code } : null;
    }
    case "gangprivacy":
      return typeof b.private === "boolean" ? { type: "gangprivacy", private: b.private } : null;
    case "blackjackdeal":
    case "slots":
    case "pokerjoin": {
      const n = int(b.type === "pokerjoin" ? b.buyIn : b.bet, 1, 1_000_000_000_000);
      if (n === null) return null;
      return b.type === "pokerjoin" ? { type: "pokerjoin", buyIn: n } : { type: b.type, bet: n };
    }
    case "roulette": {
      const bet = int(b.bet, 1, 1_000_000_000_000);
      const choice = String(b.choice ?? "") as RouletteChoice;
      const number = int(b.number ?? 0, 0, 36) ?? (ROULETTE.includes(choice) && choice !== "number" ? 0 : null);
      return bet !== null && ROULETTE.includes(choice) && number !== null ? { type: "roulette", bet, choice, number } : null;
    }
    case "gear":
    case "pack":
    case "copgear":
    case "autosell":
    case "workerautosell":
    case "payheat":
    case "ditch":
    case "respec":
    case "prestige":
    case "reset":
    case "release":
    case "prisonstart":
    case "hp":
    case "gangleave":
    case "blackjackhit":
    case "blackjackstand":
    case "pokerdeal":
    case "pokerleave":
      return { type: b.type };
    default:
      return null;
  }
}

/** Every action type the route accepts, for tests and the spec. */
export const ACTION_TYPES = [
  "autosell", "blackjackdeal", "blackjackhit", "blackjackstand", "bust", "caseanswer", "casestart", "chat", "copgear", "craftcontract",
  "crew", "crewpause", "ditch", "drop", "faction", "gangcreate", "gangjoin", "gangkick", "gangleave", "gangprivacy", "gear", "hp",
  "license", "openchest", "pack", "payheat", "pokerdeal", "pokerjoin", "pokerleave", "prestige", "prisoncomplete", "prisonrotate",
  "prisonstart", "pursuitanswer", "pursuitready", "pursuitsurrender", "release", "reset", "respec", "roulette", "sell", "skill", "slots",
  "starperk", "switch", "talent", "tool", "travel", "verify", "work", "worker", "workerautosell",
] as const;
