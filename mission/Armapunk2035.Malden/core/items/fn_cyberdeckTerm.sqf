// Altis Life game mechanic — fictional in-game "quickhack" ability, game logic only
/*
    File: fn_cyberdeckTerm.sqf
    LooneyBin 2026-07-18: TERMINAL BREACH minigame (Cyberdeck, heavy targets).
    Type each Linux command exactly + fast before the trace lands. Cyan deck (dialog cyberdeck_term).
    BLOCKING -- returns: 1 = root/breach, 0 = trace fail, -1 = aborted.
    _difficulty: 1 = house door (3 cmds), 2 = bank vault (6), 3 = fed (9).
*/
params [["_difficulty", 1]];
disableSerialization;
// owner 2026-07-20: Breach Kit consumable -- if armed, auto-solve this breach (skip the minigame) and spend the charge.
if (AP_breachKitArmed) exitWith {AP_breachKitArmed = false;
    ["<t color='#c9e21a'>BREACH KIT</t> -- terminal auto-solved.", "basic"] spawn AP_fnc_handleMessage;
    1};

private _N   = switch (_difficulty) do { case 3: { 9 }; case 2: { 6 }; default { 3 } };
private _per = switch (_difficulty) do { case 3: { 9 }; case 2: { 11 }; default { 13 } };  // seconds budget per command
private _timeLimit = round (_N * _per * (2/3));   // base budget cut by 1/3 (owner 2026-07-21)
if (1 in (player getVariable ["AP_cdMods", []])) then { _timeLimit = _timeLimit + 4; };   // Overclock Module: +time

private _pool = ["nmap -sS 10.0.0.1","nc -zv 192.168.0.1","sudo mount /dev/sda1","ssh root@10.0.0.5",
    "hydra -l admin -P rock","chmod 777 /etc/keys","cat /etc/shadow","iptables -F",
    "kill -9 1337","rm -rf /var/lock","curl -X POST /unlock","grep -r KEY /sys",
    "./exploit --run","openssl enc -d lock","tar xzf payload.gz"];
private _p2 = +_pool;
private _cmds = [];
for "_i" from 1 to _N do {if (count _p2 isEqualTo 0) exitWith {};
    private _pick = selectRandom _p2;
    _p2 = _p2 - [_pick];
    _cmds pushBack _pick;};

// ---- HTML SURFACE (2026-08-14, first pass) ------------------------------------
// Same trade as the sequence breach: SQF still picks the commands and owns the
// budget, the page draws the terminal. Look is deliberately plain -- the game is
// right, the design pass comes later (owner).
AP_cbWebCfg = createHashMapFromArray [["cmds", _cmds], ["time", _timeLimit]];
AP_breachResult = nil;
if (!createDialog "AP_web_terminal") exitWith { -1 };
waitUntil { !isNil "AP_breachResult" || { isNull (findDisplay 937800) } };
private _r = missionNamespace getVariable ["AP_breachResult", -1];
AP_breachResult = nil;
waitUntil { isNull (findDisplay 937800) };
_r
