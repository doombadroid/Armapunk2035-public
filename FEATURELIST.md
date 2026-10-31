# LooneyBin — Feature List

Full-featured Asylum-style Altis Life (deobfuscated 2020 client + 2017 serverside, rebranded). Systems present in the codebase, grouped by role/area.

## 🚔 Police (MaxSec)
- **Ranks:** Cadet → Constable → Corporal → Sergeant → Lieutenant → Captain → Chief
- **Prestige tree (cop):** Warrant Squad / Man Tracker (fugitive radius), Combat Medicine (I/V + Triage lines), Undercover (unmarked cars/air, plainclothes — **SGT+**), Mobile HQ (**SGT+**, land/air vehicle pull), Leadership (Tacticool, Allied Armory)
- **Standard MaxSec talents:** Watch Dog/Informants/Snitches/Surveillance, Traffic Cop/Highway Patrol, Show of Force (weapon unlocks), Mechanic, High Alert (alarms/trackers), First Aid/Combat Medic, Country Cop/Patrol Officer (vehicle unlocks)
- **Loadouts:** save / load custom loadouts; gear shop; weapon shop; vehicle shop
- **Policing:** arrest, restrain, escort, jail, surrender, ticketing, charges/crime, wanted list, warrants, APB
- **Search & seizure:** search player/vehicle/house, seize illegal items/tents/objects, evidence vault lock, evidence system
- **Tools:** radar / speed camera / traffic cams, deployables (cones, barriers, gates), spike strips, non-lethal, disarm, taze, backup/superior request
- **Vehicles:** marked + undercover; lights/siren; service chopper; impound
- **Medical:** combat-medic revive, medkits, bloodbag
- **Mobile HQ**, bounty collection, prestige earn, MaxTac enroll/system

## 🚑 Medic (TT)
- **Ranks:** EMR → EMT → AEMT → Paramedic → Asst Chief → Chief
- **TT prestige tree** (AEMT+)
- **Treatment:** revive, bloodbag, FAK/first aid, adrenaline shot, painkillers, set pain, rehab
- **Revive drones (AEMT+):** UAV, fly + treat (revive/bloodbag/FAK/adrenaline), shared charges + recharge, rotor lights + siren, mobile medical shop, owner gets revive $/XP
- **Vehicles/units:** medic vehicles, sirens/lights, hexes/markers, partners, dispatch/requests, repair buildings
- **Firefighter system:** signup, fire hose + gallons, axe, building fires
- **Medic earn** (revive rewards → bank)

## 🧑 Civilian
- **Gangs:** create, invite, ranks, kick, leave, disband, transfer ownership, tag, gang house, **gang garage** (add/pull/repair/refuel), gang bank/funds + history, **gang talents/perks**, **gang wars** (challenge/accept/surrender/status), **gang fortress** + boat flag
- **Cartels:** Arms / Drug / Oil / Wong's — capture + hold; perks (gathering speed, robbery payouts, black-market discount)
- **Turf wars:** capture turf, turf dealer/shops/vehicles, turf tax
- **Heists:** bank robbery (drill/safe/vault/lighthouse), Federal Reserve, Jewelry Emporium, Evidence Vault, store robbery, convoy robbery, person robbery, gas stations
- **Bounty Hunter:** Vigilante → Master BH (talents 1–8), **Honor / Skiptracer** system, request bounty, track bounty/APB, persistent bounties, capture & turn-in, civilian Hunter vehicle
- **Rebel:** Infamy system + tree, rebel weapons/vehicles, rebel license
- **Drugs:** gather + process cannabis, heroin (opium), cocaine (oyster), meth/crank/LSD/PCP; **drug runner** (ground + **air**); effects/addiction/overdose/rehab; moonshine + alcohol; smoking
- **Gathering / industry:** mining (copper, iron, diamond, gold, **uranium**, salt, sand), oil (drill/pump/process/sell), fishing (net + turtle), fungi, hunting (skin animals/scalp), wood chopping, water, metal detector + **treasure hunt**
- **Delivery missions (DP):** ground + air shipments, parcels
- **Houses:** buy, storage, upgrade, keys (manage/holders/trade), lock, lighthouse, **tax**, sell, **aging barrel**
- **Governor:** elections + voting, candidate menu, law menu, pardons, gov bank, gov tax, electric-chair execution
- **Justice:** jail, bail, post bail, **prison break**, courthouse, **trial / jury system**
- **Exchange:** player-to-player market (create listing, storage, filters, manage)
- **Progression:** standard talents, quests/missions, achievements, titles, stats, daily login bonus
- **Misc:** licenses (DMV + buy), phone hub, groups, settings, protest, camp fire, lotto, **duel arena**, time trials, UFO crash event, tutorial, passive mode

## 💰 Economy
- Cash / bank / **New Drachma**, paychecks, ATM, wire transfer, debit card, wealth tracking, admin comp
- Shops: general, weapon, vehicle, clothing, **virtual** (processed goods); market prices; chop shop (claim/sell)
- Dynamic market — cartel control shifts prices/payouts

## 🚗 Vehicles
- Buy / garage (store/pull) / impound / keys (trade/drop) / lockpick / repair / refuel / color / plate check / weight; vehicle skins (base-Arma liveries currently); chop shop

## 🌍 World & Systems
- Day/night + weather, seasonal events (Christmas tree gifts, Easter), governor world-state
- Phone menu = hub for most player features
- Admin: spectate, admin menu/cam, **admin events** (Gun Game / Battle Royale / Graveyard / PURGE — *server side STUBBED, deferred*)

## 🤖 LooneyBin / Discord (loonybot)
- **!report** — DM wizard → private per-reporter thread (Bug/Exploit or Player Report), staff-pinged
- **!link** — bind Discord ↔ player ID (once each), grants **Discord Linked** role + 500k bank incentive
- **!addperms / !removeperms / !perms** — bot admin access
- **!bug / !bugs / !resolve / !accept** — bug + feature intake → BUGS.md / features.md
- Admin console: !info, !pid, !whitelist, !comp, !srv (restart/msg/kick/ban)

> **Beta note:** while in closed beta every player loads **maxed** (1B in all progression + all trees unlocked). See `launch.md` to revert before public launch.
