/*
    AP_fnc_buyTalentPoint  (LooneyBin, owner 2026-07-16) -- BUY an extra talent point past the free cap.
    Price ladder: 1st = $1.0m, each additional +$500k (1.5m, 2.0m, ...). Capped once every talent in your
    side's tree is learnable (no point hoarding useless points). Bank-money purchase, deducted client-side
    (the learnTalent/respec precedent); the server records the count (talent_points table) and pushes the
    authoritative total back, which re-runs calTalents.
*/
// Re-plumbed 2026-08-11 for the web deck: takes an optional pre-answered confirm
// so the phone can ask in its own UI instead of stacking a native message box
// over the browser control. With it set nothing here suspends, so that form can
// be `call`ed and returns whether the sale went through.
//     [] spawn AP_fnc_buyTalentPoint;      // dialog -- unchanged, asks
//     [true] call AP_fnc_buyTalentPoint;   // deck -> returns bool
params [["_confirmed", false, [false]]];
if (!hasInterface) exitWith {false};
private _bought = missionNamespace getVariable ["AP_boughtTalents", 0];
private _price = 1000000 + (500000 * _bought);

// how big is my side's tree? once currentTalents covers it, more points are useless -- block the sale
// (getTalents self-filters by AP_effSide)
private _treeCount = count (["getTalents"] call AP_fnc_talentCfg);
if (_treeCount > 0 && {AP_currentTalents >= _treeCount}) exitWith {
    ["You already have enough points to learn every talent in your tree.", "basic"] spawn AP_fnc_handleMessage; false};

private _action = true;
if (!_confirmed) then {
    _action = [format ["Buy 1 additional talent point for $%1? (Each one you buy raises the next one's price by $500,000.)", [_price] call AP_fnc_numberText], "Buy Talent Point", "Buy", "Cancel"] call BIS_fnc_guiMessage;
};
if (!_action) exitWith {false};
if (AP_atmcash < _price) exitWith {
    [format ["You need $%1 in your BANK to buy this talent point.", [_price] call AP_fnc_numberText], "basic"] spawn AP_fnc_handleMessage; false
};
AP_atmcash = AP_atmcash - _price;
AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
AP_boughtTalents = _bought + 1;
[] call AP_fnc_calTalents;
[["buy"], "APS_fnc_talentPointsSRV", 2] spawn AP_fnc_MP;
[format ["Talent point purchased for $%1. You now have %2 bought point(s). Spend it in the Talents app.", [_price] call AP_fnc_numberText, AP_boughtTalents], "basic"] spawn AP_fnc_handleMessage;
[["-TALENTS-", player, (profileName), format ["bought talent point #%1 for $%2", AP_boughtTalents, _price]], "APS_fnc_logIt", 2] spawn AP_fnc_MP;
// refresh the open talent menu header if it's up
// the TALENTS tree repaints from the deck's own push
true
