# Armapunk Pixel — v3: LITERAL 1:1 clone (owner 2026-09-10, fourth time: "I want a literal 1:1 of asylum pixel to then edit")

Supersedes the v1 rebuild and the v2 "1:1 balance pass". Both kept a Malden rename layer (towns, glitter,
own copy, "structure only" UI). v3 removes every layer: the reference game's cities, site ids, item names,
blurbs, guide copy, UI strings, Tailwind classes, layout, theme tokens and numbers ship verbatim. The owner
edits afterwards. **Sanctioned differences (the whole list):** the brand string in the h1 / `<title>`
("Armapunk Pixel"), the API base (`/api/pixel/`), our Steam session + our Postgres, the portal shell
around the page. Anything else that differs is a bug and must be listed in the hand-off.

Reference material (never delete): `~/archive/asylum-pixel-ref-20260910/`
- `work/AsylumPixel.deminified.jsx` — their entire page as JSX (Babel de-minified from the Turbopack chunk
  by `work/deminify.js`; classes, strings, icons, hooks, polling, action dispatch all verbatim; minified
  component names). `work/component_map.json` = each function → line range + first strings.
- `work/ui/*.jsx` — their shadcn (**Base UI** flavour, `@base-ui/react`) wrappers: Button (cva variants),
  Input, Switch, Table*, Tabs*, Select*, Sheet*, Dialog*, AlertDialog*, Pagination, DateValue, FMT.
  Badge and useToast were not captured (use shadcn's Badge classes; toast → sonner).
- `work/theme.css` — their Tailwind v4 theme vars, `:root` (light) and `.dark` token sets, custom
  utilities (`h-below-topbar`, `bg-surface`, `text-primary-emphasis`, `border-border-subtle`, …).
- `work/reference_strings.json` / `work/reference_classes.json` — every string / className literal.
- `work/statics.json` — the SSR `statics` prop (every data table). In-repo copy:
  `website/src/lib/pixel/reference/statics.json`.
- `api_state.json` (runtime shape, the owner's own save) → sanitized `website/src/lib/pixel/reference/state_example.json`.
- `work/deminify_report.json` — action vocabulary with payload keys (46 actions), styled-jsx CSS blocks.
- `source_rules.md`, `mechanics_notes.md`, `source_data.json` — every displayed formula and every
  server-side unknown (marked NOT IN BUNDLE) with the fitted inference.
- `site/0adewzh162m6n.css` — their compiled CSS (check how `dark:` variants compile).

## Contract (both lanes build to this; it is the reference's own wire format)

- `GET /api/pixel/state?sinceChat=&chatRevision=&chatGeneration=` → snapshot exactly like
  `state_example.json`: `{ now, me, prices, mults, roster, gangs, online, headsByCity, feed, chat,
  chatOldestId, chatRevision, chatGeneration, dispatch, suspects, leaderboard, npcCrime, wantedAt,
  pursuitFleeCost, casino }`. `me` carries all 66 keys of the example (null/0/[] when not applicable).
- `POST /api/pixel/action` body `{ type, ...payload, sinceChat, chatRevision, chatGeneration }` →
  `{ snapshot, result }`, `result = { ok: true, gained?: {itemId: n}, cash?, xp?, papers?, chest?: rarity,
  heat?, talentPoints?, message?, jackpot?: true } | { ok: false, error }`; HTTP 4xx with `{ error }` for
  rejected/unknown; 429 with `Retry-After` for the rate limit.
- Action types + payload keys (verbatim, lowercase): see `deminify_report.json.actionCalls`
  (`work {siteId}`, `sell {itemId, amount}`, `drop {itemId, amount}`, `travel {cityId}`, `license
  {licenseId}`, `skill {skillId}`, `talent {talentId}`, `starperk {perkId}`, `tool {kind}`, `gear`,
  `pack`, `copgear`, `crew {siteId}`, `crewpause {siteId, paused}`, `worker {siteId, minutes, kind}`,
  `craftcontract {qty}`, `openchest {rarity}`, `autosell`, `workerautosell`, `payheat`, `ditch`,
  `respec`, `prestige`, `reset`, `faction {faction}`, `switch {faction}`, `bust {targetId}`, `casestart
  {practice}`, `caseanswer {id, round, choice}`, `release`, `prisonstart`, `prisonrotate {custodyId,
  jobId, tile}`, `prisoncomplete {custodyId, jobId}`, `pursuitready {id}`, `pursuitanswer {id, round,
  choice}`, `pursuitsurrender {id}`, `verify {id, answer}`, `hp`, `chat {text}`, `gangcreate {name,
  tag}`, `gangjoin {gangId, code}`, `gangleave`, `gangkick {targetId}`, `gangprivacy {private}`,
  `blackjackdeal {bet}`, `blackjackhit`, `blackjackstand`, `slots {bet}`, `roulette {bet, choice,
  number}`, `pokerjoin {buyIn}`, `pokerdeal`, `pokerleave`).
- Page props: `statics` (= `reference/statics.json`, verbatim) and `canAccessCasino` (true).
- `GET /api/pixel/gang?id=` → gang detail (`{ id, name, tag, level, members: [{steamId, name, level,
  faction, isLeader}], createdAt, leaderName, cap, private }` per the client's use) or `{ error }`.

## Lanes (parallel)

**C — client port** (`website/src/components/pixel/**`, `website/src/components/pixel/ui/**`,
`website/src/app/pixel/page.tsx`, `website/src/app/globals.css` pixel block, `website/package.json`):
turn `AsylumPixel.deminified.jsx` into typed TSX files with meaningful names, byte-identical classes and
strings; port the Base UI shadcn wrappers; their theme tokens + Geist fonts scoped to the page; nuqs tab
state; fidelity tests (our strings ⊆ theirs, our classes ⊆ theirs).

**S — server** (`website/src/lib/pixel/**`, `website/src/app/api/pixel/**`, `website/sql/pg/**`):
content verbatim from `statics.json` (ids untouched: `kav_apple`, Kavala, Pixie Dust), engine producing
the exact `me` shape, all 46 actions (civ complete; cop / gang / casino / prison / checkpoint / pursuit
as far as a solo player can drive them, with the reference's own error strings), store with roster /
feed / chat / leaderboard / gangs / casino tables, the two routes + gang route.

**I — integration** (after both): `npm run build`, `npm test`, deploy `website/deploy/push-96.sh`, smoke,
owner eyeballs `/pixel` next to the reference.

## Verification

- `cd website && npm test` — engine + content + fidelity suites green; `npm run build` clean.
- Fidelity: every JSX text / string literal under `components/pixel` is in `reference_strings.json`
  (allowlist: the brand string), every className token set is in `reference_classes.json`.
- Content: `content.ts` tables deep-equal `reference/statics.json`.
- Shape: `view()` output keys deep-equal `state_example.json` keys (recursively for `me`).
- Deploy smoke as v1 (owner 200 / non-owner 404 / bad action 400) + a `work` round-trip.
