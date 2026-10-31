// Armapunk Pixel v3 snapshot: what GET /api/pixel/state returns and what every action carries back
// as `snapshot`, in the reference's runtime shape (reference/state_example.json). Pure: derived from
// a ticked PlayerState, the shared rows and the world the store read around the player.
import { CITIES, CONST, INFERRED, ITEMS, SKILLS } from "./content";
import {
  bribeCost, capacityKg, career, carriedKg, factionOf, fineEstimate, marketKey, marketMultAt, netWorth, prestigeBlockers,
  respecCost, seizable, seizableUnits, staminaMax, staminaRegen, unitPrice, visibleAt,
} from "./economy";
import { custodyCredit, gangCap, gangInvite, npcCrimeAt, releaseCost } from "./engine";
import { gangLevelFromXp, levelFromXp, talentPoints, talentSpent } from "./level";
import { blackjackScore } from "./casino";
import { GANG } from "./content";
import type { CityId, ItemId, PlayerState, Shared, Snapshot, WireBlackjack, WireCasino, WireGang, WireGangProfile, WireMe, World } from "./types";

function skillsFor(s: PlayerState): Record<string, number> {
  const c = career(s);
  const out: Record<string, number> = {};
  for (const sk of SKILLS) if (sk.faction === "both" || sk.faction === factionOf(s)) out[sk.id] = c.skills[sk.id] ?? 0;
  return out;
}

/** The player's own gang card: level, bonuses, cap, the invite code (private gangs) and the members with the world's name / level / online. */
export function gangCard(s: PlayerState, shared: Shared, world: World, now: number): WireGang | null {
  const g = s.gangId ? shared.gangs[s.gangId] : undefined;
  if (!g) return null;
  const lv = gangLevelFromXp(g.xp);
  const invite = gangInvite(g, now);
  return {
    id: g.id,
    name: g.name,
    tag: g.tag,
    level: lv.level,
    xp: g.xp,
    xpInto: lv.xpInto,
    xpNeeded: lv.xpNeeded,
    cap: gangCap(lv.level),
    yieldBonus: GANG.yieldPerLevel * lv.level,
    xpBonus: GANG.xpPerLevel * lv.level,
    isLeader: g.leaderId === s.steamId,
    isPrivate: g.private,
    inviteCode: g.private ? invite.code : null,
    inviteExpiresAt: invite.expiresAt,
    members: g.members.map((m) => {
      const info = world.gangMembers[m.steamId] ?? { name: m.steamId === s.steamId ? s.name : "Unknown", level: 1, prestige: 0, online: false };
      return { steamId: m.steamId, name: info.name, level: info.level, prestige: info.prestige, leader: m.steamId === g.leaderId, online: info.online };
    }),
  };
}

/** GET /api/pixel/gang?id= */
export function gangProfile(shared: Shared, gangId: string, viewerId: string, members: World["gangMembers"]): WireGangProfile | null {
  const g = shared.gangs[gangId];
  if (!g) return null;
  const lv = gangLevelFromXp(g.xp);
  const leader = members[g.leaderId];
  return {
    id: g.id,
    name: g.name,
    tag: g.tag,
    level: lv.level,
    xp: g.xp,
    xpInto: lv.xpInto,
    xpNeeded: lv.xpNeeded,
    cap: gangCap(lv.level),
    yieldBonus: GANG.yieldPerLevel * lv.level,
    xpBonus: GANG.xpPerLevel * lv.level,
    createdAt: g.createdAt,
    leaderName: leader?.name ?? "Unknown",
    private: g.private,
    isMine: g.members.some((m) => m.steamId === viewerId),
    members: g.members.map((m) => {
      const info = members[m.steamId] ?? { name: "Unknown", level: 1, prestige: 0, online: false };
      return { steamId: m.steamId, name: info.name, level: info.level, prestige: info.prestige, leader: m.steamId === g.leaderId, online: info.online };
    }),
  };
}

function blackjackWire(s: PlayerState): WireBlackjack | null {
  const h = s.blackjack;
  if (!h) return null;
  const playing = h.status === "playing";
  return {
    dealerCards: playing ? [h.dealerCards[0], null] : [...h.dealerCards],
    dealerScore: playing ? null : blackjackScore(h.dealerCards),
    playerCards: [...h.playerCards],
    playerScore: blackjackScore(h.playerCards),
    status: h.status,
    bet: h.bet,
    payout: h.payout,
  };
}

export function casinoWire(s: PlayerState, shared: Shared): WireCasino {
  const t = shared.poker;
  return {
    blackjack: blackjackWire(s),
    poker: { seats: t.seats.map((x) => ({ steamId: x.steamId, name: x.name, buyIn: x.buyIn })), pot: t.pot, buyIn: t.buyIn, minPlayers: t.minPlayers, lastResult: t.lastResult },
  };
}

/** `me`: the 66 keys of the reference snapshot, derived from the active career. */
export function me(s: PlayerState, shared: Shared, world: World, now: number): WireMe {
  const c = career(s);
  const civ = s.careers.civ;
  const lv = levelFromXp(c.xp);
  const faction = factionOf(s);
  const blockers = s.faction ? prestigeBlockers(c, faction) : [];
  const units = seizableUnits(civ);
  const fine = fineEstimate(civ);
  const credit = custodyCredit(s, now);
  const bail = s.custody ? releaseCost(s.custody, now) : 0;
  return {
    steamId: s.steamId,
    name: s.name,
    avatarUrl: world.avatarUrl,
    faction: s.faction,
    cityId: s.cityId,
    cash: c.cash,
    xp: c.xp,
    level: lv.level,
    xpInto: lv.xpInto,
    xpNeeded: lv.xpNeeded,
    stamina: Math.floor(s.stamina),
    staminaMax: staminaMax(c),
    staminaRegen: Math.round(staminaRegen(c) * 100) / 100,
    capacity: capacityKg(s),
    carried: carriedKg(c),
    netWorth: netWorth(c),
    heat: s.heat,
    wanted: s.heat >= visibleAt(civ),
    jailedUntil: s.custody?.jailedUntil ?? 0,
    travelUntil: s.travelUntil,
    travelTo: s.travelTo,
    skills: skillsFor(s),
    licenses: [...c.licenses],
    gearTier: civ.gearTier,
    copGearTier: s.careers.cop.copGearTier,
    talents: { ...c.talents },
    tools: { ...civ.tools },
    packTier: civ.packTier,
    autoSell: civ.autoSell,
    workerAutoSell: civ.workerAutoSell,
    prestige: c.prestige,
    prestigeReady: !!s.faction && blockers.length === 0,
    prestigeBlockers: blockers,
    perks: { ...c.perks },
    starPicks: c.starPicks,
    duel: s.duel
      ? {
          id: s.duel.id, role: s.duel.role, opponentName: s.duel.opponentName, status: s.duel.status, readyUntil: s.duel.readyUntil,
          startsAt: s.duel.startsAt, until: s.duel.until, rounds: s.duel.rounds, myAnswers: s.duel.myAnswers, opponentAnswers: s.duel.opponentAnswers,
          myReady: s.duel.myReady, opponentReady: s.duel.opponentReady, outcome: s.duel.outcome, reason: s.duel.reason,
        }
      : null,
    custody: s.custody
      ? {
          id: s.custody.id,
          releaseCost: bail,
          job: s.custody.job ? { id: s.custody.job.id, tiles: [...s.custody.job.tiles], readyAt: s.custody.job.readyAt } : null,
          availableCreditSeconds: credit.availableCreditSeconds,
          workRemainingSeconds: credit.workRemainingSeconds,
        }
      : null,
    apdCase: s.apdCase,
    apdCaseReadyAt: s.apdCaseReadyAt,
    freePursuitRespec: s.freePursuitRespec,
    activityLockUntil: s.activityLockUntil,
    checkpoint: s.checkpoint ? { id: s.checkpoint.id, target: s.checkpoint.target, options: [...s.checkpoint.options], lockedUntil: s.checkpoint.lockedUntil } : null,
    pursuit: null,
    pursuitStyle: "qte",
    gang: gangCard(s, shared, world, now),
    visibleAt: visibleAt(civ),
    bribeCost: bribeCost(s),
    manpowerMult: world.manpowerMult,
    bustEstimate: {
      fine,
      fineCeiling: fine,
      seized: seizable(civ),
      bounty: Math.round(units * INFERRED.bountyPerUnitMin),
      bountyCeiling: Math.round(units * INFERRED.bountyPerUnitMax),
    },
    arrestFine: s.arrestFine,
    bailCost: bail,
    papers: s.papers,
    processPapers: s.processPapers,
    chests: { ...s.chests },
    workers: civ.workers.map((w) => ({ siteId: w.siteId, perMinute: w.perMinute, until: w.until, earned: w.earned, kind: w.kind })),
    talentPoints: talentPoints(c),
    talentSpent: talentSpent(c),
    respecCost: respecCost(c),
    careerSwitchReadyAt: s.careerSwitchReadyAt,
    inventory: { ...c.inventory },
    crews: { ...civ.crews },
    pausedCrews: [...civ.pausedCrews],
    stats: { ...s.stats },
  };
}

/**
 * Build the snapshot. `state` must already be ticked to `now` (the store does that before
 * persisting), so the figures shown are exactly the ones saved. Prices and multipliers cover every
 * item for the current city (raw goods price 0); the world passes through untouched.
 */
export function snapshot(state: PlayerState, shared: Shared, world: World, now: number, casino: boolean): Snapshot {
  const s = state;
  const c = career(s);
  const prices: Record<ItemId, number> = {};
  const mults: Record<ItemId, number> = {};
  for (const item of ITEMS) {
    prices[item.id] = unitPrice(item.id, s.cityId, shared.market, c, now);
    mults[item.id] = Math.round(marketMultAt(shared.market[marketKey(s.cityId, item.id)], now) * 1000) / 1000;
  }
  const npcCrime = Object.fromEntries(CITIES.map((city) => [city.id, Math.round(npcCrimeAt(shared.npcCrime[city.id], now))])) as Record<CityId, number>;
  return {
    now,
    me: me(s, shared, world, now),
    prices,
    mults,
    roster: world.roster,
    gangs: world.gangs,
    online: world.online,
    headsByCity: world.headsByCity,
    feed: world.feed,
    chat: world.chat,
    chatOldestId: world.chatOldestId,
    chatRevision: world.chatRevision,
    chatGeneration: world.chatGeneration,
    dispatch: world.dispatch,
    suspects: world.suspects,
    leaderboard: world.leaderboard,
    npcCrime,
    wantedAt: CONST.wantedAt,
    pursuitFleeCost: INFERRED.pursuitFleeCost,
    casino: casino ? casinoWire(s, shared) : null,
  };
}
