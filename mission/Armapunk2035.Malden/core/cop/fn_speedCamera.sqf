params[["_locationName", "", [""]], ["_speed", 0, [0]], ["_limit", 0, [0]]];
private _ticketPrice = 5;
if (_speed < (_limit + 7)) exitWith {};
if (isNull objectParent player) exitWith {};
if (driver(vehicle player) != player) exitWith {};
if !((vehicle player) isKindOf "Car") exitWith {};
private _ticket = format["<t align='center'><t size='1.5' color='#FF0000'>Speeding Ticket</t><br/><br/><t size='1.25'>Current Speed: <br/>%1 km/h<br/>Speed Limit: <br/>%2 km/h<br/><br/></t><t size='0.8'>You have been photographed by a speed camera and the fine of $%3 has automatically been deducted from your bank account.</t>", round _speed, _limit, _ticketPrice];
playSound "camera";
if !(license_civ_driver) then {
    _ticket = format["<t align='center'><t size='1.5' color='#FF0000'>Speeding Ticket</t><br/><br/><t size='1.25'>Current Speed: <br/>%1 km/h<br/>Speed Limit: <br/>%2 km/h<br/>Charge Added:<br/>Driving without a license<br/><br/></t><t size='0.8'>You have been photographed by a speed camera and the fine has of $%3 automatically been deducted from your bank account. You have received an additional fine for driving without a license.</t>", round _speed, _limit, _ticketPrice];
    [[41, player], "APS_fnc_wantedAdd", 2] spawn AP_fnc_MP;};
[_ticket, "speedingticket"] spawn AP_fnc_handleMessage;
if (AP_atmcash >= _ticketPrice) then {AP_atmcash = (round(AP_atmcash - _ticketPrice)) max 0;
    AP_atmcashCacheB = ((AP_atmcash / 4) + 11);
    [1] call AP_fnc_ClupdatePartial;};
private _dir = call {private _heading = getDir player;
    if (_heading >= 338) exitWith {"heading North"};
    if (_heading <= 23) exitWith {"heading North"};
    if (_heading <= 68) exitWith {"heading North East"};
    if (_heading <= 113) exitWith {"heading East"};
    if (_heading <= 158) exitWith {"heading South East"};
    if (_heading <= 203) exitWith {"heading South"};
    if (_heading <= 248) exitWith {"heading South West"};
    if (_heading <= 293) exitWith {"heading West"};
    if (_heading <= 338) exitWith {"heading North West"};"heading some unknown direction";};
private _vehicleName = getText(configFile >> "CfgVehicles" >> (typeOf vehicle player) >> "displayName");
private _aOrAn =
if ((toLower _vehicleName) select[0, 1] in ["a", "e", "i", "o", "u"]) then {"an"} else {"a"};
["action", "runspeedcam", 1] spawn AP_fnc_handleQuest; [
    [format["%1 was seen speeding (%2 kph) in %3 %4 near %5 %6", profileName, ceil _speed, _aOrAn, _vehicleName, _locationName, _dir], "basic"], "AP_fnc_handleMessage", west] spawn AP_fnc_MP;