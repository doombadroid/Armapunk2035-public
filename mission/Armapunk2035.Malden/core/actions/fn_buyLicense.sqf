params["", "", "", "_type"];
private _price = ["getPrice", _type] call AP_fnc_licenseCfg;
private _licenseName = ["getName", _type] call AP_fnc_licenseCfg;
private _side =
switch (AP_effSide) do {case (civilian): {"civ"};
    case (west): {"cop"};
    case (independent): {"med"};}; if (_type isEqualTo "bounty" && {getPlayerUID player in AP_revokedBH}) exitWith {
    ["Your bounty hunter license was revoked recently by MaxSec. You will be able to repurchase this license after server restart.", "basic"] spawn AP_fnc_handleMessage;
};
if !([_price] call AP_fnc_debitCard) exitWith {};
titleText[format["You bought a %1 for $%2", _licenseName, [_price] call AP_fnc_numberText], "PLAIN"];
PlaySound "purchase";
missionNamespace setVariable[format["license_%1_%2", _side, _type], true];
["action", format ["buylicense_%1", _type], 1] call AP_fnc_handleQuest;   // owner 2026-07-11: Parole Papers step 3 (+ future license quests)
if (_type isEqualTo "bounty" && license_civ_rebel) then {missionNamespace setVariable["license_civ_rebel", false];};
if (_type isEqualTo "rebel" && license_civ_bounty) then {missionNamespace setVariable["license_civ_bounty", false];
    player setVariable["AP_isBountyHunter", false, true];};
if (_type isEqualTo "bounty") then {
    [format["You are a bounty hunter, %1!<br/><br/>As a <t color='#FF0000'>bounty hunter</t> you must adhere to certain rules or risk the removal of your license or possibly even being banned from the server.<br/><br/><t color='#FF0000'>It is very important</t> to understand that you are still a civilian, and must obey all rules other civilians do.  Shooting another player to stun them with rubber bullets is still considered RDM if you do not engage verbally first with a warning. Do not attack unprovoked, even to stun, and always give them a chance to comply before opening fire.<br/><br/>As a bounty hunter you are not to interfere when MaxSec are present, your job is to bring in criminals when <t color='#00FF00'>police forces are not present</t>.<br/><br/>", [profileName] call AP_fnc_cleanName], "policerecruit"] spawn AP_fnc_handleMessage;
};
[2] call AP_fnc_ClupdatePartial;
if (license_civ_bounty) then {player setVariable["AP_isBountyHunter", true, true];}