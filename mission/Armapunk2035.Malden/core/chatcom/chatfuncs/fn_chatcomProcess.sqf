if ((_this select 1) != 28) exitWith {false};
private _chatmsg = ctrlText(finddisplay 24 displayctrl 101);
if ((getText(getMissionConfig "rwt_chatcom" >> "specialchar")) != (_chatmsg select[0, 1])) exitWith {false};
(finddisplay 24 displayctrl 101) ctrlSetText "";
closeDialog 0;
(findDisplay 24) displayRemoveEventHandler["KeyDown", rwt_chatcom_chat_eh];
(findDisplay 24) closeDisplay 1;
(_chatmsg splitString "! ") call RWT_fnc_chatcomExec;
true;