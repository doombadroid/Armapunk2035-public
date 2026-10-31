# Luxe AV — owner playtest (M1 quad-rotor, deployed b2041, 2026-09-23, unplayed)

Autonomous air taxi `ap_av_lux` (addon `ap_av` in `@Armapunk2035`). Server-flown with the shared
kinematic core; passengers pick a preset helipad. Code: `server/AP_server/core/TON/fn_avSRV.sqf` (verbs),
`fn_avFly.sqf` (the flight), `mission/.../core/vehicle/fn_avClient.sqf` (passenger actions). Asset + build
pipeline: `design/av-hovercraft/` (`AV_LOG.md`, `ARMA_PLAN.md`; untracked). Kill switch `SRV_avEnabled`.

**Your client needs the updated mod** — `@Armapunk2035/addons/ap_av.pbo` (already in `radio/dist`, which
your Arma install symlinks). Any other tester without it gets "missing addon ap_av" at join.

## A. Spawn + look (one client)
1. Admin menu → vehicle spawn → **Luxe AV (autonomous)** (it is listed with the Air classes). It appears 5 m off.
2. Walk round it: nose forward, gull-wing door on the RIGHT, four ducted quad rotors on arms, sitting on its belly.
3. Night: light lines visible? (emissive strength is a first guess — say brighter/dimmer.)
4. Get in (action menu → get in as passenger). You should sit in one of four lounge seats. **Check the pose**:
   sitting ON the cushion, facing the right way (front pair faces the tail). Report if you float/sink.

## B. Door
5. Aboard, landed: **AV: open door** / **AV: close door** — the right-side gull-wing swings up and out.

## C. Flight (each destination at least once)
6. Aboard: **AV: fly to …** — six pads: Larche Helipad, North Coast Heliport, Chapoi Clinic Pad,
   La Port Helipad, West Clinic Pad, Mountain Heliport.
7. Expect: "Departing" → door shuts → rotors spin up (~2.5 s) → vertical climb → cruise (≥120 m) → vertical
   descent onto the pad → belly touchdown → rotors stop → door opens → "Arrived".
   Rotors must keep spinning the whole flight — a rotor that freezes mid-air is a bug (rotor hitpoint damage).
8. Try getting out mid-flight (should be refused — cargo is locked in flight).
9. Watch from a SECOND client on the ground: does the AV move smoothly or step? (server-flown trade-off
   you chose; this is the thing to judge.)

## D. Kill switch
10. `SRV_avEnabled = false; publicVariable "SRV_avEnabled";` (debug console, global) → the actions stop
    showing for new boardings and the server refuses requests.

## Known limits (M1)
- Engine sound is the inherited helicopter rotor sound.
- The heli sim's rotor-strike check uses the memory points `rotor_main_center` / `rotor_tail_center`
  (placed above the roof). Without them it put the virtual rotors at the origin, struck the ground
  and destroyed HitHRotor/HitVRotor within ~5 s of engine-on (fixed 2026-09-23, smoke-verified).
- Seat pose offsets are estimated from BI's sample heli; first thing to tune after A4.
- The server cannot see streamed map objects, so destinations are ONLY verified helipads. Adding one:
  `tools/map_query.py near X Y 9` must show nothing but the pad.
- Pre-existing, NOT fixed here: `APS_fnc_summonSRV` still calls `createUnit`, which `CfgDisabledCommands.hpp`
  blocks on every machine since 2026-09-07 → rotorcraft SUMMON is probably broken on .96 (owner to decide).
