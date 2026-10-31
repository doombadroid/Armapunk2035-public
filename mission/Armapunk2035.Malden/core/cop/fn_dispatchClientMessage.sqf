if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params[["_type", -2, [0]], ["_senderName", "", [""]], ["_message", "", [""]], ["_senderObj", objNull, [objNull]], ["_senderCopLvl", 0, [0]]];
if (_type isEqualTo - 2 || _senderName isEqualTo "" || _message isEqualTo "" || _senderObj isEqualTo player || _senderCopLvl isEqualTo 0) exitWith {};
switch (_type) do {case 0: {
            [format["<t color='#316dff'><t size='1.8'><t align='center'>New Dispatch<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>All Officers<br/><t color='#33CC33'>From: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", _senderName, _message], "copmsg"] spawn AP_fnc_handleMessage;
            systemChat format["---POLICE DISPATCH FROM %1: %2", _senderName, _message];
            [_senderName, getPosATL _senderObj, " Backup request -", "colorBLUFOR", "mil_warning", 120] spawn AP_fnc_createLMarker;
            AP_messages pushBack[_senderName, format["---POLICE DISPATCH FROM %1: %2", _senderName, _message], time];};
    case 1: {if (call AP_copLevel <= _senderCopLvl) exitWith {};
            [format["<t color='#316dff'><t size='1.8'><t align='center'>New Dispatch<br/><br/><t color='#33CC33'><t align='left'><t size='0.8'>To: <t color='#ffffff'>All Officers<br/><t color='#33CC33'>From: <t color='#ffffff'>%1<br/><br/><t color='#33CC33'>Message:<br/><t color='#ffffff'>%2", _senderName, _message], "copmsg"] spawn AP_fnc_handleMessage;
            systemChat format["---POLICE DISPATCH FROM %1: %2", _senderName, _message];
            [_senderName, getPosATL _senderObj, " Superior request -", "colorBLUFOR", "mil_end", 120] spawn AP_fnc_createLMarker;
            AP_messages pushBack[_senderName, format["---POLICE DISPATCH FROM %1: %2", _senderName, _message], time];};};