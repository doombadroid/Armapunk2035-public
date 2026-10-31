params[["_type", 0, [[], 0]], ["_message", "", [""]], ["_localize", false, [false]]];
if (_message isEqualTo "") exitWith {};
// SEC (audit 2026-09-26): any client may send this, and the local spawns below read isRemoteExecuted false, so pass
// fn_handleMessage its untrusted flag -- else a client's text lands in the duty-refusal tap as the server's answer.
private _untrusted = isRemoteExecuted && {remoteExecutedOwner != 2};
// Streamer Mode: filter server-wide broadcasts (e.g. ANN/SERVER NEWS) before they hit this client's screen.
// Only the non-localize path uses the raw _message; localize entries are stringtable game text (no user input).
if (hasInterface && {!isNil "AP_streamerMode"} && {AP_streamerMode} && {_message isEqualType ""}) then { _message = [_message] call AP_fnc_profanityFilter; };
if (_localize) exitWith {private _arr = _this select 3;
    private _msg =
    switch (count _arr) do {case 0: {localize _message;};
        case 1: {format[localize _message, _arr select 0];};
        case 2: {format[localize _message, _arr select 0, _arr select 1];};
        case 3: {format[localize _message, _arr select 0, _arr select 1, _arr select 2];};
        case 4: {format[localize _message, _arr select 0, _arr select 1, _arr select 2, _arr select 3];};}; if (_type isEqualType[]) then {
        for "_i"
        from 0 to(count _type) - 1 do {switch ((_type select _i)) do {case 0: {systemChat _msg;};
                case 1: {[_msg, "basic", {true}, _untrusted] spawn AP_fnc_handleMessage;};
                case 2: {titleText[_msg, "PLAIN DOWN"];};};};} else {switch (_type) do {case 0: {systemChat _msg;};
            case 1: {[_msg, "basic", {true}, _untrusted] spawn AP_fnc_handleMessage;};
            case 2: {titleText[_msg, "PLAIN DOWN"];};};};};
if (_type isEqualType[]) then {for "_i"
    from 0 to(count _type) - 1 do {switch ((_type select _i)) do {case 0: {systemChat _message};
            case 1: {[format["%1", _message], "basic", {true}, _untrusted] spawn AP_fnc_handleMessage;};
            case 2: {titleText[format["%1", _message], "PLAIN DOWN"];};};};} else {switch (_type) do {case 0: {systemChat _message};
        case 1: {[format["%1", _message], "basic", {true}, _untrusted] spawn AP_fnc_handleMessage;};
        case 2: {titleText[format["%1", _message], "PLAIN DOWN"];};

        case 5: {["cartelEventAlert", [format["%1", _message]]] call BIS_fnc_showNotification;};};};