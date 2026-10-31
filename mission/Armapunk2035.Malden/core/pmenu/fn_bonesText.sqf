/*
    AP_fnc_bonesText  (client) -- an incoming text from Ben Bones Official. Server pushes the reply here.
    Styled notification + drops into the phone inbox (AP_messages) like any other text.
*/
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {};   // server-origin only: CfgRE allowedTargets limits the target, never the sender
params [["_msg", "", [""]]];
if (_msg isEqualTo "") exitWith {};
AP_messages pushBack ["Ben Bones Official", format [">>>MESSAGE FROM Ben Bones Official: %1", _msg], time];
[format ["<t size='1.25' color='#e8b23a'>Ben Bones Official</t><br/><t size='1.05'>%1</t>", _msg], "bones"] spawn AP_fnc_handleMessage;
