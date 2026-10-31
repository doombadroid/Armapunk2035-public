/*
    APS_fnc_lagCheck  (LooneyBin: server-alive ack for inventory/menu opens)
    2020 client args: [player]
    The client sets AP_didServerRespond=false, calls this on the server, then waitUntil's on
    AP_didServerRespond before opening an inventory (fn_openInventory), cartel rubber, exchange, etc.
    Nothing ever set it back true (the old file was a no-op stub) -> every inventory/trunk open hit the
    5s timeout -> "Inventory opening failed... Try again." Ack the caller by setting the var true and
    pushing it to that client (proven publicVariableClient path, same as fn_garageCount).
*/
params [["_player", objNull, [objNull]]];
if (isNull _player) exitWith {};
AP_didServerRespond = true;
(owner _player) publicVariableClient "AP_didServerRespond";
