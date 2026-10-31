/*
    AP_fnc_cartelCfg  --  THE cartel roster for Armapunk 2035. One table, read by both the
    client and the server (mission functions exist on every machine), so there is exactly one place
    to tune a cartel.

    Replaces the inherited Altis set of four (arms / drug / oil / wongs) with the six the map
    designer marked and described in the off-map legend at x~4020, y 13229..14439. The four legacy
    global flag names are kept as ALIASES onto four of the new flags (see custom_p3ds/
    malden_cartels.sqf) so the ~30 existing benefit call sites -- shops, crafting, processing,
    loadouts, discounts -- keep working without being rewritten. New code should use the new names.

    Row: [id, displayName, flagVar, markerName, position, legacyFlagVar, payout, perk]

      id            short key, also the cartel_state PRIMARY KEY
      flagVar       global variable holding the flag object (created at runtime -- Malden's
                    mission.sqm has only mil_flag MARKERS here, no named objects like Altis had)
      markerName    ALWAYS <id>_cartel: AP_fnc_zoneCreator builds the capture trigger and
                    AP_fnc_captureCartel resolves the flag as format["%1_cartel"/"%1_flag", id],
                    so the id, the marker and the flag var must line up or a cartel silently
                    has no capture trigger (which is exactly how Grimstone/Wreckridge were dead)
      legacyFlagVar the Altis name aliased onto this flag, or "" for the two new cartels
      payout        ["items", [[class, perTick, cap], ...]]  accrues ON THE FLAG, collected there
                    ["money", amountPerTick, cap, "flag"]    accrues on the flag, collected there
                    ["money", amountPerTick, 0,   "bank"]    paid straight into the owning gang bank
      perk          [] or ["discount", <shop keys>, fraction] / ["freegas"]

    Owner decisions 2026-07-25:
      * production 1 unit per 60s tick, cap 100 -- matches the oil cartel's already-tuned figures
        (it was nerfed from 25/tick cap 250 as too generous, so a richer good must not start looser)
      * money $30,000 per 300s tick, matching the existing cartel auto-deposit
      * secondary perks 15%, matching the arms cartel's existing rebel discount. fn_getDiscount
        clamps the civilian total at 20% off, so perks cannot stack into something absurd.
      * ONLY Blacksite pays into the gang bank. Everything else is collected at the flag.

    Item classnames were resolved against core/config/fn_virtItemCfg.sqf; display names are in the
    comments so a swap is obvious. Two were a judgement call because the legend is unqualified:
    "Marijuana" -> marijuana (Reggie Cannabis) rather than marijuanam (Medicinal), and "Uranium" ->
    uraniumu (Uranium Ore) rather than uraniump (Weapon Grade), on the grounds that a cartel
    PRODUCES the raw good. Both are a one-word edit here.
*/
private _tick   = 1;        // units produced per accrual tick (60s)
private _cap    = 100;      // max units held on a flag before production stalls
private _money  = 30000;    // $ per money tick (300s)
private _mcap   = 300000;   // max $ held on a flag (~50 min) -- forces collection, prevents infinite farming
private _perk   = 0.15;     // secondary discount fraction

[
    ["ashfall", "Ashfall", "ashfall_flag", "ashfall_cartel", [6802.5, 11428.6], "drug_flag",
        ["items", [
            ["marijuana", _tick, _cap],      // Reggie Cannabis
            ["smash",  _tick, _cap]       // Smash (processed)
        ]], []],

    ["grimstone", "Grimstone", "grimstone_flag", "grimstone_cartel", [6095.4, 10760.1], "",
        ["items", [
            ["diamondf",   _tick, _cap],     // Flawless Diamond
            ["ruby",       _tick, _cap],     // Ruby
            ["goldnugget", _tick, _cap]      // Gold Nugget
        ]], []],

    ["wreckridge", "Wreckridge", "wreckridge_flag", "wreckridge_cartel", [5440.4, 10899.3], "",
        ["items", [
            ["uraniumu", _tick, _cap]        // Uranium Ore
        ]], ["discount", ["explosive", "explosives"], _perk]],

    ["boomtown", "Boomtown", "boomtown_flag", "boomtown_cartel", [5546.8, 11206.0], "oil_flag",
        ["items", [
            ["oilu",   _tick, _cap],         // Unprocessed Oil
            ["rubber", _tick, _cap]          // Rubber
        ]], ["freegas"]],

    ["bayview", "Bayview", "bayview_flag", "bayview_cartel", [7084.8, 12047.2], "wongs_flag",
        ["money", _money, _mcap, "flag"], []],

    ["blacksite", "Blacksite", "blacksite_flag", "blacksite_cartel", [7486.3, 11281.3], "arms_flag",
        ["money", _money, 0, "bank"], ["discount", ["rebel", "rebelwep", "rebcloth"], _perk]]
]
