params[["_mode", -1, [0]], "_val"];
if (_mode isEqualTo - 1) exitWith {[]};

private _isAdmin = call AP_adminLevel >= 3;
private _config = [[0, "Stock Horn", 0, true, "CarHorn", -1], [1, "Cucaracha", 5000, true, "hornCucaracha", 2],
    [2, "Battle", 5000, true, "hornBattle", 3], [3, "Bicycle", 5000, true, "hornBike", 1], [4, "Roadrunner", 5000, true, "roadrunner", 1],
    [5, "Slow Bruh", 5000, true, "slowbruh", 2], [6, "Oof", 5000, true, "oofhorn", 1], [7, "1951 Tractor", 5000, true, "tractorhorn", 4.5],
    [8, "Ship Horn", 5000, true, "shiphorn", 2], [9, "Magic School Bus", 5000, true, "magicschool", 5],
    [10, "Move Bitch", 5000, true, "movebitch", 5], [11, "Discord Ping", 5000, true, "discordping", 1],
    [12, "Chainsaw", 5000, true, "chainsaw", 3], [13, "Free Real Estate", 5000, true, "realestate", 1],
    [14, "Noot Noot", 5000, true, "noothorn", 1], [15, "Train Horn", 5000, true, "trainhorn", 2],
    [16, "Michael Myers", 5000, true, "mikemyers", 5], [17, "Tactical Nuke", 5000, true, "tacnuke", 5],
    [18, "Leeroy Jenkins", 5000, true, "leeroy", 4], [19, "TS3 Poke", 5000, true, "tspoke", 1],
    [28, "God Please No", 5000, true, "godPlsNo", 1.5], [29, "Dense Mother Fucker", 5000, true, "denseMotherFucker", 3],
    [30, "Say No To Drugs", 5000, true, "noToDrugs", 1.5], [31, "Do You Really Wanna Do This?", 5000, true, "wannaDoThis", 1.6],
    [32, "Who The Hell Said That?", 5000, true, "whoSaidThat", 1.5], [33, "Send You To Jesus", 5000, true, "sendToJesus", 1.6],
    [35, "Emotional Damage", 5000, true, "emotionalDamage", 1.9], [36, "I'm gonna say it", 5000, true, "imgonnasayit", 8],
    [37, "EFN", 5000, true, "EFN", 6], [38, "Randy Marsh", 5000, true, "randymarsh", 1.5],
    [39, "Not a Big Fan", 5000, true, "notabigfan", 10], [40, "RIP George", 5000, true, "ripgeorge", 16],
    [41, "Whopper", 5000, true, "whopper", 6], [42, "Tornado Siren", 5000, true, "tornadosiren", 20],
    [43, "Ricky Spanish", 5000, true, "rickyspanish", 4], [44, "Officer Maggot", 5000, true, "officerMaggot", 19],
    [45, "Claude is a bitch", 5000, true, "hangKnocker", 4], [46, "Water", 5000, true, "water", 8],
    [47, "Glory To China", 5000, true, "glorytochina", 7.5], [48, "Open The Door", 5000, true, "openthedoor", 6]];
private "_return";
switch (_mode) do {case 0: {_return = _config;};
    case 1: {_return = []; {if ((_x select 3) || _isAdmin) then {_return pushBack _x;};}
            forEach _config;};
    case 2: {_return = -1;
            private _idx = _config findIf {(_x select 0) isEqualTo _val};
            if !(_idx isEqualTo - 1) then {_return = _config select _idx;};};
    default {[]};}; _return