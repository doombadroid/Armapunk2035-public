// Armapunk Pixel v3: the contract shared by the engine, the store, the view and the routes. The wire
// types mirror the reference game's runtime snapshot (reference/state_example.json) key for key;
// the content types mirror reference/statics.json. Nothing here does I/O.

export type CityId = "kavala" | "neochori" | "athira" | "pyrgos" | "sofia";
export type ItemId = string;
export type Faction = "civ" | "cop";
export type FactionScope = Faction | "both";
export type LicenseId = string;
export type SkillId = string;
export type TalentId = string;
export type StarPerkId = string;

/** Owner advantages (cheats.ts); resolved from the Steam id by the store, never on the wire. */
export interface PixelCheats {
  /** Work, patrol and arrest never check or spend stamina; the bar is pinned to its maximum. */
  unlimitedStamina: boolean;
  /** Both careers sit at the top prestige star with the picks that tier grants, minus those spent. */
  maxPrestige: boolean;
  /** The 200 ms gap between actions is not enforced, so nothing is ever refused as "Too fast". */
  noRateLimit: boolean;
}
export type ToolKind = "gather" | "process";
export type ChestRarity = "common" | "rare" | "epic" | "legendary";

// ---- content (statics.json, verbatim)

export interface CityDef { id: CityId; name: string; blurb: string; x: number; y: number; demand: number }
export interface SiteDef {
  id: string; name: string; cityId: CityId; legal: boolean; mode: ToolKind; from: string; output: ItemId;
  yield: number; stamina: number; skill: "harvesting" | "refining";
  input?: ItemId; inputPer?: number; license?: LicenseId; minLevel?: number; jackpot?: [ItemId, number, number];
}
export interface ItemDef { id: ItemId; name: string; kind: string; legal: boolean; sell: number; weight: number; illegalValue?: number }
export interface SkillDef { id: SkillId; name: string; blurb: string; faction: FactionScope; max: number; costs: number[] }
export interface LicenseDef { id: LicenseId; name: string; cost: number; legal: boolean; faction?: Faction; effect?: string }
export interface GearDef { tier: number; name: string; capacity: number; cost: number; speed: number }
export interface BackpackDef { tier: number; name: string; capacity: number; cost: number; minLevel: number }
export interface CopGearDef { tier: number; name: string; cost: number; bustBonus: number; bountyMult: number; staminaDelta: number; requires?: LicenseId; blurb: string }
export interface ToolDef { tier: number; kind: ToolKind; name: string; mult: number; cost: number; minLevel: number; blurb: string }
export interface TalentDef { id: TalentId; name: string; blurb: string; faction: FactionScope; max: number; minLevel: number; costs: number[] }
export interface CrewDef { id: string; name: string; siteId: string; cost: number; perMinute: number }
export interface ChestDef { rarity: ChestRarity; name: string; weight: number; cash: number }
export interface WorkerContractDef { minutes: number; papers: number }
export interface ProcessContractDef { minutes: number; contracts: number }
export interface PrestigeDef { max: number; cashBase: number; cashStep: number }
export interface GangDef {
  createCost: number; minLevel: number; baseCap: number; maxCap: number; maxLevel: number;
  yieldPerLevel: number; xpPerLevel: number; xpShare: number; inviteWindowMs: number; xpCurve: number[];
}
export interface StarPerkDef { id: StarPerkId; name: string; faction: FactionScope; max: number; value: number; blurb: string }

/** The reference's SSR `statics` prop, every table. */
export interface Statics {
  cities: CityDef[];
  sites: SiteDef[];
  items: ItemDef[];
  skills: SkillDef[];
  licenses: LicenseDef[];
  gear: GearDef[];
  backpacks: BackpackDef[];
  copGear: CopGearDef[];
  tools: ToolDef[];
  talents: TalentDef[];
  crews: CrewDef[];
  processRates: Record<string, number>;
  talentPointsPerLevel: number;
  xpCurve: number[];
  maxLevel: number;
  chests: ChestDef[];
  autoSellUnlockLevel: number;
  workerContracts: WorkerContractDef[];
  processContracts: ProcessContractDef[];
  processContractPaperCost: number;
  workerRateMult: number;
  workerMaxActive: number;
  paperDropChance: number;
  prestige: PrestigeDef;
  gang: GangDef;
  starPerks: StarPerkDef[];
  careerSwitchCooldownMin: number;
  travel: Record<CityId, Record<CityId, number>>;
  wantedAt: number;
  maxArrestBounty: number;
  maxCrewsPerSite: number;
  chatMaxLen: number;
}

// ---- server state (jsonb per player)

/** A contractor working a site for a fixed window (wall clock, online or not). */
export interface Worker { siteId: string; kind: ToolKind; perMinute: number; startedAt: number; until: number; lastTickAt: number; earned: number }

export interface PlayerStats {
  clicks: number; gathered: number; processed: number; sold: number; earned: number;
  busts: number; timesBusted: number; timesFled: number; timesResisted: number; jackpots: number; chestsFound: number;
}

/** Everything one career owns: "Each side has its own cash, level, licences, respec cost, prestige tier and star perks" and its own bag. */
export interface CareerState {
  cash: number;
  xp: number;
  licenses: LicenseId[];
  skills: Record<SkillId, number>;
  talents: Record<TalentId, number>;
  respecs: number;
  tools: { gather: number; process: number };
  gearTier: number;
  packTier: number;
  copGearTier: number;
  inventory: Record<ItemId, number>;
  autoSell: boolean;
  workerAutoSell: boolean;
  crews: Record<string, number>;
  pausedCrews: string[];
  crewsAt: number;
  workers: Worker[];
  prestige: number;
  starPicks: number;
  perks: Record<StarPerkId, number>;
  /** cop: the minute the salary was last paid to */
  salaryAt: number;
}

export interface RouteOption { label: string; distance: number; obstacles: number }
export interface RouteRound { id: string; prompt: string; obstacleCost: number; options: RouteOption[] }
export interface RouteAnswer { choice: number; score: number }

export type DuelStatus = "pending" | "active" | "resolved";
export type DuelOutcome = "capture" | "escape" | "cancelled";
export interface Duel {
  id: string;
  role: Faction;
  opponentId: string;
  opponentName: string;
  status: DuelStatus;
  readyUntil: number;
  startsAt: number;
  until: number;
  rounds: RouteRound[];
  myAnswers: RouteAnswer[];
  opponentAnswers: RouteAnswer[];
  myReady: boolean;
  opponentReady: boolean;
  outcome: DuelOutcome | null;
  reason: string | null;
}

export type ApdCaseStatus = "active" | "won" | "lost" | "expired";
export interface ApdCase {
  id: string; status: ApdCaseStatus; practice: boolean; targetScore: number; reward: number;
  rounds: RouteRound[]; answers: RouteAnswer[]; startsAt: number; until: number;
}

export interface PrisonJob { id: string; tiles: number[]; readyAt: number; startedAt: number }
export interface Custody {
  id: string;
  startedAt: number;
  jailedUntil: number;
  sentenceMs: number;
  fine: number;
  creditedSeconds: number;
  job: PrisonJob | null;
}

export interface CheckpointState { id: string; target: string; options: string[]; lockedUntil: number; misses: number }

export type BlackjackStatus = "playing" | "won" | "push" | "lost";
export interface BlackjackHand { deck: string[]; dealerCards: string[]; playerCards: string[]; status: BlackjackStatus; bet: number; payout: number }

export interface PlayerState {
  v: 3;
  steamId: string;
  name: string;
  createdAt: number;
  lastActionAt: number;
  /** null until the career picker ("Choose your life on Altis") */
  faction: Faction | null;
  careers: { civ: CareerState; cop: CareerState };
  cityId: CityId;
  travelTo: CityId | null;
  travelUntil: number;
  /** stamina as of staminaAt; regen is applied lazily by tick */
  stamina: number;
  staminaAt: number;
  heat: number;
  heatAt: number;
  papers: number;
  processPapers: number;
  chests: Record<ChestRarity, number>;
  stats: PlayerStats;
  careerSwitchReadyAt: number;
  activityLockUntil: number;
  custody: Custody | null;
  arrestFine: number;
  checkpoint: CheckpointState | null;
  checkpointClicks: number;
  duel: Duel | null;
  apdCase: ApdCase | null;
  apdCaseReadyAt: number;
  gangId: string | null;
  blackjack: BlackjackHand | null;
  freePursuitRespec: boolean;
  /** owner advantages, stamped from the Steam id on every load (cheats.ts); absent means none */
  cheats?: PixelCheats;
}

// ---- shared state (rows other players also read)

export interface MarketRow { mult: number; at: number }
/** key `${cityId}:${itemId}` */
export type Market = Record<string, MarketRow>;
export interface NpcCrimeRow { value: number; at: number }
export type NpcCrime = Record<CityId, NpcCrimeRow>;

export interface GangMember { steamId: string; joinedAt: number }
export interface GangRecord {
  id: string; name: string; tag: string; leaderId: string; private: boolean;
  codeSeed: string; codeBumps: number; xp: number; createdAt: number; members: GangMember[];
}

export interface PokerSeat { steamId: string; name: string; buyIn: number; faction: Faction }
export interface PokerPlayerResult { steamId: string; name: string; cards: string[]; hand: string }
export interface PokerResult { pot: number; board: string[]; players: PokerPlayerResult[]; winners: { steamId: string; payout: number }[] }
export interface PokerTable { seats: PokerSeat[]; pot: number; buyIn: number | null; minPlayers: number; lastResult: PokerResult | null }

export interface Shared { market: Market; npcCrime: NpcCrime; gangs: Record<string, GangRecord>; poker: PokerTable }

// ---- actions (the reference vocabulary, lowercase, with its payload keys)

export type Action =
  | { type: "work"; siteId: string }
  | { type: "sell"; itemId: ItemId; amount: number | "all" }
  | { type: "drop"; itemId: ItemId; amount: number | "all" }
  | { type: "travel"; cityId: CityId }
  | { type: "license"; licenseId: LicenseId }
  | { type: "skill"; skillId: SkillId }
  | { type: "talent"; talentId: TalentId }
  | { type: "starperk"; perkId: StarPerkId }
  | { type: "tool"; kind: ToolKind }
  | { type: "gear" }
  | { type: "pack" }
  | { type: "copgear" }
  | { type: "crew"; siteId: string }
  | { type: "crewpause"; siteId: string | null; paused: boolean }
  | { type: "worker"; siteId: string; minutes: number; kind: ToolKind }
  | { type: "craftcontract"; qty: number }
  | { type: "openchest"; rarity: ChestRarity }
  | { type: "autosell" }
  | { type: "workerautosell" }
  | { type: "payheat" }
  | { type: "ditch" }
  | { type: "respec" }
  | { type: "prestige" }
  | { type: "reset" }
  | { type: "faction"; faction: Faction }
  | { type: "switch"; faction: Faction }
  | { type: "bust"; targetId: string }
  | { type: "casestart"; practice: boolean }
  | { type: "caseanswer"; id: string; round: number; choice: number }
  | { type: "release" }
  | { type: "prisonstart" }
  | { type: "prisonrotate"; custodyId: string; jobId: string; tile: number }
  | { type: "prisoncomplete"; custodyId: string; jobId: string }
  | { type: "pursuitready"; id: string }
  | { type: "pursuitanswer"; id: string; round: number; choice: number }
  | { type: "pursuitsurrender"; id: string }
  | { type: "verify"; id: string; answer: string }
  | { type: "hp" }
  | { type: "chat"; text: string }
  | { type: "gangcreate"; name: string; tag: string }
  | { type: "gangjoin"; gangId: string; code: string }
  | { type: "gangleave" }
  | { type: "gangkick"; targetId: string }
  | { type: "gangprivacy"; private: boolean }
  | { type: "blackjackdeal"; bet: number }
  | { type: "blackjackhit" }
  | { type: "blackjackstand" }
  | { type: "slots"; bet: number }
  | { type: "roulette"; bet: number; choice: RouletteChoice; number: number }
  | { type: "pokerjoin"; buyIn: number }
  | { type: "pokerdeal" }
  | { type: "pokerleave" };

export type ActionType = Action["type"];
export type RouletteChoice = "red" | "black" | "even" | "odd" | "green" | "number";

/** `result` of POST /api/pixel/action, the shape the reference client reads for its pops. */
export interface ActionOk {
  ok: true;
  gained?: Record<ItemId, number>;
  cash?: number;
  xp?: number;
  papers?: number;
  chest?: ChestRarity;
  heat?: number;
  talentPoints?: number;
  message?: string;
  jackpot?: true;
  /** slots: { reels, bet, payout }; roulette: { number, color, bet, payout } */
  casino?: SlotsResult | RouletteResult;
}
export interface ActionErr { ok: false; error: string }
export type ActionResult = ActionOk | ActionErr;
export interface SlotsResult { reels: string[]; bet: number; payout: number }
export interface RouletteResult { number: number; color: "red" | "black" | "green"; bet: number; payout: number }

export type FeedKind = "bust" | "raid" | "sale" | "jackpot" | "join" | "level";
export interface FeedEvent { kind: FeedKind; text: string }

/** What apply() hands back: the ticked (or updated) save, the shared rows, feed events and the client-facing result. */
export interface ApplyOutcome { state: PlayerState; shared: Shared; events: FeedEvent[]; result: ActionResult }

// ---- wire (GET /api/pixel/state and the `snapshot` of every action)

export interface WireWorker { siteId: string; perMinute: number; until: number; earned: number; kind: ToolKind }
export interface WireDuel {
  id: string; role: Faction; opponentName: string; status: DuelStatus; readyUntil: number; startsAt: number; until: number;
  rounds: RouteRound[]; myAnswers: RouteAnswer[]; opponentAnswers: RouteAnswer[]; myReady: boolean; opponentReady: boolean;
  outcome: DuelOutcome | null; reason: string | null;
}
export interface WireCustody {
  id: string; releaseCost: number; job: { id: string; tiles: number[]; readyAt: number } | null;
  availableCreditSeconds: number; workRemainingSeconds: number;
}
export interface WireCheckpoint { id: string; target: string; options: string[]; lockedUntil: number }
export interface WireGangMember { steamId: string; name: string; level: number; prestige: number; leader: boolean; online: boolean }
export interface WireGang {
  id: string; name: string; tag: string; level: number; xp: number; xpInto: number; xpNeeded: number; cap: number;
  yieldBonus: number; xpBonus: number; isLeader: boolean; isPrivate: boolean; inviteCode: string | null; inviteExpiresAt: number;
  members: WireGangMember[];
}
export interface BustEstimate { fine: number; fineCeiling: number; seized: number; bounty: number; bountyCeiling: number }

export interface WireMe {
  steamId: string;
  name: string;
  avatarUrl: string;
  faction: Faction | null;
  cityId: CityId;
  cash: number;
  xp: number;
  level: number;
  xpInto: number;
  xpNeeded: number;
  stamina: number;
  staminaMax: number;
  staminaRegen: number;
  capacity: number;
  carried: number;
  netWorth: number;
  heat: number;
  wanted: boolean;
  jailedUntil: number;
  travelUntil: number;
  travelTo: CityId | null;
  skills: Record<SkillId, number>;
  licenses: LicenseId[];
  gearTier: number;
  copGearTier: number;
  talents: Record<TalentId, number>;
  tools: { gather: number; process: number };
  packTier: number;
  autoSell: boolean;
  workerAutoSell: boolean;
  prestige: number;
  prestigeReady: boolean;
  prestigeBlockers: string[];
  perks: Record<StarPerkId, number>;
  starPicks: number;
  duel: WireDuel | null;
  custody: WireCustody | null;
  apdCase: ApdCase | null;
  apdCaseReadyAt: number;
  freePursuitRespec: boolean;
  activityLockUntil: number;
  checkpoint: WireCheckpoint | null;
  pursuit: null;
  pursuitStyle: "qte";
  gang: WireGang | null;
  visibleAt: number;
  bribeCost: number;
  manpowerMult: number;
  bustEstimate: BustEstimate;
  arrestFine: number;
  bailCost: number;
  papers: number;
  processPapers: number;
  chests: Record<ChestRarity, number>;
  workers: WireWorker[];
  talentPoints: number;
  talentSpent: number;
  respecCost: number;
  careerSwitchReadyAt: number;
  inventory: Record<ItemId, number>;
  crews: Record<string, number>;
  pausedCrews: string[];
  stats: PlayerStats;
}

export interface RosterRow {
  steamId: string; name: string; avatarUrl: string; faction: Faction | null; cityId: CityId; level: number; prestige: number;
  gangTag?: string; netWorth: number; jailed: boolean; travelling: boolean; wanted?: boolean; heat?: number;
}
export interface GangDirectoryRow { id: string; name: string; tag: string; level: number; members: number; cap: number; leaderName: string; private: boolean }
export interface FeedRow { id: number; at: number; kind: FeedKind; steamId: string; name: string; text: string }
export interface ChatRow { id: number; at: number; steamId: string; name: string; faction: Faction | null; text: string }
export interface DispatchRow { cityId: CityId; wantedCount: number; officerCount: number; travelSeconds: number; latestSeen: number | null }
export interface SuspectRow { steamId: string; name: string; avatarUrl: string; heat: number; estValue: number; pursued: boolean }
export interface LeaderboardRow { name: string; avatarUrl: string; netWorth: number; level: number; faction: Faction | null }
export interface WireBlackjack { dealerCards: (string | null)[]; dealerScore: number | null; playerCards: string[]; playerScore: number; status: BlackjackStatus; bet: number; payout: number }
export interface WirePoker { seats: { steamId: string; name: string; buyIn: number }[]; pot: number; buyIn: number | null; minPlayers: number; lastResult: PokerResult | null }
export interface WireCasino { blackjack: WireBlackjack | null; poker: WirePoker }

export interface ChatWindow { chat: ChatRow[]; chatOldestId: number; chatRevision: number; chatGeneration: string }
export interface ChatCursor { sinceChat: number; chatRevision: number; chatGeneration: string }

/** The world the store reads around the player; the view passes it through. */
export interface World extends ChatWindow {
  roster: RosterRow[];
  gangs: GangDirectoryRow[];
  online: number;
  headsByCity: Partial<Record<CityId, number>>;
  feed: FeedRow[];
  dispatch: DispatchRow[];
  suspects: SuspectRow[];
  leaderboard: LeaderboardRow[];
  /** name / level / prestige / online for the members of the player's own gang */
  gangMembers: Record<string, { name: string; level: number; prestige: number; online: boolean }>;
  manpowerMult: number;
  avatarUrl: string;
}

export interface Snapshot extends ChatWindow {
  now: number;
  me: WireMe;
  prices: Record<ItemId, number>;
  mults: Record<ItemId, number>;
  roster: RosterRow[];
  gangs: GangDirectoryRow[];
  online: number;
  headsByCity: Partial<Record<CityId, number>>;
  feed: FeedRow[];
  dispatch: DispatchRow[];
  suspects: SuspectRow[];
  leaderboard: LeaderboardRow[];
  npcCrime: Record<CityId, number>;
  wantedAt: number;
  pursuitFleeCost: number;
  casino: WireCasino | null;
}

/** GET /api/pixel/gang?id= */
export interface WireGangProfile {
  id: string; name: string; tag: string; level: number; xp: number; xpInto: number; xpNeeded: number; cap: number;
  yieldBonus: number; xpBonus: number; createdAt: number; leaderName: string; private: boolean; isMine: boolean;
  members: WireGangMember[];
}
