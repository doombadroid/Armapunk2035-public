// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_qhCfg.sqf  (AP_fnc_qhCfg)
    LooneyBin 2026-07-21: QUICKHACK CATALOGUE (Tier 1). Cyberpunk-fiction intrusion tools for the
    cyberdeck ring -- see quickhacks.md / talos.md.

    Three universal levers make these fair rather than oppressive:
      UPLOAD CHANNEL  the hack takes 1-8s during which the victim sees INTRUSION DETECTED + a bar.
                      The SERVER runs the clock (a client can't skip it) and re-validates on completion.
      TRACE WINDOW    for 10s after being hit the victim can trace back and pin the hacker's position.
      FIREWALL SLOTS  counter-chips are owned permanently but only TWO can be equipped, so nobody is
                      immune to everything.

    Cop variants are gated by AUTHORISATION (wanted / restrained / armed-and-wanted), not rarity --
    RP-legal rather than "cops get the same toys".

      [id, name, blurb, icon, side, uploadSecs, cooldown, range, needsLOS, auth, targetKind, counterChip]
      auth:       ""  none | "wanted" | "restrained" | "wantedArmed"
      targetKind: "player" | "area"
*/
params [["_side", "civ", [""]]];

// CHIP MODEL (owner 2026-07-22): EVERY civ hack is unlocked by USING its chip item -- one USE installs the
// hack PERMANENTLY into AP_cdMods (field 13 id); a second copy of the same chip is refused at install.
// Tier 1 chips are SOLD at Kabuki Electronics; everything above T1 is LOOT ONLY (one guaranteed weighted
// chip per completed fed -- see APS_fnc_qhLootSRV). Chip ids: 201 plateghost, 202-206 T4, 207-210 T1,
// 211-219 T3. Cop hacks stay authorisation-gated, no chips.
private _civ = [
    ["ping",     "Ping.exe",       "Paints a target on your map for 10s.",                  "qh_ping",     "civ", 2, 60, 150, false, "", "player", "scrambler", 207],
    ["distract", "Distract.exe",   "Sets off an alarm or a ringtone nearby. Misdirection.", "qh_distract", "civ", 1, 30,  50, false, "", "area",   "",          208],
    ["static",   "Static Burst",   "Fills a target's vision with static for 3s.",           "qh_static",   "civ", 3, 45,  60, true,  "", "player", "optic",     209],
    ["whiteout", "Whiteout",       "Deafens a target for 8s.",                              "qh_whiteout", "civ", 3, 45,  60, false, "", "player", "audio",     210],
    ["plateghost","Plate Ghost",   "Spoofs this ride's plate readout for 5 minutes.",       "qh_plateghost","civ", 3, 600, 15, false, "", "vehicle", "", 201],
    // ---- TIER 3 (owner 2026-07-21). Long channels and long cooldowns: these shape a whole engagement
    // rather than winning a fight, so they are priced in TIME rather than in raw power.
    // Sticky Fingers moved T1 -> T3 (owner 2026-07-22).
    ["sticky",   "Sticky Fingers", "Forces a holster. They can't re-draw for 3s.",          "qh_sticky",   "civ", 2, 45,  40, true,  "", "player", "hardened", 211],
    ["jam",      "Jam.exe",        "50m radio and phone blackout for 30s.",                 "qh_jam",      "civ", 4, 240,  50, false, "", "area",   "freqhop",  212],
    ["wiretap",  "Wiretap",        "Read everything a target texts for 3 minutes.",         "qh_wiretap",  "civ", 5, 300,  40, false, "", "player", "encsim",   213],
    ["crybaby",  "Crybaby",        "Fakes a 911 call wherever you are looking.",            "qh_crybaby",  "civ", 3, 240, 500, false, "", "area",   "",         214],
    ["synapse",  "Synapse Drag",   "Overloads a target's legs. No sprint for 8s.",          "qh_synapse",  "civ", 3, 60,  40, true,  "", "player", "",         215],
    ["leech",    "Leech",          "Siphons a vehicle's fuel dry from 15m.",                "qh_leech",    "civ", 4, 90,  15, false, "", "anyveh", "sealed",   216],
    ["short",    "Short Circuit",  "A 3s zap: light damage and a sparking screen.",         "qh_short",    "civ", 3, 45,  25, true,  "", "player", "surge",    217],
    ["eyespy",   "Eye Spy",        "Hijack the nearest CCTV. Watch the feed for 30s.",      "qh_eyespy",   "civ", 4, 120, 400, false, "", "area",   "",         218],
    // VALET is "area" kind on purpose: it summons the nearest EMPTY vehicle you hold keys to, resolved
    // server-side. A cursor target cannot reach 400m, and the whole point of a valet is that the car is
    // somewhere else. Requires the target to carry an Autopilot Module; an Analog Retrofit has nothing to call.
    ["valet",    "Valet Protocol", "Summons the nearest empty car you hold keys to.",       "qh_valet",    "civ", 6, 420, 400, false, "", "area",   "",         219],
    // ---- TIER 4 (owner 2026-07-21): NEVER SOLD. Each one gates on a drop-only chip (field 13), so the only
    // way onto your ring is loot. Owner 2026-07-22: chips are PERMANENT installs -- loot it once, unlocked
    // forever (the old Flatline/Puppet burn-per-cast is gone; cooldowns are the only per-use cost).
    ["gridout",  "Blackout",       "Kills every light on the block for 60 seconds.",        "qh_gridout",  "civ", 6, 900, 150, false, "", "area",   "",  202],
    ["flatline", "Flatline",       "5s full-body ragdoll.",                                 "qh_flatline", "civ", 4, 600,  25, true,  "", "player", "",  203],
    ["memhole",  "Memory Hole",    "Wipes their last two minutes. They never saw you.",     "qh_memhole",  "civ", 5, 600,  20, true,  "", "player", "",  204],
    // Chauffeur Override (moved T3 -> T4, owner 2026-07-22, drop-only chip 206): re-route an OCCUPIED car to
    // your destination. You never steer -- the autopilot does, and the driver fights back. Target needs an
    // autopilot module and NOT be an analog retrofit (both re-checked server-side).
    // 18min cooldown (owner 2026-07-23): permanence removed the per-cast cost, so the apex hacks are gated by a
    // long cooldown to keep them events rather than a 12/hr rotation -- matches their <1% drop rarity.
    ["chauffeur","Chauffeur Override","Re-route an occupied car. The autopilot drives, they wrestle.", "qh_chauffeur", "civ", 6, 1080, 60, false, "", "occupied", "", 206],
    // PUPPET STRINGS (Tier 4, drop-only chip 205). Deck-dive: your body slumps where you stand, your view
    // jumps into the car and you DRIVE it yourself through the safety governor (~80% top speed, Asimov
    // Lock on). Any damage to your meat body severs the link. The 5min cooldown is the real cost per dive.
    ["puppet",   "Puppet Strings", "Deck-dive and drive their car yourself. Your body is exposed.", "qh_puppet", "civ", 5, 1080, 60, false, "", "drivable", "", 205],
    // DETONATE (Tier 4 apex, drop-only chip 220, owner 2026-08-03). Overloads a vehicle's cell and blows
    // it -- the only LETHAL quickhack in the catalogue, so it is fenced differently from everything else:
    //   * 4s upload, then a further 3s ARMED fuse during which the SERVER re-checks that the hacker is
    //     alive, inside 20m and still holding line of sight. Break any of the three and it defuses.
    //     That positional hold IS the counterplay -- there is no counter chip (field 12 empty).
    //   * 2h cooldown, and unlike every other hack it is enforced SERVER-side and persisted to
    //     players.qh_cooldowns, because a client-side 2h gate is cleared by relogging.
    //   * anyveh: Car/Air/Ship/Tank. A heli is legal but you must hold 20m + LOS on it for 3s, which in
    //     practice means landed or hovering low -- the range limit is what keeps it off aircraft.
    //   * 20m range against a 10m blast: cast close and you die with them. That dial is deliberate.
    ["detonate", "Detonate",      "Overloads a vehicle's cell. Hold the link or it fizzles.", "qh_detonate", "civ", 4, 7200, 20, true, "", "anyveh", "", 220]
];
// field 13: required AP_cdMods id -- EVERY civ hack gates on its installed chip (client fn_qhCast + server
// fn_qhSRV both re-check). USE the chip item once -> permanent install; duplicates refused in fn_useItem.

private _cop = [
    ["pursuit",  "Pursuit Tag",     "Paints a WANTED suspect on your map for 10s.",         "qh_pursuit",  "cop", 2, 60, 150, false, "wanted",      "player", "scrambler"],
    ["pa",       "PA Override",     "Speak through a nearby vehicle's speakers.",           "qh_pa",       "cop", 1, 30,  50, false, "",            "area",   ""],
    ["dazzle",   "Dazzle Protocol", "Static burst -- pursuit only.",                        "qh_dazzle",   "cop", 3, 45,  60, true,  "wanted",      "player", "optic"],
    ["silence",  "Silence Cell",    "Mutes a restrained suspect's radio and phone.",        "qh_silence",  "cop", 2, 45,  15, false, "restrained",  "player", "audio"],
    ["interlock","Safety Interlock","Compliance tool: forces a wanted, armed suspect to holster.", "qh_interlock", "cop", 2, 45, 40, true, "wantedArmed", "player", "hardened"],
    // ---- TIER 3 MaxSec counterparts (owner 2026-07-21). Same mechanics, lawful framing, authorisation-gated.
    ["blackout", "Negotiation Blackout","Kills comms in a standoff. Forces them to talk face to face.", "qh_blackout", "cop", 4, 240,  50, false, "",       "area",   "freqhop"],
    ["warranttap","Warrant Tap",   "Reads a wanted suspect's texts for 3 minutes.",         "qh_warranttap","cop", 5, 300,  40, false, "wanted", "player", "encsim"],
    ["decoy",    "Decoy Unit",     "Drops a fake patrol blip onto illegal scanners.",       "qh_decoy",    "cop", 2, 240, 500, false, "",       "area",   ""],
    ["recall",   "Impound Recall", "Drives an abandoned vehicle to you for impound.",       "qh_recall",   "cop", 6, 420, 400, false, "",       "area",   ""]
];

switch (toLower _side) do {case "cop": { _cop };
    case "all": { _civ + _cop };
    default    { _civ };};
