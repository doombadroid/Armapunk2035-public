AP_currentTalents =
switch (true) do {case (AP_side_exp >= 14200): {28};
    case (AP_side_exp >= 13000): {27};
    case (AP_side_exp >= 12000): {26};
    case (AP_side_exp >= 11000): {25};
    case (AP_side_exp >= 10400): {24};
    case (AP_side_exp >= 9500): {23};
    case (AP_side_exp >= 8700): {22};
    case (AP_side_exp >= 8000): {21};
    case (AP_side_exp >= 7200): {20};
    case (AP_side_exp >= 6500): {19};
    case (AP_side_exp >= 5900): {18};
    case (AP_side_exp >= 5200): {17};
    case (AP_side_exp >= 4600): {16};
    case (AP_side_exp >= 4100): {15};
    case (AP_side_exp >= 3500): {14};
    case (AP_side_exp >= 3100): {13};
    case (AP_side_exp >= 2600): {12};
    case (AP_side_exp >= 2200): {11};
    case (AP_side_exp >= 1800): {10};
    case (AP_side_exp >= 1500): {9};
    case (AP_side_exp >= 1200): {8};
    case (AP_side_exp >= 920): {7};
    case (AP_side_exp >= 690): {6};
    case (AP_side_exp >= 490): {5};
    case (AP_side_exp >= 320): {4};
    case (AP_side_exp >= 190): {3};
    case (AP_side_exp >= 97): {2};
    case (AP_side_exp >= 36): {1};
    default {0};};
// owner 2026-06-24: MAX TALENT POINTS baked in PERMANENTLY -- grant the FULL per-side cap regardless of XP (no grind)
// and independent of beta god-stats (AP_betaMaxStats), so it survives public launch. The XP switch above is now
// vestigial (overridden). To restore XP-earned points later, change these back to selectMin[AP_currentTalents, CAP].
if (AP_effSide isEqualTo west) then {AP_currentTalents = AP_maxTalents};
if (AP_effSide isEqualTo independent) then {AP_currentTalents = 16};
if (AP_effSide isEqualTo civilian) then {AP_currentTalents = 20};
// LooneyBin 2026-07-16: BUYABLE TALENT POINTS -- purchased extras (talent_points table, loaded at login via
// APS_fnc_talentPointsSRV -> AP_fnc_talentPointsRecv) stack on top of the free cap. The menu's Points cap
// display tracks up with it.
private _boughtPts = missionNamespace getVariable ["AP_boughtTalents", 0];
AP_currentTalents = AP_currentTalents + _boughtPts;
if (!isNil "AP_maxTalents") then { AP_maxTalents = AP_maxTalents max AP_currentTalents; };
AP_currentTalents;