/*
    File: fn_factionPerkCfg.sqf  (AP_fnc_factionPerkCfg)

    Faction perks. See FACTION_REP_SPEC.md section 5.

    Row shape, deliberately the same as fn_talentCfg.sqf's so this reads as the
    same kind of thing:

        [_id, _faction, _parent, _cost, _name, _description]

    _id       unique across faction perks. Stored in AP_faction_talents and checked
              at the point of use as `id in AP_faction_talents` -- identical to how
              every existing talent gate in this mission works, so no gameplay code
              needs a new idiom.
    _faction  the faction id from fn_factionCfg.sqf that must be the player's
              PRIMARY for this perk to apply. Not merely "standing above n": the
              gate is relative, which is what makes allegiance cost something.
    _parent   prerequisite perk id, or -1 for a root. Same as talents.
    _cost     points, from AP_fnc_calFactionTalents.

    IDS START AT 9000 to stay clear of fn_talentCfg.sqf's range. These are checked
    against a DIFFERENT array (AP_faction_talents, not AP_side_talents), so a
    collision would not actually misfire -- but a reader seeing `9001 in ...` should
    never have to work out which of two systems owns it.

    THESE ARE PLACEHOLDERS, deliberately modest. Standing is new, unbalanced, and
    untested against real play; shipping powerful perks off an untuned curve is how
    a progression system gets nerfed in week two and feels bad forever after. Each
    is a small, legible economic edge rather than a capability nobody can counter.

    AND NONE OF THEM DOES ANYTHING YET. Say it here rather than let someone infer
    it from the descriptions: AP_fnc_hasFactionPerk has ZERO call sites in gameplay
    code (grepped across mission/ and server/, 2026-08-30). Points accrue, the perk
    is bought, the id is stored in AP_faction_talents and persisted -- and no rule
    anywhere reads it. Every description below is therefore a PROMISE, not a
    behaviour. Wiring each one means adding the `id in AP_faction_talents` check at
    the site that owns that rule, exactly as the side-talent gates do; until then
    this tree must not be surfaced to players as a thing they can spend on, because
    it would take their points and give them nothing.

    The 2026-08-30 rethemes changed NAMES AND TEXT ONLY. Ids and tier costs are
    untouched, because an id is what a bought perk is stored as -- renumbering
    would silently hand players a different perk than the one they paid for. The
    faction each block belongs to is likewise unchanged: 9001-9003 have always been
    f_neon, 9101-9103 f_dock, 9201-9203 f_maxsec, 9301-9303 f_pharma, and the
    factions were named around that rather than the other way round.

    Usage:
        ["all"]                call AP_fnc_factionPerkCfg -> every row
        ["byFaction","f_neon"] call AP_fnc_factionPerkCfg -> that faction's rows
        ["byId", 9001]         call AP_fnc_factionPerkCfg -> the row, or []
*/
params [["_mode", "", [""]], ["_arg", "", ["", 0]]];

private _perks = [
    // ---- f_neon = LIGHTRUNNERS (Nero, Larche): information and movement
    [9001, "f_neon",   -1,   1, "Contacts",       "Fixer job payouts from the Lightrunners are 10% higher."],
    [9002, "f_neon",   9001, 2, "Backchannel",    "Lightrunner contracts refresh on a shorter timer."],
    [9003, "f_neon",   9002, 3, "Ghosted",        "Your name is withheld from Lightrunner territory reports."],

    // ---- f_dock = CRUSADERS (Pope, Chapoi): the work, and absolution for it
    [9101, "f_dock",   -1,   1, "Congregation",   "Crusader contracts pay 10% more."],
    [9102, "f_dock",   9101, 2, "Penance",        "One Crusader contract failure a day is forgiven -- no standing lost."],
    [9103, "f_dock",   9102, 3, "Last Rites",     "Dying inside Crusader territory costs you no standing with Pope."],

    // ---- f_maxsec = RESERVED. No faction is named here yet, so these carry no
    // flavour of their own -- naming them would attach the reserved slot to a
    // theme before anyone has decided what it is.
    [9201, "f_maxsec", -1,   1, "Retained",       "Reserved. Payouts from this faction are 10% higher."],
    [9202, "f_maxsec", 9201, 2, "Briefed",        "Reserved. Quest markers from this faction are visible to your group."],
    [9203, "f_maxsec", 9202, 3, "Cleared",        "Reserved. Access this faction's restricted contract board."],

    // ---- f_pharma = SILENT PARTNERS (The Administrator, La Port): logistics,
    // leverage and deniability
    [9301, "f_pharma", -1,   1, "On Retainer",    "Silent Partner contracts pay 10% more."],
    [9302, "f_pharma", 9301, 2, "Manifest",       "Carry 10% more weight while a Silent Partner delivery is active."],
    [9303, "f_pharma", 9302, 3, "No Paper Trail", "Silent Partner contracts completed with no witnesses pay a bonus."]
];


switch (toLower _mode) do {
    case "all": { _perks };
    case "byfaction": { _perks select { (_x select 1) isEqualTo _arg } };
    case "byid": {
        private _i = _perks findIf { (_x select 0) isEqualTo _arg };
        if (_i isEqualTo -1) then { [] } else { _perks select _i }
    };
    default {
        diag_log format ["[AP][faction] factionPerkCfg: unknown mode '%1'", _mode];
        []
    };
};
