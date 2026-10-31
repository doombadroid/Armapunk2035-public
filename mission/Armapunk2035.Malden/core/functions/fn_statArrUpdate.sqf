params[["_item", "", [""]], ["_value", -1, [0]], ["_statArr", [], [[]]]];
if !(_statArr isEqualTo[]) exitWith {{_x call AP_fnc_statArrUpdate}
    forEach _statArr;};
if (_item isEqualTo "" || _value isEqualTo - 1) exitWith {};
// Stat-slot lookup. This was a 153-arm `switch (toLower _item)` whose every arm was a bare
// string -> slot-index constant, so it is now one HashMap built once on first use.
// It returns a Number, not an array, so there is nothing a caller can mutate and no copy is
// needed (contrast fn_recipeDetail, where a shared row WOULD be mutated by fn_craftRecipe).
// Several names are deliberate aliases onto one slot -- 153 names, 139 distinct slots.
if (isNil "AP_statSlotMap") then {AP_statSlotMap = createHashMapFromArray [
        ["copkills", 0], ["defibs", 1], ["picksuccess", 2], ["pickfail", 3], ["prisontime", 4], ["speedbomb", 5],
        ["suivest", 6], ["bankdrill", 7], ["goldsold", 8], ["adrenaline", 9], ["coffee", 10], ["redgull", 11],
        ["boltcut", 12], ["bloodbag", 13], ["berries", 14], ["kebab", 15], ["meatcooked", 16], ["fuelcans", 17],
        ["toxicslurry", 18], ["redshift", 19], ["ironore", 20], ["diamondf", 21], ["donuts", 22], ["glitterbase", 23],
        ["glitter", 24], ["lacebase", 25], ["blacklace", 26], ["treasure", 28], ["marijuana", 29],
        ["manflesh", 30], ["manfleshp", 30], ["wreckexcavate", 31], ["moonshine", 32], ["scotch_0", 33], ["scotch_1", 33],
        ["scotch_2", 33], ["scotch_3", 33], ["shank", 34], ["salt_r", 35], ["rubber", 36], ["plates", 37],
        ["timber", 38], ["timberh", 38], ["timber1", 38], ["fishcaught", 39], ["salema", 40], ["ornate", 40],
        ["mackerel", 40], ["mullet", 40], ["catshark", 40], ["tuna", 40], ["vehiclesbought", 41], ["turtles", 42],
        ["ziptied", 43], ["oilp", 44], ["bankmoney", 45], ["evidencesdone", 46], ["gasrob", 47], ["casinoloss", 48],
        ["casinogain", 49], ["lottoloss", 50], ["lottowin", 51], ["moneypickedup", 52], ["silverpiece", 53], ["doubloon", 53],
        ["ruby", 53], ["gasrobmoney", 54], ["vehchop", 55], ["vehclaim", 56], ["fugitivearrested", 57],
        ["ticketspaid", 58], ["ticketspaidamount", 59], ["ticketsgiven", 60], ["ticketsgivenamount", 61], ["normquests_completed", 66], ["seasquests_completed", 67],
        ["blacklaceprime_proc", 68], ["blacklaceprime_sold", 69], ["uranium_proc", 70], ["uranium_sold", 71], ["smashbrick_proc", 72], ["smashbrick_sold", 73],
        ["rpg_vehhits", 74], ["civ_cops_downed", 75], ["civ_cops_restrained", 76], ["civ_cops_grenaded", 77], ["civ_cops_maxtackilled", 78], ["civ_cops_headshots", 79],
        ["warkill_headshots", 80], ["civ_cops_vested", 81], ["civ_cops_speedbombed", 82], ["turfscaptured", 83], ["cartelscaptured", 84], ["drugrunnerplanes", 85],
        ["drugrunnerboats", 86], ["boltcutted", 87], ["weaponscrafted", 88], ["vehiclescrafted", 89], ["moneyspentrebel", 90], ["moneyspentbail", 91],
        ["moneyspenthouses", 92], ["fedsafeopened", 93], ["killsbyarmedoffroad", 94], ["killsbyarmedquil", 95], ["killsbyarmedjeep", 96], ["moneyearnedcop", 97],
        ["moneyearnedmedic", 98], ["moonshine_proc", 99], ["moonshine_sold", 100], ["moonshinep_proc", 101], ["moonshinep_sold", 102], ["distancewalked", 103],
        ["distancedrove", 104], ["graveyardwon", 105], ["battleroyalewon", 106], ["gungamewon", 107], ["barley", 108], ["corn", 109],
        ["blackjackwon", 114], ["blackjacklost", 115],
        ["slotswon", 116], ["slotslost", 117], ["prisonsdone", 118], ["convoysdone", 119], ["convoymoneyearned", 120], ["banksdone", 121],
        ["bankmoneystolen", 122], ["loonybinbreached", 123], ["executedelectricchair", 124], ["pardonedbygov", 125], ["ignitionbomb", 127], ["giveawaymoneywon", 129],
        ["loginbonusopened", 130], ["housefirecompleted", 131], ["jewelrycasesopened", 132], ["jewelrydrilled", 133], ["remotecarexplosive", 134], ["moneyspentelectricbill", 135],
        ["gangfortresscapped", 136], ["cryptocoinssold", 137], ["jewelryscompleted", 138], ["copskilledjewelry", 139], ["remoteenginekillswitch", 143]];};
private _index = AP_statSlotMap getOrDefault [toLower _item, -1];
if (_index isEqualTo - 1) exitWith {};
// singleevh.md Phase 3a: flag ON -> accumulate the delta in the AP_stats_dirty hashMap (double-buffered,
// durable-flushed). Flag OFF -> the legacy 148-slot accumulator, byte-for-byte unchanged.
if (AP_useStatBuffer) then {AP_stats_dirty set [_index, (AP_stats_dirty getOrDefault [_index, 0]) + _value];   // delta -> flush buffer
    AP_stats_live  set [_index, (AP_stats_live  getOrDefault [_index, 0]) + _value];   // absolute -> live reads (Phase 3a.2)
} else {APV_tempStats set[_index, ((APV_tempStats select _index) + _value)];};