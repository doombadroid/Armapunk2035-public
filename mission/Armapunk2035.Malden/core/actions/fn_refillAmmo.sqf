private _startMags = count(magazinesAmmoFull[player, true]);
private _magazines = [];
private _price = 0;
private _capacity = 0;
private _boxAmmo = ["200Rnd_556x45_Box_F", "200Rnd_65x39_cased_Box", "150Rnd_762x54_Box"];
private _drumAmmo = ["150Rnd_556x45_Drum_Mag_F", "75Rnd_762x39_Mag_F", "75rnd_762x39_AK12_Lush_Mag_F", "100Rnd_65x39_caseless_black_mag"];
private _infamyFreeMags = false; {_x params["_magClassname", "_magCurrentAmmo", "_loaded"];
    if !("Grenade" in _magClassname || "Smoke" in _magClassname || "Chem" in _magClassname) then {
        _capacity = getNumber(configFile >> "CfgMagazines" >> _magClassname >> "count");
        if !(_magCurrentAmmo isEqualTo _capacity) then {if (28 in AP_infamy_talents && license_civ_rebel) exitWith {
                _infamyFreeMags = true;};
            _price = _price + 50;};
        if ((_magClassname in _drumAmmo) && !(_magCurrentAmmo isEqualTo _capacity)) then {_price = _price + 300;};
        if ((_magClassname in _boxAmmo) && !(_magCurrentAmmo isEqualTo _capacity)) then {_price = _price + 950;};
        if !(_loaded) then {_magazines pushBack _magClassname;};};}
forEach(magazinesAmmoFull[player, true]);
if (_infamyFreeMags) then {_price = _price + 1;};
if (_price isEqualTo 0) exitWith {["You don't have any mags which need refilling.", "basic"] spawn AP_fnc_handleMessage};
private _action = [format["Do you wish to pay $%1 to refill your magazines?", [_price] call AP_fnc_numberText], "Refill Magazines", "Yes", "No"] call BIS_fnc_guiMessage;
if !(_action) exitWith {};
private _startPos = getPos player;
titleText["Refilling magazines... Don't move.", "PLAIN"];
uiSleep 3;
private _curMags = count(magazinesAmmoFull[player, true]);
if ((player distance2D _startPos) > 0.5) exitWith {["Mag refilling cancelled.", "basic"] spawn AP_fnc_handleMessage;};
if !(_curMags isEqualTo _startMags) exitWith {["Mag refilling cancelled.", "basic"] spawn AP_fnc_handleMessage;};
if !([_price] call AP_fnc_debitCard) exitWith {};
player setAmmo[primaryWeapon player, 1000];
player setAmmo[handgunWeapon player, 1000]; {_x params["_magClassname", "_magCurrentAmmo"];
    if !("Grenade" in _magClassname || "Smoke" in _magClassname || "Chem" in _magClassname) then {player removeMagazine _magClassname;};}
forEach(magazinesAmmoFull[player, true]); {player addMagazine[_x, 1000];}
forEach _magazines;
titleText["All your magazines have been refilled", "PLAIN"];