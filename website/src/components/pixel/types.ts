// Armapunk Pixel v3 client types. Derived from the reference wire format
// (`website/src/lib/pixel/reference/statics.json` = the `statics` page prop,
// `state_example.json` = a GET /api/pixel/state snapshot) and from how the reference
// page reads them. Lane S (server) conforms to these shapes.

export type Faction = "civ" | "cop";
export type FactionScope = Faction | "both";
export type SiteMode = "gather" | "process";
export type ChestRarity = "common" | "rare" | "epic" | "legendary";
export type Connection = "connecting" | "connected" | "reconnecting" | "offline";

// ---------------------------------------------------------------------------
// statics (page prop)
// ---------------------------------------------------------------------------

export interface City {
  id: string;
  name: string;
  blurb: string;
  x: number;
  y: number;
  demand: number;
}

export interface Site {
  id: string;
  name: string;
  cityId: string;
  legal: boolean;
  mode: SiteMode;
  from: string;
  output: string;
  input?: string;
  inputPer?: number;
  yield: number;
  stamina: number;
  skill: string;
  license?: string;
  minLevel?: number;
  jackpot?: [string, number, number];
}

export interface Item {
  id: string;
  name: string;
  kind: string;
  legal: boolean;
  sell: number;
  weight: number;
  illegalValue?: number;
}

export interface Skill {
  id: string;
  name: string;
  blurb: string;
  faction: FactionScope;
  max: number;
  costs: number[];
}

export interface License {
  id: string;
  name: string;
  cost: number;
  legal: boolean;
  faction?: Faction;
  effect?: string;
}

export interface Gear {
  tier: number;
  name: string;
  capacity: number;
  cost: number;
  speed: number;
}

export interface Backpack {
  tier: number;
  name: string;
  capacity: number;
  cost: number;
  minLevel: number;
}

export interface CopGear {
  tier: number;
  name: string;
  cost: number;
  bustBonus: number;
  bountyMult: number;
  staminaDelta: number;
  blurb: string;
  requires?: string;
}

export interface Tool {
  tier: number;
  kind: SiteMode;
  name: string;
  mult: number;
  cost: number;
  minLevel: number;
  blurb: string;
}

export interface Talent {
  id: string;
  name: string;
  blurb: string;
  faction: FactionScope;
  max: number;
  minLevel: number;
  costs: number[];
}

export interface Crew {
  id: string;
  name: string;
  siteId: string;
  cost: number;
  perMinute: number;
}

export interface Chest {
  rarity: ChestRarity;
  name: string;
  weight: number;
  cash: number;
}

export interface WorkerContract {
  minutes: number;
  papers: number;
}

export interface ProcessContract {
  minutes: number;
  contracts: number;
}

export interface StarPerk {
  id: string;
  name: string;
  faction: FactionScope;
  max: number;
  value: number;
  blurb: string;
}

export interface GangStatics {
  createCost: number;
  minLevel: number;
  baseCap: number;
  maxCap: number;
  maxLevel: number;
  yieldPerLevel: number;
  xpPerLevel: number;
  xpShare: number;
  inviteWindowMs: number;
  xpCurve: number[];
}

export interface Statics {
  cities: City[];
  sites: Site[];
  items: Item[];
  skills: Skill[];
  licenses: License[];
  gear: Gear[];
  backpacks: Backpack[];
  copGear: CopGear[];
  tools: Tool[];
  talents: Talent[];
  crews: Crew[];
  processRates: Record<string, number>;
  talentPointsPerLevel: number;
  xpCurve: number[];
  maxLevel: number;
  chests: Chest[];
  autoSellUnlockLevel: number;
  workerContracts: WorkerContract[];
  processContracts: ProcessContract[];
  processContractPaperCost: number;
  workerRateMult: number;
  workerMaxActive: number;
  paperDropChance: number;
  prestige: { max: number; cashBase: number; cashStep: number };
  gang: GangStatics;
  starPerks: StarPerk[];
  careerSwitchCooldownMin: number;
  travel: Record<string, Record<string, number>>;
  wantedAt: number;
  maxArrestBounty: number;
  maxCrewsPerSite: number;
  chatMaxLen: number;
}

// ---------------------------------------------------------------------------
// snapshot (GET /api/pixel/state, POST /api/pixel/action -> { snapshot, result })
// ---------------------------------------------------------------------------

export interface RouteOption {
  label: string;
  distance: number;
  obstacles: number;
}

export interface Round {
  id: string;
  prompt: string;
  obstacleCost: number;
  options: RouteOption[];
}

export interface RoundAnswer {
  choice?: number;
  score: number;
}

export interface Duel {
  id: string;
  role: Faction;
  opponentName: string;
  status: "pending" | "active" | "resolved";
  readyUntil: number;
  startsAt: number;
  until: number;
  rounds: Round[];
  myAnswers: RoundAnswer[];
  opponentAnswers: RoundAnswer[];
  myReady: boolean;
  opponentReady: boolean;
  outcome?: "capture" | "escape" | "cancelled" | null;
  reason?: string | null;
}

export interface CustodyJob {
  id: string;
  tiles: number[];
  readyAt: number;
}

export interface Custody {
  id: string;
  job: CustodyJob | null;
  availableCreditSeconds: number;
  workRemainingSeconds: number;
  releaseCost?: number;
}

export interface ApdCase {
  id: string;
  status: "active" | "won" | "lost" | "expired";
  practice: boolean;
  targetScore: number;
  reward: number;
  rounds: Round[];
  answers: RoundAnswer[];
  startsAt: number;
  until: number;
}

export interface Checkpoint {
  id: string;
  lockedUntil: number;
  target: string;
  options: string[];
}

export interface GangMember {
  steamId: string;
  name: string;
  level: number;
  prestige: number;
  leader: boolean;
  online: boolean;
}

export interface MyGang {
  id: string;
  name: string;
  tag: string;
  level: number;
  xp: number;
  xpInto: number;
  xpNeeded: number;
  cap: number;
  yieldBonus: number;
  xpBonus: number;
  isLeader: boolean;
  isPrivate: boolean;
  inviteCode: string | null;
  inviteExpiresAt: number;
  members: GangMember[];
}

export interface BustEstimate {
  fine: number;
  fineCeiling: number;
  seized: number;
  bounty: number;
  bountyCeiling: number;
}

export interface Worker {
  siteId: string;
  perMinute: number;
  until: number;
  earned: number;
  kind: SiteMode;
}

export interface LifetimeStats {
  clicks: number;
  gathered: number;
  processed: number;
  sold: number;
  earned: number;
  busts: number;
  timesBusted: number;
  timesFled: number;
  timesResisted: number;
  jackpots: number;
  chestsFound: number;
}

export interface Me {
  steamId: string;
  name: string;
  avatarUrl: string | null;
  faction: Faction | null;
  cityId: string;
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
  travelTo: string | null;
  skills: Record<string, number>;
  licenses: string[];
  gearTier: number;
  copGearTier: number;
  talents: Record<string, number>;
  tools: Record<SiteMode, number>;
  packTier: number;
  autoSell: boolean;
  workerAutoSell: boolean;
  prestige: number;
  prestigeReady: boolean;
  prestigeBlockers: string[];
  perks: Record<string, number>;
  starPicks: number;
  duel: Duel | null;
  custody: Custody | null;
  apdCase: ApdCase | null;
  apdCaseReadyAt: number;
  freePursuitRespec: boolean;
  activityLockUntil: number;
  checkpoint: Checkpoint | null;
  pursuit: unknown;
  pursuitStyle: string;
  gang: MyGang | null;
  visibleAt: number;
  bribeCost: number;
  manpowerMult: number;
  bustEstimate: BustEstimate;
  arrestFine: number;
  bailCost: number;
  papers: number;
  processPapers: number;
  chests: Record<ChestRarity, number>;
  workers: Worker[];
  talentPoints: number;
  talentSpent: number;
  respecCost: number;
  careerSwitchReadyAt: number;
  inventory: Record<string, number>;
  crews: Record<string, number>;
  pausedCrews: string[];
  stats: LifetimeStats;
}

export interface RosterEntry {
  steamId: string;
  name: string;
  avatarUrl: string;
  faction: Faction;
  cityId: string;
  level: number;
  prestige: number;
  gangTag?: string;
  netWorth: number;
  jailed: boolean;
  travelling: boolean;
  wanted?: boolean;
  heat?: number;
}

export interface GangRow {
  id: string;
  name: string;
  tag: string;
  level: number;
  members: number;
  cap: number;
  leaderName: string;
  private: boolean;
}

export interface FeedEntry {
  id: number;
  at: number;
  kind: string;
  steamId: string;
  name: string;
  text: string;
}

export interface ChatMessage {
  id: number;
  at: number;
  steamId: string;
  name: string;
  faction: Faction;
  text: string;
}

export interface DispatchEntry {
  cityId: string;
  wantedCount: number;
  officerCount: number;
  travelSeconds: number;
  latestSeen: number | null;
}

export interface Suspect {
  steamId: string;
  name: string;
  avatarUrl: string;
  heat: number;
  estValue: number;
  pursued: boolean;
}

export interface LeaderboardEntry {
  name: string;
  avatarUrl: string;
  netWorth: number;
  level: number;
  faction: Faction;
}

export interface BlackjackState {
  status: "playing" | "won" | "push" | "lost";
  dealerCards: (string | null)[];
  dealerScore: number | null;
  playerCards: (string | null)[];
  playerScore: number | null;
  bet: number;
  payout: number;
}

export interface PokerSeat {
  steamId: string;
  name: string;
  buyIn: number;
}

export interface PokerPlayerResult {
  steamId: string;
  name: string;
  cards: string[];
  hand: string;
}

export interface PokerResult {
  pot: number;
  board: string[];
  players: PokerPlayerResult[];
  winners: { steamId: string; payout: number }[];
}

export interface PokerState {
  seats: PokerSeat[];
  pot: number;
  minPlayers: number;
  buyIn: number | null;
  lastResult: PokerResult | null;
}

export interface CasinoState {
  blackjack: BlackjackState | null;
  poker: PokerState;
}

export interface Snapshot {
  now: number;
  me: Me | null;
  prices: Record<string, number>;
  mults: Record<string, number>;
  roster: RosterEntry[];
  gangs: GangRow[];
  online: number;
  headsByCity: Record<string, number>;
  feed: FeedEntry[];
  chat: ChatMessage[];
  chatOldestId: number;
  chatRevision: number;
  chatGeneration: string;
  dispatch: DispatchEntry[];
  suspects: Suspect[];
  leaderboard: LeaderboardEntry[];
  npcCrime: Record<string, number>;
  wantedAt: number;
  pursuitFleeCost: number;
  casino: CasinoState | null;
}

// GET /api/pixel/gang?id= -> { gang: GangProfile } | { error }
export interface GangProfile {
  id: string;
  name: string;
  tag: string;
  level: number;
  xp: number;
  xpInto: number;
  xpNeeded: number;
  yieldBonus: number;
  xpBonus: number;
  cap: number;
  members: GangMember[];
  createdAt: number | string | null;
  isMine?: boolean;
}

// ---------------------------------------------------------------------------
// actions (POST /api/pixel/action body { type, ...payload, sinceChat, chatRevision, chatGeneration })
// ---------------------------------------------------------------------------

export interface ActionPayloads {
  work: { siteId: string };
  sell: { itemId: string; amount: number | "all" };
  drop: { itemId: string; amount: number | "all" };
  travel: { cityId: string };
  license: { licenseId: string };
  skill: { skillId: string };
  talent: { talentId: string };
  starperk: { perkId: string };
  tool: { kind: SiteMode };
  gear: EmptyPayload;
  pack: EmptyPayload;
  copgear: EmptyPayload;
  crew: { siteId: string };
  crewpause: { siteId: string | null; paused: boolean };
  worker: { siteId: string; minutes: number; kind: SiteMode };
  craftcontract: { qty: number };
  openchest: { rarity: ChestRarity };
  autosell: EmptyPayload;
  workerautosell: EmptyPayload;
  payheat: EmptyPayload;
  ditch: EmptyPayload;
  respec: EmptyPayload;
  prestige: EmptyPayload;
  reset: EmptyPayload;
  faction: { faction: Faction };
  switch: { faction: Faction };
  bust: { targetId: string };
  casestart: { practice: boolean };
  caseanswer: { id: string; round: number; choice: number };
  release: EmptyPayload;
  prisonstart: EmptyPayload;
  prisonrotate: { custodyId: string; jobId: string; tile: number };
  prisoncomplete: { custodyId: string; jobId: string };
  pursuitready: { id: string };
  pursuitanswer: { id: string; round: number; choice: number };
  pursuitsurrender: { id: string };
  verify: { id: string; answer: string };
  hp: EmptyPayload;
  chat: { text: string };
  gangcreate: { name: string; tag: string };
  gangjoin: { gangId: string; code: string };
  gangleave: EmptyPayload;
  gangkick: { targetId: string };
  gangprivacy: { private: boolean };
  blackjackdeal: { bet: number };
  blackjackhit: EmptyPayload;
  blackjackstand: EmptyPayload;
  slots: { bet: number };
  roulette: { bet: number; choice: string; number: number };
  pokerjoin: { buyIn: number };
  pokerdeal: EmptyPayload;
  pokerleave: EmptyPayload;
}

export type EmptyPayload = Record<string, never>;
export type ActionType = keyof ActionPayloads;

export interface CasinoOutcome {
  reels?: string[];
  number?: number;
  color?: string;
  bet?: number;
  payout?: number;
}

export type ActionResult =
  | {
      ok: true;
      gained?: Record<string, number>;
      cash?: number;
      xp?: number;
      papers?: number;
      chest?: ChestRarity;
      heat?: number;
      talentPoints?: number;
      message?: string;
      jackpot?: boolean;
      casino?: CasinoOutcome | null;
    }
  | { ok: false; error?: string };

export type Act = <T extends ActionType>(type: T, payload?: ActionPayloads[T]) => Promise<ActionResult | null>;

export type PopTone = "gain" | "cash" | "heat" | "bad" | "gold" | "xp";

export interface Pop {
  id: number;
  text: string;
  tone: PopTone;
}

export type TabId =
  | "work"
  | "casino"
  | "market"
  | "inventory"
  | "progression"
  | "upgrades"
  | "talents"
  | "gang"
  | "clan"
  | "police"
  | "guide";

export interface TabDef {
  id: TabId;
  label: string;
  icon: React.ReactNode;
  show: boolean;
}
