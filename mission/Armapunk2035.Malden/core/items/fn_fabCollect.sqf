/*
    AP_fnc_fabCollect -- ask the server for the finished job in this machine.

    Sends nothing but the printer id. What was printed, how many, and whether it is actually done
    are all re-read server-side from the database; this cannot assert any of them. The grant only
    happens after the server has cleared the job row AND proved the clear committed, which is what
    stops a failed write from turning every scroll into a fresh batch.
*/
private _anchor = missionNamespace getVariable ["AP_fabAnchor", objNull];
if (isNull _anchor) then { _anchor = call AP_fnc_fabNear; };
if (isNull _anchor) exitWith { ["No fabricator here.", "basic"] spawn AP_fnc_handleMessage; };
if ((player distance _anchor) > 6) exitWith { ["Stand at the fabricator.", "basic"] spawn AP_fnc_handleMessage; };

[["collect", [player, _anchor getVariable ["AP_fabId", -1]]], "APS_fnc_fabSRV", 2] spawn AP_fnc_MP;
if (!isNull (findDisplay 1810)) then { closeDialog 0; };
